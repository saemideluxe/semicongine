import std/tables

import ../semicongine

# shader setup
const
  shaderConfiguration = CreateShaderConfiguration(
    name = "default shader",
    inputs = [
      Attr[Vec3f]("position"),
      Attr[Vec4f]("color"),
    ],
    intermediates = [Attr[Vec4f]("outcolor")],
    outputs = [Attr[Vec4f]("color")],
    vertexCode = "gl_Position = vec4(position, 1.0); outcolor = color;",
    fragmentCode = "color = outcolor;",
  )

# scene setup
var
  scene = Scene(name: "scene",
    meshes: @[NewMesh(
      positions = [NewVec3f(-0.5, 0.5), NewVec3f(0, -0.5), NewVec3f(0.5, 0.5)],
      colors = [NewVec4f(1, 0, 0, 1), NewVec4f(0, 1, 0, 1), NewVec4f(0, 0, 1, 1)],
      material = VERTEX_COLORED_MATERIAL.InitMaterialData()
    )]
  )
  myengine = InitEngine("Hello triangle", showFps = true)

myengine.InitRenderer({VERTEX_COLORED_MATERIAL: shaderConfiguration}, inFlightFrames = 2)
myengine.LoadScene(scene)

while myengine.UpdateInputs() and not KeyWasPressed(Escape):
  Transform[Vec3f](scene.meshes[0][], "position", Scale(1.001, 1.001))
  myengine.RenderScene(scene)

myengine.Destroy()
