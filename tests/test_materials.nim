import semicongine

proc main() =
  var scene = newScene("main", root=newEntity("rect", rect()))
  let (R, W) = ([255'u8, 0'u8, 0'u8, 255'u8], [255'u8, 255'u8, 255'u8, 255'u8])
  let (RT, WT, PT) = (hexToColorAlpha("A51931").asPixel, hexToColorAlpha("F4F5F8").asPixel, hexToColorAlpha("2D2A4A").asPixel)
  scene.addTexture("my_texture", TextureImage(width: 13, height: 5, imagedata: @[
    R, R, R, R, R, W, RT, RT, RT, RT, RT, RT, RT,
    R, R, W, R, R, W, WT, WT, WT, WT, WT, WT, WT,
    R, W, W, W, R, W, PT, PT, PT, PT, PT, PT, PT,
    R, R, W, R, R, W, WT, WT, WT, WT, WT, WT, WT,
    R, R, R, R, R, W, RT, RT, RT, RT, RT, RT, RT,
  ]))
  var m: Mesh = Mesh(scene.root.components[0])

  var engine = initEngine("Test materials")
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec2f]("uvout")]
    samplers = @[attr[Sampler2DType]("my_texture")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      samplers=samplers,
      outputs=vertexOutput,
      main="""gl_Position = vec4(position, 1.0); uvout = uv;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      samplers=samplers,
      outputs=fragOutput,
      main="color = texture(my_texture, uvout);"
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput)
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
