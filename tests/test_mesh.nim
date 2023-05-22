import semicongine

proc main() =
  var scenes = [
    loadScene("default_cube.glb", "1"),
    loadScene("default_cube1.glb", "3"),
    loadScene("default_cube2.glb", "4"),
    loadScene("flat.glb", "5"),
    loadScene("tutorialk-donat.glb", "6"),
    loadScene("personv3.glb", "2"),
  ]

  var engine = initEngine("Test meshes")
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[uint8]("material", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec4f]("vertexColor")]
    fragOutput = @[attr[Vec4f]("color")]
    uniforms = @[
      attr[Mat4]("projection"),
      attr[Mat4]("view"),
      attr[Mat4]("model"),
      attr[Vec4f]("material_color", arrayCount=16),
    ]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      outputs=vertexOutput,
      uniforms=uniforms,
      main="""gl_Position =  Uniforms.projection * Uniforms.view * Uniforms.model * vec4(position, 1.0); vertexColor = Uniforms.material_color[material];"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      outputs=fragOutput,
      uniforms=uniforms,
      main="""color = vertexColor;"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode, clearColor=newVec4f(0, 0, 0, 1)))
  for scene in scenes.mitems:
    engine.addScene(scene, vertexInput)
    scene.addShaderGlobal("projection", Unit4)
    scene.addShaderGlobal("view", Unit4)
    scene.addShaderGlobal("model", Unit4)
  var
    size = 0.3'f32
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
       scale3d(size, size, size) * rotate3d(elevation, newVec3f(1, 0, 0)) * rotate3d(azimut, Yf32)
    )
    scenes[currentScene].setShaderGlobal("model", Unit4f32)
    engine.renderScene(scenes[currentScene])
  engine.destroy()


when isMainModule:
  main()
