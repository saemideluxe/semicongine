import std/strformat
import semicongine

const
  MeshMaterial* = MaterialType(
    name: "colored single texture material",
    vertexAttributes: {
      "position": Vec3F32,
      "texcoord_0": Vec2F32,
    }.toTable,
    attributes: {"baseTexture": TextureType, "color": Vec4F32}.toTable
  )

proc main() =
  var scenes = [
    Scene(name: "Donut", meshes: loadMeshes("donut.glb", MeshMaterial)[0].toSeq),
  ]

  var engine = InitEngine("Test meshes")
  const
    shaderConfiguration = createShaderConfiguration(
      name = "default shader",
      inputs = [
        Attr[Vec3f]("position", memoryPerformanceHint = PreferFastRead),
        Attr[uint16](MATERIALINDEX_ATTRIBUTE, memoryPerformanceHint = PreferFastRead, perInstance = true),
        Attr[Vec2f]("texcoord_0", memoryPerformanceHint = PreferFastRead),
        Attr[Mat4]("transform", memoryPerformanceHint = PreferFastWrite, perInstance = true),
      ],
      intermediates = [
        Attr[Vec4f]("vertexColor"),
        Attr[Vec2f]("colorTexCoord"),
        Attr[uint16]("materialIndexOut", noInterpolation = true)
      ],
      outputs = [Attr[Vec4f]("color")],
      uniforms = [
        Attr[Mat4]("projection"),
        Attr[Mat4]("view"),
        Attr[Vec4f]("color", arrayCount = 4),
      ],
      samplers = [Attr[Texture]("baseTexture", arrayCount = 4)],
      vertexCode = &"""
  gl_Position =  vec4(position, 1.0) * (transform * (Uniforms.view * Uniforms.projection));
  vertexColor = Uniforms.color[{MATERIALINDEX_ATTRIBUTE}];
  colorTexCoord = texcoord_0;
  materialIndexOut = {MATERIALINDEX_ATTRIBUTE};
  """,
      fragmentCode = "color = texture(baseTexture[materialIndexOut], colorTexCoord) * vertexColor;"
    )
  engine.InitRenderer({MeshMaterial: shaderConfiguration})

  for scene in scenes.mitems:
    scene.addShaderGlobal("projection", Unit4F32)
    scene.addShaderGlobal("view", Unit4F32)
    engine.LoadScene(scene)

  var
    size = 1'f32
    elevation = 0'f32
    azimut = 0'f32
    currentScene = 0

  while engine.UpdateInputs() and not KeyIsDown(Escape):
    if KeyWasPressed(`1`):
      currentScene = 0
    elif KeyWasPressed(`2`):
      currentScene = 1
    elif KeyWasPressed(`3`):
      currentScene = 2
    elif KeyWasPressed(`4`):
      currentScene = 3
    elif KeyWasPressed(`5`):
      currentScene = 4
    elif KeyWasPressed(`6`):
      currentScene = 5

    if KeyWasPressed(NumberRowExtra3):
      size = 0.3'f32
      elevation = 0'f32
      azimut = 0'f32

    let ratio = engine.GetWindow().size[0] / engine.GetWindow().size[1]
    size *= 1'f32 + MouseWheel() * 0.05
    azimut += MouseMove().x / 180'f32
    elevation -= MouseMove().y / 180'f32
    scenes[currentScene].setShaderGlobal("projection", Perspective(PI / 2, ratio, -0.5, 1))
    scenes[currentScene].setShaderGlobal(
      "view",
       Scale(size, size, size) * Rotate(elevation, NewVec3f(1, 0, 0)) * Rotate(azimut, Yf32)
    )
    engine.RenderScene(scenes[currentScene])
  engine.Destroy()

when isMainModule:
  main()
