import std/strutils
import std/times

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec2]
    color: ColorAttribute[Vec3]
    transform: ModelTransformAttribute
  Uniforms = object
    projection: Descriptor[Mat44]
    cursor: Descriptor[Vec2]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms
  scene: Thing
  time: float


proc globalUpdate(engine: var Engine, dt: float32) =
  time += dt
  uniforms.cursor.value = engine.input.mousePos
  uniforms.projection.value = ortho[float32](
    0'f32, float32(engine.vulkan.frameSize.x),
    0'f32, float32(engine.vulkan.frameSize.y),
    0'f32, 1'f32,
  )
  engine.vulkan.device.updateUniformData(pipeline, uniforms)

  let cursor = firstPartWithName[Mesh[VertexDataA]](scene, "cursor")
  if cursor != nil:
    for c in cursor.vertexData.color.data.mitems:
      c[1] = (sin(time * 8) * 0.5 + 0.5) * 0.2
      c[2] = (sin(time * 8) * 0.5 + 0.5) * 0.2
    engine.vulkan.device.updateVertexData(cursor.vertexData.color)

    var trans = translate3d(engine.input.mousePos.x, engine.input.mousePos.y, 0'f32)
    # cursor.vertexData.transform.data = @[trans.transposed()]
    engine.vulkan.device.updateVertexData(cursor.vertexData.transform)


const
  shape = @[
    Vec2([ - 1'f32, - 1'f32]),
    Vec2([1'f32, - 1'f32]),
    Vec2([-0.3'f32, -0.3'f32]),
    Vec2([-0.3'f32, -0.3'f32]),
    Vec2([ - 1'f32, 1'f32]),
    Vec2([ - 1'f32, - 1'f32]),
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

  var cursormesh = new Mesh[VertexDataA]
  cursormesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec2](data: shape, useOnDeviceMemory: true),
    color: ColorAttribute[Vec3](data: colors),
    transform: ModelTransformAttribute(data: @[Unit44]),
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
    let pos = Vec3([cursormesh.vertexData.position.data[i][0],
        cursormesh.vertexData.position.data[i][1], 1'f32])
    cursormesh.vertexData.position.data[i] = (cursorscale * pos).xy

  var boxmesh = new Mesh[VertexDataA]
  boxmesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec2](data: shape),
    color: ColorAttribute[Vec3](data: colors),
    transform: ModelTransformAttribute(data: @[Unit44]),
  )
  for i in 0 ..< boxmesh.vertexData.position.data.len:
    let boxscale = translate2d(100'f32, 100'f32) * scale2d(100'f32, 100'f32)
    let pos = Vec3([boxmesh.vertexData.position.data[i][0],
        boxmesh.vertexData.position.data[i][1], 1'f32])
    boxmesh.vertexData.position.data[i] = (boxscale * pos).xy

  scene = newThing("scene")
  scene.add newThing("cursor", cursormesh)
  scene.add newThing("a box", boxmesh, newTransform(Unit44), newTransform(
      translate3d(1'f32, 0'f32, 0'f32)))
  scene.add newTransform(scale3d(1.5'f32, 1.5'f32, 1.5'f32))

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
    out_position = uniforms.projection * transform * vec4(position, 0, 1);
  """)
  const fragmentShader = generateFragmentShaderCode[VertexDataA]()
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
