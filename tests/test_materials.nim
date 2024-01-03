import std/times
import std/tables

import semicongine

let
  sampler = Sampler(magnification: VK_FILTER_NEAREST, minification: VK_FILTER_NEAREST)
  (RT, WT, PT) = (toRGBA("A51931").asPixel, toRGBA("F4F5F8").asPixel, toRGBA("2D2A4A").asPixel)
  thai = Image(width: 7, height: 5, imagedata: @[
    RT, RT, RT, RT, RT, RT, RT,
    WT, WT, WT, WT, WT, WT, WT,
    PT, PT, PT, PT, PT, PT, PT,
    WT, WT, WT, WT, WT, WT, WT,
    RT, RT, RT, RT, RT, RT, RT,
  ])
  swiss = loadImage("flag.png")
  doubleTextureMaterial = MaterialType(
    name:"Double texture",
    vertexAttributes: {
      "position": Vec3F32,
      "uv": Vec2F32,
    }.toTable,
    attributes: {"tex1": TextureType, "tex2": TextureType}.toTable
  )
  material = initMaterialData(
    theType=doubleTextureMaterial,
    name="swiss-thai",
    attributes={
      "tex1": initDataList(@[Texture(image: thai, sampler: sampler)]),
      "tex2": initDataList(@[Texture(image: swiss, sampler: sampler)]),
    }
  )

proc main() =
  var flag = rect()
  flag.material = material
  var scene = Scene(name: "main", meshes: @[flag])
  scene.addShaderGlobalArray("test2", @[0'f32, 0'f32])

  var engine = initEngine("Test materials")

  const
    shaderConfiguration1 = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
      ],
      intermediates=[
        attr[Vec2f]("uvout"),
      ],
      uniforms=[attr[float32]("test2", arrayCount=2)],
      samplers = @[
        attr[Texture]("tex1", arrayCount=1),
        attr[Texture]("tex2", arrayCount=1),
      ],
      outputs=[attr[Vec4f]("color")],
      vertexCode="""
      gl_Position = vec4(position.x, position.y + sin(Uniforms.test2[1]) / Uniforms.test2[1] * 0.5, position.z, 1.0);
      uvout = uv;""",
      fragmentCode="""
      float d = sin(Uniforms.test2[0]) * 0.5 + 0.5;
      color = texture(tex1[0], uvout) * (1 - d) + texture(tex2[0], uvout) * d;
      """,
    )
  engine.initRenderer({
    doubleTextureMaterial: shaderConfiguration1,
  })
  engine.loadScene(scene)
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    var d = float32(cpuTime() - t)
    setShaderGlobalArray(scene, "test2", @[d, d * 2])
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
