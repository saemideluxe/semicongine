import std/tables
import std/math
import std/streams
import std/os
import std/unicode

import ../core/vector
import ../core/imagetypes
import ../core/fonttypes

{.emit: "#define STBTT_STATIC" .}
{.emit: "#define STB_TRUETYPE_IMPLEMENTATION" .}
{.emit: "#include \"" & currentSourcePath.parentDir() & "/stb_truetype.h\"" .}

type
  stbtt_fontinfo {.importc, incompleteStruct .} = object

proc stbtt_InitFont(info: ptr stbtt_fontinfo, data: ptr char, offset: cint): cint {.importc, nodecl.}
proc stbtt_ScaleForPixelHeight(info: ptr stbtt_fontinfo, pixels: cfloat): cfloat {.importc, nodecl.}
proc stbtt_GetCodepointBitmap(info: ptr stbtt_fontinfo, scale_x: cfloat, scale_y: cfloat, codepoint: cint, width, height, xoff, yoff: ptr cint): cstring {.importc, nodecl.}
proc stbtt_GetCodepointHMetrics(info: ptr stbtt_fontinfo, codepoint: cint, advance, leftBearing: ptr cint) {.importc, nodecl.}
proc stbtt_GetCodepointKernAdvance(info: ptr stbtt_fontinfo, ch1, ch2: cint): cint {.importc, nodecl.}

proc free(p: pointer) {.importc.}

proc readTrueType*(stream: Stream, name: string, codePoints: seq[Rune], color: Vec4f, resolution: float32): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, addr indata[0], 0) == 0:
    raise newException(Exception, "An error occured while loading PNG file")

  result.resolution = resolution
  result.fontscale = float32(stbtt_ScaleForPixelHeight(addr fontinfo, cfloat(resolution)))
  var
    offsetX: uint32
    bitmaps: Table[Rune, (cstring, cint, cint)]
    topOffsets: Table[Rune, int]
  for codePoint in codePoints:
    var
      width, height: cint
      offX, offY: cint
      data = stbtt_GetCodepointBitmap(
        addr fontinfo,
        result.fontscale, result.fontscale,
        cint(codePoint),
        addr width, addr height,
        addr offX, addr offY
      )
    bitmaps[codePoint] = (data, width, height)
    result.maxHeight = max(result.maxHeight, int(height))
    offsetX += uint32(width + 1)
    topOffsets[codePoint] = offY

  result.name = name
  result.fontAtlas = Texture(
    name: name & "_texture",
    image: newImage(offsetX, uint32(result.maxHeight + 1)),
    sampler: FONTSAMPLER_SOFT
  )

  offsetX = 0
  for codePoint in codePoints:
    let
      bitmap = bitmaps[codePoint][0]
      width = uint32(bitmaps[codePoint][1])
      height = uint32(bitmaps[codePoint][2])

    # bitmap data
    for y in 0 ..< height:
      for x in 0 ..< width:
        let value = float32(bitmap[y * width + x])
        result.fontAtlas.image[x + offsetX, y] = [
          uint8(round(color.r * 255'f32)),
          uint8(round(color.g * 255'f32)),
          uint8(round(color.b * 255'f32)),
          uint8(round(color.a * value))
        ]

    # horizontal spaces:
    var advance, leftBearing: cint
    stbtt_GetCodepointHMetrics(addr fontinfo, cint(codePoint), addr advance, addr leftBearing)

    result.glyphs[codePoint] = GlyphInfo(
      dimension: newVec2f(float32(width), float32(height)),
      uvs: [
        newVec2f(float32(offsetX) / float32(result.fontAtlas.image.width), int(height) / result.maxHeight),
        newVec2f(float32(offsetX) / float32(result.fontAtlas.image.width), 0),
        newVec2f(float32(offsetX + width) / float32(result.fontAtlas.image.width), 0),
        newVec2f(float32(offsetX + width) / float32(result.fontAtlas.image.width), int(height) / result.maxHeight),
      ],
      topOffset: float32(topOffsets[codePoint]),
      leftOffset: float32(leftBearing) * result.fontscale,
      advance: float32(advance) * result.fontscale,
    )
    offsetX += width + 1
    free(bitmap)
    for codePointAfter in codePoints:
      result.kerning[(codePoint, codePointAfter)] = float32(stbtt_GetCodepointKernAdvance(
        addr fontinfo,
        cint(codePoint),
        cint(codePointAfter)
      )) * result.fontscale
