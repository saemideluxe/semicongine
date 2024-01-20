import times
import std/tables
import std/strformat
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

  result.fontscale = float32(stbtt_ScaleForPixelHeight(addr fontinfo, cfloat(lineHeightPixels)))

  # ensure all codepoints are available in the font
  for codePoint in codePoints:
    if stbtt_FindGlyphIndex(addr fontinfo, cint(codePoint)) == 0:
      warn &"Loading font {name}: Codepoint '{codePoint}' ({cint(codePoint)}) has no glyph"

  var
    offsetX = 0
    bitmaps: Table[Rune, (cstring, cint, cint)]
    topOffsets: Table[Rune, int]
    images: seq[Image[GrayPixel]]
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

    if width > 0 and height > 0:
      var bitmap = newSeq[GrayPixel](width * height)
      for i in 0 ..< width * height:
        bitmap[i] = GrayPixel(data[i])
      images.add newImage[GrayPixel](int(width), int(height), bitmap)

    bitmaps[codePoint] = (data, width, height)
    result.maxHeight = max(result.maxHeight, int(height))
    offsetX += width
    topOffsets[codePoint] = offY
  assert offsetX < MAX_TEXTURE_WIDTH, &"Font size too big, choose a smaller lineHeightPixels when loading the font (required texture width is {offsetX} but max is {MAX_TEXTURE_WIDTH}), must be smaller than {lineHeightPixels * float(MAX_TEXTURE_WIDTH) / float(offsetX) } (approx.)"

  let packed = pack(images)
  packed.atlas.writePNG("tmp.png")

  result.name = name
  result.fontAtlas = Texture(
    name: name & "_texture",
    isGrayscale: true,
    grayImage: newImage[GrayPixel](offsetX, result.maxHeight),
    sampler: FONTSAMPLER_SOFT
  )

  for codePoint in codePoints:
    let
      bitmap = bitmaps[codePoint][0]
      width = bitmaps[codePoint][1]
      height = bitmaps[codePoint][2]

  offsetX = 0
  for codePoint in codePoints:
    let
      bitmap = bitmaps[codePoint][0]
      width = bitmaps[codePoint][1]
      height = bitmaps[codePoint][2]

    # bitmap data
    for y in 0 ..< height:
      for x in 0 ..< width:
        result.fontAtlas.grayImage[x + offsetX, y] = uint8(bitmap[y * width + x])

    # horizontal spaces:
    var advance, leftBearing: cint
    stbtt_GetCodepointHMetrics(addr fontinfo, cint(codePoint), addr advance, addr leftBearing)

    result.glyphs[codePoint] = GlyphInfo(
      dimension: newVec2f(float32(width), float32(height)),
      uvs: [
        newVec2f((float32(offsetX) + 0.5) / float32(result.fontAtlas.grayImage.width), (float32(height) - 1.0) / float32(result.maxHeight)),
        newVec2f((float32(offsetX) + 0.5) / float32(result.fontAtlas.grayImage.width), 0.5 / float32(result.maxHeight)),
        newVec2f((float32(offsetX + width) - 1.0) / float32(result.fontAtlas.grayImage.width), 0.5 / float32(result.maxHeight)),
        newVec2f((float32(offsetX + width) - 1.0) / float32(result.fontAtlas.grayImage.width), (float32(height) - 1.0) / float32(result.maxHeight)),
      ],
      topOffset: float32(topOffsets[codePoint]),
      leftOffset: float32(leftBearing) * result.fontscale,
      advance: float32(advance) * result.fontscale,
    )
    offsetX += width
    free(bitmap)
    for codePointAfter in codePoints:
      result.kerning[(codePoint, codePointAfter)] = float32(stbtt_GetCodepointKernAdvance(
        addr fontinfo,
        cint(codePoint),
        cint(codePointAfter)
      )) * result.fontscale
