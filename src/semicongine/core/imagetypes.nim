import ./vulkanapi

type
  Pixel* = array[4, uint8]
  ImageObject* = object
    width*: uint32
    height*: uint32
    imagedata*: seq[Pixel]
  Sampler* = object
    magnification*: VkFilter
    minification*: VkFilter
    wrapModeS*: VkSamplerAddressMode
    wrapModeT*: VkSamplerAddressMode

  Image* = ref ImageObject
  Texture* = object
    name*: string
    image*: Image
    sampler*: Sampler

proc DefaultSampler*(): Sampler =
  Sampler(
    magnification: VK_FILTER_LINEAR,
    minification: VK_FILTER_LINEAR,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )

proc `[]`*(image: Image, x, y: uint32): Pixel =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x]

proc `[]=`*(image: var Image, x, y: uint32, value: Pixel) =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x] = value

const EMPTYPIXEL = [0'u8, 0'u8, 0'u8, 0'u8]
proc newImage*(width, height: uint32, imagedata: seq[Pixel] = @[], fill=EMPTYPIXEL): Image =
  assert width > 0 and height > 0
  assert uint32(imagedata.len) == width * height or imagedata.len == 0

  result = new Image
  result.imagedata = (if imagedata.len == 0: newSeq[Pixel](width * height) else: imagedata)
  assert width * height == uint32(result.imagedata.len)

  result.width = width
  result.height = height
  if fill != EMPTYPIXEL:
    for y in 0 ..< height:
      for x in 0 ..< width:
        result[x, y] = fill

