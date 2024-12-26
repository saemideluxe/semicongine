import std/algorithm
import std/logging
import std/os
import std/sequtils
import std/streams
import std/strformat
import std/strutils
import std/tables
import std/unicode

import ./core
import ./resources
import ./rendering
import ./rendering/vulkan/api
import ./image
import ./contrib/algorithms/texture_packing

type
  GlyphQuad[MaxGlyphs: static int] = object
    pos: array[MaxGlyphs, Vec4f]
      # vertex offsets to glyph center: [left, bottom, right, top]
    uv: array[MaxGlyphs, Vec4f] # [left, bottom, right, top]

  TextRendering* = object
    aspectRatio*: float32

  GlyphDescriptorSet*[MaxGlyphs: static int] = object
    fontAtlas*: Image[Gray]
    glyphquads*: GPUValue[GlyphQuad[MaxGlyphs], StorageBuffer]

  GlyphShader*[MaxGlyphs: static int] = object
    position {.InstanceAttribute.}: Vec3f
    color {.InstanceAttribute.}: Vec4f
    scale {.InstanceAttribute.}: float32
    glyphIndex {.InstanceAttribute.}: uint16
    textRendering {.PushConstant.}: TextRendering

    fragmentUv {.Pass.}: Vec2f
    fragmentColor {.PassFlat.}: Vec4f
    outColor {.ShaderOutput.}: Vec4f
    glyphData {.DescriptorSet: 3.}: GlyphDescriptorSet[MaxGlyphs]
    vertexCode* =
      """
const int[6] indices = int[](0, 1, 2, 2, 3, 0);
const int[4] i_x = int[](0, 0, 2, 2);
const int[4] i_y = int[](1, 3, 3, 1);
const float epsilon = 0.0000001;
// const float epsilon = 0.1;

void main() {
  int vertexI = indices[gl_VertexIndex];
  vec3 vertexPos = vec3(
    glyphquads.pos[glyphIndex][i_x[vertexI]] * scale / textRendering.aspectRatio,
    glyphquads.pos[glyphIndex][i_y[vertexI]] * scale,
    1 - (gl_InstanceIndex + 1) * epsilon // allows overlapping glyphs to make proper depth test
  );
  gl_Position = vec4(vertexPos + position, 1.0);
  vec2 uv = vec2(glyphquads.uv[glyphIndex][i_x[vertexI]], glyphquads.uv[glyphIndex][i_y[vertexI]]);
  fragmentUv = uv;
  fragmentColor = color;
}  """
    fragmentCode* =
      """void main() {
    float a = texture(fontAtlas, fragmentUv).r;
    outColor = vec4(fragmentColor.rgb, fragmentColor.a * a);
}"""

  FontObj*[MaxGlyphs: static int] = object
    advance*: Table[Rune, float32]
    kerning*: Table[(Rune, Rune), float32]
    lineAdvance*: float32
    lineHeight*: float32 # like lineAdvance - lineGap
    ascent*: float32 # from baseline to highest glyph
    descent*: float32 # from baseline to highest glyph
    xHeight*: float32 # from baseline to height of lowercase x
    descriptorSet*: DescriptorSetData[GlyphDescriptorSet[MaxGlyphs]]
    descriptorGlyphIndex: Table[Rune, uint16]
    fallbackCharacter: Rune

  Font*[MaxGlyphs: static int] = ref FontObj[MaxGlyphs]

  TextHandle* = distinct int

  TextAlignment* = enum
    Left
    Center
    Right

  Text = object
    bufferOffset: int
    text: seq[Rune]
    position: Vec3f = vec3()
    alignment: TextAlignment = Left
    anchor: Vec2f = vec2()
    scale: float32 = 0
    color: Vec4f = vec4(1, 1, 1, 1)
    capacity: int

  TextBuffer*[MaxGlyphs: static int] = object
    cursor: int
    font*: Font[MaxGlyphs]
    baseScale*: float32
    position*: GPUArray[Vec3f, VertexBufferMapped]
    color*: GPUArray[Vec4f, VertexBufferMapped]
    scale*: GPUArray[float32, VertexBufferMapped]
    glyphIndex*: GPUArray[uint16, VertexBufferMapped]
    texts: seq[Text]

proc `=copy`[MaxGlyphs: static int](
  dest: var FontObj[MaxGlyphs], source: FontObj[MaxGlyphs]
) {.error.}

proc `=copy`[MaxGlyphs: static int](
  dest: var TextBuffer[MaxGlyphs], source: TextBuffer[MaxGlyphs]
) {.error.}

