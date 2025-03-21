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
  Mat1Type = MaterialType(
    name: "single texture material 1",
    vertexAttributes: {
      "color": Vec4F32,
      "position": Vec3F32,
      "uv": Vec2F32,
    }.toTable,
    attributes: {"baseTexture": TextureType}.toTable
  )
  mat = Mat1Type.InitMaterialData(
    name = "mat",
    attributes = {
      "baseTexture": InitDataList(@[Texture(isGrayscale: false, colorImage: Image[RGBAPixel](width: 5, height: 5, imagedata: @[
      R, R, R, R, R,
      R, R, W, R, R,
      R, W, W, W, R,
      R, R, W, R, R,
      R, R, R, R, R,
    ]), sampler: sampler)])
  }.toTable
  )
  Mat2Type = MaterialType(
    name: "single texture material 2",
    vertexAttributes: {
      "color": Vec4F32,
      "position": Vec3F32,
      "uv": Vec2F32,
    }.toTable,
    attributes: {"baseTexture": TextureType}.toTable
  )
  mat2 = Mat2Type.InitMaterialData(
    name = "mat2",
    attributes = {
      "baseTexture": InitDataList(@[Texture(isGrayscale: false, colorImage: Image[RGBAPixel](width: 5, height: 5, imagedata: @[
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
      W, R, W, R, W,
      R, W, R, W, R,
    ]), sampler: sampler)])
  }.toTable
  )
  mat3 = SINGLE_COLOR_MATERIAL.InitMaterialData(
    name = "mat3",
    attributes = {
      "color": InitDataList(@[NewVec4f(0, 1, 0, 1)])
    }.toTable
  )

