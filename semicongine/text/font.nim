{.emit: "#define STBTT_STATIC".}
{.emit: "#define STB_TRUETYPE_IMPLEMENTATION".}
{.
  emit:
    "#include \"" & currentSourcePath.parentDir().parentDir() &
    "/thirdparty/stb/stb_truetype.h\""
.}

const ASCII_CHARSET = PrintableChars.toSeq.toRunes

type stbtt_fontinfo {.importc, incompleteStruct.} = object

proc stbtt_InitFont(
  info: ptr stbtt_fontinfo, data: ptr char, offset: cint
): cint {.importc, nodecl.}

proc stbtt_ScaleForPixelHeight(
  info: ptr stbtt_fontinfo, pixels: cfloat
): cfloat {.importc, nodecl.}

proc stbtt_GetCodepointBitmap(
  info: ptr stbtt_fontinfo,
  scale_x: cfloat,
  scale_y: cfloat,
  codepoint: cint,
  width, height, xoff, yoff: ptr cint,
): cstring {.importc, nodecl.}

# proc stbtt_GetCodepointBitmapBox(info: ptr stbtt_fontinfo, codepoint: cint, scale_x, scale_y: cfloat, ix0, iy0, ix1, iy1: ptr cint) {.importc, nodecl.}

proc stbtt_GetCodepointHMetrics(
  info: ptr stbtt_fontinfo, codepoint: cint, advance, leftBearing: ptr cint
) {.importc, nodecl.}

proc stbtt_GetCodepointKernAdvance(
  info: ptr stbtt_fontinfo, ch1, ch2: cint
): cint {.importc, nodecl.}

proc stbtt_FindGlyphIndex(
  info: ptr stbtt_fontinfo, codepoint: cint
): cint {.importc, nodecl.}

proc stbtt_GetFontVMetrics(
  info: ptr stbtt_fontinfo, ascent, descent, lineGap: ptr cint
) {.importc, nodecl.}

