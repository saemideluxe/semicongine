import std/sequtils
import std/tables
import std/unicode

import ./scene
import ./mesh
import ./core/vector
import ./core/matrix
import ./core/fonttypes

type
  TextAlignment = enum
    Left
    Center
    Right
  Textbox* = ref object of Entity
    maxLen*: uint32
    text: seq[Rune]
    dirty: bool
    alignment*: TextAlignment
    font*: Font
    mesh*: Mesh

proc updateMesh(textbox: var Textbox) =

  # pre-calculate text-width
  var width = 0'f32
  for i in 0 ..< min(uint32(textbox.text.len), textbox.maxLen):
    width += textbox.font.glyphs[textbox.text[i]].advance
    if i < uint32(textbox.text.len - 1):
      width += textbox.font.kerning[(textbox.text[i], textbox.text[i + 1])]

  let centerX = width / 2
  let centerY = textbox.font.maxHeight / 2

  var offsetX = 0'f32
  for i in 0 ..< textbox.maxLen:
    let vertexOffset = i * 4
    if i < uint32(textbox.text.len):
      let
        glyph = textbox.font.glyphs[textbox.text[i]]
        left = offsetX + glyph.leftOffset
        right = offsetX + glyph.leftOffset + glyph.dimension.x
        top = glyph.topOffset
        bottom = glyph.topOffset + glyph.dimension.y

      textbox.mesh.updateMeshData("position", vertexOffset + 0, newVec3f(left - centerX, bottom + centerY))
      textbox.mesh.updateMeshData("position", vertexOffset + 1, newVec3f(left - centerX, top + centerY))
      textbox.mesh.updateMeshData("position", vertexOffset + 2, newVec3f(right - centerX, top + centerY))
      textbox.mesh.updateMeshData("position", vertexOffset + 3, newVec3f(right - centerX, bottom + centerY))

      textbox.mesh.updateMeshData("uv", vertexOffset + 0, glyph.uvs[0])
      textbox.mesh.updateMeshData("uv", vertexOffset + 1, glyph.uvs[1])
      textbox.mesh.updateMeshData("uv", vertexOffset + 2, glyph.uvs[2])
      textbox.mesh.updateMeshData("uv", vertexOffset + 3, glyph.uvs[3])

      offsetX += glyph.advance
      if i < uint32(textbox.text.len - 1):
        offsetX += textbox.font.kerning[(textbox.text[i], textbox.text[i + 1])]
    else:
      textbox.mesh.updateMeshData("position", vertexOffset + 0, newVec3f())
      textbox.mesh.updateMeshData("position", vertexOffset + 1, newVec3f())
      textbox.mesh.updateMeshData("position", vertexOffset + 2, newVec3f())
      textbox.mesh.updateMeshData("position", vertexOffset + 3, newVec3f())


func text*(textbox: Textbox): seq[Rune] =
  textbox.text

proc `text=`*(textbox: var Textbox, text: seq[Rune]) =
  textbox.text = text
  textbox.name = $text
  textbox.updateMesh()

proc newTextbox*(maxLen: uint32, font: Font, text=toRunes("")): Textbox =
  var
    positions = newSeq[Vec3f](int(maxLen * 4))
    indices: seq[array[3, uint32]]
    uvs = newSeq[Vec2f](int(maxLen * 4))
  for i in 0 ..< maxLen:
    let offset = i * 4
    indices.add [[offset + 0, offset + 1, offset + 2], [offset + 2, offset + 3, offset + 0]]

  result = Textbox(maxLen: maxLen, text: text, font: font, dirty: true)
  result.mesh = newMesh(positions = positions, indices = indices, uvs = uvs)
  result.mesh.setInstanceTransforms(@[Unit4F32])
  result.name = $text
  result.transform = Unit4F32

  # wrap the text mesh in a new entity to preserve the font-scaling
  var box = newEntity("box", result.mesh)
  # box.transform = scale3d(font.fontscale * 0.002, font.fontscale * 0.002)
  box.transform = scale3d(1 / font.resolution, 1 / font.resolution)
  result.add box
  result.updateMesh()