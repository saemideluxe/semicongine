import std/tables

import semicongine


let
  sampler = Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
  (R, W) = ([255'u8, 0'u8, 0'u8, 255'u8], [255'u8, 255'u8, 255'u8, 255'u8])
  mat = Material(
    name: "mat",
    materialType: "my_material",
    textures: {
      "my_little_texture": Texture(image: Image(width: 5, height: 5, imagedata: @[
      R, R, R, R, R,
      R, R, W, R, R,
      R, W, W, W, R,
      R, R, W, R, R,
      R, R, R, R, R,
      ]), sampler: sampler)
    }.toTable
  )
  mat2 = Material(
    name: "mat2",
    materialType: "my_material",
    textures: {
      "my_little_texture": Texture(image: Image(width: 5, height: 5, imagedata: @[
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
      ]), sampler: sampler)
    }.toTable
  )
  mat3 = Material(
    name: "mat3",
    materialType: "my_special_material",
    constants: {
      "colors": toGPUValue(newVec4f(0.5, 0.5, 0))
    }.toTable
  )

proc scene_different_mesh_types(): Entity =
  result = newEntity("root", [],
    newEntity("triangle1", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      material=mat,
    ))}),
    newEntity("triangle1b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, -0.4), newVec3f(0.4, 0.4), newVec3f(-0.4, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      material=mat,
    ))}),
    newEntity("triangle2a", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, 0.5), newVec3f(0.5, -0.5), newVec3f(-0.5, -0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]],
      material=mat2,
    ))}),
    newEntity("triangle2b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.0, 0.4), newVec3f(0.4, -0.4), newVec3f(-0.4, -0.4)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]],
      material=mat2,
    ))}),
    newEntity("triangle3a", {"mesh": Component(newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false,
      material=mat2,
    ))}),
    newEntity("triangle3b", {"mesh": Component(newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false,
      material=mat2,
    ))}),
  )
  for mesh in allComponentsOfType[Mesh](result):
    mesh.setInstanceData("translate", @[newVec3f()])
  result[0]["mesh", Mesh()].updateInstanceData("translate", @[newVec3f(-0.6, -0.6)])
  result[1]["mesh", Mesh()].updateInstanceData("translate", @[newVec3f(-0.6, 0.6)])
  result[2]["mesh", Mesh()].updateInstanceData("translate", @[newVec3f(0.6, -0.6)])
  result[3]["mesh", Mesh()].updateInstanceData("translate", @[newVec3f(0.6, 0.6)])

proc scene_simple(): Entity =
  var mymesh1 = newMesh(
    positions=[newVec3f(0.0, -0.3), newVec3f(0.3, 0.3), newVec3f(-0.3, 0.3)],
    colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    material=mat,
  )
  var mymesh2 = newMesh(
    positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
    colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    material=mat,
  )
  var mymesh3 = newMesh(
    positions=[newVec3f(0.0, -0.6), newVec3f(0.6, 0.6), newVec3f(-0.6, 0.6)],
    colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
    indices=[[0'u32, 1'u32, 2'u32]],
    autoResize=false,
    material=mat,
  )
  var mymesh4 = newMesh(
    positions=[newVec3f(0.0, -0.8), newVec3f(0.8, 0.8), newVec3f(-0.8, 0.8)],
    colors=[newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
    indices=[[0'u16, 1'u16, 2'u16]],
    instanceCount=2,
    material=mat,
  )
  mymesh1.setInstanceData("translate", @[newVec3f( 0.4,  0.4)])
  mymesh2.setInstanceData("translate", @[newVec3f( 0.4, -0.4)])
  mymesh3.setInstanceData("translate", @[newVec3f(-0.4, -0.4)])
  mymesh4.setInstanceData("translate", @[newVec3f(-0.4,  0.4), newVec3f(0.0, 0.0)])
  result = newEntity("root", [], newEntity("triangle", {"mesh1": Component(mymesh4), "mesh2": Component(mymesh3), "mesh3": Component(mymesh2), "mesh4": Component(mymesh1)}))

proc scene_primitives(): Entity =
  var r = rect(color="ff0000")
  var t = tri(color="0000ff")
  var c = circle(color="00ff00")
  r.material = mat
  t.material = mat
  c.material = mat

  r.setInstanceData("translate", @[newVec3f(0.5, -0.3)])
  t.setInstanceData("translate", @[newVec3f(0.3,  0.3)])
  c.setInstanceData("translate", @[newVec3f(-0.3,  0.1)])
  result = newEntity("root", {"mesh1": Component(t), "mesh2": Component(r), "mesh3": Component(c)})

proc scene_flag(): Entity =
  var r = rect(color="ffffff")
  r.material = mat
  result = newEntity("root", {"mesh": Component(r)})

proc scene_multi_material(): Entity =
  var
    r1 = rect(color="ffffff")
    r2 = rect(color="000000")
  r1.material = mat
  r2.material = mat3
  r1.setInstanceData("translate", @[newVec3f(-0.5)])
  r2.setInstanceData("translate", @[newVec3f(+0.5)])
  result = newEntity("root", {"mesh1": Component(r1), "mesh2": Component(r2)})

proc main() =
  var engine = initEngine("Test")

  # INIT RENDERER:
  const
    shaderConfiguration = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[Vec4f]("color", memoryPerformanceHint=PreferFastWrite),
        attr[Vec3f]("translate", perInstance=true),
        attr[uint16]("materialIndex", perInstance=true),
      ],
      intermediates=[
        attr[Vec4f]("outcolor"),
        attr[uint16]("materialIndexOut", noInterpolation=true),
      ],
      outputs=[attr[Vec4f]("color")],
      uniforms=[attr[float32]("time")],
      samplers=[
        attr[Sampler2DType]("my_little_texture", arrayCount=2)
      ],
      vertexCode="""gl_Position = vec4(position + translate, 1.0); outcolor = color; materialIndexOut = materialIndex;""",
      fragmentCode="color = texture(my_little_texture[materialIndexOut], outcolor.xy) * 0.5 + outcolor * 0.5;",
    )
  engine.initRenderer({
    "my_material": shaderConfiguration,
    "my_special_material": shaderConfiguration,
  }.toTable)

  # INIT SCENES
  var scenes = [
    newScene("simple", scene_simple(), transformAttribute=""),
    newScene("different mesh types", scene_different_mesh_types(), transformAttribute=""),
    newScene("primitives", scene_primitives(), transformAttribute=""),
    newScene("flag", scene_multi_material(), transformAttribute=""),
  ]

  for scene in scenes.mitems:
    scene.addShaderGlobal("time", 0.0'f32)
    engine.addScene(scene)

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
