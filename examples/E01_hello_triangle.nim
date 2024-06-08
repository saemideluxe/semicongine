import std/tables

import ../semicongine

# shader setup
const
  shaderConfiguration = createShaderConfiguration(
    name = "default shader",
    inputs = [
      attr[Vec3f]("position"),
      attr[Vec4f]("color"),
    ],
    intermediates = [attr[Vec4f]("outcolor")],
    outputs = [attr[Vec4f]("color")],
    vertexCode = "gl_Position = vec4(position, 1.0); outcolor = color;",
    fragmentCode = "color = outcolor;",
  )

# scene setup
var
  scene = Scene(name: "scene",
    meshes: @[newMesh(
      positions = [NewVec3f(-0.5, 0.5), NewVec3f(0, -0.5), NewVec3f(0.5, 0.5)],
      colors = [NewVec4f(1, 0, 0, 1), NewVec4f(0, 1, 0, 1), NewVec4f(0, 0, 1, 1)],
      material = VERTEX_COLORED_MATERIAL.InitMaterialData()
    )]
  )
  myengine = initEngine("Hello triangle", showFps = true)

myengine.initRenderer({VERTEX_COLORED_MATERIAL: shaderConfiguration}, inFlightFrames = 2)
myengine.loadScene(scene)

while myengine.UpdateInputs() and not KeyWasPressed(Escape):
  transform[Vec3f](scene.meshes[0][], "position", scale(1.001, 1.001))
  myengine.renderScene(scene)

myengine.destroy()
