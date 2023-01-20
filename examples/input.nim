import std/times
import std/strutils
import std/enumerate

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2]
    color: ColorAttribute[Vec3]
    iscursor: GenericAttribute[int32]
  Uniforms = object
    projection: Descriptor[Mat44]
    cursor: Descriptor[Vec2]

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
  var cursormesh = new Mesh[VertexDataA]
  cursormesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec2](data: shape),
    color: ColorAttribute[Vec3](data: colors),
    iscursor: GenericAttribute[int32](data: @[1'i32, 1'i32, 1'i32, 1'i32, 1'i32, 1'i32]),
  )
  # transform the cursor a bit to make it look nice
  for i in 0 ..< cursormesh.vertexData.position.data.len:
    let cursorscale = (
      scale2d(20'f32, 20'f32) *
      translate2d(1'f32, 1'f32) *
      rotate2d(-float32(PI) / 4'f32) *
      scale2d(0.5'f32, 1'f32) *
      rotate2d(float32(PI) / 4'f32)
    )
    let pos = Vec3([cursormesh.vertexData.position.data[i][0], cursormesh.vertexData.position.data[i][1], 1'f32])
    cursormesh.vertexData.position.data[i] = (cursorscale * pos).xy
  cursor.parts.add cursormesh

  var box = new Thing
  var boxmesh = new Mesh[VertexDataA]
  boxmesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec2](data: shape),
    color: ColorAttribute[Vec3](data: colors),
    iscursor: GenericAttribute[int32](data: @[1'i32, 1'i32, 1'i32, 1'i32, 1'i32, 1'i32]),
  )

  var scene = new Thing
  scene.children.add cursor

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
    out_position = uniforms.projection * vec4(in_position + (uniforms.cursor * iscursor), 0, 1);
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
