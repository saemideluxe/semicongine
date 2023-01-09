import zamikongine/engine
import zamikongine/math/vector
import zamikongine/vertex
import zamikongine/mesh
import zamikongine/thing
import zamikongine/shader

type
  # define type of vertex
  VertexDataA = object
    position: VertexAttribute[Vec2[float32]]
    color: VertexAttribute[Vec3[float32]]

# vertex data (types must match the above VertexAttributes)
const
  triangle_pos = @[
    Vec2([-0.5'f32, -0.5'f32]),
    Vec2([ 0.5'f32,  0.5'f32]),
    Vec2([-0.5'f32,  0.5'f32]),
  ]
  triangle_color = @[
    Vec3([1.0'f32, 1.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 1.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 1.0'f32, 1.0'f32]),
  ]

when isMainModule:
  var myengine = igniteEngine()

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
  setupPipeline[VertexDataA, uint16](
    myengine,
    triangle,
    generateVertexShaderCode[VertexDataA]("main", "position", "color"),
    generateFragmentShaderCode[VertexDataA]("main"),
  )
  # show something
  myengine.fullThrottle()
  myengine.trash()
