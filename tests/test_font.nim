import semicongine

proc main() =
  var scene = newScene("main", root=newEntity("rect", rect()))
  var font = loadFont("DejaVuSans.ttf", "myfont")
  var img = loadImage("flag.png")

  var textbox = newTextbox(10, 10, font, "Joni")
  scene.root.add textbox

  var sampler = DefaultSampler()
  sampler.magnification = VK_FILTER_NEAREST
  sampler.minification = VK_FILTER_NEAREST
  scene.addTextures("my_texture", @[
    Texture(image: img, sampler: sampler)
  ])
  scene.addShaderGlobalArray("test2", @[1'f32, 2'f32])

  var engine = initEngine("Test fonts")

  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec2f]("uvout")]
    uniforms = @[attr[float32]("test2", arrayCount=2)]
    samplers = @[attr[Sampler2DType]("my_texture", arrayCount=1)]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=vertexOutput,
      main="""gl_Position = vec4(position, 1.0); uvout = uv;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=fragOutput,
      main="""color = texture(my_texture[0], uvout);"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput, samplers)
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
