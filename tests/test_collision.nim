import semicongine


proc main() =
  var scene = newScene("main", root=newEntity("rect"))

  var obj1 = newEntity("Obj1", {
    "mesh": Component(rect(color="f00f")),
    "hitbox": Component(HitBox(transform: translate3d(-0.5, -0.5, -0.5)))
  })
  var obj2 = newEntity("Obj2", {
    "mesh": Component(rect()),
    "hitbox": Component(HitBox(transform: translate3d(-0.5, -0.5, -0.5)))
  })
  var obj3 = newEntity("Obj3", {
    "mesh": Component(circle(color="0f0f")),
    "hitbox": Component(HitSphere(radius: 0.5))
  })
  
  scene.root.add obj2
  scene.root.add obj1
  scene.root.add obj3
  obj1.transform = scale3d(0.8, 0.8)
  obj3.transform = scale3d(0.1, 0.1)

  const
    vertexInput = @[
      attr[Mat4]("transform", memoryPerformanceHint=PreferFastRead, perInstance=true),
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
      attr[Vec4f]("color", memoryPerformanceHint=PreferFastRead),
    ]
    intermediate = @[attr[Vec4f]("colorout"),]
    uniforms = @[attr[Mat4]("perspective")]
    fragOutput = @[attr[Vec4f]("fragcolor")]
    (vertexCode, fragmentCode) = compileVertexFragmentShaderSet(
      inputs=vertexInput,
      intermediate=intermediate,
      outputs=fragOutput,
      uniforms=uniforms,
      vertexCode="""gl_Position = vec4(position, 1.0) * (transform * Uniforms.perspective); colorout = color;""",
      fragmentCode="""fragcolor = colorout;""",
    )

  var engine = initEngine("Test collisions")
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput, @[], materialIndexAttribute="")
  scene.addShaderGlobal("perspective", Unit4F32)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      scene.setShaderGlobal("perspective", orthoWindowAspect(winSize[1] / winSize[0]))
    if engine.keyIsDown(A): obj1.transform = obj1.transform * translate3d(-0.001,      0, 0)
    if engine.keyIsDown(D): obj1.transform = obj1.transform * translate3d( 0.001,      0, 0)
    if engine.keyIsDown(W): obj1.transform = obj1.transform * translate3d(     0, -0.001, 0)
    if engine.keyIsDown(S): obj1.transform = obj1.transform * translate3d(     0,  0.001, 0)
    if engine.keyIsDown(Q): obj1.transform = obj1.transform * rotate3d(-0.001, Z)
    if engine.keyIsDown(Key.E): obj1.transform = obj1.transform * rotate3d( 0.001, Z)

    if engine.keyIsDown(Key.Z): obj2.transform = obj2.transform * rotate3d(-0.001, Z)
    if engine.keyIsDown(Key.X): obj2.transform = obj2.transform * rotate3d( 0.001, Z)
    if engine.keyIsDown(Key.C): obj2.transform = obj2.transform * translate3d(0, -0.001, 0)
    if engine.keyIsDown(Key.V): obj2.transform = obj2.transform * translate3d(0,  0.001, 0)
    echo intersects(obj1["hitbox", HitBox()], obj3["hitbox", HitSphere()])
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
