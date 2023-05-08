import semicongine


const
  vertexInput = @[
    attr[Vec3f]("position"),
    attr[Vec3f]("color"),
  ]
  vertexOutput = @[attr[Vec3f]("outcolor")]
  fragOutput = @[attr[Vec4f]("color")]
  vertexCode = compileGlslShader(
    stage=VK_SHADER_STAGE_VERTEX_BIT,
    inputs=vertexInput,
    outputs=vertexOutput,
    main="""
    gl_Position = vec4(position, 1.0);
    outcolor = color;
    """
  )
  fragmentCode = compileGlslShader(
    stage=VK_SHADER_STAGE_FRAGMENT_BIT,
    inputs=vertexOutput,
    outputs=fragOutput,
    main="color = vec4(outcolor, 1);"
  )

var
  triangle = newScene("scene", newEntity(
    "triangle",
    newMesh(
      [newVec3f(-0.5, 0.5), newVec3f(0, -0.5), newVec3f(0.5, 0.5)],
      [X, Y, Z],
    )
  ))
  myengine = initEngine("Hello triangle")
  renderPass = myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode)

myengine.setRenderer(renderPass)
myengine.addScene(triangle, vertexInput)

while myengine.updateInputs() == Running and not myengine.keyWasPressed(Escape):
  myengine.renderScene(triangle)

myengine.destroy()
