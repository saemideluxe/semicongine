import std/tables
import std/algorithm
import std/unicode
import std/strformat

import ./core
import ./mesh
import ./material
import ./vulkan/shader

const
  NEWLINE = Rune('\n')
  SPACE = Rune(' ')

  # font shader
  MAX_TEXT_MATERIALS = 10
  SHADER_ATTRIB_PREFIX = "semicon_text_"
  POSITION_ATTRIB = SHADER_ATTRIB_PREFIX & "position"
  UV_ATTRIB = SHADER_ATTRIB_PREFIX & "uv"
  TEXT_MATERIAL_TYPE* = MaterialType(
    name: "default-text-material-type",
    vertexAttributes: {TRANSFORM_ATTRIB: Mat4F32, POSITION_ATTRIB: Vec3F32, UV_ATTRIB: Vec2F32}.toTable,
    attributes: {"fontAtlas": TextureType, "color": Vec4F32}.toTable,
  )
  TEXT_SHADER* = createShaderConfiguration(
    inputs = [
      attr[Mat4](TRANSFORM_ATTRIB, memoryPerformanceHint = PreferFastWrite, perInstance = true),
      attr[Vec3f](POSITION_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      attr[Vec2f](UV_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      attr[uint16](MATERIALINDEX_ATTRIBUTE, memoryPerformanceHint = PreferFastRead, perInstance = true),
    ],
    intermediates = [
      attr[Vec2f]("uvFrag"),
      attr[uint16]("materialIndexOut", noInterpolation = true)
    ],
    outputs = [attr[Vec4f]("color")],
    uniforms = [attr[Vec4f]("color", arrayCount = MAX_TEXT_MATERIALS)],
    samplers = [attr[Texture]("fontAtlas", arrayCount = MAX_TEXT_MATERIALS)],
    vertexCode = &"""
  gl_Position = vec4({POSITION_ATTRIB}, 1.0) * {TRANSFORM_ATTRIB};
  uvFrag = {UV_ATTRIB};
  materialIndexOut = {MATERIALINDEX_ATTRIBUTE};
  """,
    fragmentCode = &"""color = vec4(Uniforms.color[materialIndexOut].rgb, Uniforms.color[materialIndexOut].a * texture(fontAtlas[materialIndexOut], uvFrag).r);"""
  )

var instanceCounter = 0

type
  Text* = object
    maxLen*: int
    font*: Font
    maxWidth: float32 = 0
    # properties:
    text: seq[Rune]
    position: Vec2f
    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    scale: float32
    aspect_ratio: float32
    # management/internal:
    dirty: bool                 # is true if any of the attributes changed
    processedText: seq[Rune]    # used to store processed (word-wrapper) text to preserve original
    lastRenderedText: seq[Rune] # stores the last rendered text, to prevent unnecessary updates
    mesh: Mesh

func `$`*(text: Text): string =
  "\"" & $text.text[0 ..< min(text.text.len, 16)] & "\""

proc refresh*(text: var Text) =
  if not text.dirty and text.processedText == text.lastRenderedText:
    return

  # pre-calculate text-width
  var width = 0'f32
  var lineWidths: seq[float32]
  for i in 0 ..< text.processedText.len:
    if text.processedText[i] == NEWLINE:
      lineWidths.add width
      width = 0'f32
    else:
      if not (i == text.processedText.len - 1 and text.processedText[i].isWhiteSpace):
        width += text.font.glyphs[text.processedText[i]].advance
      if i < text.processedText.len - 1:
        width += text.font.kerning[(text.processedText[i], text.processedText[i + 1])]
  lineWidths.add width
  var height = float32(lineWidths.len) * text.font.lineAdvance
  if lineWidths[^1] == 0 and lineWidths.len > 1:
    height -= 1

  let anchorY = (case text.verticalAlignment
    of Top: 0'f32
    of Center: height / 2
    of Bottom: height) - text.font.lineAdvance

  var
    offsetX = 0'f32
    offsetY = 0'f32
    lineIndex = 0
    anchorX = case text.horizontalAlignment
      of Left: 0'f32
      of Center: lineWidths[lineIndex] / 2
      of Right: lineWidths[lineIndex]
  for i in 0 ..< text.maxLen:
    let vertexOffset = i * 4
    if i < text.processedText.len:
      if text.processedText[i] == Rune('\n'):
        offsetX = 0
        offsetY += text.font.lineAdvance
        text.mesh[POSITION_ATTRIB, vertexOffset + 0] = newVec3f()
        text.mesh[POSITION_ATTRIB, vertexOffset + 1] = newVec3f()
        text.mesh[POSITION_ATTRIB, vertexOffset + 2] = newVec3f()
        text.mesh[POSITION_ATTRIB, vertexOffset + 3] = newVec3f()
        inc lineIndex
        anchorX = case text.horizontalAlignment
          of Left: 0'f32
          of Center: lineWidths[lineIndex] / 2
          of Right: lineWidths[lineIndex]
      else:
        let
          glyph = text.font.glyphs[text.processedText[i]]
          left = offsetX + glyph.leftOffset
          right = offsetX + glyph.leftOffset + glyph.dimension.x
          top = offsetY + glyph.topOffset
          bottom = offsetY + glyph.topOffset + glyph.dimension.y

        text.mesh[POSITION_ATTRIB, vertexOffset + 0] = newVec3f(left - anchorX, bottom - anchorY)
        text.mesh[POSITION_ATTRIB, vertexOffset + 1] = newVec3f(left - anchorX, top - anchorY)
        text.mesh[POSITION_ATTRIB, vertexOffset + 2] = newVec3f(right - anchorX, top - anchorY)
        text.mesh[POSITION_ATTRIB, vertexOffset + 3] = newVec3f(right - anchorX, bottom - anchorY)

        text.mesh[UV_ATTRIB, vertexOffset + 0] = glyph.uvs[0]
        text.mesh[UV_ATTRIB, vertexOffset + 1] = glyph.uvs[1]
        text.mesh[UV_ATTRIB, vertexOffset + 2] = glyph.uvs[2]
        text.mesh[UV_ATTRIB, vertexOffset + 3] = glyph.uvs[3]

        offsetX += glyph.advance
        if i < text.processedText.len - 1:
          offsetX += text.font.kerning[(text.processedText[i], text.processedText[i + 1])]
    else:
      text.mesh[POSITION_ATTRIB, vertexOffset + 0] = newVec3f()
      text.mesh[POSITION_ATTRIB, vertexOffset + 1] = newVec3f()
      text.mesh[POSITION_ATTRIB, vertexOffset + 2] = newVec3f()
      text.mesh[POSITION_ATTRIB, vertexOffset + 3] = newVec3f()
  text.mesh.transform = translate(text.position.x, text.position.y, 0) * scale(text.scale, text.scale * text.aspect_ratio)
  text.lastRenderedText = text.processedText
  text.dirty = false


func width(text: seq[Rune], font: Font): float32 =
  var currentWidth = 0'f32
  var lineWidths: seq[float32]
  for i in 0 ..< text.len:
    if text[i] == NEWLINE:
      lineWidths.add currentWidth
      currentWidth = 0'f32
    else:
      if not (i == text.len - 1 and text[i].isWhiteSpace):
        currentWidth += font.glyphs[text[i]].advance
      if i < text.len - 1:
        currentWidth += font.kerning[(text[i], text[i + 1])]
  lineWidths.add currentWidth
  return lineWidths.max

func wordWrapped(text: seq[Rune], font: Font, maxWidth: float32): seq[Rune] =
  var remaining: seq[seq[Rune]] = @[@[]]
  for c in text:
    if c == SPACE:
      remaining.add newSeq[Rune]()
    else:
      remaining[^1].add c
  remaining.reverse()

  var currentLine: seq[Rune]

  while remaining.len > 0:
    var currentWord = remaining.pop()
    assert not (SPACE in currentWord)

    if currentWord.len == 0:
      currentLine.add SPACE
    else:
      assert currentWord[^1] != SPACE
      # if this is the first word of the line and it is too long we need to
      # split by character
      if currentLine.len == 0 and (SPACE & currentWord).width(font) > maxWidth:
        var subWord = @[currentWord[0]]
        for c in currentWord[1 .. ^1]:
          if (subWord & c).width(font) > maxWidth:
            break
          subWord.add c
        result.add subWord & NEWLINE
        remaining.add currentWord[subWord.len .. ^1] # process rest of the word in next iteration
      else:
        if (currentLine & SPACE & currentWord).width(font) <= maxWidth:
          if currentLine.len == 0:
            currentLine = currentWord
          else:
            currentLine = currentLine & SPACE & currentWord
        else:
          result.add currentLine & NEWLINE
          remaining.add currentWord
          currentLine = @[]
  if currentLine.len > 0 and currentLine != @[SPACE]:
    result.add currentLine

  return result


func text*(text: Text): seq[Rune] =
  text.text

proc `text=`*(text: var Text, newText: seq[Rune]) =
  text.text = newText[0 ..< min(newText.len, text.maxLen)]

  text.processedText = text.text
  if text.maxWidth > 0:
    text.processedText = text.processedText.wordWrapped(text.font, text.maxWidth / text.scale)

proc `text=`*(text: var Text, newText: string) =
  `text=`(text, newText.toRunes)

proc position*(text: Text): Vec2f =
  text.position
proc `position=`*(text: var Text, value: Vec2f) =
  if value != text.position:
    text.position = value
    text.dirty = true

proc color*(text: Text): Vec4f =
  text.mesh.material["color", 0, Vec4f]
proc `color=`*(text: var Text, value: Vec4f) =
  if value != text.color:
    text.mesh.material["color", 0] = value

proc horizontalAlignment*(text: Text): HorizontalAlignment =
  text.horizontalAlignment
proc `horizontalAlignment=`*(text: var Text, value: HorizontalAlignment) =
  if value != text.horizontalAlignment:
    text.horizontalAlignment = value
    text.dirty = true

proc verticalAlignment*(text: Text): VerticalAlignment =
  text.verticalAlignment
proc `verticalAlignment=`*(text: var Text, value: VerticalAlignment) =
  if value != text.verticalAlignment:
    text.verticalAlignment = value
    text.dirty = true

proc scale*(text: Text): float32 =
  text.scale
proc `scale=`*(text: var Text, value: float32) =
  if value != text.scale:
    text.scale = value
    text.dirty = true

proc aspect_ratio*(text: Text): float32 =
  text.aspect_ratio
proc `aspect_ratio=`*(text: var Text, value: float32) =
  if value != text.aspect_ratio:
    text.aspect_ratio = value
    text.dirty = true

proc initText*(font: Font, text = "".toRunes, maxLen: int = text.len, color = newVec4f(0.07, 0.07, 0.07, 1), scale = 1'f32, position = newVec2f(), verticalAlignment = VerticalAlignment.Center, horizontalAlignment = HorizontalAlignment.Center, maxWidth = 0'f32): Text =
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

  result = Text(maxLen: maxLen, font: font, dirty: true, scale: scale, position: position, aspect_ratio: 1, horizontalAlignment: horizontalAlignment, verticalAlignment: verticalAlignment, maxWidth: maxWidth)
  `text=`(result, text)
  result.mesh = newMesh(positions = positions, indices = indices, uvs = uvs, name = &"text-{instanceCounter}")
  result.mesh[].renameAttribute("position", POSITION_ATTRIB)
  result.mesh[].renameAttribute("uv", UV_ATTRIB)
  result.mesh.material = initMaterialData(
    theType = TEXT_MATERIAL_TYPE,
    name = font.name & " text",
    attributes = {"fontAtlas": initDataList(@[font.fontAtlas]), "color": initDataList(@[color])},
  )
  inc instanceCounter

  result.refresh()

proc initText*(font: Font, text = "", maxLen: int = text.len, color = newVec4f(0.07, 0.07, 0.07, 1), scale = 1'f32, position = newVec2f(), verticalAlignment = VerticalAlignment.Center, horizontalAlignment = HorizontalAlignment.Center, maxWidth = 0'f32): Text =
  initText(font = font, text = text.toRunes, maxLen = maxLen, color = color, scale = scale, position = position, horizontalAlignment = horizontalAlignment, verticalAlignment = verticalAlignment, maxWidth = maxWidth)
