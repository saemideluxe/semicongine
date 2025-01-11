import std/algorithm
import std/os
import std/sequtils
import std/strformat
import std/strutils
import std/tables
import std/unicode

import ./core
import ./rendering
import ./images
import ./rendering/renderer
import ./rendering/memory

proc initTextBuffer*[MaxGlyphs: static int](
    font: Font[MaxGlyphs],
    bufferSize: int,
    renderdata: var RenderData,
    baseScale = 1'f32,
): TextBuffer[MaxGlyphs] =
  result.cursor = 0
  result.font = font
  result.baseScale = baseScale
  result.position.data.setLen(bufferSize)
  result.scale.data.setLen(bufferSize)
  result.color.data.setLen(bufferSize)
  result.glyphIndex.data.setLen(bufferSize)
  assignBuffers(renderdata, result)

iterator splitLines(text: seq[Rune]): seq[Rune] =
  var current = newSeq[Rune]()
  for c in text:
    if c == Rune('\n'):
      yield current
      current = newSeq[Rune]()
    else:
      current.add c
  yield current

proc width*(font: Font, text: seq[Rune]): float32 =
  for i in 0 ..< text.len:
    if not (i == text.len - 1 and text[i].isWhiteSpace):
      if text[i] in font.advance:
        result += font.advance[text[i]]
      else:
        result += font.advance[font.fallbackCharacter]
    if i < text.len - 1:
      result += font.kerning.getOrDefault((text[i], text[i + 1]), 0)
  return result

proc width*(font: Font, text: string): float32 =
  width(font, text.toRunes)

proc textDimension*(font: Font, text: seq[Rune]): Vec2f =
  let nLines = text.countIt(it == Rune('\n')).float32
  let h = (nLines * font.lineAdvance + font.lineHeight)
  let w = max(splitLines(text).toSeq.mapIt(width(font, it)))
  return vec2(w, h)

proc textDimension*(font: Font, text: string): Vec2f =
  textDimension(font, text.toRunes())

proc textDimension*(textBuffer: TextBuffer, text: string | seq[Rune]): Vec2f =
  textDimension(textBuffer.font, text) * textBuffer.baseScale

proc updateGlyphData*(textbuffer: var TextBuffer, textHandle: TextHandle) =
  assert textHandle.generation == textbuffer.generation

  let
    textI = textHandle.index
    text = textbuffer.texts[textI].text
    position = textbuffer.texts[textI].position
    anchor = textbuffer.texts[textI].anchor

    globalScale = textbuffer.texts[textI].scale * textbuffer.baseScale
    box = textbuffer.textDimension(text) * textbuffer.texts[textI].scale
    xH = textbuffer.font.xHeight * globalScale
    aratio = getAspectRatio()
    origin = vec3(
      position.x - (anchor.x * 0.5 + 0.5) * box.x / aratio,
      position.y + (anchor.y * -0.5 + 0.5) * box.y - xH * 0.5 -
        textbuffer.font.lineHeight * globalScale * 0.5,
      position.z,
    )
    lineWidths = splitLines(text).toSeq.mapIt(width(textbuffer.font, it) * globalScale)
    maxWidth = box.x

  template leftBearing(r: Rune): untyped =
    textbuffer.font.leftBearing.getOrDefault(r, 0) * globalScale

  var
    cursorPos = origin
    lineI = 0

  case textbuffer.texts[textI].alignment
  of Left:
    cursorPos.x = origin.x
  of Center:
    cursorPos.x = origin.x + ((maxWidth - lineWidths[lineI]) / aratio * 0.5)
  of Right:
    cursorPos.x = origin.x + (maxWidth - lineWidths[lineI]) / aratio

  # add left bearing for first character at line start
  if text.len > 0:
    cursorPos.x = cursorPos.x - leftBearing(text[0])

  var bufferOffset = textbuffer.texts[textI].bufferOffset
  let bufferEnd =
    textbuffer.texts[textI].bufferOffset + textbuffer.texts[textI].capacity
  var i = 0
  while i < textbuffer.texts[textI].capacity and bufferOffset < bufferEnd:
    # for i in 0 ..< textbuffer.texts[textI].capacity:
    if i < text.len:
      if text[i] == Rune('\n'):
        inc lineI
        case textbuffer.texts[textI].alignment
        of Left:
          cursorPos.x = origin.x
        of Center:
          cursorPos.x = origin.x + ((maxWidth - lineWidths[lineI]) / aratio * 0.5)
        of Right:
          cursorPos.x = origin.x + (maxWidth - lineWidths[lineI]) / aratio

        # add left bearing for first character at line start
        if text.len > i + 1:
          cursorPos.x = cursorPos.x - leftBearing(text[i + 1])

        cursorPos.y = cursorPos.y - textbuffer.font.lineAdvance * globalScale
      else:
        if not text[i].isWhitespace():
          textbuffer.position[bufferOffset] = cursorPos
          textbuffer.scale[bufferOffset] = globalScale
          textbuffer.color[bufferOffset] = textbuffer.texts[textI].color
          if text[i] in textbuffer.font.descriptorGlyphIndex:
            textbuffer.glyphIndex[bufferOffset] =
              textbuffer.font.descriptorGlyphIndex[text[i]]
          else:
            textbuffer.glyphIndex[bufferOffset] =
              textbuffer.font.descriptorGlyphIndex[textbuffer.font.fallbackCharacter]
          # only use up buffer space when we actually draw a glyph i.e. whitespace is not using buffer space
          inc bufferOffset

        if text[i] in textbuffer.font.advance:
          cursorPos.x =
            cursorPos.x + textbuffer.font.advance[text[i]] * globalScale / aratio
        else:
          cursorPos.x =
            cursorPos.x +
            textbuffer.font.advance[textbuffer.font.fallbackCharacter] * globalScale /
            aratio

        if i < text.len - 1:
          cursorPos.x =
            cursorPos.x +
            textbuffer.font.kerning.getOrDefault((text[i], text[i + 1]), 0) * globalScale /
            aratio
    if i >= text.len or text[i].isWhiteSpace():
      textbuffer.position[bufferOffset] = vec3()
      textbuffer.scale[bufferOffset] = 0
      textbuffer.color[bufferOffset] = vec4()
      textbuffer.glyphIndex[bufferOffset] = 0
      inc bufferOffset
    inc i

