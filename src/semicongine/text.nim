import std/tables
import std/unicode

import ./core
import ./mesh
import ./vulkan/shader

type
  TextAlignment = enum
    Left
    Center
    Right
  Textbox* = object
    maxLen*: int
    text: seq[Rune]
    dirty: bool
    alignment*: TextAlignment
    font*: Font
    mesh*: Mesh

const
  TEXT_MATERIAL* = "default-text"
  TEXT_SHADER* = createShaderConfiguration(
    inputs=[
      attr[Mat4]("transform", memoryPerformanceHint=PreferFastWrite, perInstance=true),
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastWrite),
      attr[Vec2f]("uv", memoryPerformanceHint=PreferFastWrite),
    ],
    intermediates=[attr[Vec2f]("uvFrag")],
    outputs=[attr[Vec4f]("color")],
    samplers=[attr[Sampler2DType]("fontAtlas")],
    vertexCode="""gl_Position = vec4(position, 1.0) * transform; uvFrag = uv;""",
    fragmentCode="""color = texture(fontAtlas, uvFrag);""",
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

      textbox.mesh[].updateAttributeData("position", vertexOffset + 0, newVec3f(left - centerX, bottom + centerY))
      textbox.mesh[].updateAttributeData("position", vertexOffset + 1, newVec3f(left - centerX, top + centerY))
      textbox.mesh[].updateAttributeData("position", vertexOffset + 2, newVec3f(right - centerX, top + centerY))
      textbox.mesh[].updateAttributeData("position", vertexOffset + 3, newVec3f(right - centerX, bottom + centerY))

      textbox.mesh[].updateAttributeData("uv", vertexOffset + 0, glyph.uvs[0])
      textbox.mesh[].updateAttributeData("uv", vertexOffset + 1, glyph.uvs[1])
      textbox.mesh[].updateAttributeData("uv", vertexOffset + 2, glyph.uvs[2])
      textbox.mesh[].updateAttributeData("uv", vertexOffset + 3, glyph.uvs[3])

      offsetX += glyph.advance
      if i < textbox.text.len - 1:
        offsetX += textbox.font.kerning[(textbox.text[i], textbox.text[i + 1])]
    else:
      textbox.mesh[].updateAttributeData("position", vertexOffset + 0, newVec3f())
      textbox.mesh[].updateAttributeData("position", vertexOffset + 1, newVec3f())
      textbox.mesh[].updateAttributeData("position", vertexOffset + 2, newVec3f())
      textbox.mesh[].updateAttributeData("position", vertexOffset + 3, newVec3f())


func text*(textbox: Textbox): seq[Rune] =
  textbox.text

proc `text=`*(textbox: var Textbox, text: seq[Rune]) =
  textbox.text = text
  textbox.updateMesh()

proc initTextbox*(maxLen: int, font: Font, text=toRunes("")): Textbox =
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
  result.mesh = newMesh(positions = positions, indices = indices, uvs = uvs)
  result.mesh.material = Material(
    name: TEXT_MATERIAL,
    textures: {"fontAtlas": font.fontAtlas}.toTable,
  )

  result.updateMesh()
