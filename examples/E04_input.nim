import std/tables
import std/enumerate
import std/strutils
import std/typetraits
import std/times
import std/math

import semicongine

type
  # define type of vertex
  VertexDataA = object
    position: PositionAttribute[Vec3]
    color: ColorAttribute[Vec4]
    transform: ModelTransformAttribute
  Uniforms = object
    projection: Descriptor[Mat44]

const
  arrow = @[
    Vec3([-1'f32, -1'f32, 0'f32]),
    Vec3([1'f32, -1'f32, 0'f32]),
    Vec3([-0.3'f32, -0.3'f32, 0'f32]),
    Vec3([-0.3'f32, -0.3'f32, 0'f32]),
    Vec3([-1'f32, 1'f32, 0'f32]),
    Vec3([-1'f32, -1'f32, 0'f32]),
  ]
  arrow_colors = @[
    Vec4([1'f32, 0'f32, 0'f32, 1'f32]),
    Vec4([1'f32, 0'f32, 0'f32, 1'f32]),
    Vec4([1'f32, 0'f32, 0'f32, 1'f32]),
    Vec4([0.8'f32, 0'f32, 0'f32, 1'f32]),
    Vec4([0.8'f32, 0'f32, 0'f32, 1'f32]),
    Vec4([0.8'f32, 0'f32, 0'f32, 1'f32]),
  ]
  # keyboard layout, specifying rows with key widths, negative numbers are empty spaces
  keyrows = (
    [1.0, -0.6, 1.0, 1.0, 1.0, 1.0, -0.5, 1.0, 1.0, 1.0, 1.0, -0.5, 1.0, 1.0,
        1.0, 1.0, -0.1, 1.0, 1.0, 1.0],
    [1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.8, -0.1,
        1.0, 1.0, 1.0],
    [1.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.5, 1.0,
        1.0, 1.0],
    [2.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    [2.6, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.8, -1.3, 1.0],
    [1.5, 1.5, 1.5, 6, 1.5, 1.5, -1.2, 1.5, -0.1, 1.0, 1.0, 1.0],
  )
  keyDimension = 50'f32
  keyGap = 10'f32
  backgroundColor = Vec4([1'f32, 0.3'f32, 0.3'f32, 0'f32])
  baseColor = Vec4([1'f32, 0'f32, 0'f32, 0'f32])
  activeColor = Vec4([1'f32, 1'f32, 1'f32, 0'f32])
  keyIndices = [
    Escape, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, PrintScreen,
    ScrollLock, Pause,

    NumberRowExtra1, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `0`,

    NumberRowExtra2, NumberRowExtra3, Backspace, Insert, Home, PageUp,
    Tab, Q, W, Key.E, R, T, Key.Y, U, I, O, P, LetterRow1Extra1,
    LetterRow1Extra2, Delete, End, PageDown,

    CapsLock, A, S, D, F, G, H, J, K, L, LetterRow2Extra1, LetterRow2Extra2,
    LetterRow2Extra3, Enter,

    ShiftL, Key.Z, Key.X, C, V, B, N, M, LetterRow3Extra1, LetterRow3Extra2,
    LetterRow3Extra3, ShiftR, Up,

    CtrlL, SuperL, AltL, Space, AltR, SuperR, CtrlR, Left, Down, Right
  ]

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms
  scene: Thing
  keyvertexpos: seq[Vec3]
  keyvertexcolor: seq[Vec4]
  keymeshindices: seq[array[3, uint16]]
  rowpos = Vec2([0'f32, 0'f32])
  i = 0'u16
  firstRow = true
  rowWidth = 0'f32
for row in keyrows.fields:
  for key in row:
    let keySpace = float32(keyDimension * key)
    if key > 0:
      if keyIndices[i div 4] == Enter:
        keyvertexpos.add Vec3([rowpos[0], rowpos[1] - keyDimension - keyGap, 0'f32])
        keyvertexpos.add Vec3([rowpos[0] + keySpace, rowpos[1] - keyDimension -
            keyGap, 0'f32])
      else:
        keyvertexpos.add Vec3([rowpos[0], rowpos[1], 0'f32])
        keyvertexpos.add Vec3([rowpos[0] + keySpace, rowpos[1], 0'f32])
      keyvertexpos.add Vec3([rowpos[0] + keySpace, rowpos[1] + keyDimension, 0'f32])
      keyvertexpos.add Vec3([rowpos[0], rowpos[1] + keyDimension, 0'f32])
      keyvertexcolor.add [baseColor, baseColor, baseColor, baseColor]
      keymeshindices.add [i, i + 1, i + 2]
      keymeshindices.add [i + 2, i + 3, i]
      rowpos[0] += keySpace + keyGap
      i += 4
    else:
      rowpos[0] += -keySpace + keyGap
  if firstRow:
    rowWidth = rowpos[0]
  rowpos[0] = 0
  rowpos[1] += keyDimension + keyGap * (if firstRow: 2'f32 else: 1'f32)
  firstRow = false


proc globalUpdate(engine: var Engine, dt: float32) =
  uniforms.projection.value = ortho[float32](
    0'f32, float32(engine.vulkan.frameSize.x),
    0'f32, float32(engine.vulkan.frameSize.y),
    0'f32, 1'f32,
  )
  engine.vulkan.device.updateUniformData(pipeline, uniforms)

  let
    mousePos = translate3d(engine.input.mousePos.x, engine.input.mousePos.y, 0'f32)
    winsize = engine.window.size
    center = translate3d(float32(winsize[0]) / 2'f32, float32(winsize[1]) /
        2'f32, 0.1'f32)
  scene.firstWithName("cursor").transform = mousePos
  scene.firstWithName("keyboard-center").transform = center
  scene.firstWithName("background").transform = scale3d(float32(winsize[0]),
      float32(winsize[1]), 0'f32)
  var mesh = Mesh[VertexDataA, uint16](scene.firstWithName("keyboard").parts[0])
  var hadUpdate = false
  for (index, key) in enumerate(keyIndices):
    if key in engine.input.keysPressed:
      let baseIndex = index * 4
      mesh.vertexData.color.data[baseIndex + 0] = activeColor
      mesh.vertexData.color.data[baseIndex + 1] = activeColor
      mesh.vertexData.color.data[baseIndex + 2] = activeColor
      mesh.vertexData.color.data[baseIndex + 3] = activeColor
      hadUpdate = true
    if key in engine.input.keysReleased:
      let baseIndex = index * 4
      mesh.vertexData.color.data[baseIndex + 0] = baseColor
      mesh.vertexData.color.data[baseIndex + 1] = baseColor
      mesh.vertexData.color.data[baseIndex + 2] = baseColor
      mesh.vertexData.color.data[baseIndex + 3] = baseColor
      hadUpdate = true
  if hadUpdate:
    engine.vulkan.device.updateVertexData(mesh.vertexData.color)


when isMainModule:
  var myengine = igniteEngine("Input")

  # cursor
  var cursormesh = new Mesh[VertexDataA, uint16]
  cursormesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec3](data: arrow, useOnDeviceMemory: true),
    color: ColorAttribute[Vec4](data: arrow_colors),
    transform: ModelTransformAttribute(data: @[Unit44]),
  )
  # transform the cursor a bit to make it look nice
  let cursorscale = (
    scale2d(20'f32, 20'f32) *
    translate2d(1'f32, 1'f32) *
    rotate2d(-float32(PI) / 4'f32) *
    scale2d(0.5'f32, 1'f32) *
    rotate2d(float32(PI) / 4'f32)
  )
  for i in 0 ..< cursormesh.vertexData.position.data.len:
    let pos = Vec3([cursormesh.vertexData.position.data[i][0],
        cursormesh.vertexData.position.data[i][1], 0'f32])
    cursormesh.vertexData.position.data[i] = (cursorscale * pos)

  # keyboard
  var keyboardmesh = new Mesh[VertexDataA, uint16]
  keyboardmesh.indexed = true
  keyboardmesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec3](data: keyvertexpos,
        useOnDeviceMemory: true),
    color: ColorAttribute[Vec4](data: keyvertexcolor),
    transform: ModelTransformAttribute(data: @[Unit44]),
  )
  keyboardmesh.indices = keymeshindices

  # background
  var backgroundmesh = new Mesh[VertexDataA, uint16]
  backgroundmesh.indexed = true
  backgroundmesh.indices = @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]]
  backgroundmesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec3](data: @[
      Vec3([0'f32, 0'f32, 0'f32]),
      Vec3([1'f32, 0'f32, 0'f32]),
      Vec3([1'f32, 1'f32, 0'f32]),
      Vec3([0'f32, 1'f32, 0'f32]),
    ], useOnDeviceMemory: true),
    color: ColorAttribute[Vec4](data: @[
      backgroundColor,
      backgroundColor,
      backgroundColor,
      backgroundColor,
    ]),
    transform: ModelTransformAttribute(data: @[Unit44]),
  )

  scene = newThing("scene")
  scene.add newThing("background", backgroundmesh)
  let keyboard = newThing("keyboard", keyboardmesh)
  keyboard.transform = translate3d(-float32(rowWidth) / 2'f32, -float32(
      tupleLen(keyRows) * (keyDimension + keyGap) - keyGap) / 2'f32, 0'f32)
  scene.add newThing("keyboard-center", keyboard)
  scene.add newThing("cursor", cursormesh)

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[VertexDataA, Uniforms]("""
    out_position = uniforms.projection * transform * vec4(position, 1);
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
