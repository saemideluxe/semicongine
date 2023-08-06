import ../src/semicongine


const
  inputs = @[
    attr[Vec3f]("position"),
    attr[Vec4f]("color"),
  ]
  intermediate = @[attr[Vec4f]("outcolor")]
  outputs = @[attr[Vec4f]("color")]
  (vertexCode, fragmentCode) = compileVertexFragmentShaderSet(
    inputs=inputs,
    intermediate=intermediate,
    outputs=outputs,
    vertexCode="""
    gl_Position = vec4(position, 1.0);
    outcolor = color;
    """,
    fragmentCode="color = outcolor;",
  )

var
  triangle = newScene("scene", newEntity(
    "triangle",
    {"mesh": Component(newMesh(
      [newVec3f(-0.5, 0.5), newVec3f(0, -0.5), newVec3f(0.5, 0.5)],
      [newVec4f(1, 0, 0, 1), newVec4f(0, 1, 0, 1), newVec4f(0, 0, 1, 1)],
    ))}
  ))
  myengine = initEngine("Hello triangle")
  renderPass = myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode)

myengine.setRenderer(renderPass)
myengine.addScene(triangle, inputs, @[], transformAttribute="")

while myengine.updateInputs() == Running and not myengine.keyWasPressed(Escape):
  myengine.renderScene(triangle)

myengine.destroy()
