import std/strformat
import std/tables
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
proc stbtt_ScaleForPixelHeight(info: ptr stbtt_fontinfo, pixels: float): cfloat {.importc, nodecl.}
proc stbtt_GetCodepointBitmap(info: ptr stbtt_fontinfo, scale_x: cfloat, scale_y: cfloat, codepoint: cint, width: ptr cint, height: ptr cint, xoff: ptr cint, yoff: ptr cint): cstring {.importc, nodecl.}
# proc free(p: pointer) {.importc.}

proc readTrueType*(stream: Stream, name: string, codePoints: seq[Rune]): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, addr indata[0], 0) == 0:
    raise newException(Exception, "An error occured while loading PNG file")

  let fontheight = stbtt_ScaleForPixelHeight(addr fontinfo, 100)
  var
    charOffset: Table[Rune, uint32]
    offsetX: uint32
    maxheight: uint32
    bitmaps: Table[Rune, (cstring, cint, cint)]
    baselines: Table[Rune, int]
  for codePoint in codePoints:
    var
      width, height: cint
      leftStart, baseline: cint
      data = stbtt_GetCodepointBitmap(
        addr fontinfo,
        0, fontheight,
        cint('a'),
        addr width, addr height,
        addr leftStart, addr baseline
      )
    bitmaps[codePoint] = (data, width, height)
    maxheight = max(maxheight, uint32(height))
    charOffset[codePoint] = offsetX
    offsetX += uint32(width)
    baselines[codePoint] = baseline

  result.name = name
  result.fontAtlas = newImage(offsetX, maxheight)

  offsetX = 0
  for codePoint in codePoints:
    let d = bitmaps[codePoint][0]
    let width = uint32(bitmaps[codePoint][1])
    let height = uint32(bitmaps[codePoint][2])
    for y in 0 ..< height:
      for x in 0 ..< width:
        result.fontAtlas[x + offsetX, y] = [255'u8, 255'u8, 255'u8, uint8(d[y * width + x])]
    result.characterDimensions[codePoint] = newVec2f(float32(width), float32(height))
    result.characterUVs[codePoint] = [
      newVec2f(float32(offsetX) / float32(result.fontAtlas.width), 0),
      newVec2f(float32(offsetX + width) / float32(result.fontAtlas.width), 0),
      newVec2f(float32(offsetX) / float32(result.fontAtlas.width), 1),
      newVec2f(float32(offsetX + width) / float32(result.fontAtlas.width), 1),
    ]
    offsetX += width