proc updateGlyphData*(textbuffer: var TextBuffer) =
  for i in 0 ..< textbuffer.texts.len:
    textbuffer.updateGlyphData(
      TextHandle(index: uint32(i), generation: textbuffer.generation)
    )

proc reset*(textbuffer: var TextBuffer) =
  inc textbuffer.generation # integer overflow *should* be okay here
  textbuffer.cursor = 0
  textbuffer.texts.setLen(0)

proc refresh*(textbuffer: var TextBuffer, flush = false) =
  textbuffer.updateGlyphData()
  textbuffer.updateAllGPUBuffers(flush = flush)

proc add*(
    textbuffer: var TextBuffer,
    text: seq[Rune],
    position: Vec3f,
    alignment: TextAlignment = Left,
    anchor: Vec2f = vec2(0, 0),
    scale: float32 = 1'f32,
    color: Vec4f = vec4(1, 1, 1, 1),
    capacity: int = 0,
): TextHandle =
  ## This should be called again after aspect ratio of window changes 

  let cap = if capacity == 0: text.len else: capacity
  let l = textbuffer.position.len
  assert textbuffer.cursor + cap <= l,
    &"Text is too big for TextBuffer ({l - textbuffer.cursor} left, but need {cap})"

  result =
    TextHandle(generation: textbuffer.generation, index: textbuffer.texts.len.uint32)

  textbuffer.texts.add Text(
    bufferOffset: textbuffer.cursor,
    text: text,
    position: position,
    alignment: alignment,
    anchor: anchor,
    scale: scale,
    color: color,
    capacity: cap,
  )
  textbuffer.cursor += cap

proc add*(
    textbuffer: var TextBuffer,
    text: string,
    position: Vec3f,
    alignment: TextAlignment = Left,
    anchor: Vec2f = vec2(0, 0),
    scale: float32 = 1'f32,
    color: Vec4f = vec4(1, 1, 1, 1),
    capacity: int = 0,
): TextHandle =
  add(textbuffer, text.toRunes, position, alignment, anchor, scale, color, capacity)

proc text*(textbuffer: var TextBuffer, textHandle: TextHandle, text: seq[Rune]) =
  assert textHandle.generation == textbuffer.generation
  if text.len <= textbuffer.texts[textHandle.index].capacity:
    textbuffer.texts[textHandle.index].text = text
  else:
    textbuffer.texts[textHandle.index].text =
      text[0 ..< textbuffer.texts[textHandle.index].capacity]

proc text*(textbuffer: var TextBuffer, textHandle: TextHandle, text: string) =
  assert textHandle.generation == textbuffer.generation
  text(textbuffer, textHandle, text.toRunes)

proc position*(textbuffer: var TextBuffer, textHandle: TextHandle, position: Vec3f) =
  assert textHandle.generation == textbuffer.generation
  textbuffer.texts[textHandle.index].position = position

proc alignment*(
    textbuffer: var TextBuffer, textHandle: TextHandle, alignment: TextAlignment
) =
  assert textHandle.generation == textbuffer.generation
  textbuffer.texts[textHandle.index].alignment = alignment

proc anchor*(textbuffer: var TextBuffer, textHandle: TextHandle, anchor: Vec2f) =
  assert textHandle.generation == textbuffer.generation
  textbuffer.texts[textHandle.index].anchor = anchor

proc scale*(textbuffer: var TextBuffer, textHandle: TextHandle, scale: float32) =
  assert textHandle.generation == textbuffer.generation
  textbuffer.texts[textHandle.index].scale = scale

proc color*(textbuffer: var TextBuffer, textHandle: TextHandle, color: Vec4f) =
  assert textHandle.generation == textbuffer.generation
  textbuffer.texts[textHandle.index].color = color

type EMPTY = object
const EMPTYOBJECT = EMPTY()

proc renderTextBuffer*(
    commandBuffer: VkCommandBuffer, pipeline: Pipeline, textbuffer: TextBuffer
) =
  renderWithPushConstant(
    commandbuffer,
    pipeline,
    EMPTYOBJECT,
    textbuffer,
    pushConstant = TextRendering(aspectRatio: getAspectRatio()),
    fixedVertexCount = 6,
    fixedInstanceCount = textbuffer.cursor,
  )
