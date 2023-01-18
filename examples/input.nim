import std/times
import std/strutils
import std/enumerate

import semicongine/engine
import semicongine/math/vector
import semicongine/math/matrix
import semicongine/vertex
import semicongine/descriptor
import semicongine/mesh
import semicongine/thing
import semicongine/shader
import semicongine/buffer

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2[float32]]
    color: ColorAttribute[Vec3[float32]]
  Uniforms = object
    cursor: Descriptor[Vec2[float32]]
    aspect: Descriptor[float32]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms
uniforms.aspect.value = 1


proc globalUpdate(engine: var Engine, dt: float32) =
  uniforms.aspect.value = float32(engine.vulkan.frameDimension.height) / float32(engine.vulkan.frameDimension.width)
  uniforms.cursor.value[0] = ((float32(engine.input.mouseX) / float32(engine.vulkan.frameDimension.width)) * 2'f32 ) - 1'f32
  uniforms.cursor.value[1] = ((float32(engine.input.mouseY) / float32(engine.vulkan.frameDimension.height)) * 2'f32 ) - 1'f32
  for buffer in pipeline.uniformBuffers:
    buffer.updateData(uniforms)

# vertex data (types must match the above VertexAttributes)
const
  shape = @[
    Vec2([-  1'f32, -  1'f32]),
    Vec2([   1'f32, -  1'f32]),
    Vec2([-0.3'f32, -0.3'f32]),
    Vec2([-0.3'f32, -0.3'f32]),
    Vec2([-  1'f32,    1'f32]),
    Vec2([-  1'f32, -  1'f32]),
  ]
  colors = @[
    Vec3([1'f32, 0'f32, 0'f32]),
    Vec3([1'f32, 0'f32, 0'f32]),
    Vec3([1'f32, 0'f32, 0'f32]),
    Vec3([0.8'f32, 0'f32, 0'f32]),
    Vec3([0.8'f32, 0'f32, 0'f32]),
    Vec3([0.8'f32, 0'f32, 0'f32]),
  ]

when isMainModule:
  var myengine = igniteEngine("Input")

  # build a single-object scene graph
  var cursor = new Thing
  var cursorpart = new Mesh[VertexDataA]
  cursorpart.vertexData = VertexDataA(
    position: PositionAttribute[Vec2[float32]](data: shape),
    color: ColorAttribute[Vec3[float32]](data: colors),
  )
  # transform the cursor a bit to make it look nice
  for i in 0 ..< cursorpart.vertexData.position.data.len:
    let cursorscale = (
      scale2d(0.07'f32, 0.07'f32) *
      translate2d(1'f32, 1'f32) *
      rotate2d(-float32(PI) / 4'f32) *
      scale2d(0.5'f32, 1'f32) *
      rotate2d(float32(PI) / 4'f32)
    )
    let pos = Vec3[float32]([cursorpart.vertexData.position.data[i][0], cursorpart.vertexData.position.data[i][1], 1'f32])
    cursorpart.vertexData.position.data[i] = (cursorscale * pos).xy
  cursor.parts.add cursorpart

  var scene = new Thing
  scene.children.add cursor

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
  out_position.x = in_position.x * uniforms.aspect + uniforms.cursor.x;
  out_position.y = in_position.y + uniforms.cursor.y;
  """)
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
  echo vertexShader
  echo fragmentShader
  pipeline = setupPipeline[VertexDataA, Uniforms, uint16](
    myengine,
    scene,
    vertexShader,
    fragmentShader
  )
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
