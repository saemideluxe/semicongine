import std/tables
import std/strutils

import ./glslang/glslang
import ./vulkan


when defined(release):
  const ENABLEVULKANVALIDATIONLAYERS = false
else:
  const ENABLEVULKANVALIDATIONLAYERS = true


template checkVkResult*(call: untyped) =
  let value = call
  if value != VK_SUCCESS:
    raise newException(Exception, "Vulkan error: " & astToStr(call) & " returned " & $value)


proc VK_MAKE_API_VERSION*(variant: uint32, major: uint32, minor: uint32, patch: uint32): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch


proc getInstanceExtensions*(): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), addr(extensions[0]))

  for extension in extensions:
    result.add(join(extension.extensionName).strip(chars={char(0)}))


proc getDeviceExtensions*(device: VkPhysicalDevice): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), nil)
  var extensions = newSeq[VkExtensionProperties](extensionCount)
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), addr(extensions[0]))

  for extension in extensions:
    result.add(join(extension.extensionName).strip(chars={char(0)}))


proc getValidationLayers*(): seq[string] =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  var layers = newSeq[VkLayerProperties](n_layers)
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), addr(layers[0]))

  for layer in layers:
    result.add(join(layer.layerName).strip(chars={char(0)}))


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
    VK_PRESENT_MODE_MAILBOX_KHR,
    VK_PRESENT_MODE_FIFO_RELAXED_KHR,
    VK_PRESENT_MODE_FIFO_KHR,
    VK_PRESENT_MODE_IMMEDIATE_KHR,
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

  echo "Using validation layers: ", usableLayers
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


proc getVulcanDevice*(
  physicalDevice: var VkPhysicalDevice,
  features: var VkPhysicalDeviceFeatures,
  selectedQueueFamily: uint32,
): (VkDevice, VkQueue) =
  # setup queue and device
  var priority = 1.0'f32
  var queueCreateInfo = VkDeviceQueueCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    queueFamilyIndex: uint32(selectedQueueFamily),
    queueCount: 1,
    pQueuePriorities: addr(priority),
  )

  var requiredExtensions = ["VK_KHR_swapchain".cstring]
  var deviceCreateInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    pQueueCreateInfos: addr(queueCreateInfo),
    queueCreateInfoCount: 1,
    pEnabledFeatures: addr(features),
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: cast[ptr UncheckedArray[cstring]](addr(requiredExtensions))
  )
  checkVkResult vkCreateDevice(physicalDevice, addr(deviceCreateInfo), nil, addr(result[0]))
  vkGetDeviceQueue(result[0], selectedQueueFamily, 0'u32, addr(result[1]));

proc createShaderStage*(device: VkDevice, stage: VkShaderStageFlagBits, shader: string): VkPipelineShaderStageCreateInfo =
  const VK_GLSL_MAP = {
    VK_SHADER_STAGE_VERTEX_BIT: GLSLANG_STAGE_VERTEX,
    VK_SHADER_STAGE_FRAGMENT_BIT: GLSLANG_STAGE_FRAGMENT,
  }.toTable()
  var code = compileGLSLToSPIRV(VK_GLSL_MAP[stage], shader, "<memory-shader>")
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: code.len.uint,
    pCode: addr(code[0]),
  )
  var shaderModule: VkShaderModule
  checkVkResult vkCreateShaderModule(device, addr(createInfo), nil, addr(shaderModule))

  var vertShaderStageInfo = VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: stage,
    module: shaderModule,
    pName: "main", # entry point for shader
  )
