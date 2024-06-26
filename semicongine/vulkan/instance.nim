import std/strformat
import std/tables
import std/sequtils
import std/logging

import ../core

import ../platform/vulkanExtensions
import ../platform/window
import ../platform/surface

type
  Instance* = object
    vk*: VkInstance
    window*: NativeWindow
    surface*: VkSurfaceKHR
  Debugger* = object
    instance*: Instance
    messenger*: VkDebugUtilsMessengerEXT
  DebugCallback* = proc (
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
    userData: pointer
  ): VkBool32 {.cdecl.}

proc GetInstanceExtensions*(): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), extensions.ToCPointer)
    for extension in extensions:
      result.add(CleanString(extension.extensionName))

proc GetLayers*(): seq[string] =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  if n_layers > 0:
    var layers = newSeq[VkLayerProperties](n_layers)
    checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), layers.ToCPointer)
    for layer in layers:
      result.add(CleanString(layer.layerName))

proc CreateInstance*(
  window: NativeWindow,
  vulkanVersion: uint32,
  instanceExtensions: seq[string],
  layers: seq[string],
  name = "defaultVulkanInstance",
  engine = "defaultEngine",
): Instance =

  let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface"] & instanceExtensions
  for i in requiredExtensions:
    assert i in GetInstanceExtensions(), $i
  var availableLayers: seq[string]
  for i in layers:
    if i in GetLayers():
      availableLayers.add i
  debug "Enabled layers: " & $availableLayers
  var
    layersC = allocCStringArray(availableLayers)
    instanceExtensionsC = allocCStringArray(requiredExtensions)
    appinfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: name,
      pEngineName: engine,
      apiVersion: vulkanVersion,
    )
    createinfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: addr(appinfo),
      enabledLayerCount: availableLayers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: requiredExtensions.len.uint32,
      ppEnabledExtensionNames: instanceExtensionsC
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result.vk))
  result.vk.loadVulkan()
  deallocCStringArray(layersC)
  deallocCStringArray(instanceExtensionsC)
  for extension in requiredExtensions:
    result.vk.loadExtension($extension)
  result.surface = result.vk.CreateNativeSurface(window)

proc Destroy*(instance: var Instance) =
  assert instance.vk.Valid
  assert instance.surface.Valid
  # needs to happen after window is trashed as the driver might have a hook registered for the window destruction
  instance.vk.vkDestroySurfaceKHR(instance.surface, nil)
  instance.surface.Reset()
  instance.vk.vkDestroyInstance(nil)
  instance.vk.Reset()

const LEVEL_MAPPING = {
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT: lvlDebug,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT: lvlInfo,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT: lvlWarn,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT: lvlError,
}.toTable

proc defaultDebugCallback(
  messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
  messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
  pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
  userData: pointer
): VkBool32 {.cdecl.} =

  log LEVEL_MAPPING[messageSeverity], &"{toEnums messageTypes}: {pCallbackData.pMessage}"
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    let errorMsg = getStackTrace() & &"\n{toEnums messageTypes}: {pCallbackData.pMessage}"
    raise newException(Exception, errorMsg)
  return false

proc CreateDebugMessenger*(
  instance: Instance,
  severityLevels: openArray[VkDebugUtilsMessageSeverityFlagBitsEXT] = @[],
  types: openArray[VkDebugUtilsMessageTypeFlagBitsEXT] = @[],
  callback: DebugCallback = defaultDebugCallback
): Debugger =
  assert instance.vk.Valid
  result.instance = instance
  var severityLevelBits = VkDebugUtilsMessageSeverityFlagBitsEXT.items.toSeq.toBits
  var typeBits = VkDebugUtilsMessageTypeFlagBitsEXT.items.toSeq.toBits
  if severityLevels.len > 0:
    severityLevelBits = toBits severityLevels
  if types.len > 0:
    typeBits = toBits types
  var createInfo = VkDebugUtilsMessengerCreateInfoEXT(
    sType: VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
    messageSeverity: severityLevelBits,
    messageType: typeBits,
    pfnUserCallback: callback,
    pUserData: nil,
  )
  checkVkResult instance.vk.vkCreateDebugUtilsMessengerEXT(addr(createInfo), nil, addr(result.messenger))

proc Destroy*(debugger: var Debugger) =
  assert debugger.messenger.Valid
  assert debugger.instance.vk.Valid
  debugger.instance.vk.vkDestroyDebugUtilsMessengerEXT(debugger.messenger, nil)
  debugger.messenger.Reset()
