import std/times

import semicongine

proc main() =
  var scene = newScene("main", root=newEntity("rect", rect()))
  let (RT, WT, PT) = (hexToColorAlpha("A51931").asPixel, hexToColorAlpha("F4F5F8").asPixel, hexToColorAlpha("2D2A4A").asPixel)
  let
    # image from memory
    t1 = Image(width: 7, height: 5, imagedata: @[
      RT, RT, RT, RT, RT, RT, RT,
      WT, WT, WT, WT, WT, WT, WT,
      PT, PT, PT, PT, PT, PT, PT,
      WT, WT, WT, WT, WT, WT, WT,
      RT, RT, RT, RT, RT, RT, RT,
    ])
    # image from file
    t2 = loadImage("flag.png")
  var sampler = DefaultSampler()
  sampler.magnification = VK_FILTER_NEAREST
  sampler.minification = VK_FILTER_NEAREST
  scene.addTextures("my_texture", @[Texture(image: t1, sampler: sampler), Texture(image: t2, sampler: sampler)])
  scene.addShaderGlobalArray("test2", @[0'f32, 0'f32])

  var engine = initEngine("Test materials")
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec2f]("uvout")]
    uniforms = @[attr[float32]("test2", arrayCount=2)]
    samplers = @[attr[Sampler2DType]("my_texture", arrayCount=2)]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=vertexOutput,
      main="""gl_Position = vec4(position.x, position.y + sin(Uniforms.test2[1]) / Uniforms.test2[1] * 0.5, position.z, 1.0); uvout = uv;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      samplers=samplers,
      outputs=fragOutput,
      main="""
float d = sin(Uniforms.test2[0]) * 0.5 + 0.5;
color = texture(my_texture[0], uvout) * (1 - d) + texture(my_texture[1], uvout) * d;
"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput)
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    var d = float32(cpuTime() - t)
    setShaderGlobalArray(scene, "test2", @[d, d * 2])
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
