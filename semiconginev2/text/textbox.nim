type
  Textbox* = object
    font*: Font
    maxLen*: int                # maximum amount of characters that will be rendered
    maxWidth: float32 = 0       # if set, will cause automatic word breaks at maxWidth
                                # properties:
    text: seq[Rune]
    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    # management/internal:
    dirtyGeometry: bool         # is true if any of the attributes changed
    dirtyShaderdata: bool       # is true if any of the attributes changed
    processedText: seq[Rune]    # used to store processed (word-wrapper) text to preserve original
    lastRenderedText: seq[Rune] # stores the last rendered text, to prevent unnecessary updates

    # rendering data
    position: GPUArray[Vec3f, VertexBuffer]
    uv: GPUArray[Vec2f, VertexBuffer]
    indices: GPUArray[uint16, IndexBuffer]
    shaderdata: DescriptorSet[TextboxDescriptorSet]

func `$`*(text: Textbox): string =
  "\"" & $text.text[0 ..< min(text.text.len, 16)] & "\""

proc RefreshShaderdata(text: Textbox) =
  if not text.dirtyShaderdata:
    return
  text.shaderdata.data.textbox.UpdateGPUBuffer()

proc RefreshGeometry(text: var Textbox) =
  if not text.dirtyGeometry and text.processedText == text.lastRenderedText:
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
  var height = float32(lineWidths.len - 1) * text.font.lineAdvance + text.font.capHeight
  if lineWidths[^1] == 0 and lineWidths.len > 1:
    height -= 1

  let anchorY = (case text.verticalAlignment
    of Top: 0'f32
    of Center: height / 2
    of Bottom: height) - text.font.capHeight

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
        text.position.data[vertexOffset + 0] = NewVec3f()
        text.position.data[vertexOffset + 1] = NewVec3f()
        text.position.data[vertexOffset + 2] = NewVec3f()
        text.position.data[vertexOffset + 3] = NewVec3f()
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

        text.position.data[vertexOffset + 0] = NewVec3f(left - anchorX, bottom - anchorY)
        text.position.data[vertexOffset + 1] = NewVec3f(left - anchorX, top - anchorY)
        text.position.data[vertexOffset + 2] = NewVec3f(right - anchorX, top - anchorY)
        text.position.data[vertexOffset + 3] = NewVec3f(right - anchorX, bottom - anchorY)

        text.uv.data[vertexOffset + 0] = glyph.uvs[0]
        text.uv.data[vertexOffset + 1] = glyph.uvs[1]
        text.uv.data[vertexOffset + 2] = glyph.uvs[2]
        text.uv.data[vertexOffset + 3] = glyph.uvs[3]

        offsetX += glyph.advance
        if i < text.processedText.len - 1:
          offsetX += text.font.kerning[(text.processedText[i], text.processedText[i + 1])]
    else:
      text.position.data[vertexOffset + 0] = NewVec3f()
      text.position.data[vertexOffset + 1] = NewVec3f()
      text.position.data[vertexOffset + 2] = NewVec3f()
      text.position.data[vertexOffset + 3] = NewVec3f()
  text.lastRenderedText = text.processedText
  text.dirtyGeometry = false

proc Refresh*(textbox: var Textbox) =
  textbox.RefreshShaderdata()
  textbox.RefreshGeometry()

func text*(text: Textbox): seq[Rune] =
  text.text

proc `text=`*(text: var Textbox, newText: seq[Rune]) =
  text.text = newText[0 ..< min(newText.len, text.maxLen)]

  text.processedText = text.text
  if text.maxWidth > 0:
    text.processedText = WordWrapped(
      text.processedText,
      text.font[],
      text.maxWidth / text.shaderdata.data.textbox.data.scale,
    )

proc `text=`*(text: var Textbox, newText: string) =
  `text=`(text, newText.toRunes)

proc Color*(text: Textbox): Vec4f =
  text.shaderdata.data.textbox.data.color

proc `Color=`*(text: var Textbox, value: Vec4f) =
  if text.shaderdata.data.textbox.data.color != value:
    text.dirtyShaderdata = true
    text.shaderdata.data.textbox.data.color = value

proc Scale*(text: Textbox): float32 =
  text.shaderdata.data.textbox.data.scale

proc `Scale=`*(text: var Textbox, value: float32) =
  if text.shaderdata.data.textbox.data.scale != value:
    text.dirtyShaderdata = true
    text.shaderdata.data.textbox.data.scale = value

proc Position*(text: Textbox): Vec3f =
  text.shaderdata.data.textbox.data.position

proc `Position=`*(text: var Textbox, value: Vec3f) =
  if text.shaderdata.data.textbox.data.position != value:
    text.dirtyShaderdata = true
    text.shaderdata.data.textbox.data.position = value

proc horizontalAlignment*(text: Textbox): HorizontalAlignment =
  text.horizontalAlignment
proc `horizontalAlignment=`*(text: var Textbox, value: HorizontalAlignment) =
  if value != text.horizontalAlignment:
    text.horizontalAlignment = value
    text.dirtyGeometry = true

proc verticalAlignment*(text: Textbox): VerticalAlignment =
  text.verticalAlignment
proc `verticalAlignment=`*(text: var Textbox, value: VerticalAlignment) =
  if value != text.verticalAlignment:
    text.verticalAlignment = value
    text.dirtyGeometry = true

proc Draw(text: Textbox, commandbuffer: VkCommandBuffer, pipeline: Pipeline, currentFiF: int) =
  WithBind(commandbuffer, (textbox.shaderdata, ), pipeline, currentFiF):
    Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = text)

proc InitTextbox*(
  renderdata: var RenderData,
  descriptorSetLayout: VkDescriptorSetLayout,
  font: Font,
  text = "".toRunes,
  scale: float32 = 1,
  position: Vec3f = NewVec3f(),
  color: Vec4f = NewVec4f(0, 0, 0, 1),
  maxLen: int = text.len,
  verticalAlignment: VerticalAlignment = Center,
  horizontalAlignment: HorizontalAlignment = Center,
  maxWidth = 0'f32
): Textbox =

  result = Textbox(
    maxLen: maxLen,
    font: font,
    dirtyGeometry: true,
    horizontalAlignment: horizontalAlignment,
    verticalAlignment: verticalAlignment,
    maxWidth: maxWidth,
    position: asGPUArray(newSeq[Vec3f](int(maxLen * 4)), VertexBuffer),
    uv: asGPUArray(newSeq[Vec2f](int(maxLen * 4)), VertexBuffer),
    indices: asGPUArray(newSeq[uint16](int(maxLen * 6)), IndexBuffer),
    shaderdata: asDescriptorSet(
      TextboxDescriptorSet(
        textbox: asGPUValue(TextboxData(
          scale: scale,
          position: position,
          color: color,
    ), UniformBufferMapped),
    fontAtlas: font.fontAtlas
  )
    )
  )

  for i in 0 ..< maxLen:
    let vertexIndex = i.uint16 * 4'u16
    result.indices.data[i * 6 + 0] = vertexIndex + 0
    result.indices.data[i * 6 + 1] = vertexIndex + 1
    result.indices.data[i * 6 + 2] = vertexIndex + 2
    result.indices.data[i * 6 + 3] = vertexIndex + 2
    result.indices.data[i * 6 + 4] = vertexIndex + 3
    result.indices.data[i * 6 + 5] = vertexIndex + 0

  `text=`(result, text)

  AssignBuffers(renderdata, result)
  UploadImages(renderdata, result.shaderdata)
  InitDescriptorSet(renderdata, descriptorSetLayout, result.shaderdata)

  result.Refresh()