proc scene_different_mesh_types(): seq[Mesh] =
  @[
    NewMesh(
      positions = [NewVec3f(0.0, -0.5), NewVec3f(0.5, 0.5), NewVec3f(-0.5, 0.5)],
      uvs = [NewVec2f(0.0, -0.5), NewVec2f(0.5, 0.5), NewVec2f(-0.5, 0.5)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      material = mat,
      transform = Translate(-0.7, -0.5),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, -0.4), NewVec3f(0.4, 0.4), NewVec3f(-0.4, 0.5)],
      uvs = [NewVec2f(0.0, -0.4), NewVec2f(0.4, 0.4), NewVec2f(-0.4, 0.5)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      material = mat,
      transform = Translate(0, -0.5),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, 0.5), NewVec3f(0.5, -0.5), NewVec3f(-0.5, -0.5)],
      uvs = [NewVec2f(0.0, 0.5), NewVec2f(0.5, -0.5), NewVec2f(-0.5, -0.5)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      indices = [[0'u16, 2'u16, 1'u16]],
      material = mat2,
      transform = Translate(0.7, -0.5),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, 0.4), NewVec3f(0.4, -0.4), NewVec3f(-0.4, -0.4)],
      uvs = [NewVec2f(0.0, 0.4), NewVec2f(0.4, -0.4), NewVec2f(-0.4, -0.4)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      indices = [[0'u16, 2'u16, 1'u16]],
      material = mat2,
      transform = Translate(-0.7, 0.5),
    ),
    NewMesh(
      positions = [NewVec3f(0.4, 0.5), NewVec3f(0.9, -0.3), NewVec3f(0.0, -0.3)],
      uvs = [NewVec2f(0.4, 0.5), NewVec2f(0.9, -0.3), NewVec2f(0.0, -0.3)],
      colors = [NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1)],
      indices = [[0'u32, 2'u32, 1'u32]],
      autoResize = false,
      material = mat2,
      transform = Translate(0, 0.5),
    ),
    NewMesh(
      positions = [NewVec3f(0.4, 0.5), NewVec3f(0.9, -0.3), NewVec3f(0.0, -0.3)],
      uvs = [NewVec2f(0.4, 0.5), NewVec2f(0.9, -0.3), NewVec2f(0.0, -0.3)],
      colors = [NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1)],
      indices = [[0'u32, 2'u32, 1'u32]],
      autoResize = false,
      material = mat2,
      transform = Translate(0.7, 0.5),
    ),
  ]

proc scene_simple(): seq[Mesh] =
  @[
    NewMesh(
      positions = [NewVec3f(0.0, -0.3), NewVec3f(0.3, 0.3), NewVec3f(-0.3, 0.3)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      uvs = [NewVec2f(0.0, -0.3), NewVec2f(0.3, 0.3), NewVec2f(-0.3, 0.3)],
      material = mat,
      transform = Translate(0.4, 0.4),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, -0.5), NewVec3f(0.5, 0.5), NewVec3f(-0.5, 0.5)],
      colors = [NewVec4f(1.0, 0.0, 0.0, 1), NewVec4f(0.0, 1.0, 0.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      uvs = [NewVec2f(0.0, -0.5), NewVec2f(0.5, 0.5), NewVec2f(-0.5, 0.5)],
      material = mat,
      transform = Translate(0.4, -0.4),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, -0.6), NewVec3f(0.6, 0.6), NewVec3f(-0.6, 0.6)],
      colors = [NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1), NewVec4f(1.0, 1.0, 0.0, 1)],
      uvs = [NewVec2f(0.0, -0.6), NewVec2f(0.6, 0.6), NewVec2f(-0.6, 0.6)],
      indices = [[0'u32, 1'u32, 2'u32]],
      autoResize = false,
      material = mat,
      transform = Translate(-0.4, 0.4),
    ),
    NewMesh(
      positions = [NewVec3f(0.0, -0.8), NewVec3f(0.8, 0.8), NewVec3f(-0.8, 0.8)],
      colors = [NewVec4f(0.0, 0.0, 1.0, 1), NewVec4f(0.0, 0.0, 1.0, 1), NewVec4f(0.0, 0.0, 1.0, 1)],
      uvs = [NewVec2f(0.0, -0.8), NewVec2f(0.8, 0.8), NewVec2f(-0.8, 0.8)],
      indices = [[0'u16, 1'u16, 2'u16]],
      instanceTransforms = [Unit4F32, Unit4F32],
      material = mat,
      transform = Translate(-0.4, -0.4),
    )
  ]

proc scene_primitives(): seq[Mesh] =
  var r = Rect(color = "ff0000")
  var t = Tri(color = "0000ff")
  var c = Circle(color = "00ff00")
  r.material = mat
  t.material = mat
  c.material = mat
  r.transform = Translate(NewVec3f(0.5, -0.3))
  t.transform = Translate(NewVec3f(0.3, 0.3))
  c.transform = Translate(NewVec3f(-0.3, 0.1))
  result = @[r, c, t]

proc scene_flag(): seq[Mesh] =
  @[
    NewMesh(
      positions = [NewVec3f(-1.0, -1.0), NewVec3f(1.0, -1.0), NewVec3f(1.0, 1.0), NewVec3f(-1.0, 1.0)],
      uvs = [NewVec2f(-1.0, -1.0), NewVec2f(1.0, -1.0), NewVec2f(1.0, 1.0), NewVec2f(-1.0, 1.0)],
      colors = [NewVec4f(-1, -1, 1, 1), NewVec4f(1, -1, 1, 1), NewVec4f(1, 1, 1, 1), NewVec4f(-1, 1, 1, 1)],
      indices = [[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
      material = mat,
      transform = Scale(0.5, 0.5)
    )
  ]

proc scene_multi_material(): seq[Mesh] =
  var
    r1 = Rect(color = "ffffff")
    r2 = Rect(color = "000000")
  r1.material = mat
  r2.material = mat3
  r1.transform = Translate(NewVec3f(-0.5))
  r2.transform = Translate(NewVec3f(+0.5))
  result = @[r1, r2]

proc main() =
  var engine = InitEngine("Test")

  # INIT RENDERER:
  const
    shaderConfiguration1 = CreateShaderConfiguration(
      name = "shader1",
      inputs = [
        Attr[Vec3f]("position", memoryPerformanceHint = PreferFastRead),
        Attr[Vec4f]("color", memoryPerformanceHint = PreferFastWrite),
        Attr[Mat4]("transform", perInstance = true),
      ],
      intermediates = [
        Attr[Vec4f]("outcolor"),
      ],
      outputs = [Attr[Vec4f]("color")],
      samplers = [Attr[Texture]("baseTexture")],
      vertexCode = """gl_Position = vec4(position, 1.0) * transform; outcolor = color;""",
      fragmentCode = "color = texture(baseTexture, outcolor.xy) * 0.5 + outcolor * 0.5;",
    )
    shaderConfiguration2 = CreateShaderConfiguration(
      name = "shader2",
      inputs = [
        Attr[Vec3f]("position", memoryPerformanceHint = PreferFastRead),
        Attr[Mat4]("transform", perInstance = true),
      ],
      intermediates = [Attr[Vec4f]("outcolor")],
      outputs = [Attr[Vec4f]("color")],
      uniforms = [Attr[Vec4f]("color", arrayCount = 1)],
      vertexCode = """gl_Position = vec4(position, 1.0) * transform; outcolor = Uniforms.color[0];""",
      fragmentCode = "color = outcolor;",
    )
  engine.InitRenderer({
    Mat1Type: shaderConfiguration1,
    Mat1Type: shaderConfiguration1,
    Mat2Type: shaderConfiguration1,
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
    engine.LoadScene(scene)

  # MAINLOOP
  echo "Setup successfull, start rendering"
  for i in 0 ..< 3:
    for scene in scenes.mitems:
      echo "rendering scene ", scene.name
      for i in 0 ..< 1000:
        if not engine.UpdateInputs() or KeyIsDown(Escape):
          engine.Destroy()
          return
        engine.RenderScene(scene)

  # cleanup
  echo "Start cleanup"
  engine.Destroy()

when isMainModule:
  main()
