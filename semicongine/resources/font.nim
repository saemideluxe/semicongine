import times
import std/tables
import std/strformat
import std/sequtils
import std/streams
import std/os
import std/unicode
import std/logging

import ../core/vector
import ../core/imagetypes
import ../core/fonttypes
import ../algorithms
import ./image

{.emit: "#define STBTT_STATIC" .}
{.emit: "#define STB_TRUETYPE_IMPLEMENTATION" .}
{.emit: "#include \"" & currentSourcePath.parentDir() & "/stb_truetype.h\"" .}

type stbtt_fontinfo {.importc, incompleteStruct .} = object

const MAX_TEXTURE_WIDTH = 4096

proc stbtt_InitFont(info: ptr stbtt_fontinfo, data: ptr char, offset: cint): cint {.importc, nodecl.}
proc stbtt_ScaleForPixelHeight(info: ptr stbtt_fontinfo, pixels: cfloat): cfloat {.importc, nodecl.}

proc stbtt_GetCodepointBitmap(info: ptr stbtt_fontinfo, scale_x: cfloat, scale_y: cfloat, codepoint: cint, width, height, xoff, yoff: ptr cint): cstring {.importc, nodecl.}
proc stbtt_GetCodepointBitmapBox(info: ptr stbtt_fontinfo, codepoint: cint, scale_x, scale_y: cfloat, ix0, iy0, ix1, iy1: ptr cint) {.importc, nodecl.}

proc stbtt_GetCodepointHMetrics(info: ptr stbtt_fontinfo, codepoint: cint, advance, leftBearing: ptr cint) {.importc, nodecl.}
proc stbtt_GetCodepointKernAdvance(info: ptr stbtt_fontinfo, ch1, ch2: cint): cint {.importc, nodecl.}
proc stbtt_FindGlyphIndex(info: ptr stbtt_fontinfo, codepoint: cint): cint {.importc, nodecl.}

proc free(p: pointer) {.importc.}

proc readTrueType*(stream: Stream, name: string, codePoints: seq[Rune], lineHeightPixels: float32): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, addr indata[0], 0) == 0:
    raise newException(Exception, "An error occured while loading PNG file")

  result.name = name
  result.fontscale = float32(stbtt_ScaleForPixelHeight(addr fontinfo, cfloat(lineHeightPixels)))

  # ensure all codepoints are available in the font
  for codePoint in codePoints:
    if stbtt_FindGlyphIndex(addr fontinfo, cint(codePoint)) == 0:
      warn &"Loading font {name}: Codepoint '{codePoint}' ({cint(codePoint)}) has no glyph"

  var
    bitmaps: Table[Rune, (cstring, cint, cint)]
    topOffsets: Table[Rune, int]
    images: seq[Image[GrayPixel]]
  let empty_image = newImage[GrayPixel](1, 1, [0'u8])

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

    if width > 0 and height > 0:
      var bitmap = newSeq[GrayPixel](width * height)
      for i in 0 ..< width * height:
        bitmap[i] = GrayPixel(data[i])
      images.add newImage[GrayPixel](int(width), int(height), bitmap)
    else:
      images.add empty_image

    free(data)

  let packed = pack(images)

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
      dimension: newVec2f(float32(image.width), float32(image.height)),
      uvs: [
        newVec2f((coord.x + 0.5 )     / w, (coord.y + ih - 0.5) / h),
        newVec2f((coord.x + 0.5 )     / w, (coord.y + 0.5)      / h),
        newVec2f((coord.x + iw - 0.5) / w, (coord.y + 0.5)      / h),
        newVec2f((coord.x + iw - 0.5) / w, (coord.y + ih - 0.5) / h),
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
