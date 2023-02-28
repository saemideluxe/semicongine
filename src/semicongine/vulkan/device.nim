import std/sequtils
import std/options
import std/tables

import ./api
import ./utils
import ./instance
import ./surface

type
  PhysicalDevice* = object
    vk*: VkPhysicalDevice
  Device* = object
    physicalDevice*: PhysicalDevice
    vk*: VkDevice
    queues*: Table[QueueFamily, Queue]
  QueueFamily* = object
    properties*: VkQueueFamilyProperties
    index*: uint32
    flags*: seq[VkQueueFlagBits]
    presentation: bool
    # presentation is related to a specific surface, saving it here if provided during querying
    surface: Option[Surface]
  Queue* = object
    vk*: VkQueue

proc getPhysicalDevices*(instance: Instance): seq[PhysicalDevice] =
  assert instance.vk.valid
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), devices.toCPointer)
  for i in 0 ..< nDevices:
    result.add PhysicalDevice(vk: devices[i])

proc getExtensions*(device: PhysicalDevice): seq[string] =
  assert device.vk.valid
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), extensions.toCPointer)
    for extension in extensions:
      result.add(cleanString(extension.extensionName))

proc getSurfaceFormats*(device: PhysicalDevice, surface: Surface): seq[VkSurfaceFormatKHR] =
  assert device.vk.valid
  assert surface.vk.valid
  var n_formats: uint32
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, surface.vk, addr(n_formats), nil)
  result = newSeq[VkSurfaceFormatKHR](n_formats)
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, surface.vk, addr(n_formats), result.toCPointer)

proc getSurfacePresentModes*(device: PhysicalDevice, surface: Surface): seq[VkPresentModeKHR] =
  assert device.vk.valid
  assert surface.vk.valid
  var n_modes: uint32
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device.vk, surface.vk, addr(n_modes), nil)
  result = newSeq[VkPresentModeKHR](n_modes)
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device.vk, surface.vk, addr(n_modes), result.toCPointer)

proc getQueueFamilies*(device: PhysicalDevice): seq[QueueFamily] =
  assert device.vk.valid
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies , queuFamilies.toCPointer)
  for i in 0 ..< nQueuefamilies:
    result.add QueueFamily(
      properties: queuFamilies[i],
      index: i,
      flags: queuFamilies[i].queueFlags.toEnums,
      presentation: VkBool32(false),
    )

proc getQueueFamilies*(device: PhysicalDevice, surface: Surface): seq[QueueFamily] =
  assert device.vk.valid
  assert surface.vk.valid
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies , queuFamilies.toCPointer)
  for i in 0 ..< nQueuefamilies:
    var presentation = VkBool32(false)
    checkVkResult vkGetPhysicalDeviceSurfaceSupportKHR(device.vk, i, surface.vk, addr presentation)
    result.add QueueFamily(
      properties: queuFamilies[i],
      index: i,
      flags: queuFamilies[i].queueFlags.toEnums,
      surface: if presentation: some(surface) else: none(Surface),
      presentation: presentation,
    )

proc filterForGraphicsPresentationQueues*(families: seq[QueueFamily]): seq[QueueFamily] =
  var hasGraphics = false
  var hasPresentation = false
  var queues: Table[uint32, QueueFamily]
  for family in families:
    if VK_QUEUE_GRAPHICS_BIT in family.flags:
      queues[family.index] = family
      hasGraphics = true
    if family.presentation:
      queues[family.index] = family
      hasPresentation = true
    if hasGraphics and hasPresentation:
      return queues.values.toSeq

proc createDevice*(
  physicalDevice: PhysicalDevice,
  enabledLayers: openArray[string],
  enabledExtensions: openArray[string],
  queueFamilies: openArray[QueueFamily],
): Device =
  assert physicalDevice.vk.valid
  assert queueFamilies.len > 0
  result.physicalDevice = physicalDevice
  var
    enabledLayersC = allocCStringArray(enabledLayers)
    enabledExtensionsC = allocCStringArray(enabledExtensions)
    priority = 1'f32
  var deviceQueues: Table[QueueFamily, VkDeviceQueueCreateInfo]
  for family in queueFamilies:
    deviceQueues[family] = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: family.index,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )

  var queueList = deviceQueues.values.toSeq
  var createInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: uint32(queueList.len),
    pQueueCreateInfos: queueList.toCPointer,
    enabledLayerCount: uint32(enabledLayers.len),
    ppEnabledLayerNames: enabledLayersC,
    enabledExtensionCount: uint32(enabledExtensions.len),
    ppEnabledExtensionNames: enabledExtensionsC,
    pEnabledFeatures: nil,
  )

  checkVkResult vkCreateDevice(
    physicalDevice=physicalDevice.vk,
    pCreateInfo=addr createInfo,
    pAllocator=nil,
    pDevice=addr result.vk
  )
  deallocCStringArray(enabledLayersC)
  deallocCStringArray(enabledExtensionsC)
  for queueFamily in deviceQueues.keys:
    var queue: VkQueue
    vkGetDeviceQueue(result.vk, queueFamily.index, 0, addr queue)
    result.queues[queueFamily] = Queue(vk: queue)

func firstGraphicsQueue*(device: Device): Option[Queue] =
  for family, queue in device.queues:
    if VK_QUEUE_GRAPHICS_BIT in family.flags:
      return some(queue)

func firstPresentationQueue*(device: Device): Option[Queue] =
  for family, queue in device.queues:
    if family.presentation:
      return some(queue)

proc destroy*(device: var Device) =
  assert device.vk.valid
  device.vk.vkDestroyDevice(nil)
  device.vk.reset()
