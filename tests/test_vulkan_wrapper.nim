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

proc scene_different_mesh_types(): Entity =
  result = newEntity("root",
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
  for mesh in allComponentsOfType[Mesh](result):
    mesh.setInstanceData("translate", @[newVec3f()])

proc scene_simple(): Entity =
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
  mymesh1.setInstanceData("translate", @[newVec3f(0.3, 0.0)])
  mymesh2.setInstanceData("translate", @[newVec3f(0.0, 0.3)])
  mymesh3.setInstanceData("translate", @[newVec3f(-0.3, 0.0)])
  mymesh4.setInstanceData("translate", @[newVec3f(0.0, -0.3), newVec3f(0.0, 0.5)])
  result = newEntity("root", newEntity("triangle", mymesh4, mymesh3, mymesh2, mymesh1))

proc scene_primitives(): Entity =
  var r = rect(color="ff0000")
  var t = tri(color="0000ff")
  var c = circle(color="00ff00")
  setInstanceData[Vec3f](r, "translate", @[newVec3f(0.5, -0.3)])
  setInstanceData[Vec3f](t, "translate", @[newVec3f(0.3,  0.3)])
  setInstanceData[Vec3f](c, "translate", @[newVec3f(-0.3,  0.1)])
  result = newEntity("root", t, r, c)

when isMainModule:
  var engine = initEngine("Test")

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
      main="""gl_Position = vec4(position + translate, 1.0); outcolor = color;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      outputs=fragOutput,
      main="color = vec4(outcolor, 1);"
    )
  var
    surfaceFormat = engine.gpuDevice.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
    renderPass = engine.gpuDevice.simpleForwardRenderPass(surfaceFormat.format, vertexCode, fragmentCode, 2)
    renderer = engine.gpuDevice.initRenderer([renderPass])

  # INIT SCENE

  var scenes = [scene_simple(), scene_different_mesh_types(), scene_primitives()]
  var time = initShaderGlobal("time", 0.0'f32)
  for scene in scenes.mitems:
    scene.components.add time
    renderer.setupDrawableBuffers(scene, vertexInput)

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 3:
    for scene in scenes:
      for i in 0 ..< 1000:
        setValue[float32](time.value, get[float32](time.value) + 0.0005)
        discard renderer.render(scene)
  echo "Rendered ", renderer.framesRendered, " frames"

  # cleanup
  echo "Start cleanup"
  checkVkResult engine.gpuDevice.vk.vkDeviceWaitIdle()
  renderer.destroy()
  engine.destroy()
