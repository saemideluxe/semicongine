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
    uniforms = @[attr[Mat4]("transform"), attr[Vec4f]("material_colors", arrayCount=16), ]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      outputs=vertexOutput,
      uniforms=uniforms,
      main="""gl_Position = vec4(position, 1.0) * Uniforms.transform; vertexColor = Uniforms.material_colors[material];"""
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
    scene.addShaderGlobal("transform", Unit4)
  var
    size = 1'f32
    elevation = -float32(PI) / 3'f32
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
      size = 1'f32
      elevation = -float32(PI) / 3'f32
      azimut = 0'f32

    size *= 1'f32 + engine.mouseWheel() * 0.05
    azimut += engine.mouseMove().x / 180'f32
    elevation -= engine.mouseMove().y / 180'f32
    scenes[currentScene].setShaderGlobal(
      "transform",
      scale3d(size, size, size) * rotate3d(elevation, newVec3f(1, 0, 0)) * rotate3d(azimut, Yf32)
    )
    engine.renderScene(scenes[currentScene])
  engine.destroy()


when isMainModule:
  main()
