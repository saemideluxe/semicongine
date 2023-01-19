import std/times
import std/strutils
import std/enumerate

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2[float32]]
    color: ColorAttribute[Vec3[float32]]
    translate: InstanceAttribute[Vec2[float32]]
  Uniforms = object
    projection: Descriptor[Mat44[float32]]
    cursor: Descriptor[Vec2[float32]]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms


proc globalUpdate(engine: var Engine, dt: float32) =
  uniforms.cursor.value[0] = float32(engine.input.mouseX)
  uniforms.cursor.value[1] = float32(engine.input.mouseY)
  uniforms.projection.value = ortho[float32](
    0'f32, float32(engine.vulkan.frameDimension.width),
    0'f32, float32(engine.vulkan.frameDimension.height),
    0'f32, 1'f32,
  )
  echo uniforms.projection.value
  # echo uniforms.projection
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
    translate: InstanceAttribute[Vec2[float32]](data: @[Vec2[float32]([100'f32, 100'f32])]),
  )
  # transform the cursor a bit to make it look nice
  for i in 0 ..< cursorpart.vertexData.position.data.len:
    let cursorscale = (
      scale2d(20'f32, 20'f32) *
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
    out_position = uniforms.projection * vec4(in_position + uniforms.cursor, 0, 1);
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
