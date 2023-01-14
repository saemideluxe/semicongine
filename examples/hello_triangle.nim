import std/times
import std/strutils
import std/enumerate

import zamikongine/engine
import zamikongine/math/vector
import zamikongine/math/matrix
import zamikongine/vertex
import zamikongine/descriptor
import zamikongine/mesh
import zamikongine/thing
import zamikongine/shader
import zamikongine/buffer

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2[float32]]
    color: ColorAttribute[Vec3[float32]]
  Uniforms = object
    mat: Descriptor[Mat44[float32]]
    dt: Descriptor[float32]

var pipeline: RenderPipeline[VertexDataA, Uniforms]

var pos = 0'f32;
var uniforms = Uniforms(
  mat: Descriptor[Mat44[float32]](value: Unit44f32),
  dt: Descriptor[float32](value: 0'f32),
)
var scaledir = 1'f32
proc globalUpdate(engine: var Engine, dt: float32) =
  uniforms.mat.value = uniforms.mat.value * scale3d(1 + scaledir * dt, 1 + scaledir * dt, 0'f32)
  if uniforms.mat.value[0, 0] > 2'f32 or uniforms.mat.value[0, 0] < 0.5'f32:
    scaledir = - scaledir
  for buffer in pipeline.uniformBuffers:
    buffer.updateData(uniforms)
  echo uniforms.mat.value

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
    position: PositionAttribute[Vec2[float32]](data: triangle_pos),
    color: ColorAttribute[Vec3[float32]](data: triangle_color),
  )
  # build a single-object scene graph
  var triangle = new Thing
  # add the triangle mesh to the object
  triangle.parts.add trianglemesh

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms](
    # have 1 at:
    # [2][0] [0][3]
    # "out_position = vec4(in_position[0] + uniforms.mat[0][0], in_position[1] + uniforms.mat[0][0], 0, 1);"
    "out_position = uniforms.mat * vec4(in_position, 0, 1);"
    # "out_position = vec4(in_position, 0, 1);"
  )
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  static:
    echo "--------------"
    for (i, line) in enumerate(vertexShader.splitLines()):
      echo $(i + 1) & " " & line
    echo "--------------"
    echo fragmentShader
    echo "--------------"
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
