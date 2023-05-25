import std/strformat
import std/streams
import std/os
import std/unicode

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

proc readTrueType*(stream: Stream): Font =
  var
    indata = stream.readAll()
    fontinfo: stbtt_fontinfo
  if stbtt_InitFont(addr fontinfo, addr indata[0], 0) == 0:
    raise newException(Exception, "An error occured while loading PNG file")
  var
    width, height: cint
    offsetX, offsetY: cint
    data = stbtt_GetCodepointBitmap(addr fontinfo, 0, stbtt_ScaleForPixelHeight(addr fontinfo, 20), cint('a'), addr width, addr height, addr offsetX, addr offsetY)
  echo width, "x", height
  echo "offset: ", offsetX, "x", offsetY
  for y in 0 ..< height:
    for x in 0 ..< width:
      if data[y * width + x] > char(128):
        write stdout, '#'
      else:
        write stdout, ' '
      write stdout, ' '
    write stdout, '\n'
  result
