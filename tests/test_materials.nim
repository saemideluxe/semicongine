import std/times

import semicongine

proc main() =
  var scene = newScene("main", root=newEntity("rect", rect()))
  let (R, W) = ([255'u8, 0'u8, 0'u8, 255'u8], [255'u8, 255'u8, 255'u8, 255'u8])
  let (RT, WT, PT) = (hexToColorAlpha("A51931").asPixel, hexToColorAlpha("F4F5F8").asPixel, hexToColorAlpha("2D2A4A").asPixel)
  let
    t1 = Image(width: 5, height: 5, imagedata: @[
      R, R, R, R, R,
      R, R, W, R, R,
      R, W, W, W, R,
      R, R, W, R, R,
      R, R, R, R, R,
    ])
    t2 = Image(width: 7, height: 5, imagedata: @[
      RT, RT, RT, RT, RT, RT, RT,
      WT, WT, WT, WT, WT, WT, WT,
      PT, PT, PT, PT, PT, PT, PT,
      WT, WT, WT, WT, WT, WT, WT,
      RT, RT, RT, RT, RT, RT, RT,
    ])
  scene.addTextures("my_texture", @[t1, t2], interpolation=VK_FILTER_NEAREST)
  scene.addShaderGlobal("time", 0'f32)
  var m: Mesh = Mesh(scene.root.components[0])

  var engine = initEngine("Test materials")
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec2f]("uvout")]
    uniforms = @[attr[float32]("time")]
    samplers = @[attr[Sampler2DType]("my_texture", arrayCount=2)]
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
      main="""
float d = sin(Uniforms.time * 0.5) * 0.5 + 0.5;
color = texture(my_texture[0], uvout) * (1 - d) + texture(my_texture[1], uvout) * d;
"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput)
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    setShaderGlobal(scene, "time", float32(cpuTime() - t))
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
