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

proc scene_different_mesh_types(): Scene =
  result = Scene(
    name: "main",
    root: newEntity("root",
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

proc scene_simple(): Scene =
  var mymesh1 = newMesh(
    positions=[newVec3f(0.0, -0.3), newVec3f(0.3, 0.3), newVec3f(-0.3, 0.3)],
    colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
  )
  var mymesh2 = newMesh(
    positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
    colors=[newVec3f(1.0, 0.0, 0.0), newVec3f(0.0, 1.0, 0.0), newVec3f(0.0, 0.0, 1.0)],
  )
  var mymesh3 = newMesh(
    positions=[newVec3f(0.0, -0.6), newVec3f(0.6, 0.6), newVec3f(-0.6, 0.6)],
    colors=[newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0), newVec3f(1.0, 1.0, 0.0)],
    indices=[[0'u32, 1'u32, 2'u32]],
    autoResize=false
  )
  var mymesh4 = newMesh(
    positions=[newVec3f(0.0, -0.8), newVec3f(0.8, 0.8), newVec3f(-0.8, 0.8)],
    colors=[newVec3f(0.0, 0.0, 1.0), newVec3f(0.0, 0.0, 1.0), newVec3f(0.0, 0.0, 1.0)],
    indices=[[0'u16, 1'u16, 2'u16]],
    instanceCount=2
  )
  setMeshData[Vec3f](mymesh1, "translate", @[newVec3f(0.3, 0.0)])
  setMeshData[Vec3f](mymesh2, "translate", @[newVec3f(0.0, 0.3)])
  setMeshData[Vec3f](mymesh3, "translate", @[newVec3f(-0.3, 0.0)])
  setMeshData[Vec3f](mymesh4, "translate", @[newVec3f(0.0, -0.3), newVec3f(0.0, 0.5)])
  result = Scene(
    name: "main",
    root: newEntity("root", newEntity("triangle", mymesh4, mymesh3, mymesh2, mymesh1))
  )

proc scene_primitives(): Scene =
  var r = rect(color="ff0000")
  var t = tri(color="0000ff")
  var c = circle(color="00ff00")
  setMeshData[Vec3f](r, "translate", @[newVec3f(0.5, -0.3)])
  setMeshData[Vec3f](t, "translate", @[newVec3f(0.3,  0.3)])
  setMeshData[Vec3f](c, "translate", @[newVec3f(-0.3,  0.1)])
  result = Scene(
    name: "main",
    root: newEntity("root", t, r, c)
  )

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
      attr[Vec3f]("position", memoryLocation=VRAM),
      attr[Vec3f]("color", memoryLocation=VRAM),
      attr[Vec3f]("translate", perInstance=true)
    ]
    vertexOutput = @[attr[Vec3f]("outcolor")]
    uniforms = @[attr[float32]("time")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      outputs=vertexOutput,
      body="""gl_Position = vec4(position + translate, 1.0); outcolor = color;"""
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

  # var thescene = scene_simple()
  # var thescene = scene_different_mesh_types()
  var thescene = scene_primitives()
  thescene.root.components.add time
  thescene.setupDrawables(renderPass)
  swapchain.setupUniforms(thescene)

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 10000:
    setValue[float32](time.value, get[float32](time.value) + 0.0005)
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
