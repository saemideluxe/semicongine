import std/enumerate
import std/tables
import std/typetraits
import std/math

import ../semicongine

const
  arrow = @[
    newVec3f(-1, -1),
    newVec3f(1, -1),
    newVec3f(-0.3, -0.3),
    newVec3f(-0.3, -0.3),
    newVec3f(-1, 1),
    newVec3f(-1, -1),
  ]
  # keyboard layout, specifying rows with key widths, negative numbers are empty spaces
  keyrows = (
    [1.0, -0.6, 1.0, 1.0, 1.0, 1.0, -0.5, 1.0, 1.0, 1.0, 1.0, -0.5, 1.0, 1.0, 1.0, 1.0, -0.1, 1.0, 1.0, 1.0],
    [1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.8, -0.1, 1.0, 1.0, 1.0],
    [1.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.5, 1.0, 1.0, 1.0],
    [2.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    [2.6, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.8, -1.3, 1.0],
    [1.5, 1.5, 1.5, 6, 1.5, 1.5, -1.2, 1.5, -0.1, 1.0, 1.0, 1.0],
  )
  keyDimension = 50'f32
  keyGap = 10'f32
  backgroundColor = newVec4f(0.6705882352941176, 0.6078431372549019, 0.5882352941176471, 1)
  baseColor = newVec4f(0.9411764705882353, 0.9058823529411765, 0.8470588235294118, 1)
  activeColor = newVec4f(0.6509803921568628, 0.22745098039215686, 0.3137254901960784, 1)
  arrow_colors = @[
    baseColor * 0.9'f32,
    baseColor * 0.9'f32,
    baseColor * 0.9'f32,
    baseColor * 0.8'f32,
    baseColor * 0.8'f32,
    baseColor * 0.8'f32,
  ]
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

# build keyboard and cursor meshes
var
  scene: Scene
  keyvertexpos: seq[Vec3f]
  keyvertexcolor: seq[Vec4f]
  keymeshindices: seq[array[3, uint16]]
  rowpos = newVec2f(0, 0)
  i = 0'u16
  firstRow = true
  rowWidth = 0'f32
for row in keyrows.fields:
  for key in row:
    let keySpace = float32(keyDimension * key)
    if key > 0:
      if keyIndices[i div 4] == Enter:
        keyvertexpos.add newVec3f(rowpos[0], rowpos[1] - keyDimension - keyGap)
        keyvertexpos.add newVec3f(rowpos[0] + keySpace, rowpos[1] - keyDimension - keyGap)
      else:
        keyvertexpos.add newVec3f(rowpos[0], rowpos[1])
        keyvertexpos.add newVec3f(rowpos[0] + keySpace, rowpos[1])
      keyvertexpos.add newVec3f(rowpos[0] + keySpace, rowpos[1] + keyDimension)
      keyvertexpos.add newVec3f(rowpos[0], rowpos[1] + keyDimension)
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


when isMainModule:
  var myengine = initEngine("Input")

  # transform the cursor a bit to make it look nice
  let cursorscale = (
    scale2d(20'f32, 20'f32) *
    translate2d(1'f32, 1'f32) *
    rotate2d(-float32(PI) / 4'f32) *
    scale2d(0.5'f32, 1'f32) *
    rotate2d(float32(PI) / 4'f32)
  )
  var positions = arrow
  for i in 0 ..< positions.len:
    positions[i] = cursorscale * newVec3f(positions[i].x, positions[i].y)

  # define mesh objects
  var
    matDef = MaterialType(name: "default", vertexAttributes: {
      "position": Vec3F32,
      "color": Vec4F32,
    }.toTable)
    cursormesh = newMesh(
      positions = positions,
      colors = arrow_colors,
      material = matDef.initMaterialData(),
    )
    keyboardmesh = newMesh(
      positions = keyvertexpos,
      colors = keyvertexcolor,
      indices = keymeshindices,
      material = matDef.initMaterialData(),
    )
    backgroundmesh = newMesh(
      positions = @[
        newVec3f(0'f32, 0'f32),
        newVec3f(1'f32, 0'f32),
        newVec3f(1'f32, 1'f32),
        newVec3f(0'f32, 1'f32),
      ],
      colors = @[
        backgroundColor,
        backgroundColor,
        backgroundColor,
        backgroundColor,
      ],
      indices = @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
      material = matDef.initMaterialData(),
    )

  # define mesh objects
  var keyboard_center = translate(
    -float32(rowWidth) / 2'f32,
    -float32(tupleLen(keyRows) * (keyDimension + keyGap) - keyGap) / 2'f32,
    0'f32
  )
  scene = Scene(name: "scene", meshes: @[backgroundmesh, keyboardmesh, cursormesh])

  # shaders
  const
    shaderConfiguration = createShaderConfiguration(
      name = "default shader",
      inputs = [
        attr[Vec3f]("position"),
        attr[Vec4f]("color", memoryPerformanceHint = PreferFastWrite),
        attr[Mat4]("transform", memoryPerformanceHint = PreferFastWrite, perInstance = true),
      ],
      intermediates = [attr[Vec4f]("outcolor")],
      uniforms = [attr[Mat4]("projection")],
      outputs = [attr[Vec4f]("color")],
      vertexCode = """outcolor = color; gl_Position = vec4(position, 1) * (transform * Uniforms.projection);""",
      fragmentCode = "color = outcolor;",
    )

  # set up rendering
  myengine.initRenderer({matDef: shaderConfiguration})
  scene.addShaderGlobal("projection", Unit4f32)
  myengine.loadScene(scene)
  myengine.HideSystemCursor()

  # mainloop
  while myengine.UpdateInputs():
    if WindowWasResized():
      scene.setShaderGlobal("projection",
        ortho(
          0, float32(myengine.GetWindow().size[0]),
          0, float32(myengine.GetWindow().size[1]),
          0, 1,
        )
      )
      let
        winsize = myengine.GetWindow().size
        center = translate(float32(winsize[0]) / 2'f32, float32(winsize[1]) / 2'f32, 0.1'f32)
      keyboardmesh.transform = keyboard_center * center
      backgroundmesh.transform = scale(float32(winsize[0]), float32(winsize[1]), 1'f32)

    let mousePos = translate(MousePosition().x + 20, MousePosition().y + 20, 0'f32)
    cursormesh.transform = mousePos

    for (index, key) in enumerate(keyIndices):
      if KeyWasPressed(key):
        let baseIndex = index * 4
        keyboardmesh["color", baseIndex + 0] = activeColor
        keyboardmesh["color", baseIndex + 1] = activeColor
        keyboardmesh["color", baseIndex + 2] = activeColor
        keyboardmesh["color", baseIndex + 3] = activeColor
      if KeyWasReleased(key):
        let baseIndex = index * 4
        keyboardmesh["color", baseIndex + 0] = baseColor
        keyboardmesh["color", baseIndex + 1] = baseColor
        keyboardmesh["color", baseIndex + 2] = baseColor
        keyboardmesh["color", baseIndex + 3] = baseColor

    myengine.renderScene(scene)

  myengine.destroy()
