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
    position*: GPUArray[Vec3f, VertexBuffer]
    uv*: GPUArray[Vec2f, VertexBuffer]
    indices*: GPUArray[uint16, IndexBuffer]
    shaderdata*: DescriptorSet[TextboxDescriptorSet]

func `$`*(textbox: Textbox): string =
  "\"" & $textbox.text[0 ..< min(textbox.text.len, 16)] & "\""

proc RefreshShaderdata(textbox: Textbox) =
  textbox.shaderdata.data.textbox.UpdateGPUBuffer(flush = true)

proc RefreshGeometry(textbox: var Textbox) =
  # pre-calculate text-width
  var width = 0'f32
  var lineWidths: seq[float32]
  for i in 0 ..< textbox.processedText.len:
    if textbox.processedText[i] == NEWLINE:
      lineWidths.add width
      width = 0'f32
    else:
      if not (i == textbox.processedText.len - 1 and textbox.processedText[i].isWhiteSpace):
        width += textbox.font.glyphs[textbox.processedText[i]].advance
      if i < textbox.processedText.len - 1:
        width += textbox.font.kerning[(textbox.processedText[i], textbox.processedText[i + 1])]
  lineWidths.add width
  var height = float32(lineWidths.len - 1) * textbox.font.lineAdvance + textbox.font.capHeight
  if lineWidths[^1] == 0 and lineWidths.len > 1:
    height -= 1

  let anchorY = (case textbox.verticalAlignment
    of Top: 0'f32
    of Center: -height / 2
    of Bottom: -height
  ) + textbox.font.capHeight

  var
    offsetX = 0'f32
    offsetY = 0'f32
    lineIndex = 0
    anchorX = case textbox.horizontalAlignment
      of Left: 0'f32
      of Center: lineWidths[lineIndex] / 2
      of Right: lineWidths[lineIndex]
  for i in 0 ..< textbox.maxLen:
    let vertexOffset = i * 4
    if i < textbox.processedText.len:
      if textbox.processedText[i] == Rune('\n'):
        offsetX = 0
        offsetY -= textbox.font.lineAdvance
        textbox.position.data[vertexOffset + 0] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 1] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 2] = vec3(0, 0, 0)
        textbox.position.data[vertexOffset + 3] = vec3(0, 0, 0)
        inc lineIndex
        anchorX = case textbox.horizontalAlignment
          of Left: 0'f32
          of Center: lineWidths[lineIndex] / 2
          of Right: lineWidths[lineIndex]
      else:
        let
          glyph = textbox.font.glyphs[textbox.processedText[i]]
          left = offsetX + glyph.leftOffset
          right = offsetX + glyph.leftOffset + glyph.dimension.x
          top = offsetY - glyph.topOffset
          bottom = offsetY - glyph.topOffset - glyph.dimension.y

        textbox.position.data[vertexOffset + 0] = vec3(left - anchorX, bottom - anchorY, 0)
        textbox.position.data[vertexOffset + 1] = vec3(left - anchorX, top - anchorY, 0)
        textbox.position.data[vertexOffset + 2] = vec3(right - anchorX, top - anchorY, 0)
        textbox.position.data[vertexOffset + 3] = vec3(right - anchorX, bottom - anchorY, 0)

        textbox.uv.data[vertexOffset + 0] = glyph.uvs[0]
        textbox.uv.data[vertexOffset + 1] = glyph.uvs[1]
        textbox.uv.data[vertexOffset + 2] = glyph.uvs[2]
        textbox.uv.data[vertexOffset + 3] = glyph.uvs[3]

        offsetX += glyph.advance
        if i < textbox.processedText.len - 1:
          offsetX += textbox.font.kerning[(textbox.processedText[i], textbox.processedText[i + 1])]
    else:
      textbox.position.data[vertexOffset + 0] = vec3(0, 0, 0)
      textbox.position.data[vertexOffset + 1] = vec3(0, 0, 0)
      textbox.position.data[vertexOffset + 2] = vec3(0, 0, 0)
      textbox.position.data[vertexOffset + 3] = vec3(0, 0, 0)
  UpdateGPUBuffer(textbox.position)
  UpdateGPUBuffer(textbox.uv)
  textbox.lastRenderedText = textbox.processedText

