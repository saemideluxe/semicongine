import ./vulkanapi

type
  Pixel* = array[4, uint8]
  ImageObject* = object
    width*: int
    height*: int
    imagedata*: seq[Pixel]
  Sampler* = object
    magnification*: VkFilter = VK_FILTER_LINEAR
    minification*: VkFilter = VK_FILTER_LINEAR
    wrapModeS*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    wrapModeT*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT

  Image* = ref ImageObject
  Texture* = object
    name*: string
    image*: Image
    sampler*: Sampler

proc `[]`*(image: Image, x, y: int): Pixel =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x]

proc `[]=`*(image: var Image, x, y: int, value: Pixel) =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x] = value

const EMPTYPIXEL = [0'u8, 0'u8, 0'u8, 0'u8]
proc newImage*(width, height: int, imagedata: seq[Pixel] = @[], fill=EMPTYPIXEL): Image =
  assert width > 0 and height > 0
  assert imagedata.len == width * height or imagedata.len == 0

  result = new Image
  result.imagedata = (if imagedata.len == 0: newSeq[Pixel](width * height) else: imagedata)
  assert width * height == result.imagedata.len

  result.width = width
  result.height = height
  if fill != EMPTYPIXEL:
    for y in 0 ..< height:
      for x in 0 ..< width:
        result[x, y] = fill

let INVALID_TEXTURE* = Texture(image: newImage(1, 1, @[[255'u8, 0'u8, 255'u8, 255'u8]]), sampler: Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
)
let EMPTY_TEXTURE* = Texture(image: newImage(1, 1, @[[255'u8, 255'u8, 255'u8, 255'u8]]), sampler: Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
)
