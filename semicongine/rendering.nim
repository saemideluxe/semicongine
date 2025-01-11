import std/logging
import std/hashes
import std/macros
import std/os
import std/sequtils
import std/strformat
import std/strutils
import std/typetraits

import ./core

import ./image

# in this file:
# - const defintions for rendering
# - custom pragma defintions for rendering
# - type defintions for rendering
# - some utils code that is used in mutiple rendering files
# - inclusion of all rendering files

# there is a big, bad global vulkan object
# believe me, this makes everything much, much easier

when defined(windows):
  include ./rendering/platform/windows
when defined(linux):
  include ./rendering/platform/linux

import ../semicongine/rendering/memory
import ../semicongine/rendering/renderer
import ../semicongine/rendering/swapchain
import ../semicongine/rendering/shaders
import ../semicongine/rendering/renderpasses
import ../semicongine/rendering/vulkan_wrappers
export memory
export renderer
export swapchain
export shaders
export renderpasses
export vulkan_wrappers

proc debugCallback(
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
    userData: pointer,
): VkBool32 {.cdecl.} =
  const LOG_LEVEL_MAPPING = {
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT: lvlDebug,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT: lvlInfo,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT: lvlWarn,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT: lvlError,
  }.toTable
  log LOG_LEVEL_MAPPING[messageSeverity],
    &"{toEnums messageTypes}: {pCallbackData.pMessage}"
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    stderr.writeLine "-----------------------------------"
    stderr.write getStackTrace()
    stderr.writeLine LOG_LEVEL_MAPPING[messageSeverity],
      &"{toEnums messageTypes}: {pCallbackData.pMessage}"
    stderr.writeLine "-----------------------------------"
    let errorMsg =
      getStackTrace() & &"\n{toEnums messageTypes}: {pCallbackData.pMessage}"
    raise newException(Exception, errorMsg)
  return false

proc initVulkan*(appName: string = "semicongine app"): VulkanObject =
  # instance creation

  # enagle all kind of debug stuff
  when not defined(release):
    let requiredExtensions =
      REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface", "VK_EXT_debug_utils"]
    let layers: seq[string] =
      if hasValidationLayer():
        @["VK_LAYER_KHRONOS_validation"]
      else:
        @[]
    putEnv(
      "VK_LAYER_ENABLES",
      "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT",
    )
  else:
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface"]
    let layers: seq[string] = @[]

  var
    layersC = allocCStringArray(layers)
    instanceExtensionsC = allocCStringArray(requiredExtensions)
  defer:
    deallocCStringArray(layersC)
    deallocCStringArray(instanceExtensionsC)

  var
    appinfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: appName,
      pEngineName: "semicongine",
      apiVersion: VK_MAKE_API_VERSION(0, 1, 3, 0),
    )
    createinfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: addr(appinfo),
      enabledLayerCount: layers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: requiredExtensions.len.uint32,
      ppEnabledExtensionNames: instanceExtensionsC,
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result.instance))
  loadVulkan(result.instance)

  # load extensions
  #
  for extension in requiredExtensions:
    loadExtension(result.instance, $extension)
  result.window = createWindow(appName)
  result.surface = createNativeSurface(result.instance, result.window)

  # logical device creation

  # TODO: allowing support for physical devices without hasUniformBufferStandardLayout
  # would require us to ship different shaders, so we don't support standard layout
  # if that will be added, check the function vulkan/shaders.nim:glslUniforms and update accordingly
  # let hasUniformBufferStandardLayout = "VK_KHR_uniform_buffer_standard_layout" in physicalDevice.getExtensions()
  # var deviceExtensions  = @["VK_KHR_swapchain", "VK_KHR_uniform_buffer_standard_layout"]
  var deviceExtensions = @["VK_KHR_swapchain"]
  for extension in deviceExtensions:
    loadExtension(result.instance, extension)

  when not defined(release):
    var debugMessengerCreateInfo = VkDebugUtilsMessengerCreateInfoEXT(
      sType: VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
      messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT.items.toSeq.toBits,
      messageType: VkDebugUtilsMessageTypeFlagBitsEXT.items.toSeq.toBits,
      pfnUserCallback: debugCallback,
      pUserData: nil,
    )
    checkVkResult vkCreateDebugUtilsMessengerEXT(
      result.instance, addr(debugMessengerCreateInfo), nil, addr(result.debugMessenger)
    )

  # get physical device and graphics queue family
  result.physicalDevice = getBestPhysicalDevice(result.instance)
  result.graphicsQueueFamily =
    getQueueFamily(result.physicalDevice, result.surface, VK_QUEUE_GRAPHICS_BIT)

  let
    priority = cfloat(1)
    queueInfo = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: result.graphicsQueueFamily,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )
    deviceExtensionsC = allocCStringArray(deviceExtensions)
  defer:
    deallocCStringArray(deviceExtensionsC)
  let enabledFeatures = VkPhysicalDeviceFeatures(
    fillModeNonSolid: true, depthClamp: true, wideLines: true, largePoints: true
  )
  var createDeviceInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: 1,
    pQueueCreateInfos: addr(queueInfo),
    enabledLayerCount: 0,
    ppEnabledLayerNames: nil,
    enabledExtensionCount: uint32(deviceExtensions.len),
    ppEnabledExtensionNames: deviceExtensionsC,
    pEnabledFeatures: addr(enabledFeatures),
  )
  checkVkResult vkCreateDevice(
    physicalDevice = result.physicalDevice,
    pCreateInfo = addr createDeviceInfo,
    pAllocator = nil,
    pDevice = addr result.device,
  )
  result.graphicsQueue =
    svkGetDeviceQueue(result.device, result.graphicsQueueFamily, VK_QUEUE_GRAPHICS_BIT)

proc destroyVulkan*() =
  if engine().vulkan.swapchain != nil:
    clearSwapchain()
  vkDestroyDevice(engine().vulkan.device, nil)
  vkDestroySurfaceKHR(engine().vulkan.instance, engine().vulkan.surface, nil)
  if engine().vulkan.debugMessenger.Valid:
    vkDestroyDebugUtilsMessengerEXT(
      engine().vulkan.instance, engine().vulkan.debugMessenger, nil
    )
  vkDestroyInstance(engine().vulkan.instance, nil)
  destroyWindow(engine().vulkan.window)

proc showSystemCursor*(value: bool) =
  engine().vulkan.window.showSystemCursor(value)

proc fullscreen*(): bool =
  engine().vulkan.fullscreen_internal

proc setFullscreen*(enable: bool) =
  if enable != engine().vulkan.fullscreen_internal:
    engine().vulkan.fullscreen_internal = enable
    engine().vulkan.window.setFullscreen(engine().vulkan.fullscreen_internal)

proc getAspectRatio*(): float32 =
  assert engine().vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  engine().vulkan.swapchain.width.float32 / engine().vulkan.swapchain.height.float32

proc maxFramebufferSampleCount*(
    maxSamples = VK_SAMPLE_COUNT_8_BIT
): VkSampleCountFlagBits =
  let limits = svkGetPhysicalDeviceProperties().limits
  let available = VkSampleCountFlags(
    limits.framebufferColorSampleCounts.uint32 and
      limits.framebufferDepthSampleCounts.uint32
  ).toEnums
  return min(max(available), maxSamples)