include ./text/font

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
  result.texts.setLen(bufferSize) # waste a lot of memory?
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

proc updateGlyphData*(textbuffer: var TextBuffer, textHandle: TextHandle) =
  let
    i = int(textHandle)
    text = textbuffer.texts[i].text
    position = textbuffer.texts[i].position
    alignment = textbuffer.texts[i].alignment
    anchor = textbuffer.texts[i].anchor
    scale = textbuffer.texts[i].scale
    color = textbuffer.texts[i].color
    offset = textbuffer.texts[i].bufferOffset
    capacity = textbuffer.texts[i].capacity

    globalScale = scale * textbuffer.baseScale
    box = textDimension(textbuffer.font, text) * globalScale
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

  var
    cursorPos = origin
    lineI = 0

  case alignment
  of Left:
    cursorPos.x = origin.x
  of Center:
    cursorPos.x = origin.x + ((maxWidth - lineWidths[lineI]) / aratio * 0.5)
  of Right:
    cursorPos.x = origin.x + (maxWidth - lineWidths[lineI]) / aratio

  for i in 0 ..< capacity:
    if i < text.len:
      if text[i] == Rune('\n'):
        inc lineI
        case alignment
        of Left:
          cursorPos.x = origin.x
        of Center:
          cursorPos.x = origin.x + ((maxWidth - lineWidths[lineI]) / aratio * 0.5)
        of Right:
          cursorPos.x = origin.x + (maxWidth - lineWidths[lineI]) / aratio
        cursorPos.y = cursorPos.y - textbuffer.font.lineAdvance * globalScale
      else:
        if not text[i].isWhitespace():
          textbuffer.position[offset + i] = cursorPos
          textbuffer.scale[offset + i] = globalScale
          textbuffer.color[offset + i] = color
          if text[i] in textbuffer.font.descriptorGlyphIndex:
            textbuffer.glyphIndex[offset + i] =
              textbuffer.font.descriptorGlyphIndex[text[i]]
          else:
            textbuffer.glyphIndex[offset + i] =
              textbuffer.font.descriptorGlyphIndex[textbuffer.font.fallbackCharacter]

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
    else:
      textbuffer.position[offset + i] = vec3()
      textbuffer.scale[offset + i] = 0
      textbuffer.color[offset + i] = vec4()
      textbuffer.glyphIndex[offset + i] = 0

proc updateGlyphData*(textbuffer: var TextBuffer) =
  for i in 0 ..< textbuffer.texts.len:
    textbuffer.updateGlyphData(TextHandle(i))

proc refresh*(textbuffer: var TextBuffer) =
  textbuffer.updateGlyphData()
  textbuffer.updateAllGPUBuffers(flush = true)

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
  assert textbuffer.cursor + cap <= textbuffer.position.len,
    &"Text is too big for TextBuffer ({textbuffer.position.len - textbuffer.cursor} left, but need {cap})"

  result = TextHandle(textbuffer.texts.len)

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
  textbuffer.updateGlyphData(result)

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
  if text.len <= textbuffer.texts[int(textHandle)].capacity:
    textbuffer.texts[int(textHandle)].text = text
  else:
    textbuffer.texts[int(textHandle)].text =
      text[0 ..< textbuffer.texts[int(textHandle)].capacity]

proc text*(textbuffer: var TextBuffer, textHandle: TextHandle, text: string) =
  text(textbuffer, textHandle, text.toRunes)

proc position*(textbuffer: var TextBuffer, textHandle: TextHandle, position: Vec3f) =
  textbuffer.texts[int(textHandle)].position = position

proc alignment*(
    textbuffer: var TextBuffer, textHandle: TextHandle, alignment: TextAlignment
) =
  textbuffer.texts[int(textHandle)].alignment = alignment

proc anchor*(textbuffer: var TextBuffer, textHandle: TextHandle, anchor: Vec2f) =
  textbuffer.texts[int(textHandle)].anchor = anchor

proc scale*(textbuffer: var TextBuffer, textHandle: TextHandle, scale: float32) =
  textbuffer.texts[int(textHandle)].scale = scale

proc color*(textbuffer: var TextBuffer, textHandle: TextHandle, color: Vec4f) =
  textbuffer.texts[int(textHandle)].color = color

proc reset*(textbuffer: var TextBuffer) =
  textbuffer.cursor = 0
  for i in 0 ..< textbuffer.texts.len:
    textbuffer.texts[i] = default(Text)

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
