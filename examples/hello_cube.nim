#
#   TODO: Needs Depth-Buffer first!
#
#
#
#
#
#
#
#
import std/times
import std/strutils
import std/enumerate

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[TVec3[float32]]
    color: ColorAttribute[TVec3[float32]]
  Uniforms = object
    model: Descriptor[Mat44[float32]]
    view: Descriptor[Mat44[float32]]
    projection: Descriptor[Mat44[float32]]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms:Uniforms
  t: float32


proc globalUpdate(engine: var Engine, dt: float32) =
  let ratio = float32(engine.vulkan.frameDimension.height) / float32(engine.vulkan.frameDimension.width)
  t += dt
  uniforms.model.value = translate3d(0'f32, 0'f32, 10'f32) * rotate3d(t, Yf32) #  * rotate3d(float32(PI), Yf32)

  uniforms.view.value = Unit44f32
  uniforms.projection.value = Mat44[float32](data:[
    ratio, 0'f32, 0'f32, 0'f32,
    0'f32, 1'f32, 0'f32, 0'f32,
    0'f32, 0'f32, 1'f32, 0'f32,
    0'f32, 0'f32, 0'f32, 1'f32,
  ])
  uniforms.projection.value = perspective(float32(PI / 4), float32(engine.vulkan.frameDimension.width) / float32(engine.vulkan.frameDimension.height), 0.1'f32, 100'f32)
  for buffer in pipeline.uniformBuffers:
    buffer.updateData(uniforms)

const
  TopLeftFront =     TVec3([ -0.5'f32, -0.5'f32, -0.5'f32])
  TopRightFront =    TVec3([  0.5'f32, -0.5'f32, -0.5'f32])
  BottomRightFront = TVec3([  0.5'f32,  0.5'f32, -0.5'f32])
  BottomLeftFront =  TVec3([ -0.5'f32,  0.5'f32, -0.5'f32])
  TopLeftBack =      TVec3([  0.5'f32, -0.5'f32,  0.5'f32])
  TopRightBack =     TVec3([ -0.5'f32, -0.5'f32,  0.5'f32])
  BottomRightBack =  TVec3([ -0.5'f32,  0.5'f32,  0.5'f32])
  BottomLeftBack =   TVec3([  0.5'f32,  0.5'f32,  0.5'f32])
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
var off = 0'u16 * 4
# tris.add [off + 0'u16, off + 1'u16, off + 2'u16]
# tris.add [off + 2'u16, off + 3'u16, off + 0'u16]
# off = 1'u16 * 4
# tris.add [off + 0'u16, off + 1'u16, off + 2'u16]
# tris.add [off + 2'u16, off + 3'u16, off + 0'u16]
# off = 4'u16 * 4
# tris.add [off + 0'u16, off + 1'u16, off + 2'u16]
# tris.add [off + 2'u16, off + 3'u16, off + 0'u16]
# off = 3'u16 * 4
# tris.add [off + 0'u16, off + 1'u16, off + 2'u16]
# tris.add [off + 2'u16, off + 3'u16, off + 0'u16]

when isMainModule:
  var myengine = igniteEngine("Hello cube")

  # build a mesh
  var trianglemesh = new IndexedMesh[VertexDataA, uint16]
  trianglemesh.vertexData = VertexDataA(
    position: PositionAttribute[TVec3[float32]](data: cube_pos),
    color: ColorAttribute[TVec3[float32]](data: cube_color),
  )
  trianglemesh.indices = tris
  # build a single-object scene graph
  var triangle = new Thing
  # add the triangle mesh to the object
  triangle.parts.add trianglemesh

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
  out_position = (uniforms.projection * uniforms.view * uniforms.model) * vec4(in_position, 1);
  """)
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  pipeline = setupPipeline[VertexDataA, Uniforms, uint16](
    myengine,
    triangle,
    vertexShader,
    fragmentShader
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
