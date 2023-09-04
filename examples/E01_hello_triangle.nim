import std/tables

import ../src/semicongine

# shader setup
const
  shaderConfiguration = createShaderConfiguration(
    inputs=[
      attr[Vec3f]("position"),
      attr[Vec4f]("color"),
    ],
    intermediates=[attr[Vec4f]("outcolor")],
    outputs=[attr[Vec4f]("color")],
    vertexCode="gl_Position = vec4(position, 1.0); outcolor = color;",
    fragmentCode="color = outcolor;",
  )

# scene setup
var
  triangle = Scene(name: "scene",
    meshes: @[newMesh(
      [newVec3f(-0.5, 0.5), newVec3f(0, -0.5), newVec3f(0.5, 0.5)],
      [newVec4f(1, 0, 0, 1), newVec4f(0, 1, 0, 1), newVec4f(0, 0, 1, 1)],
      material=Material(name: "default")
    )]
  )
  myengine = initEngine("Hello triangle")

myengine.initRenderer({"default": shaderConfiguration}.toTable)
myengine.addScene(triangle)

while myengine.updateInputs() == Running and not myengine.keyWasPressed(Escape):
  myengine.renderScene(triangle)

myengine.destroy()
