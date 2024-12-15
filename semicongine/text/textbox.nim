type Textbox* = object
  font*: Font
  maxLen*: int # maximum amount of characters that will be rendered
  maxWidth: float32 = 0 # if set, will cause automatic word breaks at maxWidth
  baseScale: float32
  text: seq[Rune]
  horizontalAlignment: HorizontalAlignment = Center
  verticalAlignment: VerticalAlignment = Center
  # management/internal:
  dirtyGeometry: bool # is true if any of the attributes changed
  dirtyShaderdata: bool # is true if any of the attributes changed
  visibleText: seq[Rune]
    # used to store processed (word-wrapper) text to preserve original
  lastRenderedText: seq[Rune]
    # stores the last rendered text, to prevent unnecessary updates

  # rendering data
  position: GPUArray[Vec3f, VertexBuffer]
  uv: GPUArray[Vec2f, VertexBuffer]
  indices: GPUArray[uint16, IndexBuffer]

proc `=copy`(dest: var Textbox, source: Textbox) {.error.}

func `$`*(textbox: Textbox): string =
  "\"" & $textbox.text[0 ..< min(textbox.text.len, 16)] & "\""

proc refreshGeometry(textbox: var Textbox) =
  # pre-calculate text-width
  var width = 0'f32
  var lineWidths: seq[float32]
  for i in 0 ..< textbox.visibleText.len:
    if textbox.visibleText[i] == NEWLINE:
      lineWidths.add width
      width = 0'f32
    else:
      if not (i == textbox.visibleText.len - 1 and textbox.visibleText[i].isWhiteSpace):
        width += textbox.font.glyphdata[textbox.visibleText[i]].advance
      if i < textbox.visibleText.len - 1:
        width +=
          textbox.font.kerning[(textbox.visibleText[i], textbox.visibleText[i + 1])]
  lineWidths.add width
  var height =
    float32(lineWidths.len - 1) * textbox.font.lineAdvance + textbox.font.capHeight
  if lineWidths[^1] == 0 and lineWidths.len > 1:
    height -= 1

  let anchorY =
    (
      case textbox.verticalAlignment
      of Top: 0'f32
      of Center: -height / 2
      of Bottom: -height
    ) + textbox.font.capHeight

  var
    offsetX = 0'f32
    offsetY = 0'f32
    lineIndex = 0
    anchorX =
      case textbox.horizontalAlignment
      of Left:
        0'f32
      of Center:
        lineWidths[lineIndex] / 2
      of Right:
        lineWidths[lineIndex]
  for i in 0 ..< textbox.maxLen:
    let vertexOffset = i * 4
    if i < textbox.visibleText.len:
      if textbox.visibleText[i] == Rune('\n'):
        offsetX = 0
        offsetY -= textbox.font.lineAdvance
        textbox.position.data[vertexOffset + 0] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 1] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 2] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 3] = vec3(0, 0, 0)
        inc lineIndex
        anchorX =
          case textbox.horizontalAlignment
          of Left:
            0'f32
          of Center:
            lineWidths[lineIndex] / 2
          of Right:
            lineWidths[lineIndex]
      else:
        let
          glyph = textbox.font.glyphdata[textbox.visibleText[i]]
          left = offsetX + glyph.offsetX
          right = offsetX + glyph.offsetX + glyph.dimension.x
          top = offsetY - glyph.offsetY
          bottom = offsetY - glyph.offsetY - glyph.dimension.y

        textbox.position.data[vertexOffset + 0] =
          vec3(left - anchorX, bottom - anchorY, 0)
        textbox.position.data[vertexOffset + 1] = vec3(left - anchorX, top - anchorY, 0)
        textbox.position.data[vertexOffset + 2] =
          vec3(right - anchorX, top - anchorY, 0)
        textbox.position.data[vertexOffset + 3] =
          vec3(right - anchorX, bottom - anchorY, 0)

        textbox.uv.data[vertexOffset + 0] = glyph.uvs[0]
        textbox.uv.data[vertexOffset + 1] = glyph.uvs[1]
        textbox.uv.data[vertexOffset + 2] = glyph.uvs[2]
        textbox.uv.data[vertexOffset + 3] = glyph.uvs[3]

        offsetX += glyph.advance
        if i < textbox.visibleText.len - 1:
          offsetX +=
            textbox.font.kerning[(textbox.visibleText[i], textbox.visibleText[i + 1])]
  updateGPUBuffer(textbox.position, count = textbox.visibleText.len.uint64 * 4)
  updateGPUBuffer(textbox.uv, count = textbox.visibleText.len.uint64 * 4)
  textbox.lastRenderedText = textbox.visibleText

