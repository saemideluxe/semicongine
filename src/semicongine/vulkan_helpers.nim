import std/tables
import std/strutils
import std/strformat
import std/logging
import std/macros

import ./vulkan
import ./window

# the included code need checkVkResult, therefore having the template above
when defined(linux):
  include ./platform/linux/vulkan
when defined(windows):
  include ./platform/windows/vulkan

const ENABLEVULKANVALIDATIONLAYERS* = not defined(release)

func addrOrNil[T](obj: var openArray[T]): ptr T =
  if obj.len > 0: addr(obj[0]) else: nil

func VK_MAKE_API_VERSION*(variant: uint32, major: uint32, minor: uint32,
    patch: uint32): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch


func filterForSurfaceFormat*(formats: seq[VkSurfaceFormatKHR]): seq[
    VkSurfaceFormatKHR] =
  for format in formats:
    if format.format == VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR:
      result.add(format)

func getSuitableSurfaceFormat*(formats: seq[
    VkSurfaceFormatKHR]): VkSurfaceFormatKHR =
  let usableSurfaceFormats = filterForSurfaceFormat(formats)
  if len(usableSurfaceFormats) == 0:
    raise newException(Exception, "No suitable surface formats found")
  return usableSurfaceFormats[0]


func cleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

proc getInstanceExtensions*(): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(
      extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(
      extensionCount), addrOrNil(extensions))

  for extension in extensions:
    result.add(cleanString(extension.extensionName))


proc getDeviceExtensions*(device: VkPhysicalDevice): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(
      extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(
      extensionCount), addrOrNil(extensions))

  for extension in extensions:
    result.add(cleanString(extension.extensionName))


proc getValidationLayers*(): seq[string] =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  var layers = newSeq[VkLayerProperties](n_layers)
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), addrOrNil(layers))

  for layer in layers:
    result.add(cleanString(layer.layerName))


proc getVulkanPhysicalDevices*(instance: VkInstance): seq[VkPhysicalDevice] =
  var n_devices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(n_devices), nil)
  result = newSeq[VkPhysicalDevice](n_devices)
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(n_devices), addrOrNil(result))


proc getQueueFamilies*(device: VkPhysicalDevice): seq[VkQueueFamilyProperties] =
  var n_queuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(n_queuefamilies), nil)
  result = newSeq[VkQueueFamilyProperties](n_queuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(n_queuefamilies),
      addrOrNil(result))


proc getDeviceSurfaceFormats*(device: VkPhysicalDevice,
    surface: VkSurfaceKHR): seq[VkSurfaceFormatKHR] =
  var n_formats: uint32
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, addr(
      n_formats), nil)
  result = newSeq[VkSurfaceFormatKHR](n_formats)
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, addr(
      n_formats), addrOrNil(result))


proc getDeviceSurfacePresentModes*(device: VkPhysicalDevice,
    surface: VkSurfaceKHR): seq[VkPresentModeKHR] =
  var n_modes: uint32
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, addr(
      n_modes), nil)
  result = newSeq[VkPresentModeKHR](n_modes)
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, addr(
      n_modes), addrOrNil(result))


proc getSwapChainImages*(device: VkDevice, swapChain: VkSwapchainKHR): seq[VkImage] =
  var n_images: uint32
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), nil)
  result = newSeq[VkImage](n_images)
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), addr(
      result[0]))


func getPresentMode*(modes: seq[VkPresentModeKHR]): VkPresentModeKHR =
  let preferredModes = [
    VK_PRESENT_MODE_MAILBOX_KHR,      # triple buffering
    VK_PRESENT_MODE_FIFO_RELAXED_KHR, # double duffering
    VK_PRESENT_MODE_FIFO_KHR,         # double duffering
    VK_PRESENT_MODE_IMMEDIATE_KHR,    # single buffering
  ]
  for preferredMode in preferredModes:
    for mode in modes:
      if preferredMode == mode:
        return mode
  # should never be reached, but seems to be garuanteed by vulkan specs to always be available
  return VK_PRESENT_MODE_FIFO_KHR


