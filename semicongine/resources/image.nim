import std/os
# import std/syncio
import std/streams
import std/bitops
import std/strformat

import ../core/imagetypes
import ../core/utils

const COMPRESSION_BI_RGB = 0'u32
const COMPRESSION_BI_BITFIELDS = 3'u32
const COMPRESSION_BI_ALPHABITFIELDS = 6'u32
type
  BitmapFileHeader = object
    magicbytes: array[2, char]
    filesize: uint32
    reserved1: uint16
    reserved2: uint16
    dataStart: uint32
  DIBHeader = object
    headersize: uint32
    width: int32
    height: int32
    colorPlanes: uint16
    bitsPerPixel: uint16
    compression: uint32
    imageDataSize: uint32                 # unused
    resolutionX: int32                    # unused
    resolutionY: int32                    # unused
    nColors: uint32                       # unused
    nImportantColors: uint32              # unused
    bitMaskRed: uint32
    bitMaskGreen: uint32
    bitMaskBlue: uint32
    bitMaskAlpha: uint32
    colorSpace: array[4, char]            # not used yet
    colorSpaceEndpoints: array[36, uint8] # unused
    gammaRed: uint32                      # not used yet
    gammaGreen: uint32                    # not used yet
    gammaBlue: uint32                     # not used yet

proc readBMP*(stream: Stream): Image[RGBAPixel] =
  var
    bitmapFileHeader: BitmapFileHeader
    dibHeader: DIBHeader

  for name, value in fieldPairs(bitmapFileHeader):
    stream.read(value)
  if bitmapFileHeader.magicbytes != ['B', 'M']:
    raise newException(Exception, "Cannot open image, invalid magic bytes (is this really a BMP bitmap?)")
  for name, value in fieldPairs(dibHeader):

    when name in ["bitMaskRed", "bitMaskGreen", "bitMaskBlue"]:
      if dibHeader.compression in [COMPRESSION_BI_BITFIELDS, COMPRESSION_BI_ALPHABITFIELDS]:
        stream.read(value)
    elif name == "bitMaskAlpha":
      if dibHeader.compression == COMPRESSION_BI_ALPHABITFIELDS:
        stream.read(value)
    else:
      stream.read(value)

    when name == "headersize":
      if value != 124:
        raise newException(Exception, "Cannot open image, only BITMAPV5 supported")
    elif name == "colorPlanes":
      assert value == 1
    elif name == "bitsPerPixel":
      if not (value in [24'u16, 32'u16]):
        raise newException(Exception, "Cannot open image, only depth of 24 and 32 supported")
    elif name == "compression":
      if not (value in [0'u32, 3'u32]):
        raise newException(Exception, "Cannot open image, only BI_RGB and BI_BITFIELDS are supported compressions")
    elif name == "colorSpace":
      swap(value[0], value[3])
      swap(value[1], value[2])
  stream.setPosition(int(bitmapFileHeader.dataStart))
  var
    padding = ((int32(dibHeader.bitsPerPixel div 8)) * dibHeader.width) mod 4
    data = newSeq[RGBAPixel](dibHeader.width * abs(dibHeader.height))
  if padding > 0:
    padding = 4 - padding
  for row in 0 ..< abs(dibHeader.height):
    for col in 0 ..< dibHeader.width:

      var pixel: RGBAPixel = [0'u8, 0'u8, 0'u8, 255'u8]
      # if we got channeld bitmasks
      if dibHeader.compression in [COMPRESSION_BI_BITFIELDS, COMPRESSION_BI_ALPHABITFIELDS]:
        var value = stream.readUint32()
        pixel[0] = uint8((value and dibHeader.bitMaskRed) shr dibHeader.bitMaskRed.countTrailingZeroBits)
        pixel[1] = uint8((value and dibHeader.bitMaskGreen) shr dibHeader.bitMaskGreen.countTrailingZeroBits)
        pixel[2] = uint8((value and dibHeader.bitMaskBlue) shr dibHeader.bitMaskBlue.countTrailingZeroBits)
        if dibHeader.compression == COMPRESSION_BI_ALPHABITFIELDS:
          pixel[3] = uint8((value and dibHeader.bitMaskAlpha) shr dibHeader.bitMaskAlpha.countTrailingZeroBits)
      # if we got plain RGB(A), using little endian
      elif dibHeader.compression == COMPRESSION_BI_RGB:
        let nChannels = int(dibHeader.bitsPerPixel) div 8
        for i in 1 .. nChannels:
          stream.read(pixel[nChannels - i])
      else:
        raise newException(Exception, "Cannot open image, only BI_RGB and BI_BITFIELDS are supported compressions")

      # determine whether we read top-to-bottom or bottom-to-top
      var row_mult: int = (if dibHeader.height < 0: row else: dibHeader.height - row - 1)
      data[row_mult * dibHeader.width + col] = pixel
    stream.setPosition(stream.getPosition() + padding)

  result = NewImage(width = dibHeader.width.uint32, height = abs(dibHeader.height).uint32, imagedata = data)

{.compile: currentSourcePath.parentDir() & "/lodepng.c".}

proc lodepng_decode32(out_data: ptr cstring, w: ptr cuint, h: ptr cuint, in_data: cstring, insize: csize_t): cuint {.importc.}
proc lodepng_encode_memory(out_data: ptr cstring, outsize: ptr csize_t, image: cstring, w: cuint, h: cuint, colorType: cint, bitdepth: cuint): cuint {.importc.}

proc free(p: pointer) {.importc.} # for some reason the lodepng pointer can only properly be freed with the native free

proc readPNG*(stream: Stream): Image[RGBAPixel] =
  let indata = stream.readAll()
  var w, h: cuint
  var data: cstring

  if lodepng_decode32(out_data = addr data, w = addr w, h = addr h, in_data = cstring(indata), insize = csize_t(indata.len)) != 0:
    raise newException(Exception, "An error occured while loading PNG file")

  let imagesize = w * h * 4
  var imagedata = newSeq[RGBAPixel](w * h)
  copyMem(addr imagedata[0], data, imagesize)

  free(data)

  result = NewImage(width = w, height = h, imagedata = imagedata)

proc toPNG*[T: Pixel](image: Image[T]): seq[uint8] =
  when T is GrayPixel:
    let pngType = 0 # hardcoded in lodepng.h
  else:
    let pngType = 6 # hardcoded in lodepng.h
  var
    pngData: cstring
    pngSize: csize_t
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      discard
  let ret = lodepng_encode_memory(
    addr pngData,
    addr pngSize,
    cast[cstring](image.imagedata.ToCPointer),
    cuint(image.width),
    cuint(image.height),
    cint(pngType),
    8,
  )
  assert ret == 0, &"There was an error with generating the PNG data for image {image}, result was: {ret}"
  result = newSeq[uint8](pngSize)
  for i in 0 ..< pngSize:
    result[i] = uint8(pngData[i])
  free(pngData)

proc writePNG*[T: Pixel](image: Image[T], filename: string) =
  let f = filename.open(mode = fmWrite)
  let data = image.toPNG()
  let written = f.writeBytes(data, 0, data.len)
  assert written == data.len, &"There was an error while saving '{filename}': only {written} of {data.len} bytes were written"
  f.close()
