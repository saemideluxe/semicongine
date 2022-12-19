import std/tables
import std/strutils
import std/strformat
import std/logging

import ./glslang/glslang
import ./vulkan

when defined(release):
  const ENABLEVULKANVALIDATIONLAYERS* = false
else:
  const ENABLEVULKANVALIDATIONLAYERS* = true


template checkVkResult*(call: untyped) =
  when defined(release):
    discard call
  else:
    debug(&"CALLING vulkan: {astToStr(call)}")
    let value = call
    if value != VK_SUCCESS:
      raise newException(Exception, "Vulkan error: " & astToStr(call) & " returned " & $value)


proc VK_MAKE_API_VERSION*(variant: uint32, major: uint32, minor: uint32, patch: uint32): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch


proc filterForSurfaceFormat*(formats: seq[VkSurfaceFormatKHR]): seq[VkSurfaceFormatKHR] =
  for format in formats:
    if format.format == VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR:
      result.add(format)

proc getSuitableSurfaceFormat*(formats: seq[VkSurfaceFormatKHR]): VkSurfaceFormatKHR =
  let usableSurfaceFormats = filterForSurfaceFormat(formats)
  if len(usableSurfaceFormats) == 0:
    raise newException(Exception, "No suitable surface formats found")
  return usableSurfaceFormats[0]


proc cleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

proc getInstanceExtensions*(): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), addr(extensions[0]))

  for extension in extensions:
    result.add(cleanString(extension.extensionName))


proc getDeviceExtensions*(device: VkPhysicalDevice): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), addr(extensions[0]))

  for extension in extensions:
    result.add(cleanString(extension.extensionName))


proc getValidationLayers*(): seq[string] =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  var layers = newSeq[VkLayerProperties](n_layers)
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), addr(layers[0]))

  for layer in layers:
    result.add(cleanString(layer.layerName))


proc getVulkanPhysicalDevices*(instance: VkInstance): seq[VkPhysicalDevice] =
  var n_devices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(n_devices), nil)
  result = newSeq[VkPhysicalDevice](n_devices)
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(n_devices), addr(result[0]))


proc getQueueFamilies*(device: VkPhysicalDevice): seq[VkQueueFamilyProperties] =
  var n_queuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(n_queuefamilies), nil)
  result = newSeq[VkQueueFamilyProperties](n_queuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(n_queuefamilies), addr(result[0]))


proc getDeviceSurfaceFormats*(device: VkPhysicalDevice, surface: VkSurfaceKHR): seq[VkSurfaceFormatKHR] =
  var n_formats: uint32
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, addr(n_formats), nil);
  result = newSeq[VkSurfaceFormatKHR](n_formats)
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, addr(n_formats), addr(result[0]))


proc getDeviceSurfacePresentModes*(device: VkPhysicalDevice, surface: VkSurfaceKHR): seq[VkPresentModeKHR] =
  var n_modes: uint32
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, addr(n_modes), nil);
  result = newSeq[VkPresentModeKHR](n_modes)
  checkVkResult vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, addr(n_modes), addr(result[0]))


proc getSwapChainImages*(device: VkDevice, swapChain: VkSwapchainKHR): seq[VkImage] =
  var n_images: uint32
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), nil);
  result = newSeq[VkImage](n_images)
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), addr(result[0]));


proc getPresentMode*(modes: seq[VkPresentModeKHR]): VkPresentModeKHR =
  let preferredModes = [
    VK_PRESENT_MODE_MAILBOX_KHR, # triple buffering
    VK_PRESENT_MODE_FIFO_RELAXED_KHR, # double duffering
    VK_PRESENT_MODE_FIFO_KHR, # double duffering
    VK_PRESENT_MODE_IMMEDIATE_KHR, # single buffering
  ]
  for preferredMode in preferredModes:
    for mode in modes:
      if preferredMode == mode:
        return mode
  # should never be reached, but seems to be garuanteed by vulkan specs to always be available
  return VK_PRESENT_MODE_FIFO_KHR


proc createVulkanInstance*(vulkanVersion: uint32): VkInstance =
  var requiredExtensions = [
    "VK_EXT_acquire_xlib_display".cstring,
    "VK_EXT_direct_mode_display".cstring,
    "VK_KHR_display".cstring,
    "VK_KHR_surface".cstring,
    "VK_KHR_xlib_surface".cstring,
    "VK_EXT_debug_utils".cstring,
  ]
  let availableExtensions = getInstanceExtensions()
  for extension in requiredExtensions:
    assert $extension in availableExtensions

  let desiredLayers = ["VK_LAYER_KHRONOS_validation".cstring, "VK_LAYER_MESA_overlay".cstring]
  let availableLayers = getValidationLayers()
  var usableLayers = newSeq[cstring]()

  when ENABLEVULKANVALIDATIONLAYERS:
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
    ppEnabledLayerNames: cast[ptr UncheckedArray[cstring]](addr(usableLayers[0])),
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: cast[ptr UncheckedArray[cstring]](addr(requiredExtensions))
  )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result))

  loadVK_KHR_surface()
  loadVK_KHR_xlib_surface()
  loadVK_KHR_swapchain()
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
    pQueueCreateInfos: addr(queueCreateInfo[0]),
    pEnabledFeatures: addr(features),
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: cast[ptr UncheckedArray[cstring]](addr(requiredExtensions))
  )
  checkVkResult vkCreateDevice(physicalDevice, addr(deviceCreateInfo), nil, addr(result[0]))
  vkGetDeviceQueue(result[0], graphicsQueueFamily, 0'u32, addr(result[1]));
  vkGetDeviceQueue(result[0], presentationQueueFamily, 0'u32, addr(result[2]));

proc createShaderStage*(device: VkDevice, stage: VkShaderStageFlagBits, shader: string): VkPipelineShaderStageCreateInfo =
  const VK_GLSL_MAP = {
    VK_SHADER_STAGE_VERTEX_BIT: GLSLANG_STAGE_VERTEX,
    VK_SHADER_STAGE_FRAGMENT_BIT: GLSLANG_STAGE_FRAGMENT,
  }.toTable()
  var code = compileGLSLToSPIRV(VK_GLSL_MAP[stage], shader, "<memory-shader>")
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(code.len * sizeof(uint32)),
    pCode: addr(code[0]),
  )
  var shaderModule: VkShaderModule
  checkVkResult vkCreateShaderModule(device, addr(createInfo), nil, addr(shaderModule))

  return VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: stage,
    module: shaderModule,
    pName: "main", # entry point for shader
  )

proc debugCallback*(
  messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
  messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
  pCallbackData: VkDebugUtilsMessengerCallbackDataEXT,
  userData: pointer
): VkBool32 {.cdecl.} =
  echo &"{messageSeverity}: {VkDebugUtilsMessageTypeFlagBitsEXT(messageTypes)}: {pCallbackData.pMessage}"
  return VK_FALSE
