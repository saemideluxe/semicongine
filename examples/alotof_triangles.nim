import std/times
import std/strutils
import std/math
import std/random
import std/enumerate

import semicongine

type
  VertexDataA = object
    position11: PositionAttribute[Vec2]
    color22: ColorAttribute[Vec3]
  Uniforms = object
    dt: Descriptor[float32]

proc globalUpdate(engine: var Engine, dt: float32) =
  discard

proc randomtransform(): Mat33 =
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
    let randomcolor1 = Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))])
    let transform1 = randomtransform()
    randommesh.vertexData = VertexDataA(
      position11: PositionAttribute[Vec2](
        data: @[
          Vec2(transform1 * baseTriangle[0]),
          Vec2(transform1 * baseTriangle[1]),
          Vec2(transform1 * baseTriangle[2]),
        ]
      ),
      color22: ColorAttribute[Vec3](
        data: @[randomcolor1, randomcolor1, randomcolor1]
      )
    )

    let randomcolor2 = Vec3([float32(rand(1)), float32(rand(1)), float32(rand(1))])
    let transform2 = randomtransform()
    var randomindexedmesh = new IndexedMesh[VertexDataA, uint16]
    randomindexedmesh.vertexData = VertexDataA(
      position11: PositionAttribute[Vec2](
        data: @[
          Vec2(transform2 * baseTriangle[0]),
          Vec2(transform2 * baseTriangle[1]),
          Vec2(transform2 * baseTriangle[2]),
        ]
      ),
      color22: ColorAttribute[Vec3](
        data: @[randomcolor2, randomcolor2, randomcolor2]
      )
    )
    randomindexedmesh.indices = @[[0'u16, 1'u16, 2'u16]]
    var childthing = new Thing
    childthing.parts.add randommesh
    childthing.parts.add randomindexedmesh
    scene.children.add childthing

  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]()
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  var pipeline = setupPipeline[VertexDataA, float32, uint16](
    myengine,
    scene,
    vertexShader,
    fragmentShader
  )
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
