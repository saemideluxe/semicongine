import std/strformat

import ./api
import ./utils

type
  Instance* = object
    vk*: VkInstance
  Debugger* = object
    instance: Instance
    messenger: VkDebugUtilsMessengerEXT
  DebugCallback* = proc (
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
    userData: pointer
  ): VkBool32 {.cdecl.}

proc getInstanceExtensions*(): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateInstanceExtensionProperties(nil, addr(extensionCount), extensions.toCPointer)
    for extension in extensions:
      result.add(cleanString(extension.extensionName))

proc getLayers*(): seq[string] =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  if n_layers > 0:
    var layers = newSeq[VkLayerProperties](n_layers)
    checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), layers.toCPointer)
    for layer in layers:
      result.add(cleanString(layer.layerName))

proc createInstance*(
  vulkanVersion: uint32,
  instanceExtensions: openArray[string],
  layers: openArray[string],
  name = "defaultVulkanInstance",
  engine = "defaultEngine",
): Instance =
  for i in layers: assert i in getLayers()
  for i in instanceExtensions: assert i in getInstanceExtensions()
  var
    layersC = allocCStringArray(layers)
    instanceExtensionsC = allocCStringArray(instanceExtensions)
    appinfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: name,
      pEngineName: engine,
      apiVersion: vulkanVersion,
    )
    createinfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: addr(appinfo),
      enabledLayerCount: layers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: instanceExtensions.len.uint32,
      ppEnabledExtensionNames: instanceExtensionsC
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result.vk))
  result.vk.loadVulkan()
  deallocCStringArray(layersC)
  deallocCStringArray(instanceExtensionsC)
  for extension in instanceExtensions:
    result.vk.loadExtension($extension)

proc destroy*(instance: var Instance) =
  assert instance.vk.valid
  # needs to happen after window is trashed as the driver might have a hook registered for the window destruction
  instance.vk.vkDestroyInstance(nil)
  instance.vk.reset()

proc defaultDebugCallback(
  messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
  messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
  pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
  userData: pointer
): VkBool32 {.cdecl.} =
  echo &"{messageSeverity}: {toEnums messageTypes}: {pCallbackData.pMessage}"
  return false

proc createDebugMessenger*(
  instance: Instance,
  severityLevels: openArray[VkDebugUtilsMessageSeverityFlagBitsEXT] = @[],
  types: openArray[VkDebugUtilsMessageTypeFlagBitsEXT] = @[],
  callback: DebugCallback=defaultDebugCallback
): Debugger =
  assert instance.vk.valid
  result.instance = instance
  var severityLevelBits = high(VkDebugUtilsMessageSeverityFlagsEXT)
  var typeBits = high(VkDebugUtilsMessageTypeFlagsEXT)
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

proc destroy*(debugger: var Debugger) =
  assert debugger.messenger.valid
  assert debugger.instance.vk.valid
  debugger.instance.vk.vkDestroyDebugUtilsMessengerEXT(debugger.messenger, nil)
  debugger.messenger.reset()
