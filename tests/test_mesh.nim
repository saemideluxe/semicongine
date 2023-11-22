import std/algorithm
import std/sequtils
import std/tables
import semicongine

proc main() =
  var scenes = [
    Scene(name: "Donut", meshes: loadMeshes("tutorialk-donat.glb", COLORED_SINGLE_TEXTURE_MATERIAL)[0].toSeq),
  ]

  var engine = initEngine("Test meshes")
  const
    shaderConfiguration = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[uint16]("materialIndex", memoryPerformanceHint=PreferFastRead, perInstance=true),
        attr[Vec2f]("texcoord_0", memoryPerformanceHint=PreferFastRead),
        attr[Mat4]("transform", memoryPerformanceHint=PreferFastWrite, perInstance=true),
      ],
      intermediates=[
        attr[Vec4f]("vertexColor"),
        attr[Vec2f]("colorTexCoord"),
        attr[uint16]("materialIndexOut", noInterpolation=true)
      ],
      outputs=[attr[Vec4f]("color")],
      uniforms=[
        attr[Mat4]("projection"),
        attr[Mat4]("view"),
        attr[Vec4f]("color", arrayCount=4),
      ],
      samplers=[attr[Texture]("baseTexture", arrayCount=4)],
      vertexCode="""
  gl_Position =  vec4(position, 1.0) * (transform * Uniforms.view * Uniforms.projection);
  vertexColor = Uniforms.color[materialIndex];
  colorTexCoord = texcoord_0;
  materialIndexOut = materialIndex;
  """,
      fragmentCode="color = texture(baseTexture[materialIndexOut], colorTexCoord) * vertexColor;"
    )
  engine.initRenderer({COLORED_SINGLE_TEXTURE_MATERIAL: shaderConfiguration})

  for scene in scenes.mitems:
    scene.addShaderGlobal("projection", Unit4F32)
    scene.addShaderGlobal("view", Unit4F32)
    engine.loadScene(scene)

  var
    size = 1'f32
    elevation = 0'f32
    azimut = 0'f32
    currentScene = 0

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.keyWasPressed(`1`):
      currentScene = 0
    elif engine.keyWasPressed(`2`):
      currentScene = 1
    elif engine.keyWasPressed(`3`):
      currentScene = 2
    elif engine.keyWasPressed(`4`):
      currentScene = 3
    elif engine.keyWasPressed(`5`):
      currentScene = 4
    elif engine.keyWasPressed(`6`):
      currentScene = 5

    if engine.keyWasPressed(NumberRowExtra3):
      size = 0.3'f32
      elevation = 0'f32
      azimut = 0'f32

    let ratio = engine.getWindow().size[0] / engine.getWindow().size[1]
    size *= 1'f32 + engine.mouseWheel() * 0.05
    azimut += engine.mouseMove().x / 180'f32
    elevation -= engine.mouseMove().y / 180'f32
    scenes[currentScene].setShaderGlobal("projection", ortho(-ratio, ratio, -1, 1, -1, 1))
    scenes[currentScene].setShaderGlobal(
      "view",
       scale(size, size, size) * rotate(elevation, newVec3f(1, 0, 0)) * rotate(azimut, Yf32)
    )
    engine.renderScene(scenes[currentScene])
  engine.destroy()

when isMainModule:
  main()
