import std/times
import std/strutils
import std/enumerate

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[TVec2[float32]]
    color: ColorAttribute[TVec3[float32]]
    id: InstanceAttribute[TVec3[float32]]

var pipeline: RenderPipeline[VertexDataA, void]

proc globalUpdate(engine: var Engine, dt: float32) =
  discard

# vertex data (types must match the above VertexAttributes)
const
  triangle_pos = @[
    TVec2([ 0.0'f32, -0.5'f32]),
    TVec2([ 0.5'f32,  0.5'f32]),
    TVec2([-0.5'f32,  0.5'f32]),
  ]
  triangle_color = @[
    TVec3([1.0'f32, 0.0'f32, 0.0'f32]),
    TVec3([0.0'f32, 1.0'f32, 0.0'f32]),
    TVec3([0.0'f32, 0.0'f32, 1.0'f32]),
  ]

when isMainModule:
  var myengine = igniteEngine("Hello triangle")

  # build a mesh
  var trianglemesh = new Mesh[VertexDataA]
  trianglemesh.vertexData = VertexDataA(
    position: PositionAttribute[TVec2[float32]](data: triangle_pos),
    color: ColorAttribute[TVec3[float32]](data: triangle_color),
    id: InstanceAttribute[TVec3[float32]](data: @[TVec3[float32]([0.5'f32, 0.5'f32, 0.5'f32])]),
  )
  # build a single-object scene graph
  var triangle = new Thing
  # add the triangle mesh to the object
  triangle.parts.add trianglemesh

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, void]()
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  pipeline = setupPipeline[VertexDataA, void, void](
    myengine,
    triangle,
    vertexShader,
    fragmentShader
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
