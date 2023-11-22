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
  mat = SINGLE_TEXTURE_MATERIAL.initMaterialData(
    name="mat",
    attributes={
      "baseTexture": initDataList(@[Texture(image: Image(width: 5, height: 5, imagedata: @[
      R, R, R, R, R,
      R, R, W, R, R,
      R, W, W, W, R,
      R, R, W, R, R,
      R, R, R, R, R,
      ]), sampler: sampler)])
    }.toTable
  )
  mat2 = SINGLE_TEXTURE_MATERIAL.initMaterialData(
    name="mat2",
    attributes={
      "baseTexture": initDataList(@[Texture(image: Image(width: 5, height: 5, imagedata: @[
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
      ]), sampler: sampler)])
    }.toTable
  )
  mat3 = SINGLE_COLOR_MATERIAL.initMaterialData(
    name="mat3",
    attributes={
      "color": initDataList(@[newVec4f(0, 1, 0, 1)])
    }.toTable
  )

proc scene_different_mesh_types(): seq[Mesh] =
  @[
    newMesh(
      positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
      uvs=[newVec2f(0.0, -0.5), newVec2f(0.5, 0.5), newVec2f(-0.5, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      material=mat,
      transform=translate(-0.7, -0.5),
    ),
    newMesh(
      positions=[newVec3f(0.0, -0.4), newVec3f(0.4, 0.4), newVec3f(-0.4, 0.5)],
      uvs=[newVec2f(0.0, -0.4), newVec2f(0.4, 0.4), newVec2f(-0.4, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      material=mat,
      transform=translate(0, -0.5),
    ),
    newMesh(
      positions=[newVec3f(0.0, 0.5), newVec3f(0.5, -0.5), newVec3f(-0.5, -0.5)],
      uvs=[newVec2f(0.0, 0.5), newVec2f(0.5, -0.5), newVec2f(-0.5, -0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]],
      material=mat2,
      transform=translate(0.7, -0.5),
    ),
    newMesh(
      positions=[newVec3f(0.0, 0.4), newVec3f(0.4, -0.4), newVec3f(-0.4, -0.4)],
      uvs=[newVec2f(0.0, 0.4), newVec2f(0.4, -0.4), newVec2f(-0.4, -0.4)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      indices=[[0'u16, 2'u16, 1'u16]],
      material=mat2,
      transform=translate(-0.7, 0.5),
    ),
    newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      uvs=[newVec2f(0.4, 0.5), newVec2f(0.9, -0.3), newVec2f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false,
      material=mat2,
      transform=translate(0, 0.5),
    ),
    newMesh(
      positions=[newVec3f(0.4, 0.5), newVec3f(0.9, -0.3), newVec3f(0.0, -0.3)],
      uvs=[newVec2f(0.4, 0.5), newVec2f(0.9, -0.3), newVec2f(0.0, -0.3)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      indices=[[0'u32, 2'u32, 1'u32]],
      autoResize=false,
      material=mat2,
      transform=translate(0.7, 0.5),
    ),
  ]

proc scene_simple(): seq[Mesh] =
  @[
    newMesh(
      positions=[newVec3f(0.0, -0.3), newVec3f(0.3, 0.3), newVec3f(-0.3, 0.3)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      uvs=[newVec2f(0.0, -0.3), newVec2f(0.3, 0.3), newVec2f(-0.3, 0.3)],
      material=mat,
      transform=translate(0.4, 0.4),
    ),
    newMesh(
      positions=[newVec3f(0.0, -0.5), newVec3f(0.5, 0.5), newVec3f(-0.5, 0.5)],
      colors=[newVec4f(1.0, 0.0, 0.0, 1), newVec4f(0.0, 1.0, 0.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      uvs=[newVec2f(0.0, -0.5), newVec2f(0.5, 0.5), newVec2f(-0.5, 0.5)],
      material=mat,
      transform=translate(0.4, -0.4),
    ),
    newMesh(
      positions=[newVec3f(0.0, -0.6), newVec3f(0.6, 0.6), newVec3f(-0.6, 0.6)],
      colors=[newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1), newVec4f(1.0, 1.0, 0.0, 1)],
      uvs=[newVec2f(0.0, -0.6), newVec2f(0.6, 0.6), newVec2f(-0.6, 0.6)],
      indices=[[0'u32, 1'u32, 2'u32]],
      autoResize=false,
      material=mat,
      transform=translate(-0.4, 0.4),
    ),
    newMesh(
      positions=[newVec3f(0.0, -0.8), newVec3f(0.8, 0.8), newVec3f(-0.8, 0.8)],
      colors=[newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1), newVec4f(0.0, 0.0, 1.0, 1)],
      uvs=[newVec2f(0.0, -0.8), newVec2f(0.8, 0.8), newVec2f(-0.8, 0.8)],
      indices=[[0'u16, 1'u16, 2'u16]],
      instanceTransforms=[Unit4F32, Unit4F32],
      material=mat,
      transform=translate(-0.4, -0.4),
    )
  ]

proc scene_primitives(): seq[Mesh] =
  var r = rect(color="ff0000")
  var t = tri(color="0000ff")
  var c = circle(color="00ff00")
  r.material = mat
  t.material = mat
  c.material = mat
  r.transform = translate(newVec3f(0.5, -0.3))
  t.transform = translate(newVec3f(0.3,  0.3))
  c.transform = translate(newVec3f(-0.3,  0.1))
  result = @[r, c, t]

proc scene_flag(): seq[Mesh] =
  @[
    newMesh(
      positions=[newVec3f(-1.0, -1.0), newVec3f(1.0, -1.0), newVec3f(1.0, 1.0), newVec3f(-1.0, 1.0)],
      uvs=[newVec2f(-1.0, -1.0), newVec2f(1.0, -1.0), newVec2f(1.0, 1.0), newVec2f(-1.0, 1.0)],
      colors=[newVec4f(-1, -1, 1, 1), newVec4f(1, -1, 1, 1), newVec4f(1, 1, 1, 1), newVec4f(-1, 1, 1, 1)],
      indices=[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
      material=mat,
      transform=scale(0.5, 0.5)
    )
  ]

proc scene_multi_material(): seq[Mesh] =
  var
    r1 = rect(color="ffffff")
    r2 = rect(color="000000")
  r1.material = mat
  r2.material = mat3
  r1.transform = translate(newVec3f(-0.5))
  r2.transform = translate(newVec3f(+0.5))
  result = @[r1, r2]

proc main() =
  var engine = initEngine("Test")

  # INIT RENDERER:
  const
    shaderConfiguration1 = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[Vec4f]("color", memoryPerformanceHint=PreferFastWrite),
        attr[Mat4]("transform", perInstance=true),
      ],
      intermediates=[
        attr[Vec4f]("outcolor"),
      ],
      outputs=[attr[Vec4f]("color")],
      samplers=[
        attr[Texture]("baseTexture")
      ],
      vertexCode="""gl_Position = vec4(position, 1.0) * transform; outcolor = color;""",
      fragmentCode="color = texture(baseTexture, outcolor.xy) * 0.5 + outcolor * 0.5;",
    )
    shaderConfiguration2 = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[Mat4]("transform", perInstance=true),
      ],
      intermediates=[attr[Vec4f]("outcolor")],
      outputs=[attr[Vec4f]("color")],
      uniforms=[attr[Vec4f]("color", arrayCount=1)],
      vertexCode="""gl_Position = vec4(position, 1.0) * transform; outcolor = Uniforms.color[0];""",
      fragmentCode="color = outcolor;",
    )
  engine.initRenderer({
    SINGLE_TEXTURE_MATERIAL: shaderConfiguration1,
    SINGLE_TEXTURE_MATERIAL: shaderConfiguration1,
    SINGLE_COLOR_MATERIAL: shaderConfiguration2,
  })

  # INIT SCENES
  var scenes = [
    Scene(name: "simple", meshes: scene_simple()),
    Scene(name: "different mesh types", meshes: scene_different_mesh_types()),
    Scene(name: "primitives", meshes: scene_primitives()),
    Scene(name: "flag", meshes: scene_flag()),
    Scene(name: "multimaterial", meshes: scene_multi_material()),
  ]

  for scene in scenes.mitems:
    engine.loadScene(scene)

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 3:
    for scene in scenes.mitems:
      echo "rendering scene ", scene.name
      for i in 0 ..< 1000:
        if engine.updateInputs() != Running or engine.keyIsDown(Escape):
          engine.destroy()
          return
        engine.renderScene(scene)
  echo "Rendered ", engine.framesRendered, " frames"
  echo "Processed ", engine.eventsProcessed, " events"

  # cleanup
  echo "Start cleanup"
  engine.destroy()

when isMainModule:
  main()
