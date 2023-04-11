import ./platform/window

import ./vulkan/api
import ./vulkan/instance
import ./vulkan/device
import ./vulkan/physicaldevice

import ./config

type
  Engine* = object
    device: Device
    debugger: Debugger
    instance: Instance
    window: NativeWindow

func gpuDevice*(engine: Engine): Device =
  engine.device

proc initEngine*(applicationName: string, debug=DEBUG): Engine =
  result.window = createWindow(applicationName)
  var
    instanceExtensions: seq[string]
    enabledLayers: seq[string]

  if debug:
    instanceExtensions.add "VK_EXT_debug_utils"
    enabledLayers.add @["VK_LAYER_KHRONOS_validation", "VK_LAYER_MESA_overlay"]
  result.instance = result.window.createInstance(
    vulkanVersion=VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions=instanceExtensions,
    layers=enabledLayers,
  )
  if debug:
    result.debugger = result.instance.createDebugMessenger()
  # create devices
  let selectedPhysicalDevice = result.instance.getPhysicalDevices().filterBestGraphics()
  result.device = result.instance.createDevice(
    selectedPhysicalDevice,
    enabledLayers = @[],
    enabledExtensions = @[],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )

proc destroy*(engine: var Engine) =
  engine.device.destroy()
  engine.debugger.destroy()
  engine.instance.destroy()
  engine.window.destroy()
