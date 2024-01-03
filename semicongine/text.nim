import std/tables
import std/unicode
import std/strformat

import ./core
import ./mesh
import ./material
import ./vulkan/shader

const SHADER_ATTRIB_PREFIX = "semicon_text_"
var instanceCounter = 0

type
  TextAlignment = enum
    Left
    Center
    Right
  Textbox* = object
    maxLen*: int
    text: seq[Rune]
    dirty: bool
    alignment*: TextAlignment = Center
    font*: Font
    mesh*: Mesh

const
  TRANSFORM_ATTRIB = "transform"
  POSITION_ATTRIB = SHADER_ATTRIB_PREFIX & "position"
  UV_ATTRIB = SHADER_ATTRIB_PREFIX & "uv"
  TEXT_MATERIAL_TYPE* = MaterialType(
    name: "default-text-material-type",
    vertexAttributes: {TRANSFORM_ATTRIB: Mat4F32, POSITION_ATTRIB: Vec3F32, UV_ATTRIB: Vec2F32}.toTable,
    attributes: {"fontAtlas": TextureType}.toTable,
  )
  TEXT_SHADER* = createShaderConfiguration(
    inputs=[
      attr[Mat4](TRANSFORM_ATTRIB, memoryPerformanceHint=PreferFastWrite, perInstance=true),
      attr[Vec3f](POSITION_ATTRIB, memoryPerformanceHint=PreferFastWrite),
      attr[Vec2f](UV_ATTRIB, memoryPerformanceHint=PreferFastWrite),
    ],
    intermediates=[attr[Vec2f]("uvFrag")],
    outputs=[attr[Vec4f]("color")],
    samplers=[attr[Texture]("fontAtlas")],
    vertexCode= &"""gl_Position = vec4({POSITION_ATTRIB}, 1.0) * {TRANSFORM_ATTRIB}; uvFrag = {UV_ATTRIB};""",
    fragmentCode= &"""color = texture(fontAtlas, uvFrag);""",
  )

proc updateMesh(textbox: var Textbox) =

  # pre-calculate text-width
  var width = 0'f32
  for i in 0 ..< min(textbox.text.len, textbox.maxLen):
    width += textbox.font.glyphs[textbox.text[i]].advance
    if i < textbox.text.len - 1:
      width += textbox.font.kerning[(textbox.text[i], textbox.text[i + 1])]

  let centerX = width / 2
  let centerY = textbox.font.maxHeight / 2

  var offsetX = 0'f32
  for i in 0 ..< textbox.maxLen:
    let vertexOffset = i * 4
    if i < textbox.text.len:
      let
        glyph = textbox.font.glyphs[textbox.text[i]]
        left = offsetX + glyph.leftOffset
        right = offsetX + glyph.leftOffset + glyph.dimension.x
        top = glyph.topOffset
        bottom = glyph.topOffset + glyph.dimension.y

      textbox.mesh[POSITION_ATTRIB, vertexOffset + 0] = newVec3f(left - centerX, bottom + centerY)
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 1] = newVec3f(left - centerX, top + centerY)
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 2] = newVec3f(right - centerX, top + centerY)
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 3] = newVec3f(right - centerX, bottom + centerY)

      textbox.mesh[UV_ATTRIB, vertexOffset + 0] = glyph.uvs[0]
      textbox.mesh[UV_ATTRIB, vertexOffset + 1] = glyph.uvs[1]
      textbox.mesh[UV_ATTRIB, vertexOffset + 2] = glyph.uvs[2]
      textbox.mesh[UV_ATTRIB, vertexOffset + 3] = glyph.uvs[3]

      offsetX += glyph.advance
      if i < textbox.text.len - 1:
        offsetX += textbox.font.kerning[(textbox.text[i], textbox.text[i + 1])]
    else:
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 0] = newVec3f()
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 1] = newVec3f()
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 2] = newVec3f()
      textbox.mesh[POSITION_ATTRIB, vertexOffset + 3] = newVec3f()


func text*(textbox: Textbox): seq[Rune] =
  textbox.text

proc `text=`*(textbox: var Textbox, text: seq[Rune]) =
  textbox.text = text
  textbox.updateMesh()
proc `text=`*(textbox: var Textbox, text: string) =
  `text=`(textbox, text.toRunes)

proc initTextbox*(maxLen: int, font: Font, text="".toRunes): Textbox =
  var
    positions = newSeq[Vec3f](int(maxLen * 4))
    indices: seq[array[3, uint16]]
    uvs = newSeq[Vec2f](int(maxLen * 4))
  for i in 0 ..< maxLen:
    let offset = i * 4
    indices.add [
      [uint16(offset + 0), uint16(offset + 1), uint16(offset + 2)],
      [uint16(offset + 2), uint16(offset + 3), uint16(offset + 0)],
    ]

  result = Textbox(maxLen: maxLen, text: text, font: font, dirty: true)
  result.mesh = newMesh(positions = positions, indices = indices, uvs = uvs, name = &"textbox-{instanceCounter}")
  inc instanceCounter
  result.mesh[].renameAttribute("position", POSITION_ATTRIB)
  result.mesh[].renameAttribute("uv", UV_ATTRIB)
  result.mesh.material = initMaterialData(
    theType=TEXT_MATERIAL_TYPE,
    name=font.name & " text",
    attributes={"fontAtlas": initDataList(@[font.fontAtlas])},
  )

  result.updateMesh()

proc initTextbox*(maxLen: int, font: Font, text=""): Textbox =
  initTextbox(maxLen=maxLen, font=font, text=text.toRunes)
