import zamikongine/engine
import zamikongine/math/vector
import zamikongine/vertex
import zamikongine/mesh
import zamikongine/thing
import zamikongine/shader

type
  VertexDataA = object
    position11: VertexAttribute[Vec2[float32]]
    color22: VertexAttribute[Vec3[float32]]

when isMainModule:
  var myengine = igniteEngine()
  var mymesh1 = new Mesh[VertexDataA]
  mymesh1.vertexData = VertexDataA(
    position11: VertexAttribute[Vec2[float32]](
      data: @[
        Vec2([-0.5'f32, -0.5'f32]),
        Vec2([ 0.5'f32,  0.5'f32]),
        Vec2([-0.5'f32,  0.5'f32]),
      ]
    ),
    color22: VertexAttribute[Vec3[float32]](
      data: @[
        Vec3([1.0'f32, 1.0'f32, 0.0'f32]),
        Vec3([0.0'f32, 1.0'f32, 0.0'f32]),
        Vec3([0.0'f32, 1.0'f32, 1.0'f32]),
      ]
    )
  )
  var mymesh2 = new IndexedMesh[VertexDataA, uint16]
  mymesh2.vertexData = VertexDataA(
    position11: VertexAttribute[Vec2[float32]](
      data: @[
        Vec2([ 0.0'f32, -0.7'f32]),
        Vec2([ 0.6'f32,  0.1'f32]),
        Vec2([ 0.3'f32,  0.4'f32]),
      ]
    ),
    color22: VertexAttribute[Vec3[float32]](
      data: @[
        Vec3([1.0'f32, 1.0'f32, 0.0'f32]),
        Vec3([1.0'f32, 0.0'f32, 0.0'f32]),
        Vec3([0.0'f32, 1.0'f32, 1.0'f32]),
      ]
    )
  )
  mymesh2.indices = @[[0'u16, 1'u16, 2'u16]]
  var athing = new Thing
  athing.parts.add mymesh1
  var childthing = new Thing
  childthing.parts.add mymesh2
  athing.children.add childthing

  setupPipeline[VertexDataA, uint16](
    myengine,
    athing,
    generateVertexShaderCode[VertexDataA]("main", "position11", "color22"),
    generateFragmentShaderCode[VertexDataA]("main"),
  )
  myengine.fullThrottle()
  myengine.trash()
