import std/strutils
import std/logging

include ./vkapi

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

proc `=copy`(a: var SVkInstance, b: SVkInstance) {.error.}

proc `=destroy`(a: SVkInstance) =
  if a.vkInstance.pointer != nil:
    a.vkInstance.vkDestroyInstance(nil)

proc svkCreateInstance*(
    applicationName: string,
    enabledLayers: openArray[string] = [],
    enabledExtensions: openArray[string] = [],
    engineName = "semicongine",
    majorVersion = 1'u32,
    minorVersion = 3'u32,
): SVkInstance =
  let
    appinfo = VkApplicationInfo(
      pApplicationName: applicationName,
      pEngineName: engineName,
      apiVersion: VK_MAKE_API_VERSION(0, majorVersion, minorVersion, 0),
    )
    layersC = enabledLayers.allocCStringArray()
    extensionsC = enabledLayers.allocCStringArray()
    createinfo = VkInstanceCreateInfo(
      pApplicationInfo: addr appinfo,
      enabledLayerCount: enabledLayers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: enabledExtensions.len.uint32,
      ppEnabledExtensionNames: extensionsC,
    )
  checkVkResult vkCreateInstance(addr createinfo, nil, addr result.vkInstance)
  layersC.deallocCStringArray()
  extensionsC.deallocCStringArray()
