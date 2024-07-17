import std/tables
import std/strutils
import std/strformat
import std/streams
import std/os
import std/unicode
import std/logging

import ../core/vector
import ../core/imagetypes
import ../core/fonttypes
import ../algorithms

{.emit: "#define STBTT_STATIC".}
{.emit: "#define STB_TRUETYPE_IMPLEMENTATION".}
{.emit: "#include \"" & currentSourcePath.parentDir() & "/stb_truetype.h\"".}

type stbtt_fontinfo {.importc, incompleteStruct.} = object

proc stbtt_InitFont(info: ptr stbtt_fontinfo, data: ptr char, offset: cint): cint {.importc, nodecl.}
proc stbtt_ScaleForPixelHeight(info: ptr stbtt_fontinfo, pixels: cfloat): cfloat {.importc, nodecl.}

proc stbtt_GetCodepointBitmap(info: ptr stbtt_fontinfo, scale_x: cfloat, scale_y: cfloat, codepoint: cint, width, height, xoff, yoff: ptr cint): cstring {.importc, nodecl.}
# proc stbtt_GetCodepointBitmapBox(info: ptr stbtt_fontinfo, codepoint: cint, scale_x, scale_y: cfloat, ix0, iy0, ix1, iy1: ptr cint) {.importc, nodecl.}

proc stbtt_GetCodepointHMetrics(info: ptr stbtt_fontinfo, codepoint: cint, advance, leftBearing: ptr cint) {.importc, nodecl.}
proc stbtt_GetCodepointKernAdvance(info: ptr stbtt_fontinfo, ch1, ch2: cint): cint {.importc, nodecl.}
proc stbtt_FindGlyphIndex(info: ptr stbtt_fontinfo, codepoint: cint): cint {.importc, nodecl.}

proc stbtt_GetFontVMetrics(info: ptr stbtt_fontinfo, ascent, descent, lineGap: ptr cint) {.importc, nodecl.}

proc free(p: pointer) {.importc.}

proc ReadTrueType*(stream: Stream, name: string, codePoints: seq[Rune], lineHeightPixels: float32): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, addr indata[0], 0) == 0:
    raise newException(Exception, "An error occured while loading PNG file")

  result.name = name
  result.fontscale = float32(stbtt_ScaleForPixelHeight(addr fontinfo, cfloat(lineHeightPixels)))

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
    images: seq[Image[GrayPixel]]
  let empty_image = NewImage[GrayPixel](1, 1, [0'u8])

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
      var bitmap = newSeq[GrayPixel](width * height)
      for i in 0 ..< width * height:
        bitmap[i] = GrayPixel(data[i])
      images.add NewImage[GrayPixel](width.uint32, height.uint32, bitmap)
    else:
      images.add empty_image

    free(data)

  let packed = Pack(images)

  result.fontAtlas = Texture(
    name: name & "_texture",
    isGrayscale: true,
    grayImage: packed.atlas,
    sampler: FONTSAMPLER_SOFT,
  )

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
      dimension: NewVec2f(float32(image.width), float32(image.height)),
      uvs: [
        NewVec2f((coord.x + 0.5) / w, (coord.y + ih - 0.5) / h),
        NewVec2f((coord.x + 0.5) / w, (coord.y + 0.5) / h),
        NewVec2f((coord.x + iw - 0.5) / w, (coord.y + 0.5) / h),
        NewVec2f((coord.x + iw - 0.5) / w, (coord.y + ih - 0.5) / h),
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
