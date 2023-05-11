import std/streams
import std/bitops
import std/algorithm

import ../core/imagetypes

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
    imageDataSize: uint32 # unused
    resolutionX: int32 # unused
    resolutionY: int32 # unused
    nColors: uint32 # unused
    nImportantColors: uint32 # unused
    bitMaskRed: uint32
    bitMaskGreen: uint32
    bitMaskBlue: uint32
    bitMaskAlpha: uint32
    colorSpace: array[4, char] # not used yet
    colorSpaceEndpoints: array[36, uint8] # unused
    gammaRed: uint32 # not used yet
    gammaGreen: uint32 # not used yet
    gammaBlue: uint32 # not used yet

proc readBMP*(stream: Stream): Image =
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
    data = newSeq[Pixel](dibHeader.width * abs(dibHeader.height))
  if padding > 0:
    padding = 4 - padding
  for row in 0 ..< abs(dibHeader.height):
    for col in 0 ..< dibHeader.width:

      var pixel: Pixel = [0'u8, 0'u8, 0'u8, 255'u8]
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
      data[row_mult * dibHeader.width + col]= pixel
    stream.setPosition(stream.getPosition() + padding)

  result = newImage(width=uint32(dibHeader.width), height=uint32(abs(dibHeader.height)), imagedata=data)
