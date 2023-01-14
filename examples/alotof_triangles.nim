import std/times
import std/math
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

proc globalUpdate(engine: var Engine, dt: Duration) =
  discard

proc randomtransform(): Mat33[float32] =
  let randomscale = scale2d(float32(rand(1.0) + 0.5), float32(rand(1.0) + 0.5))
  let randomrotate = rotate2d(float32(rand(2 * PI)))
  let randomtranslate = translate2d(float32(rand(1.6) - 0.8), float32(rand(1.6) - 0.8))
  result = randomtranslate * randomrotate * randomscale

when isMainModule:
  randomize()
  var myengine = igniteEngine("A lot of triangles")
  const baseTriangle = [
    Vec3([-0.1'f32, -0.1'f32, 1'f32]),
    Vec3([ 0.1'f32,  0.1'f32, 1'f32]),
    Vec3([-0.1'f32,  0.1'f32, 1'f32]),
  ]

  var scene = new Thing

  for i in 1 .. 300:
    var randommesh = new Mesh[VertexDataA]
    # TODO: create randomized position11 from baseTriangle with random transformation matrix
    let randomcolor1 = Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))])
    let transform1 = randomtransform()
    randommesh.vertexData = VertexDataA(
      position11: VertexAttribute[Vec2[float32]](
        data: @[
          Vec2[float32](transform1 * baseTriangle[0]),
          Vec2[float32](transform1 * baseTriangle[1]),
          Vec2[float32](transform1 * baseTriangle[2]),
        ]
      ),
      color22: VertexAttribute[Vec3[float32]](
        data: @[randomcolor1, randomcolor1, randomcolor1]
      )
    )

    let randomcolor2 = Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))])
    let transform2 = randomtransform()
    var randomindexedmesh = new IndexedMesh[VertexDataA, uint16]
    randomindexedmesh.vertexData = VertexDataA(
      position11: VertexAttribute[Vec2[float32]](
        data: @[
          Vec2[float32](transform2 * baseTriangle[0]),
          Vec2[float32](transform2 * baseTriangle[1]),
          Vec2[float32](transform2 * baseTriangle[2]),
        ]
      ),
      color22: VertexAttribute[Vec3[float32]](
        data: @[randomcolor2, randomcolor2, randomcolor2]
      )
    )
    randomindexedmesh.indices = @[[0'u16, 1'u16, 2'u16]]
    var childthing = new Thing
    childthing.parts.add randommesh
    childthing.parts.add randomindexedmesh
    scene.children.add childthing

  var pipeline = setupPipeline[VertexDataA, float32, float32, uint16](
    myengine,
    scene,
    generateVertexShaderCode[VertexDataA]("main", "position11", "color22"),
    generateFragmentShaderCode[VertexDataA]("main"),
  )
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
