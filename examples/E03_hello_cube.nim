import std/tables
import std/times

import ../semicongine

const
  TopLeftFront = NewVec3f(-0.5'f32, -0.5'f32, -0.5'f32)
  TopRightFront = NewVec3f(0.5'f32, -0.5'f32, -0.5'f32)
  BottomRightFront = NewVec3f(0.5'f32, 0.5'f32, -0.5'f32)
  BottomLeftFront = NewVec3f(-0.5'f32, 0.5'f32, -0.5'f32)
  TopLeftBack = NewVec3f(0.5'f32, -0.5'f32, 0.5'f32)
  TopRightBack = NewVec3f(-0.5'f32, -0.5'f32, 0.5'f32)
  BottomRightBack = NewVec3f(-0.5'f32, 0.5'f32, 0.5'f32)
  BottomLeftBack = NewVec3f(0.5'f32, 0.5'f32, 0.5'f32)
const
  cube_pos = @[
    TopLeftFront, TopRightFront, BottomRightFront, BottomLeftFront,     # front
    TopLeftBack, TopRightBack, BottomRightBack, BottomLeftBack,         # back
    TopLeftBack, TopLeftFront, BottomLeftFront, BottomLeftBack,         # left
    TopRightBack, TopRightFront, BottomRightFront, BottomRightBack,     # right
    TopLeftBack, TopRightBack, TopRightFront, TopLeftFront,             # top
    BottomLeftFront, BottomRightFront, BottomRightBack, BottomLeftBack, # bottom
  ]
  R = NewVec4f(1, 0, 0, 1)
  G = NewVec4f(0, 1, 0, 1)
  B = NewVec4f(0, 0, 1, 1)
  cube_color = @[
    R, R, R, R,
    R * 0.5'f32, R * 0.5'f32, R * 0.5'f32, R * 0.5'f32,
    G, G, G, G,
    G * 0.5'f32, G * 0.5'f32, G * 0.5'f32, G * 0.5'f32,
    B, B, B, B,
    B * 0.5'f32, B * 0.5'f32, B * 0.5'f32, B * 0.5'f32,
  ]
var
  tris: seq[array[3, uint16]]
for i in 0'u16 ..< 6'u16:
  let off = i * 4
  tris.add [off + 0'u16, off + 1'u16, off + 2'u16]
  tris.add [off + 2'u16, off + 3'u16, off + 0'u16]

when isMainModule:
  var myengine = initEngine("Hello cube")

  const
    shaderConfiguration = createShaderConfiguration(
      name = "default shader",
      inputs = [
        attr[Vec3f]("position"),
        attr[Vec4f]("color", memoryPerformanceHint = PreferFastWrite),
      ],
      intermediates = [attr[Vec4f]("outcolor")],
      uniforms = [
        attr[Mat4]("projection"),
        attr[Mat4]("view"),
        attr[Mat4]("model"),
      ],
      outputs = [attr[Vec4f]("color")],
      vertexCode = """outcolor = color; gl_Position = (Uniforms.projection * Uniforms.view * Uniforms.model) * vec4(position, 1);""",
      fragmentCode = "color = outcolor;",
    )
  var matDef = MaterialType(name: "default material", vertexAttributes: {"position": Vec3F32, "color": Vec4F32}.toTable)
  var cube = Scene(name: "scene", meshes: @[newMesh(positions = cube_pos, indices = tris, colors = cube_color, material = matDef.initMaterialData(name = "default"))])
  cube.addShaderGlobal("projection", Unit4f32)
  cube.addShaderGlobal("view", Unit4f32)
  cube.addShaderGlobal("model", Unit4f32)
  myengine.initRenderer({matDef: shaderConfiguration})
  myengine.loadScene(cube)

  var t: float32 = cpuTime()
  while myengine.UpdateInputs() and not KeyWasPressed(Escape):
    setShaderGlobal(cube, "model", translate(0'f32, 0'f32, 10'f32) * rotate(t, Yf32))
    setShaderGlobal(cube, "projection",
      perspective(
        float32(PI / 4),
        float32(myengine.GetWindow().size[0]) / float32(myengine.GetWindow().size[1]),
        0.1'f32,
        100'f32
      )
    )
    t = cpuTime()
    myengine.renderScene(cube)

  myengine.destroy()
