import semicongine

proc main() =
  var scene = Scene(name: "main")

  scene.add rect(color = "f00f")
  scene.add rect()
  scene.add circle(color = "0f0f")
  scene.meshes[0].material = VERTEX_COLORED_MATERIAL.initMaterialData()
  scene.meshes[1].material = VERTEX_COLORED_MATERIAL.initMaterialData()
  scene.meshes[2].material = VERTEX_COLORED_MATERIAL.initMaterialData()
  scene.meshes[1].transform = Scale(0.8, 0.8)
  scene.meshes[2].transform = Scale(0.1, 0.1)
  scene.addShaderGlobal("perspective", Unit4F32)

  const
    shaderConfiguration = createShaderConfiguration(
      name = "default shader",
      inputs = [
        Attr[Mat4]("transform", memoryPerformanceHint = PreferFastRead, perInstance = true),
        Attr[Vec3f]("position", memoryPerformanceHint = PreferFastRead),
        Attr[Vec4f]("color", memoryPerformanceHint = PreferFastRead),
      ],
      intermediates = [Attr[Vec4f]("colorout")],
      uniforms = [Attr[Mat4]("perspective")],
      outputs = [Attr[Vec4f]("fragcolor")],
      vertexCode = """gl_Position = vec4(position, 1.0) * (transform * Uniforms.perspective); colorout = color;""",
      fragmentCode = """fragcolor = colorout;""",
    )

  var engine = InitEngine("Test collisions")

  engine.InitRenderer({VERTEX_COLORED_MATERIAL: shaderConfiguration})
  engine.LoadScene(scene)

  while engine.UpdateInputs() and not KeyIsDown(Escape):
    if WindowWasResized():
      var winSize = engine.GetWindow().size
      scene.setShaderGlobal("perspective", OrthoWindowAspect(winSize[0] / winSize[1]))
    if KeyIsDown(A): scene.meshes[0].transform = scene.meshes[0].transform * Translate(-0.001, 0, 0)
    if KeyIsDown(D): scene.meshes[0].transform = scene.meshes[0].transform * Translate(0.001, 0, 0)
    if KeyIsDown(W): scene.meshes[0].transform = scene.meshes[0].transform * Translate(0, -0.001, 0)
    if KeyIsDown(S): scene.meshes[0].transform = scene.meshes[0].transform * Translate(0, 0.001, 0)
    if KeyIsDown(Q): scene.meshes[0].transform = scene.meshes[0].transform * Rotate(-0.001, Z)
    if KeyIsDown(Key.E): scene.meshes[0].transform = scene.meshes[0].transform * Rotate(0.001, Z)

    if KeyIsDown(Key.Z): scene.meshes[1].transform = scene.meshes[1].transform * Rotate(-0.001, Z)
    if KeyIsDown(Key.X): scene.meshes[1].transform = scene.meshes[1].transform * Rotate(0.001, Z)
    if KeyIsDown(Key.C): scene.meshes[1].transform = scene.meshes[1].transform * Translate(0, -0.001, 0)
    if KeyIsDown(Key.V): scene.meshes[1].transform = scene.meshes[1].transform * Translate(0, 0.001, 0)
    let hitbox = Collider(theType: Box, transform: scene.meshes[0].transform * Translate(-0.5, -0.5))
    let hitsphere = Collider(theType: Sphere, transform: scene.meshes[2].transform, radius: 0.5)
    echo intersects(hitbox, hitsphere)
    engine.RenderScene(scene)
  engine.Destroy()


when isMainModule:
  main()
