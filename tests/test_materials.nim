import std/times
import std/tables

import semicongine

proc main() =
  var flag = rect()
  flag.materials = @["material2"]
  var scene = newScene("main", root=newEntity("rect", {"mesh": Component(flag)}))
  let (RT, WT, PT) = (hexToColorAlpha("A51931").asPixel, hexToColorAlpha("F4F5F8").asPixel, hexToColorAlpha("2D2A4A").asPixel)
  let
    # image from memory
    thai = Image(width: 7, height: 5, imagedata: @[
      RT, RT, RT, RT, RT, RT, RT,
      WT, WT, WT, WT, WT, WT, WT,
      PT, PT, PT, PT, PT, PT, PT,
      WT, WT, WT, WT, WT, WT, WT,
      RT, RT, RT, RT, RT, RT, RT,
    ])
  let
    # image from file
    swiss = loadImage("flag.png")

  var sampler = DefaultSampler()
  sampler.magnification = VK_FILTER_NEAREST
  sampler.minification = VK_FILTER_NEAREST
  scene.addMaterial(Material(name:"material1", textures: {
    "tex1": Texture(image: swiss, sampler: sampler),
    "tex2": Texture(image: thai, sampler: sampler),
  }.toTable))
  scene.addMaterial(Material(name:"material2", textures: {
    "tex1": Texture(image: thai, sampler: sampler),
    "tex2": Texture(image: swiss, sampler: sampler),
  }.toTable))
  scene.addShaderGlobalArray("test2", @[0'f32, 0'f32])

  var engine = initEngine("Test materials")

  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[uint16]("materialIndex", memoryPerformanceHint=PreferFastRead, perInstance=true),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
    ]
    vertexOutput = @[attr[Vec2f]("uvout"), attr[uint16]("materialIndexOut", noInterpolation=true)]
    uniforms = @[attr[float32]("test2", arrayCount=2)]
    samplers = @[
      attr[Sampler2DType]("tex1", arrayCount=2),
      attr[Sampler2DType]("tex2", arrayCount=2),
    ]
    fragOutput = @[attr[Vec4f]("color")]
    (vertexCode, fragmentCode) = compileVertexFragmentShaderSet(
      inputs=vertexInput,
      intermediate=vertexOutput,
      outputs=fragOutput,
      samplers=samplers,
      uniforms=uniforms,
      vertexCode="""
      gl_Position = vec4(position.x, position.y + sin(Uniforms.test2[1]) / Uniforms.test2[1] * 0.5, position.z, 1.0);
      uvout = uv;
      materialIndexOut = materialIndex;""",
      fragmentCode="""
      float d = sin(Uniforms.test2[0]) * 0.5 + 0.5;
      color = texture(tex1[materialIndexOut], uvout) * (1 - d) + texture(tex2[materialIndexOut], uvout) * d;
      """,
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput, samplers, transformAttribute="")
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    var d = float32(cpuTime() - t)
    setShaderGlobalArray(scene, "test2", @[d, d * 2])
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