proc createVulkanInstance*(vulkanVersion: uint32): VkInstance =

  var requiredExtensions = @["VK_KHR_surface".cstring] & REQUIRED_PLATFORM_EXTENSIONS
  when ENABLEVULKANVALIDATIONLAYERS:
    requiredExtensions.add("VK_EXT_debug_utils".cstring)

  let availableExtensions = getInstanceExtensions()
  for extension in requiredExtensions:
    assert $extension in availableExtensions, $extension

  let availableLayers = getValidationLayers()
  var usableLayers = newSeq[cstring]()

  when ENABLEVULKANVALIDATIONLAYERS:
    const desiredLayers = ["VK_LAYER_KHRONOS_validation".cstring,
        "VK_LAYER_MESA_overlay".cstring]
  else:
    const desiredLayers: array[0, string] = []
  for layer in desiredLayers:
    if $layer in availableLayers:
      usableLayers.add(layer)

  echo "Available validation layers: ", availableLayers
  echo "Using validation layers: ", usableLayers
  echo "Available extensions: ", availableExtensions
  echo "Using extensions: ", requiredExtensions

  var appinfo = VkApplicationInfo(
    sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
    pApplicationName: "Hello Triangle",
    pEngineName: "Custom engine",
    apiVersion: vulkanVersion,
  )
  var createinfo = VkInstanceCreateInfo(
    sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    pApplicationInfo: addr(appinfo),
    enabledLayerCount: usableLayers.len.uint32,
    ppEnabledLayerNames: cast[ptr UncheckedArray[cstring]](addrOrNil(
        usableLayers)),
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: cast[ptr UncheckedArray[cstring]](addr(
        requiredExtensions[0]))
  )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result))
  for extension in requiredExtensions:
    result.loadExtension($extension)

  # loadVK_KHR_surface(result)
  # loadVK_KHR_swapchain(result)
  when ENABLEVULKANVALIDATIONLAYERS:
    loadVK_EXT_debug_utils(result)


proc getVulcanDevice*(
  physicalDevice: var VkPhysicalDevice,
  features: var VkPhysicalDeviceFeatures,
  graphicsQueueFamily: uint32,
  presentationQueueFamily: uint32,
): (VkDevice, VkQueue, VkQueue) =
  # setup queue and device
  # TODO: need check this, possibly wrong logic, see Vulkan tutorial
  var priority = 1.0'f32
  var queueCreateInfo = [
    VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: graphicsQueueFamily,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    ),
  ]

  var requiredExtensions = ["VK_KHR_swapchain".cstring]
  var deviceCreateInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: uint32(queueCreateInfo.len),
    pQueueCreateInfos: addrOrNil(queueCreateInfo),
    pEnabledFeatures: addr(features),
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: cast[ptr UncheckedArray[cstring]](addr(requiredExtensions))
  )
  checkVkResult vkCreateDevice(physicalDevice, addr(deviceCreateInfo), nil,
      addr(result[0]))
  vkGetDeviceQueue(result[0], graphicsQueueFamily, 0'u32, addr(result[1]))
  vkGetDeviceQueue(result[0], presentationQueueFamily, 0'u32, addr(result[2]))

proc debugCallback*(
  messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
  messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
  pCallbackData: VkDebugUtilsMessengerCallbackDataEXT,
  userData: pointer
): bool {.cdecl.} =
  echo &"{messageSeverity}: {VkDebugUtilsMessageTypeFlagBitsEXT(messageTypes)}: {pCallbackData.pMessage}"
  return false

proc getSurfaceCapabilities*(device: VkPhysicalDevice,
    surface: VkSurfaceKHR): VkSurfaceCapabilitiesKHR =
  checkVkResult device.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(surface, addr(result))
