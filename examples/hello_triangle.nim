import std/times

import zamikongine/engine
import zamikongine/math/vector
import zamikongine/vertex
import zamikongine/mesh
import zamikongine/thing
import zamikongine/shader
import zamikongine/buffer

type
  # define type of vertex
  VertexDataA = object
    position: VertexAttribute[Vec2[float32]]
    color: VertexAttribute[Vec3[float32]]
  UniformType = float32

proc globalUpdate(engine: var Engine, dt: Duration) =
  # var t = float32(dt.inNanoseconds) / 1_000_000_000'f32
  # for buffer in engine.vulkan.uniformBuffers:
    # buffer.updateData(t)

  echo dt

# vertex data (types must match the above VertexAttributes)
const
  triangle_pos = @[
    Vec2([ 0.0'f32, -0.5'f32]),
    Vec2([ 0.5'f32,  0.5'f32]),
    Vec2([-0.5'f32,  0.5'f32]),
  ]
  triangle_color = @[
    Vec3([1.0'f32, 0.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 1.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 0.0'f32, 1.0'f32]),
  ]

when isMainModule:
  var myengine = igniteEngine("Hello triangle")

  # build a mesh
  var trianglemesh = new Mesh[VertexDataA]
  trianglemesh.vertexData = VertexDataA(
    position: VertexAttribute[Vec2[float32]](data: triangle_pos),
    color: VertexAttribute[Vec3[float32]](data: triangle_color),
  )
  # build a single-object scene graph
  var triangle = new Thing
  # add the triangle mesh to the object
  triangle.parts.add trianglemesh

  # upload data, prepare shaders, etc
  var pipeline = setupPipeline[VertexDataA, UniformType, float32, uint16](
    myengine,
    triangle,
    generateVertexShaderCode[VertexDataA]("main", "position", "color"),
    generateFragmentShaderCode[VertexDataA]("main"),
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
