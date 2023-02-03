import std/tables
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
  # row width is 15, should sum up
  keyrows = (
    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 3.0],
    [1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.8],
    [1.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2],
    [2.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    [3.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 3.0],
    [1.5, 1.5, 1.5, 6, 1.5, 1.5, 1.5],
  )
  rowWidth = 900
  keyHeight = 50'f32
  keyGap = 10'f32
  baseColor = Vec4([1'f32, 0'f32, 0'f32, 0'f32])
  activeColor = Vec4([1'f32, 1'f32, 1'f32, 0'f32])
  keyMap = {
    Escape: 0, F1: 1, F2: 2, F3: 3, F4: 4, F5: 5, F6: 6, F7: 7, F8: 8, F9: 9,
    F10: 10, F11: 11, F12: 12,
    NumberRowExtra1: 13, `1`: 14, `2`: 15, `3`: 16, `4`: 17, `5`: 18, `6`: 19,
    `7`: 20, `8`: 21, `9`: 22, `0`: 23, NumberRowExtra2: 24,
    NumberRowExtra3: 25, Backspace: 26,
    Tab: 27, Q: 28, W: 29, Key.E: 30, R: 31, T: 32, Key.Y: 33, U: 34, I: 35, O: 36,
    P: 37, LetterRow1Extra1: 38, LetterRow1Extra2: 39, LetterRow1Extra3: 40,
    CapsLock: 41, A: 42, S: 43, D: 44, F: 45, G: 46, H: 47, J: 48, K: 49, L: 50,
    LetterRow2Extra1: 51, LetterRow2Extra2: 52,
    ShiftL: 53, Key.Z: 54, Key.X: 55, C: 56, V: 57, B: 58, N: 59, M: 60,
    LetterRow3Extra1: 61, LetterRow3Extra2: 62, LetterRow3Extra3: 63,
    ShiftR: 64,
    CtrlL: 65, SuperL: 66, AltL: 67, Space: 68, AltR: 69, SuperR: 70, CtrlR: 71,
  }.toTable

var
  pipeline: RenderPipeline[VertexDataA, Uniforms]
  uniforms: Uniforms
  scene: Thing
  keyvertexpos: seq[Vec3]
  keyvertexcolor: seq[Vec4]
  keyindices: seq[array[3, uint16]]
  rowpos = Vec2([0'f32, 0'f32])
  i = 0'u16
for row in keyrows.fields:
  let
    rowSpacePx = rowWidth - (row.len - 1) * keyGap
    rowSpace = sum(row)
  for key in row:
    let keySpace = float32((key / rowSpace) * rowSpacePx)
    keyvertexpos.add Vec3([rowpos[0], rowpos[1], 0'f32])
    keyvertexpos.add Vec3([rowpos[0] + keySpace, rowpos[1], 0'f32])
    keyvertexpos.add Vec3([rowpos[0] + keySpace, rowpos[1] + keyHeight, 0'f32])
    keyvertexpos.add Vec3([rowpos[0], rowpos[1] + keyHeight, 0'f32])
    keyvertexcolor.add [baseColor, baseColor, baseColor, baseColor]
    keyindices.add [i, i + 1, i + 2]
    keyindices.add [i + 2, i + 3, i]
    rowpos[0] += keySpace + keyGap
    i += 4
  rowpos[0] = 0
  rowpos[1] += keyHeight + keyGap


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
  var mesh = Mesh[VertexDataA, uint16](scene.firstWithName("keyboard").parts[0])
  var hadUpdate = false
  for key, index in keyMap.pairs:
    if key in engine.input.keysPressed:
      echo "Pressed ", key
      let baseIndex = index * 4
      mesh.vertexData.color.data[baseIndex + 0] = activeColor
      mesh.vertexData.color.data[baseIndex + 1] = activeColor
      mesh.vertexData.color.data[baseIndex + 2] = activeColor
      mesh.vertexData.color.data[baseIndex + 3] = activeColor
      hadUpdate = true
    if key in engine.input.keysReleased:
      echo "Released ", key
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

  var keyboardmesh = new Mesh[VertexDataA, uint16]
  keyboardmesh.indexed = true
  keyboardmesh.vertexData = VertexDataA(
    position: PositionAttribute[Vec3](data: keyvertexpos,
        useOnDeviceMemory: true),
    color: ColorAttribute[Vec4](data: keyvertexcolor),
    transform: ModelTransformAttribute(data: @[Unit44]),
  )
  keyboardmesh.indices = keyindices

  scene = newThing("scene")
  let keyboard = newThing("keyboard", keyboardmesh)
  keyboard.transform = translate3d(-float32(rowWidth) / 2'f32, -float32(
      tupleLen(keyRows) * (keyHeight + keyGap) - keyGap) / 2'f32, 0'f32)
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
