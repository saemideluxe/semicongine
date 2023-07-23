import std/tables

import semicongine

proc scene_different_mesh_types(): Entity =
  result = newEntity("root", [],
    newEntity("triangle1", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    ))}),
    newEntity("triangle1b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, -0.4), newVec3f(0.4, 0.4), newVec3f(-0.4, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    ))}),
    newEntity("triangle2a", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, 0.5), newVec3f(0.5, -0.5), newVec3f(-0.5, -0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]]
    ))}),
    newEntity("triangle2b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, 0.4), newVec3f(0.4, -0.4), newVec3f(-0.4, -0.4)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]]
    ))}),
    newEntity("triangle3a", {"mesh": Component(newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false
    ))}),
    newEntity("triangle3b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false
    ))}),
  )
  for mesh in allComponentsOfType[Mesh](result):
    mesh.setInstanceData("translate", @[newVec3f()])

proc scene_simple(): Entity =
  var mymesh1 = newMesh(
    positions=[newVec3f(0.0, -0.3), newVec3f(0.3, 0.3), newVec3f(-0.3, 0.3)],
    colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
  )
  var mymesh2 = newMesh(
    positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
    colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
  )
  var mymesh3 = newMesh(
    positions=[newVec3f(0.0, -0.6), newVec3f(0.6, 0.6), newVec3f(-0.6, 0.6)],
    colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
    indices=[[0'u32, 1'u32, 2'u32]],
    autoResize=false
  )
  var mymesh4 = newMesh(
    positions=[newVec3f(0.0, -0.8), newVec3f(0.8, 0.8), newVec3f(-0.8, 0.8)],
    colors=[newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    indices=[[0'u16, 1'u16, 2'u16]],
    instanceCount=2
  )
  mymesh1.setInstanceData("translate", @[newVec3f(0.3, 0.0)])
  mymesh2.setInstanceData("translate", @[newVec3f(0.0, 0.3)])
  mymesh3.setInstanceData("translate", @[newVec3f(-0.3, 0.0)])
  mymesh4.setInstanceData("translate", @[newVec3f(0.0, -0.3), newVec3f(0.0, 0.5)])
  result = newEntity("root", [], newEntity("triangle", {"mesh1": Component(mymesh4), "mesh2": Component(mymesh3), "mesh3": Component(mymesh2), "mesh4": Component(mymesh1)}))

proc scene_primitives(): Entity =
  var r = rect(color="ff0000")
  var t = tri(color="0000ff")
  var c = circle(color="00ff00")

  r.setInstanceData("translate", @[newVec3f(0.5, -0.3)])
  t.setInstanceData("translate", @[newVec3f(0.3,  0.3)])
  c.setInstanceData("translate", @[newVec3f(-0.3,  0.1)])
  result = newEntity("root", {"mesh1": Component(t), "mesh1": Component(r), "mesh1": Component(c)})

proc scene_flag(): Entity =
  var r = rect(color="ff0000")
  r.updateMeshData("color", @[newVec4f(0, 0), newVec4f(1, 0), newVec4f(1, 1), newVec4f(0, 1)])
  result = newEntity("root", {"mesh": Component(r)})

proc main() =
  var engine = initEngine("Test")

  # INIT RENDERER:
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec4f]("color", memoryPerformanceHint=PreferFastWrite),
      attr[Vec3f]("translate", perInstance=true)
    ]
    vertexOutput = @[attr[Vec4f]("outcolor")]
    uniforms = @[attr[float32]("time")]
    samplers = @[attr[Sampler2DType]("my_little_texture")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=vertexOutput,
      main="""gl_Position = vec4(position + translate, 1.0); outcolor = color;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=fragOutput,
      main="color = texture(my_little_texture, outcolor.xy) * 0.5 + outcolor * 0.5;"
    )
  var renderPass = engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode)
  engine.setRenderer(renderPass)

  # INIT SCENES
  var scenes = [
    newScene("simple", scene_simple()),
    newScene("different mesh types", scene_different_mesh_types()),
    newScene("primitives", scene_primitives()),
    newScene("flag", scene_flag()),
  ]
  var sampler = DefaultSampler()
  sampler.magnification = VK_FILTER_NEAREST
  sampler.minification = VK_FILTER_NEAREST
  for scene in scenes.mitems:
    scene.addShaderGlobal("time", 0.0'f32)
    let (R, W) = ([255'u8, 0'u8, 0'u8, 255'u8], [255'u8, 255'u8, 255'u8, 255'u8])
    scene.addMaterial(Material(
      name: "my_material",
      textures: {
        "my_little_texture": Texture(image: Image(width: 5, height: 5, imagedata: @[
        R, R, R, R, R,
        R, R, W, R, R,
        R, W, W, W, R,
        R, R, W, R, R,
        R, R, R, R, R,
        ]), sampler: sampler)
      }.toTable
    ))
    engine.addScene(scene, vertexInput, samplers, transformAttribute="", materialIndexAttribute="")

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 3:
    for scene in scenes.mitems:
      for i in 0 ..< 1000:
        if engine.updateInputs() != Running or engine.keyIsDown(Escape):
          engine.destroy()
          return
        setShaderGlobal(scene, "time", getShaderGlobal[float32](scene, "time") + 0.0005'f)
        engine.renderScene(scene)
  echo "Rendered ", engine.framesRendered, " frames"
  echo "Processed ", engine.eventsProcessed, " events"

  # cleanup
  echo "Start cleanup"
  engine.destroy()

when isMainModule:
  main()