func text*(textbox: Textbox): seq[Rune] =
  textbox.text

proc `text=`*(textbox: var Textbox, newText: seq[Rune]) =
  if newText[0 ..< min(newText.len, textbox.maxLen)] == textbox.text:
    return

  textbox.text = newText[0 ..< min(newText.len, textbox.maxLen)]

  textbox.processedText = textbox.text
  if textbox.maxWidth > 0:
    textbox.processedText = WordWrapped(
      textbox.processedText,
      textbox.font[],
      textbox.maxWidth / textbox.shaderdata.data.textbox.data.scale,
    )

proc `text=`*(textbox: var Textbox, newText: string) =
  `text=`(textbox, newText.toRunes)

proc Color*(textbox: Textbox): Vec4f =
  textbox.shaderdata.data.textbox.data.color

proc `Color=`*(textbox: var Textbox, value: Vec4f) =
  if textbox.shaderdata.data.textbox.data.color != value:
    textbox.dirtyShaderdata = true
    textbox.shaderdata.data.textbox.data.color = value

proc Scale*(textbox: Textbox): float32 =
  textbox.shaderdata.data.textbox.data.scale

proc `Scale=`*(textbox: var Textbox, value: float32) =
  if textbox.shaderdata.data.textbox.data.scale != value:
    textbox.dirtyShaderdata = true
    textbox.shaderdata.data.textbox.data.scale = value

proc Position*(textbox: Textbox): Vec3f =
  textbox.shaderdata.data.textbox.data.position

proc `Position=`*(textbox: var Textbox, value: Vec3f) =
  if textbox.shaderdata.data.textbox.data.position != value:
    textbox.dirtyShaderdata = true
    textbox.shaderdata.data.textbox.data.position = value

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

proc Refresh*(textbox: var Textbox) =
  if textbox.shaderdata.data.textbox.data.aspectratio != GetAspectRatio():
    textbox.dirtyShaderdata = true
    textbox.shaderdata.data.textbox.data.aspectratio = GetAspectRatio()

  if textbox.dirtyShaderdata:
    textbox.RefreshShaderdata()
    textbox.dirtyShaderdata = false

  if textbox.dirtyGeometry or textbox.processedText != textbox.lastRenderedText:
    textbox.RefreshGeometry()
    textbox.dirtyGeometry = false

proc Render*(textbox: Textbox, commandbuffer: VkCommandBuffer, pipeline: Pipeline) =
  WithBind(commandbuffer, (textbox.shaderdata, ), pipeline):
    Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = textbox)

proc InitTextbox*[T: string | seq[Rune]](
  renderdata: var RenderData,
  descriptorSetLayout: VkDescriptorSetLayout,
  font: Font,
  text: T = default(T),
  scale: float32 = 1,
  position: Vec3f = vec3(0, 0, 0),
  color: Vec4f = vec4(0, 0, 0, 1),
  maxLen: int = text.len,
  verticalAlignment: VerticalAlignment = Center,
  horizontalAlignment: HorizontalAlignment = Center,
  maxWidth = 0'f32
): Textbox =

  result = Textbox(
    maxLen: maxLen,
    font: font,
    dirtyGeometry: true,
    dirtyShaderdata: true,
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
          aspectratio: 1,
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

  when T is string:
    `text=`(result, text.toRunes())
  else:
    `text=`(result, text)

  AssignBuffers(renderdata, result, uploadData = false)
  UploadImages(renderdata, result.shaderdata)
  InitDescriptorSet(renderdata, descriptorSetLayout, result.shaderdata)

  result.Refresh()
  UpdateAllGPUBuffers(result, flush = true, allFrames = true)
  UpdateAllGPUBuffers(result.shaderdata.data, flush = true)
