type
  Gray* = TVec1[uint8]
  RGBA* = TVec4[uint8]
  PixelType* = Gray | RGBA
  Image*[T: PixelType] = object
    width*: uint32
    height*: uint32
    interpolation*: VkFilter = VK_FILTER_LINEAR
    data*: seq[T]
    vk*: VkImage
    imageview*: VkImageView
    sampler*: VkSampler
    isRenderTarget*: bool = false
    samples*: VkSampleCountFlagBits = VK_SAMPLE_COUNT_1_BIT

proc LoadImage*[T: PixelType](path: string, package = DEFAULT_PACKAGE): Image[T] =
  assert path.splitFile().ext.toLowerAscii == ".png"
  when T is Gray:
    let pngType = 0.cint
  elif T is RGBA:
    let pngType = 6.cint

  let indata = loadResource_intern(path, package = package).readAll()
  var w, h: cuint
  var data: cstring

  if lodepng_decode_memory(out_data = addr(data), w = addr(w), h = addr(h), in_data = cstring(indata), insize = csize_t(indata.len), colorType = pngType, bitdepth = 8) != 0:
    raise newException(Exception, "An error occured while loading PNG file")

  let imagesize = w * h * 4
  result = Image[T](width: w, height: h, data: newSeq[T](w * h))
  copyMem(result.data.ToCPointer, data, imagesize)
  nativeFree(data)

  when T is RGBA: # converkt to BGRA
    for i in 0 ..< result.data.len:
      swap(result.data[i][0], result.data[i][2])

proc toPNG[T: PixelType](image: Image[T]): seq[uint8] =
  when T is Gray:
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
  nativeFree(pngData)

proc WritePNG*(image: Image, filename: string) =
  let f = filename.open(mode = fmWrite)
  let data = image.toPNG()
  let written = f.writeBytes(data, 0, data.len)
  assert written == data.len, &"There was an error while saving '{filename}': only {written} of {data.len} bytes were written"
  f.close()
