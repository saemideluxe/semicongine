type
  Pixel* = array[4, uint8]
  ImageObject* = object
    width*: uint32
    height*: uint32
    imagedata*: seq[Pixel]
  Image* = ref ImageObject

proc newImage*(width, height: uint32, imagedata: seq[Pixel] = @[]): Image =
  assert width > 0 and height > 0
  result.imagedata = (if imagedata.len == 0: newSeq[Pixel](width * height) else: imagedata)
  assert width * height == uint32(result.imagedata.len)

  result = new Image
  result.width = width
  result.height = height
