#
#   TODO: Needs Depth-Buffer first!
#
#
#
#
#
#


import std/times
import std/strutils

import semicongine

const
  TopLeftFront = newVec3f(-0.5'f32, -0.5'f32, -0.5'f32)
  TopRightFront = newVec3f(0.5'f32, -0.5'f32, -0.5'f32)
  BottomRightFront = newVec3f(0.5'f32, 0.5'f32, -0.5'f32)
  BottomLeftFront = newVec3f(-0.5'f32, 0.5'f32, -0.5'f32)
  TopLeftBack = newVec3f(0.5'f32, -0.5'f32, 0.5'f32)
  TopRightBack = newVec3f(-0.5'f32, -0.5'f32, 0.5'f32)
  BottomRightBack = newVec3f(-0.5'f32, 0.5'f32, 0.5'f32)
  BottomLeftBack = newVec3f(0.5'f32, 0.5'f32, 0.5'f32)
const
  cube_pos = @[
    TopLeftFront, TopRightFront, BottomRightFront, BottomLeftFront, # front
    TopLeftBack, TopRightBack, BottomRightBack, BottomLeftBack, # back
    TopLeftBack, TopLeftFront, BottomLeftFront, BottomLeftBack, # left
    TopRightBack, TopRightFront, BottomRightFront, BottomRightBack, # right
    TopLeftBack, TopRightBack, TopRightFront, TopLeftFront, # top
    BottomLeftFront, BottomRightFront, BottomRightBack, BottomLeftBack, # bottom
  ]
  cube_color = @[
    Rf32, Rf32, Rf32, Rf32,
    Rf32 * 0.5'f32, Rf32 * 0.5'f32, Rf32 * 0.5'f32, Rf32 * 0.5'f32,
    Gf32, Gf32, Gf32, Gf32,
    Gf32 * 0.5'f32, Gf32 * 0.5'f32, Gf32 * 0.5'f32, Gf32 * 0.5'f32,
    Bf32, Bf32, Bf32, Bf32,
    Bf32 * 0.5'f32, Bf32 * 0.5'f32, Bf32 * 0.5'f32, Bf32 * 0.5'f32,
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
    vertexInput = @[
      attr[Vec3f]("position"),
      attr[Vec3f]("color", memoryPerformanceHint=PreferFastWrite),
    ]
    vertexOutput = @[attr[Vec3f]("outcolor")]
    uniforms = @[
      attr[Mat4]("projection"),
      attr[Mat4]("view"),
      attr[Mat4]("model"),
    ]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      outputs=vertexOutput,
      main="""outcolor = color; gl_Position = (Uniforms.projection * Uniforms.view * Uniforms.model) * vec4(position, 1);"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      outputs=fragOutput,
      main="color = vec4(outcolor, 1);"
    )
  myengine.setRenderer(myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  var
    projection = initShaderGlobal("projection", Unit4f32)
    view = initShaderGlobal("view", Unit4f32)
    model = initShaderGlobal("model", Unit4f32)
    cube = newEntity("cube", newMesh(positions=cube_pos, indices=tris, colors=cube_color))
  cube.components.add projection
  cube.components.add view
  cube.components.add model
  myengine.addScene(cube, vertexInput)

  var t: float32 = cpuTime()
  while myengine.updateInputs() == Running and not myengine.keyWasPressed(Escape):
    setValue[Mat4](model.value, translate3d(0'f32, 0'f32, 10'f32) * rotate3d(t, Yf32))
    setValue[Mat4](
      projection.value,
      perspective(
        float32(PI / 4),
        float32(myengine.getWindow().size[0]) / float32(myengine.getWindow().size[0]),
        0.1'f32,
        100'f32
      )
    )
    t = cpuTime()

    myengine.renderScene(cube)

  myengine.destroy()
