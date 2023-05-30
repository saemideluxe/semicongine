import std/unicode
import std/tables

import semicongine

proc main() =
  var sampler = DefaultSampler()
  sampler.magnification = VK_FILTER_NEAREST
  sampler.minification = VK_FILTER_NEAREST
  var font = loadFont("DejaVuSans.ttf", color=newVec4f(1, 0.5, 0.5, 1), resolution=20)

  var scene = newScene("main", root=newEntity("rect"))

  var flag = rect()
  flag.setInstanceData("material", @[0'u8])
  # scene.root.add flag
  scene.addMaterial Material(name: "material", textures: {"textures": Texture(image: loadImage("flag.png"), sampler: sampler)}.toTable)

  var textbox = newTextbox(32, font, "".toRunes)
  scene.addMaterial Material(name: "fontMaterial", textures: {"textures": font.fontAtlas}.toTable)
  textbox.mesh.setInstanceData("material", @[1'u8])
  textbox.transform = scale3d(0.1, 0.1)
  scene.root.add textbox

  const
    vertexInput = @[
      attr[Mat4]("transform", memoryPerformanceHint=PreferFastRead, perInstance=true),
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastRead),
      attr[uint8]("material", memoryPerformanceHint=PreferFastRead, perInstance=true),
    ]
    intermediate = @[attr[Vec2f]("uvout"), attr[uint8]("materialId", noInterpolation=true)]
    samplers = @[attr[Sampler2DType]("textures", arrayCount=2)]
    uniforms = @[attr[Mat4]("perspective")]
    fragOutput = @[attr[Vec4f]("color")]
    (vertexCode, fragmentCode) = compileVertexFragmentShaderSet(
      inputs=vertexInput,
      intermediate=intermediate,
      outputs=fragOutput,
      samplers=samplers,
      uniforms=uniforms,
      vertexCode="""gl_Position = vec4(position, 1.0) * (transform * Uniforms.perspective); uvout = uv; materialId = material;""",
      fragmentCode="""color = texture(textures[materialId], uvout);""",
    )

  var engine = initEngine("Test fonts")
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput, samplers)
  scene.addShaderGlobal("perspective", Unit4F32)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      scene.setShaderGlobal("perspective", orthoWindowAspect(winSize[1] / winSize[0]))
    for c in [Key.A, Key.B, Key.C, Key.D, Key.E, Key.F, Key.G, Key.H, Key.I, Key.J, Key.K, Key.L, Key.M, Key.N, Key.O, Key.P, Key.Q, Key.R, Key.S, Key.T, Key.U, Key.V, Key.W, Key.X, Key.Y, Key.Z]:
      if engine.keyWasPressed(c):
        if engine.keyIsDown(ShiftL) or engine.keyIsDown(ShiftR):
          textbox.text = textbox.text & ($c).toRunes
        else:
          textbox.text = textbox.text & ($c).toRunes[0].toLower()
    if engine.keyWasPressed(Space):
        textbox.text = textbox.text & " ".toRunes[0]
    if engine.keyWasPressed(Backspace) and textbox.text.len > 0:
          textbox.text = textbox.text[0 ..< ^1]
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