func text*(textbox: Textbox): seq[Rune] =
  textbox.text

proc `text=`*(textbox: var Textbox, newText: seq[Rune]) =
  if newText[0 ..< min(newText.len, textbox.maxLen)] == textbox.text:
    return

  textbox.text = newText[0 ..< min(newText.len, textbox.maxLen)]

  textbox.visibleText = textbox.text
  if textbox.maxWidth > 0:
    textbox.visibleText = WordWrapped(
      textbox.visibleText, textbox.font[], textbox.maxWidth / textbox.baseScale
    )

proc `text=`*(textbox: var Textbox, newText: string) =
  `text=`(textbox, newText.toRunes)

proc horizontalAlignment*(textbox: Textbox): HorizontalAlignment =
  textbox.horizontalAlignment

proc `horizontalAlignment=`*(textbox: var Textbox, value: HorizontalAlignment) =
  if value != textbox.horizontalAlignment:
    textbox.horizontalAlignment = value
    textbox.dirtyGeometry = true

proc verticalAlignment*(textbox: Textbox): VerticalAlignment =
  textbox.verticalAlignment

proc `verticalAlignment=`*(textbox: var Textbox, value: VerticalAlignment) =
  if value != textbox.verticalAlignment:
    textbox.verticalAlignment = value
    textbox.dirtyGeometry = true

proc refresh*(textbox: var Textbox) =
  if textbox.dirtyGeometry or textbox.visibleText != textbox.lastRenderedText:
    textbox.refreshGeometry()
    textbox.dirtyGeometry = false

proc render*(
    commandbuffer: VkCommandBuffer,
    pipeline: Pipeline,
    textbox: Textbox,
    position: Vec3f,
    color: Vec4f,
    scale: Vec2f = vec2(1, 1),
) =
  renderWithPushConstant(
    commandbuffer = commandbuffer,
    pipeline = pipeline,
    mesh = textbox,
    pushConstant =
      TextboxData(position: position, scale: textbox.baseScale * scale, color: color),
    fixedVertexCount = textbox.visibleText.len * 6,
  )

proc initTextbox*[T: string | seq[Rune]](
    renderdata: var RenderData,
    descriptorSetLayout: VkDescriptorSetLayout,
    font: Font,
    baseScale: float32,
    text: T = default(T),
    maxLen: int = text.len,
    verticalAlignment: VerticalAlignment = Center,
    horizontalAlignment: HorizontalAlignment = Center,
    maxWidth = 0'f32,
): Textbox =
  result = Textbox(
    maxLen: maxLen,
    font: font,
    dirtyGeometry: true,
    dirtyShaderdata: true,
    horizontalAlignment: horizontalAlignment,
    verticalAlignment: verticalAlignment,
    maxWidth: maxWidth,
    baseScale: baseScale,
    position: asGPUArray(newSeq[Vec3f](int(maxLen * 4)), VertexBuffer),
    uv: asGPUArray(newSeq[Vec2f](int(maxLen * 4)), VertexBuffer),
    indices: asGPUArray(newSeq[uint16](int(maxLen * 6)), IndexBuffer),
  )

  for i in 0 ..< maxLen:
    let vertexIndex = i.uint16 * 4'u16
    result.indices.data[i * 6 + 0] = vertexIndex + 0
    result.indices.data[i * 6 + 1] = vertexIndex + 1
    result.indices.data[i * 6 + 2] = vertexIndex + 2
    result.indices.data[i * 6 + 3] = vertexIndex + 2
    result.indices.data[i * 6 + 4] = vertexIndex + 3
    result.indices.data[i * 6 + 5] = vertexIndex + 0

  when T is string:
    `text=`(result, text.toRunes())
  else:
    `text=`(result, text)

  assignBuffers(renderdata, result, uploadData = false)

  result.refresh()
  updateAllGPUBuffers(result, flush = true)