proc readTrueType[N: static int](
    stream: Stream, name: string, codePoints: seq[Rune], lineHeightPixels: float32
): Font[N] =
  assert codePoints.len <= N,
    "asked for " & $codePoints.len & " glyphs but shader is only configured for " & $N

  result = Font[N]()

  var
    indata = stream.readAll()
    fi: stbtt_fontinfo
  if stbtt_InitFont(addr fi, indata.ToCPointer, 0) == 0:
    raise newException(Exception, "An error occured while loading font file")

  let
    glyph2bitmapScale =
      float32(stbtt_ScaleForPixelHeight(addr fi, cfloat(lineHeightPixels)))
    glyph2QuadScale = glyph2bitmapScale / lineHeightPixels

  # ensure all codepoints are available in the font
  for codePoint in codePoints:
    if stbtt_FindGlyphIndex(addr fi, cint(codePoint)) == 0:
      warn &"Loading font {name}: Codepoint '{codePoint}' ({cint(codePoint)}) has no glyph"

  var
    offsetY: Table[Rune, cint]
    offsetX: Table[Rune, cint]
    bitmaps: seq[Image[Gray]]

  # render all glyphs to bitmaps and store quad geometry info
  for codePoint in codePoints:
    offsetX[codePoint] = 0
    offsetY[codePoint] = 0
    var width, height: cint
    let data = stbtt_GetCodepointBitmap(
      addr fi,
      glyph2bitmapScale,
      glyph2bitmapScale,
      cint(codePoint),
      addr width,
      addr height,
      addr (offsetX[codePoint]),
      addr (offsetY[codePoint]),
    )

    if width > 0 and height > 0:
      var bitmap = newSeq[Gray](width * height)
      for i in 0 ..< width * height:
        bitmap[i] = vec1u8(data[i].uint8)
      bitmaps.add Image[Gray](width: width.uint32, height: height.uint32, data: bitmap)
    else:
      bitmaps.add Image[Gray](width: 1, height: 1, data: @[vec1u8(0)])

    nativeFree(data)

  # generate glyph atlas from bitmaps
  let packed = pack(bitmaps)
  result.descriptorSet.data.fontAtlas = packed.atlas

  # generate quad-information for use in shader
  for i in 0 ..< codePoints.len:
    let codePoint = codePoints[i]
    var advanceUnscaled, leftBearingUnscaled: cint
      # is in glyph-space, needs to be scaled to pixel-space
    stbtt_GetCodepointHMetrics(
      addr fi, cint(codePoint), addr advanceUnscaled, addr leftBearingUnscaled
    )
    var leftBearing = leftBearingUnscaled.float32 * glyph2QuadScale
    result.advance[codePoint] = advanceUnscaled.float32 * glyph2QuadScale

    let
      atlasW = float32(result.descriptorSet.data.fontAtlas.width)
      atlasH = float32(result.descriptorSet.data.fontAtlas.height)
      uv = vec2(packed.coords[i].x, packed.coords[i].y)
      bitmapW = float32(bitmaps[i].width)
      bitmapH = float32(bitmaps[i].height)
      # divide by lineHeightPixels to get from pixel-space to quad-geometry-space
      left = leftBearing + offsetX[codePoint].float32 / lineHeightPixels
      right = left + bitmapW / lineHeightPixels
      top = -offsetY[codePoint].float32 / lineHeightPixels
      bottom = top - bitmapH / lineHeightPixels

    template glyphquads(): untyped =
      result.descriptorSet.data.glyphquads.data

    glyphquads.pos[i] = vec4(left, bottom, right, top)
    glyphquads.uv[i] = vec4(
      (uv.x + 0.5) / atlasW, # left
      (uv.y + bitmapH - 0.5) / atlasH, # bottom
      (uv.x + bitmapW - 0.5) / atlasW, # right
      (uv.y + 0.5) / atlasH, # top
    )
    if i == 0:
      result.fallbackCharacter = codePoint
    result.descriptorGlyphIndex[codePoint] = i.uint16

    # kerning
    for codePointAfter in codePoints:
      result.kerning[(codePoint, codePointAfter)] =
        float32(
          stbtt_GetCodepointKernAdvance(addr fi, cint(codePoint), cint(codePointAfter))
        ) * glyph2QuadScale

  # line spacing
  var ascent, descent, lineGap: cint
  stbtt_GetFontVMetrics(addr fi, addr ascent, addr descent, addr lineGap)
  result.lineAdvance = float32(ascent - descent + lineGap) * glyph2QuadScale
  result.lineHeight = float32(ascent - descent) * glyph2QuadScale
  result.ascent = float32(ascent) * glyph2QuadScale

proc loadFont*[N: static int](
    path: string,
    lineHeightPixels = 80'f32,
    additional_codepoints: openArray[Rune] = [],
    charset = ASCII_CHARSET,
    package = DEFAULT_PACKAGE,
): Font[N] =
  readTrueType[N](
    loadResource_intern(path, package = package),
    path.splitFile().name,
    charset & additional_codepoints.toSeq,
    lineHeightPixels,
  )

func textWidth*(theText: seq[Rune] | string, font: FontObj): float32 =
  var text = when theText is string: theText.toRunes else: theText
  var currentWidth = 0'f32
  var lineWidths: seq[float32]
  for i in 0 ..< text.len:
    if text[i] == NEWLINE:
      lineWidths.add currentWidth
      currentWidth = 0'f32
    else:
      if not (i == text.len - 1 and text[i].isWhiteSpace):
        currentWidth += font.advance[text[i]]
      if i < text.len - 1:
        currentWidth += font.kerning[(text[i], text[i + 1])]
  lineWidths.add currentWidth
  return lineWidths.max

func WordWrapped*(text: seq[Rune], font: FontObj, maxWidth: float32): seq[Rune] =
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
      if currentLine.len == 0 and (SPACE & currentWord).textWidth(font) > maxWidth:
        var subWord = @[currentWord[0]]
        for c in currentWord[1 .. ^1]:
          if (subWord & c).textWidth(font) > maxWidth:
            break
          subWord.add c
        result.add subWord & NEWLINE
        remaining.add currentWord[subWord.len .. ^1]
          # process rest of the word in next iteration
      else:
        if (currentLine & SPACE & currentWord).textWidth(font) <= maxWidth:
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
