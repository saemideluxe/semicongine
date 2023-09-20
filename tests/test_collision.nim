import semicongine

proc main() =
  var scene = Scene(name: "main")

  scene.add rect(color="f00f")
  scene.add rect()
  scene.add circle(color="0f0f")
  scene.meshes[1].transform = scale(0.8, 0.8)
  scene.meshes[2].transform = scale(0.1, 0.1)
  scene.addShaderGlobal("perspective", Unit4F32)

  const
    shaderConfiguration = createShaderConfiguration(
      inputs=[
        attr[Mat4]("transform", memoryPerformanceHint=PreferFastRead, perInstance=true),
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[Vec4f]("color", memoryPerformanceHint=PreferFastRead),
      ],
      intermediates=[attr[Vec4f]("colorout")],
      uniforms=[attr[Mat4]("perspective")],
      outputs=[attr[Vec4f]("fragcolor")],
      vertexCode="""gl_Position = vec4(position, 1.0) * (transform * Uniforms.perspective); colorout = color;""",
      fragmentCode="""fragcolor = colorout;""",
    )

  var engine = initEngine("Test collisions")

  engine.initRenderer({"default material": shaderConfiguration})
  engine.addScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      scene.setShaderGlobal("perspective", orthoWindowAspect(winSize[1] / winSize[0]))
    if engine.keyIsDown(A): scene.meshes[0].transform = scene.meshes[0].transform * translate(-0.001,      0, 0)
    if engine.keyIsDown(D): scene.meshes[0].transform = scene.meshes[0].transform * translate( 0.001,      0, 0)
    if engine.keyIsDown(W): scene.meshes[0].transform = scene.meshes[0].transform * translate(     0, -0.001, 0)
    if engine.keyIsDown(S): scene.meshes[0].transform = scene.meshes[0].transform * translate(     0,  0.001, 0)
    if engine.keyIsDown(Q): scene.meshes[0].transform = scene.meshes[0].transform * rotate(-0.001, Z)
    if engine.keyIsDown(Key.E): scene.meshes[0].transform = scene.meshes[0].transform * rotate( 0.001, Z)

    if engine.keyIsDown(Key.Z): scene.meshes[1].transform = scene.meshes[1].transform * rotate(-0.001, Z)
    if engine.keyIsDown(Key.X): scene.meshes[1].transform = scene.meshes[1].transform * rotate( 0.001, Z)
    if engine.keyIsDown(Key.C): scene.meshes[1].transform = scene.meshes[1].transform * translate(0, -0.001, 0)
    if engine.keyIsDown(Key.V): scene.meshes[1].transform = scene.meshes[1].transform * translate(0,  0.001, 0)
    let hitbox = Collider(theType: Box, transform: scene.meshes[0].transform * translate(-0.5, -0.5))
    let hitsphere = Collider(theType: Sphere, transform: scene.meshes[2].transform, radius: 0.5)
    echo intersects(hitbox, hitsphere)
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
