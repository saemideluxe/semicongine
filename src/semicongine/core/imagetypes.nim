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
    filter*: VkFilter # TODO: replace with mag/minification

  Image* = ref ImageObject
  TextureObject = object
    image*: Image
    sampler*: Sampler
  Texture* = ref TextureObject

proc DefaultSampler*(): Sampler =
  Sampler(
    magnification: VK_FILTER_LINEAR,
    minification: VK_FILTER_LINEAR,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )

proc newImage*(width, height: uint32, imagedata: seq[Pixel] = @[]): Image =
  assert width > 0 and height > 0
  assert uint32(imagedata.len) == width * height

  result = new Image
  result.imagedata = (if imagedata.len == 0: newSeq[Pixel](width * height) else: imagedata)
  assert width * height == uint32(result.imagedata.len)

  result.width = width
  result.height = height
