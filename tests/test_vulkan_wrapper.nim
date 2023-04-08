import std/options

import semicongine

proc diagnostics(instance: Instance) =
  # diagnostic output
  # print basic driver infos
  echo "Layers"
  for layer in getLayers():
    echo "  " & layer
  echo "Instance extensions"
  for extension in getInstanceExtensions():
    echo "  " & extension

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
  # INIT ENGINE:
  # create instance
  var thewindow = createWindow("Test")
  var instance = thewindow.createInstance(
    vulkanVersion=VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions= @["VK_EXT_debug_utils"],
    layers= @["VK_LAYER_KHRONOS_validation", "VK_LAYER_MESA_overlay"]
  )
  var debugger = instance.createDebugMessenger()
  # create devices
  let selectedPhysicalDevice = instance.getPhysicalDevices().filterBestGraphics()
  var device = instance.createDevice(
    selectedPhysicalDevice,
    @[],
    @["VK_EXT_index_type_uint8"],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )

  # INIT RENDERER:
  const
    vertexInput = @[
      attr[Vec3f]("position"),
      attr[Vec3f]("color"),
      attr[Mat4]("transform", perInstance=true)
    ]
    vertexOutput = @[attr[Vec3f]("outcolor")]
    uniforms = @[attr[float32]("time")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      outputs=vertexOutput,
      body="""gl_Position = vec4(position, 1.0); outcolor = color * sin(Uniforms.time) * 0.5 + 0.5;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      outputs=fragOutput,
      body="color = vec4(outcolor, 1);"
    )
  var
    vertexshader = device.createShaderModule(vertexCode)
    fragmentshader = device.createShaderModule(fragmentCode)
    surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
    renderPass = device.simpleForwardRenderPass(surfaceFormat.format, vertexshader, fragmentshader, 2)
    (swapchain, res) = device.createSwapchain(renderPass, surfaceFormat, device.firstGraphicsQueue().get().family, 2)
  if res != VK_SUCCESS:
    raise newException(Exception, "Unable to create swapchain")

  # INIT SCENE
  var time = initShaderGlobal("time", 0.0'f32)
  var thescene = Scene(
    name: "main",
    root: newEntity("root",
      newEntity("stuff", time),
      newEntity("triangle1", newMesh(
        positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
        colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
      )),
      newEntity("triangle1b", newMesh(
        positions=[newVec3f(0.0, -0.4), newVec3f(0.4, 0.4), newVec3f(-0.4, 0.5)],
        colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
      )),
      newEntity("triangle2a", newMesh(
        positions=[newVec3f(0.0, 0.5), newVec3f(0.5, -0.5), newVec3f(-0.5, -0.5)],
        colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
        indices=[[0'u16, 2'u16, 1'u16]]
      )),
      newEntity("triangle2b", newMesh(
        positions=[newVec3f(0.0, 0.4), newVec3f(0.4, -0.4), newVec3f(-0.4, -0.4)],
        colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
        indices=[[0'u16, 2'u16, 1'u16]]
      )),
      newEntity("triangle3a", newMesh(
        positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
        colors=[newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0)],
        indices=[[0'u32, 2'u32, 1'u32]],
        autoResize=false
      )),
      newEntity("triangle3b", newMesh(
        positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
        colors=[newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0)],
        indices=[[0'u32, 2'u32, 1'u32]],
        autoResize=false
      )),
    )
  )
  thescene.setupDrawables(renderPass)
  swapchain.setupUniforms(thescene)

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 1:
    setValue[float32](time.value, get[float32](time.value) + 0.0005)
    echo get[float32](time.value)
    discard swapchain.drawScene(thescene)
  echo "Rendered ", swapchain.framesRendered, " frames"
  checkVkResult device.vk.vkDeviceWaitIdle()

  # cleanup
  echo "Start cleanup"

  # destroy scene
  thescene.destroy()

  # destroy renderer
  vertexshader.destroy()
  fragmentshader.destroy()
  renderPass.destroy()
  swapchain.destroy()

  # destroy engine
  device.destroy()
  debugger.destroy()
  instance.destroy()
  thewindow.destroy()
