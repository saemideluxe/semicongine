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

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec3]
    color: ColorAttribute[Vec3]
  Uniforms = object
    model: Descriptor[Mat44]
    view: Descriptor[Mat44]
    projection: Descriptor[Mat44]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms


proc globalUpdate(engine: var Engine, t, dt: float32) =
  let ratio = float32(engine.vulkan.frameSize.y) / float32(
      engine.vulkan.frameSize.x)
  uniforms.model.value = translate3d(0'f32, 0'f32, 10'f32) * rotate3d(t,
      Yf32) #  * rotate3d(float32(PI), Yf32)

  uniforms.view.value = Unit44f32
  uniforms.projection.value = Mat44(data: [
    ratio, 0'f32, 0'f32, 0'f32,
    0'f32, 1'f32, 0'f32, 0'f32,
    0'f32, 0'f32, 1'f32, 0'f32,
    0'f32, 0'f32, 0'f32, 1'f32,
  ])
  uniforms.projection.value = perspective(float32(PI / 4), float32(
      engine.vulkan.frameSize.x) / float32(
      engine.vulkan.frameSize.y), 0.1'f32, 100'f32)
  engine.vulkan.device.updateUniformData(pipeline, uniforms)

const
  TopLeftFront = Vec3([-0.5'f32, -0.5'f32, -0.5'f32])
  TopRightFront = Vec3([0.5'f32, -0.5'f32, -0.5'f32])
  BottomRightFront = Vec3([0.5'f32, 0.5'f32, -0.5'f32])
  BottomLeftFront = Vec3([-0.5'f32, 0.5'f32, -0.5'f32])
  TopLeftBack = Vec3([0.5'f32, -0.5'f32, 0.5'f32])
  TopRightBack = Vec3([-0.5'f32, -0.5'f32, 0.5'f32])
  BottomRightBack = Vec3([-0.5'f32, 0.5'f32, 0.5'f32])
  BottomLeftBack = Vec3([0.5'f32, 0.5'f32, 0.5'f32])
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
  var myengine = igniteEngine("Hello cube")

  # build a mesh
  var trianglemesh = new Mesh[VertexDataA, uint16]
  trianglemesh.indexed = true
  trianglemesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec3](data: cube_pos),
    color: ColorAttribute[Vec3](data: cube_color),
  )
  trianglemesh.indices = tris
  var cube = newThing("cube", trianglemesh)

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
  out_position = (uniforms.projection * uniforms.view * uniforms.model) * vec4(in_position, 1);
  """)
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  pipeline = setupPipeline[VertexDataA, Uniforms, uint16](
    myengine,
    cube,
    vertexShader,
    fragmentShader
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
