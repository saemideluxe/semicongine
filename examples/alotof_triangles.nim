import std/random

import zamikongine/engine
import zamikongine/math/vector
import zamikongine/math/matrix
import zamikongine/vertex
import zamikongine/mesh
import zamikongine/thing
import zamikongine/shader

type
  VertexDataA = object
    position11: VertexAttribute[Vec2[float32]]
    color22: VertexAttribute[Vec3[float32]]

when isMainModule:
  randomize()
  var myengine = igniteEngine()
  const baseTriangle = [
    Vec3([-0.3'f32, -0.3'f32, 1'f32]),
    Vec3([ 0.3'f32,  0.3'f32, 1'f32]),
    Vec3([-0.3'f32,  0.3'f32, 1'f32]),
  ]

  var scene = new Thing

  for i in 1 .. 300:
    var randommesh = new Mesh[VertexDataA]
    # TODO: create randomized position11 from baseTriangle with random transformation matrix
    var transform = (Mat33[float32]().randomized() * 2'f32) - 1'f32
    randommesh.vertexData = VertexDataA(
      position11: VertexAttribute[Vec2[float32]](
        data: @[
          Vec2[float32](transform * baseTriangle[0]),
          Vec2[float32](transform * baseTriangle[1]),
          Vec2[float32](transform * baseTriangle[2]),
        ]
      ),
      color22: VertexAttribute[Vec3[float32]](
        data: @[
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
        ]
      )
    )

    var randomindexedmesh = new IndexedMesh[VertexDataA, uint16]
    randomindexedmesh.vertexData = VertexDataA(
      position11: VertexAttribute[Vec2[float32]](
        data: @[
          Vec2[float32](transform * baseTriangle[0]),
          Vec2[float32](transform * baseTriangle[1]),
          Vec2[float32](transform * baseTriangle[2]),
        ]
      ),
      color22: VertexAttribute[Vec3[float32]](
        data: @[
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
          Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))]),
        ]
      )
    )
    randomindexedmesh.indices = @[[0'u16, 1'u16, 2'u16], [0'u16, 2'u16, 1'u16]]
    var childthing = new Thing
    childthing.parts.add randommesh
    childthing.parts.add randomindexedmesh
    scene.children.add childthing

  setupPipeline[VertexDataA, uint16](
    myengine,
    scene,
    generateVertexShaderCode[VertexDataA]("main", "position11", "color22"),
    generateFragmentShaderCode[VertexDataA]("main"),
  )
  myengine.fullThrottle()
  myengine.trash()
