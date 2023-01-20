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
    index: GenericAttribute[uint32]
  Uniforms = object
    t: Descriptor[float32]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniformdata = Uniforms(t: Descriptor[float32](value: 0'f32))

proc globalUpdate(engine: var Engine, dt: float32) =
  uniformdata.t.value += dt
  for buffer in pipeline.uniformBuffers:
    buffer.updateData(uniformdata)

when isMainModule:
  randomize()
  var myengine = igniteEngine("Squares")
  const
    COLUMNS = 10
    ROWS = 10
    WIDTH = 2'f32 / COLUMNS
    HEIGHT = 2'f32 / ROWS
  var
    vertices: array[COLUMNS * ROWS * 4, Vec2]
    colors: array[COLUMNS * ROWS * 4, Vec3]
    iValues: array[COLUMNS * ROWS * 4, uint32]
    indices: array[COLUMNS * ROWS * 2, array[3, uint16]]

  for row in 0 ..< ROWS:
    for col in 0 ..< COLUMNS:
      let
        y: float32 = (row * 2 / COLUMNS) - 1
        x: float32 = (col * 2 / ROWS) - 1
        color = Vec3([(x + 1) / 2, (y + 1) / 2, 0'f32])
        squareIndex = row * COLUMNS + col
        vertIndex = squareIndex * 4
      vertices[vertIndex + 0] = Vec2([x, y])
      vertices[vertIndex + 1] = Vec2([x + WIDTH, y])
      vertices[vertIndex + 2] = Vec2([x + WIDTH, y + HEIGHT])
      vertices[vertIndex + 3] = Vec2([x, y + HEIGHT])
      colors[vertIndex + 0] = color
      colors[vertIndex + 1] = color
      colors[vertIndex + 2] = color
      colors[vertIndex + 3] = color
      iValues[vertIndex + 0] = uint32(squareIndex)
      iValues[vertIndex + 1] = uint32(squareIndex)
      iValues[vertIndex + 2] = uint32(squareIndex)
      iValues[vertIndex + 3] = uint32(squareIndex)
      indices[squareIndex * 2 + 0] = [uint16(vertIndex + 0), uint16(vertIndex + 1), uint16(vertIndex + 2)]
      indices[squareIndex * 2 + 1] = [uint16(vertIndex + 2), uint16(vertIndex + 3), uint16(vertIndex + 0)]


  type PIndexedMesh = ref IndexedMesh[VertexDataA, uint16] # required so we can use ctor with ref/on heap
  var squaremesh = PIndexedMesh(
    vertexData: VertexDataA(
      position11: PositionAttribute[Vec2](data: @vertices),
      color22: ColorAttribute[Vec3](data: @colors),
      index: GenericAttribute[uint32](data: @iValues),
    ),
    indices: @indices
  )
  var scene = new Thing
  var childthing = new Thing
  childthing.parts.add squaremesh
  scene.children.add childthing

  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms](
    """
    float pos_weight = index / 100.0; // add some gamma correction?
    float t = sin(uniforms.t * 0.5) * 0.5 + 0.5;
    float v = min(1, max(0, pow(pos_weight - t, 2)));
    v = pow(1 - v, 3000);
    out_color = vec3(in_color.r, in_color.g, v * 0.5);
    """
  )
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  pipeline = setupPipeline[VertexDataA, Uniforms, uint16](
    myengine,
    scene,
    vertexShader,
    fragmentShader
  )
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
