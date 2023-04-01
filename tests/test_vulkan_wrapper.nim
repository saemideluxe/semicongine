import std/options

import semicongine/vulkan
import semicongine/platform/window
import semicongine/math
import semicongine/entity
import semicongine/scene
import semicongine/gpu_data
import semicongine/mesh

proc diagnostics(instance: Instance) =
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

  # create devices
  let selectedPhysicalDevice = instance.getPhysicalDevices().filterBestGraphics()
  var device = instance.createDevice(
    selectedPhysicalDevice,
    @[],
    @[],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )

  const inputs = AttributeGroup(attributes: @[attr(name="position", thetype=Float32, components=3)])
  const uniforms = AttributeGroup()
  const outputs = AttributeGroup(attributes: @[attr(name="fragpos", thetype=Float32, components=3)])
  const fragOutput = AttributeGroup(attributes: @[attr(name="color", thetype=Float32, components=4)])
  const vertexBinary = shaderCode(inputs=inputs, uniforms=uniforms, outputs=outputs, stage=VK_SHADER_STAGE_VERTEX_BIT, version=450, entrypoint="main", "fragpos = position;")
  const fragmentBinary = shaderCode(inputs=outputs, uniforms=uniforms, outputs=fragOutput, stage=VK_SHADER_STAGE_FRAGMENT_BIT, version=450, entrypoint="main", "color = vec4(1, 1, 1, 1);")
  var
    vertexshader = device.createShader(inputs, uniforms, outputs, VK_SHADER_STAGE_VERTEX_BIT, "main", vertexBinary)
    fragmentshader = device.createShader(inputs, uniforms, outputs, VK_SHADER_STAGE_FRAGMENT_BIT, "main", fragmentBinary)
    surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
    renderPass = device.simpleForwardRenderPass(surfaceFormat.format, vertexshader, fragmentshader, 2)
  var (swapchain, res) = device.createSwapchain(renderPass, surfaceFormat, device.firstGraphicsQueue().get().family, 2)
  if res != VK_SUCCESS:
    raise newException(Exception, "Unable to create swapchain")

  var thescene = Scene(
    name: "main",
    root: newEntity("root",
      newEntity("triangle1", newMesh([newVec3f(-0.5, -0.5), newVec3f(0.5, 0.5), newVec3f(0.5, -0.5)])),
      newEntity("triangle2", newMesh([newVec3f(-0.5, -0.5), newVec3f(0.5, -0.5), newVec3f(0.5, 0.5)])),
    )
  )
  thescene.setupDrawables(renderPass)

  echo "Setup successfull, start rendering"
  for i in 0 ..< 1:
    discard swapchain.drawScene(thescene)
  echo "Rendered ", swapchain.framesRendered, " frames"
  echo "Start cleanup"


  # cleanup
  checkVkResult device.vk.vkDeviceWaitIdle()
  thescene.destroy()
  vertexshader.destroy()
  fragmentshader.destroy()
  renderPass.destroy()
  swapchain.destroy()
  device.destroy()

  debugger.destroy()
  instance.destroy()
