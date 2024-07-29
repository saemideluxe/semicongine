{.emit: "#define STBTT_STATIC".}
{.emit: "#define STB_TRUETYPE_IMPLEMENTATION".}
{.emit: "#include \"" & currentSourcePath.parentDir().parentDir() & "/thirdparty/stb/stb_truetype.h\"".}

type stbtt_fontinfo {.importc, incompleteStruct.} = object

proc stbtt_InitFont(info: ptr stbtt_fontinfo, data: ptr char, offset: cint): cint {.importc, nodecl.}
proc stbtt_ScaleForPixelHeight(info: ptr stbtt_fontinfo, pixels: cfloat): cfloat {.importc, nodecl.}

proc stbtt_GetCodepointBitmap(info: ptr stbtt_fontinfo, scale_x: cfloat, scale_y: cfloat, codepoint: cint, width, height, xoff, yoff: ptr cint): cstring {.importc, nodecl.}
# proc stbtt_GetCodepointBitmapBox(info: ptr stbtt_fontinfo, codepoint: cint, scale_x, scale_y: cfloat, ix0, iy0, ix1, iy1: ptr cint) {.importc, nodecl.}

proc stbtt_GetCodepointHMetrics(info: ptr stbtt_fontinfo, codepoint: cint, advance, leftBearing: ptr cint) {.importc, nodecl.}
proc stbtt_GetCodepointKernAdvance(info: ptr stbtt_fontinfo, ch1, ch2: cint): cint {.importc, nodecl.}
proc stbtt_FindGlyphIndex(info: ptr stbtt_fontinfo, codepoint: cint): cint {.importc, nodecl.}

proc stbtt_GetFontVMetrics(info: ptr stbtt_fontinfo, ascent, descent, lineGap: ptr cint) {.importc, nodecl.}

proc ReadTrueType*(stream: Stream, name: string, codePoints: seq[Rune], lineHeightPixels: float32): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, indata.ToCPointer, 0) == 0:
    raise newException(Exception, "An error occured while loading font file")

  result = Font(
    name: name,
    fontscale: float32(stbtt_ScaleForPixelHeight(addr fontinfo, cfloat(lineHeightPixels))),
  )

  var ascent, descent, lineGap: cint
  stbtt_GetFontVMetrics(addr fontinfo, addr ascent, addr descent, addr lineGap)

  result.lineHeight = float32(ascent - descent) * result.fontscale
  result.lineAdvance = float32(ascent - descent + lineGap) * result.fontscale

  # ensure all codepoints are available in the font
  for codePoint in codePoints:
    if stbtt_FindGlyphIndex(addr fontinfo, cint(codePoint)) == 0:
      warn &"Loading font {name}: Codepoint '{codePoint}' ({cint(codePoint)}) has no glyph"

  var
    topOffsets: Table[Rune, int]
    images: seq[Image[Gray]]
  let empty_image = Image[Gray](width: 1, height: 1, data: @[[0'u8]])

  for codePoint in codePoints:
    var
      width, height: cint
      offX, offY: cint
    let
      data = stbtt_GetCodepointBitmap(
        addr fontinfo,
        result.fontscale,
        result.fontscale,
        cint(codePoint),
        addr width, addr height,
        addr offX, addr offY
      )
    topOffsets[codePoint] = offY

    if char(codePoint) in UppercaseLetters:
      result.capHeight = float32(height)
    if codePoint == Rune('x'):
      result.xHeight = float32(height)

    if width > 0 and height > 0:
      var bitmap = newSeq[Gray](width * height)
      for i in 0 ..< width * height:
        bitmap[i] = [data[i].uint8]
      images.add Image[Gray](width: width.uint32, height: height.uint32, data: bitmap)
    else:
      images.add empty_image

    nativeFree(data)

  let packed = Pack(images)

  result.fontAtlas = packed.atlas

  let w = float32(packed.atlas.width)
  let h = float32(packed.atlas.height)
  for i in 0 ..< codePoints.len:
    let
      codePoint = codePoints[i]
      image = images[i]
      coord = (x: float32(packed.coords[i].x), y: float32(packed.coords[i].y))
      iw = float32(image.width)
      ih = float32(image.height)
    # horizontal spaces:
    var advance, leftBearing: cint
    stbtt_GetCodepointHMetrics(addr fontinfo, cint(codePoint), addr advance, addr leftBearing)

    result.glyphs[codePoint] = GlyphInfo(
      dimension: vec2(float32(image.width), float32(image.height)),
      uvs: [
        vec2((coord.x + 0.5) / w, (coord.y + ih - 0.5) / h),
        vec2((coord.x + 0.5) / w, (coord.y + 0.5) / h),
        vec2((coord.x + iw - 0.5) / w, (coord.y + 0.5) / h),
        vec2((coord.x + iw - 0.5) / w, (coord.y + ih - 0.5) / h),
      ],
      topOffset: float32(topOffsets[codePoint]),
      leftOffset: float32(leftBearing) * result.fontscale,
      advance: float32(advance) * result.fontscale,
    )

    for codePointAfter in codePoints:
      result.kerning[(codePoint, codePointAfter)] = float32(stbtt_GetCodepointKernAdvance(
        addr fontinfo,
        cint(codePoint),
        cint(codePointAfter)
      )) * result.fontscale

proc LoadFont*(
  path: string,
  name = "",
  lineHeightPixels = 80'f32,
  additional_codepoints: openArray[Rune] = [],
  charset = ASCII_CHARSET,
  package = DEFAULT_PACKAGE
): Font =
  var thename = name
  if thename == "":
    thename = path.splitFile().name
  loadResource_intern(path, package = package).ReadTrueType(thename, charset & additional_codepoints.toSeq, lineHeightPixels)

func TextWidth*(text: seq[Rune], font: FontObj): float32 =
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
      if currentLine.len == 0 and (SPACE & currentWord).TextWidth(font) > maxWidth:
        var subWord = @[currentWord[0]]
        for c in currentWord[1 .. ^1]:
          if (subWord & c).TextWidth(font) > maxWidth:
            break
          subWord.add c
        result.add subWord & NEWLINE
        remaining.add currentWord[subWord.len .. ^1] # process rest of the word in next iteration
      else:
        if (currentLine & SPACE & currentWord).TextWidth(font) <= maxWidth:
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

