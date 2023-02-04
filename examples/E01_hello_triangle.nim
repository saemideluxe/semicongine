import std/times
import std/strutils
import std/enumerate

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2]
    color: ColorAttribute[Vec3]

var pipeline: RenderPipeline[VertexDataA, void]

proc globalUpdate(engine: var Engine, dt: float32) =
  discard

# vertex data (types must match the above VertexAttributes)
const
  triangle_pos = @[
    Vec2([0.0'f32, -0.5'f32]),
    Vec2([0.5'f32, 0.5'f32]),
    Vec2([-0.5'f32, 0.5'f32]),
  ]
  triangle_color = @[
    Vec3([1.0'f32, 0.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 1.0'f32, 0.0'f32]),
    Vec3([0.0'f32, 0.0'f32, 1.0'f32]),
  ]

when isMainModule:
  var myengine = igniteEngine("Hello triangle")

  # build a mesh
  var trianglemesh = new Mesh[VertexDataA, uint16]
  trianglemesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec2](data: triangle_pos),
    color: ColorAttribute[Vec3](data: triangle_color),
  )
  # build a single-object scene graph
  var triangle = newThing("triangle", trianglemesh)

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, void]()
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  pipeline = setupPipeline[VertexDataA, void, uint16](
    myengine,
    triangle,
    vertexShader,
    fragmentShader
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
