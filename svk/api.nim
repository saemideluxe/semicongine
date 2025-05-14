import std/tables
import std/strutils
import std/logging
import std/os

include ./vkapi

const VULKAN_VERSION = VK_MAKE_API_VERSION(0, 1, 3, 0)

template checkVkResult*(call: untyped) =
  when defined(release):
    discard call
  else:
    # yes, a bit cheap, but this is only for nice debug output
    var callstr = astToStr(call).replace("\n", "")
    while callstr.find("  ") >= 0:
      callstr = callstr.replace("  ", " ")
    debug "Calling vulkan: ", callstr
    let value = call
    if value != VK_SUCCESS:
      error "Vulkan error: ", astToStr(call), " returned ", $value
      raise newException(
        Exception, "Vulkan error: " & astToStr(call) & " returned " & $value
      )

type SVkInstance* = object
  vkInstance: VkInstance
  debugMessenger: VkDebugUtilsMessengerEXT

proc `=copy`(a: var SVkInstance, b: SVkInstance) {.error.}

proc `=destroy`(a: SVkInstance) =
  if a.vkInstance.pointer != nil:
    if a.debugMessenger.pointer != nil:
      vkDestroyDebugUtilsMessengerEXT(a.vkInstance, a.debugMessenger, nil)
    a.vkInstance.vkDestroyInstance(nil)

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
  log LOG_LEVEL_MAPPING[messageSeverity]
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    # stderr.write getStackTrace()
    # stderr.writeLine LOG_LEVEL_MAPPING[messageSeverity], &"{toEnums messageTypes}: {pCallbackData.pMessage}"
    let errorMsg = $pCallbackData.pMessage & ": " & getStackTrace()
    raise newException(Exception, errorMsg)
  return VK_FALSE

proc svkCreateInstance*(
    applicationName: string,
    enabledLayers: openArray[string] = [],
    enabledExtensions: openArray[string] =
      if defined(release):
        @["VK_KHR_surface"]
      else:
        @["VK_KHR_surface", "VK_EXT_debug_utils"],
    engineName = "semicongine",
    withSwapchain = true,
): SVkInstance =
  putEnv("VK_LOADER_LAYERS_ENABLE", "*validation")
  putEnv(
    "VK_LAYER_ENABLES",
    "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT",
  )
  initVulkanLoader()

  let
    appinfo = VkApplicationInfo(
      pApplicationName: applicationName,
      pEngineName: engineName,
      apiVersion: VULKAN_VERSION,
    )
    enabledLayersC = allocCStringArray(enabledLayers)
    enabledExtensionsC = allocCStringArray(enabledExtensions)
    createinfo = VkInstanceCreateInfo(
      pApplicationInfo: addr appinfo,
      enabledLayerCount: enabledLayers.len.uint32,
      ppEnabledLayerNames: enabledLayersC,
      enabledExtensionCount: enabledExtensions.len.uint32,
      ppEnabledExtensionNames: enabledExtensionsC,
    )
  checkVkResult vkCreateInstance(addr createinfo, nil, addr result.vkInstance)

  enabledLayersC.deallocCStringArray()
  enabledExtensionsC.deallocCStringArray()

  load_VK_VERSION_1_0(result.vkInstance)
  load_VK_VERSION_1_1(result.vkInstance)
  load_VK_VERSION_1_2(result.vkInstance)
  load_VK_VERSION_1_3(result.vkInstance)

  for extension in enabledExtensions:
    loadExtension(result.vkInstance, extension)
  if withSwapchain:
    load_VK_KHR_swapchain(result.vkInstance)

  when not defined(release):
    var debugMessengerCreateInfo = VkDebugUtilsMessengerCreateInfoEXT(
      messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT.items.toSeq.toBits,
      messageType: VkDebugUtilsMessageTypeFlagBitsEXT.items.toSeq.toBits,
      pfnUserCallback: debugCallback,
    )
    checkVkResult vkCreateDebugUtilsMessengerEXT(
      result.vkInstance, addr debugMessengerCreateInfo, nil, addr result.debugMessenger
    )
