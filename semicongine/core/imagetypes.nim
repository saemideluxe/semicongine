import std/strformat

import ./vulkanapi
import ./vector

type
  RGBAPixel* = array[4, uint8]
  GrayPixel* = uint8
  Pixel* = RGBAPixel or GrayPixel
  ImageObject*[T: Pixel] = object
    width*: int
    height*: int
    imagedata*: seq[T]
  Image*[T: Pixel] = ref ImageObject[T]

  Sampler* = object
    magnification*: VkFilter = VK_FILTER_LINEAR
    minification*: VkFilter = VK_FILTER_LINEAR
    wrapModeS*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    wrapModeT*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
  Texture* = object
    name*: string
    case isGrayscale*: bool = false
    of false: colorImage*: Image[RGBAPixel]
    of true: grayImage*: Image[GrayPixel]
    sampler*: Sampler

proc `==`*(a, b: Texture): bool =
  if a.isGrayscale != b.isGrayscale or a.name != b.name or a.sampler != b.sampler:
    return false
  elif a.isGrayscale:
    return a.grayImage == b.grayImage
  else:
    return a.colorImage == b.colorImage

converter toRGBA*(p: RGBAPixel): Vec4f =
  newVec4f(float32(p[0]) / 255'f32, float32(p[1]) / 255'f32, float32(p[2]) / 255'f32, float32(p[3]) / 255'f32)
converter toGrayscale*(p: GrayPixel): float32 =
  float32(p) / 255'f32

proc `$`*(image: Image): string =
  &"{image.width}x{image.height}"

proc `$`*(texture: Texture): string =
  if texture.isGrayscale:
    &"{texture.name} {texture.grayImage} (gray)"
  else:
    &"{texture.name} {texture.colorImage} (color)"

proc `[]`*(image: Image, x, y: int): Pixel =
  assert x < image.width, &"{x} < {image.width} is not true"
  assert y < image.height, &"{y} < {image.height} is not true"

  image[].imagedata[y * image.width + x]

proc `[]=`*(image: var Image, x, y: int, value: Pixel) =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x] = value

proc newImage*[T: Pixel](width, height: int, imagedata: openArray[T]= []): Image[T] =
  assert width > 0 and height > 0
  assert imagedata.len == width * height or imagedata.len == 0

  result = new Image[T]
  result.imagedata = (if imagedata.len == 0: newSeq[T](width * height) else: @imagedata)
  assert width * height == result.imagedata.len

  result.width = width
  result.height = height

let INVALID_TEXTURE* = Texture(name: "Invalid texture", isGrayscale: false, colorImage: newImage(1, 1, @[[255'u8, 0'u8, 255'u8, 255'u8]]), sampler: Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
)
let EMPTY_TEXTURE* = Texture(name: "Empty texture", isGrayscale: false, colorImage: newImage(1, 1, @[[255'u8, 255'u8, 255'u8, 255'u8]]), sampler: Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
)
