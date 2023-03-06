import std/options

import semicongine/vulkan
import semicongine/platform/window
import semicongine/math


when isMainModule:
  # print basic driver infos
  echo "Layers"
  for layer in getLayers():
    echo "  " & layer
  echo "Instance extensions"
  for extension in getInstanceExtensions():
    echo "  " & extension

  # create instance
  var thewindow = createWindow("Test")
  var instance = thewindow.createInstance(
    vulkanVersion=VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions= @["VK_EXT_debug_utils"],
    layers= @["VK_LAYER_KHRONOS_validation"]
  )
  var debugger = instance.createDebugMessenger()

  # diagnostic output
  echo "Devices"
  for device in instance.getPhysicalDevices():
    echo "  " & $device
    echo "  Rating: " & $device.rateGraphics()
    echo "  Extensions"
    for extension in device.getExtensions():
      echo "    " & $extension
    echo "  Properties"
    echo "  " & $device.getProperties()
    echo "  Features"
    echo "  " & $device.getFeatures()
    echo "  Queue families"
    for queueFamily in device.getQueueFamilies():
      echo "    " & $queueFamily
    echo "  Surface present modes"
    for mode in device.getSurfacePresentModes():
      echo "    " & $mode
    echo "  Surface formats"
    for format in device.getSurfaceFormats():
      echo "    " & $format

  # create devices
  let selectedPhysicalDevice = instance.getPhysicalDevices().filterBestGraphics()
  var device = instance.createDevice(
    selectedPhysicalDevice,
    @[],
    @[],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )

  # setup render pipeline
  var (swapchain, res) = device.createSwapchain(device.physicalDevice.getSurfaceFormats().filterSurfaceFormat())
  if res != VK_SUCCESS:
    raise newException(Exception, "Unable to create swapchain")
  var renderpass = device.simpleForwardRenderPass(swapchain.format)
  var framebuffers: seq[Framebuffer]
  for imageview in swapchain.imageviews:
    framebuffers.add device.createFramebuffer(renderpass, [imageview], swapchain.dimension)

  # todo: could be create inside "device", but it would be nice to have nim v2 with support for circular dependencies first
  var commandPool = device.createCommandPool(family=device.firstGraphicsQueue().get().family, nBuffers=1)

  echo "All successfull"
  echo "Start cleanup"

  commandPool.destroy()
  # cleanup
  for fb in framebuffers.mitems:
    fb.destroy()
  renderpass.destroy()
  swapchain.destroy()
  device.destroy()

  debugger.destroy()
  instance.destroy()
