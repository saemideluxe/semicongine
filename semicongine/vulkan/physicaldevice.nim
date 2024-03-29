from std/enumerate import enumerate
import std/tables
import std/sequtils

import ../core
import ./instance

type
  PhysicalDevice* = object
    vk*: VkPhysicalDevice
    name*: string
    devicetype*: VkPhysicalDeviceType
    surface*: VkSurfaceKHR
    properties*: VkPhysicalDeviceProperties
    features*: VkPhysicalDeviceFeatures2
  QueueFamily* = object
    device: PhysicalDevice
    properties*: VkQueueFamilyProperties
    index*: uint32
    flags*: seq[VkQueueFlagBits]

func `$`*(device: PhysicalDevice): string =
  "Physical device: vk=" & $device.vk & ", name=" & $device.name & ", devicetype=" & $device.devicetype

proc getPhysicalDevices*(instance: Instance): seq[PhysicalDevice] =
  assert instance.vk.valid
  assert instance.surface.valid
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), devices.toCPointer)
  for i in 0 ..< nDevices:
    var device = PhysicalDevice(vk: devices[i], surface: instance.surface)
    device.vk.vkGetPhysicalDeviceProperties(addr device.properties)
    device.features.stype = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
    device.vk.vkGetPhysicalDeviceFeatures2(addr device.features)
    device.name = device.properties.deviceName.cleanString()
    device.devicetype = device.properties.deviceType
    result.add device

proc getExtensions*(device: PhysicalDevice): seq[string] =
  assert device.vk.valid
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), extensions.toCPointer)
    for extension in extensions:
      result.add(cleanString(extension.extensionName))

proc getSurfaceCapabilities*(device: PhysicalDevice): VkSurfaceCapabilitiesKHR =
  assert device.vk.valid
  assert device.surface.valid
  checkVkResult device.vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.surface, addr(result))

proc getSurfaceFormats*(device: PhysicalDevice): seq[VkSurfaceFormatKHR] =
  assert device.vk.valid
  assert device.surface.valid
  var n_formats: uint32
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, device.surface, addr(n_formats), nil)
  result = newSeq[VkSurfaceFormatKHR](n_formats)
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, device.surface, addr(n_formats), result.toCPointer)

func filterSurfaceFormat*(
  formats: seq[VkSurfaceFormatKHR],
  imageFormat = VK_FORMAT_B8G8R8A8_SRGB,
  colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
): VkSurfaceFormatKHR =
  for format in formats:
    if format.format == imageFormat and format.colorSpace == colorSpace:
      return format

proc filterSurfaceFormat*(device: PhysicalDevice): VkSurfaceFormatKHR =
  assert device.vk.valid
  assert device.surface.valid
  device.getSurfaceFormats().filterSurfaceFormat()

proc getSurfacePresentModes*(device: PhysicalDevice): seq[VkPresentModeKHR] =
  assert device.vk.valid
  assert device.surface.valid
  var n_modes: uint32
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device.vk, device.surface, addr(n_modes), nil)
  result = newSeq[VkPresentModeKHR](n_modes)
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device.vk, device.surface, addr(n_modes), result.toCPointer)

proc getQueueFamilies*(device: PhysicalDevice): seq[QueueFamily] =
  assert device.vk.valid
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, queuFamilies.toCPointer)
  for i in 0 ..< nQueuefamilies:
    result.add QueueFamily(
      device: device,
      properties: queuFamilies[i],
      index: i,
      flags: queuFamilies[i].queueFlags.toEnums,
    )

proc canDoGraphics*(family: QueueFamily): bool =
  VK_QUEUE_GRAPHICS_BIT in family.flags

proc canDoPresentation*(family: QueueFamily, surface: VkSurfaceKHR): bool =
  assert surface.valid
  var presentation = VkBool32(false)
  checkVkResult vkGetPhysicalDeviceSurfaceSupportKHR(family.device.vk, family.index, surface, addr presentation)
  return bool(presentation)

proc canDoTransfer*(family: QueueFamily): bool =
  VK_QUEUE_TRANSFER_BIT in family.flags

proc filterForGraphicsPresentationQueues*(device: PhysicalDevice): seq[QueueFamily] =
  var canDoGraphics = false
  var canDoPresentation = false
  var queues: Table[uint32, QueueFamily]
  for family in device.getQueueFamilies():
    if family.canDoGraphics:
      queues[family.index] = family
      canDoGraphics = true
    if family.canDoPresentation(device.surface):
      queues[family.index] = family
      canDoPresentation = true
    if canDoGraphics and canDoPresentation:
      return queues.values.toSeq

proc filterGraphics(families: seq[QueueFamily]): seq[QueueFamily] =
  for family in families:
    if family.canDoGraphics:
      result.add family

proc filterPresentation(families: seq[QueueFamily], surface: VkSurfaceKHR): seq[QueueFamily] =
  assert surface.valid
  for family in families:
    if family.canDoPresentation(surface):
      result.add family

proc rateGraphics*(device: PhysicalDevice): float =
  assert device.vk.valid
  assert device.surface.valid
  if device.getQueueFamilies().filterGraphics().filterPresentation(device.surface).len == 0:
    return -1
  if not ("VK_KHR_swapchain" in device.getExtensions()):
    return -1
  const deviceTypeMap = [
    VK_PHYSICAL_DEVICE_TYPE_OTHER,
    VK_PHYSICAL_DEVICE_TYPE_CPU,
    VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU,
    VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU,
    VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU,
  ]
  for (i, devicetype) in enumerate(deviceTypeMap):
    if device.devicetype == devicetype:
      result = float(i)

proc filterBestGraphics*(devices: seq[PhysicalDevice]): PhysicalDevice =
  var bestVal = -1'f
  for device in devices:
    assert device.vk.valid
    assert device.surface.valid
    let rating = device.rateGraphics()
    if rating > bestVal:
      bestVal = rating
      result = device
  assert bestVal >= 0
