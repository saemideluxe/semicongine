import std/math
import std/strformat

import ./vulkanapi
import ./vector
import ./color

type
  RGBAPixel* = array[4, uint8]
  GrayPixel* = uint8
  Pixel* = RGBAPixel or GrayPixel
  ImageObject*[T: Pixel] = object
    width*: uint32
    height*: uint32
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

# colorspace conversion functions

func linear2srgb*(value: RGBAPixel): RGBAPixel =
  [linear2srgb(value[0]), linear2srgb(value[1]), linear2srgb(value[2]), value[3]]
func srgb2linear*(value: RGBAPixel): RGBAPixel =
  [srgb2linear(value[0]), srgb2linear(value[1]), srgb2linear(value[2]), value[3]]

proc asSRGB*[T](image: Image[T]): Image[T] =
  result = Image[T](width: image.width, height: image.height, imagedata: newSeq[T](image.imagedata.len))
  for i in 0 .. image.imagedata.len:
    result.imagedata[i] = linear2srgb(image.imagedata[i])

proc asLinear*[T](image: Image[T]): Image[T] =
  result = Image[T](width: image.width, height: image.height, imagedata: newSeq[T](image.imagedata.len))
  for i in 0 ..< image.imagedata.len:
    result.imagedata[i] = srgb2linear(image.imagedata[i])

proc `$`*(image: Image): string =
  &"{image.width}x{image.height}"

proc `$`*(texture: Texture): string =
  if texture.isGrayscale:
    &"{texture.name} {texture.grayImage} (gray)"
  else:
    &"{texture.name} {texture.colorImage} (color)"

proc `[]`*(image: Image, x, y: uint32): Pixel =
  assert x < image.width, &"{x} < {image.width} is not true"
  assert y < image.height, &"{y} < {image.height} is not true"

  image[].imagedata[y * image.width + x]

proc `[]=`*(image: var Image, x, y: uint32, value: Pixel) =
  assert x < image.width
  assert y < image.height

  image[].imagedata[y * image.width + x] = value

proc newImage*[T: Pixel](width, height: uint32, imagedata: openArray[T] = []): Image[T] =
  assert width > 0 and height > 0
  assert imagedata.len.uint32 == width * height or imagedata.len == 0

  result = new Image[T]
  result.imagedata = (if imagedata.len == 0: newSeq[T](width * height) else: @imagedata)
  assert width * height == result.imagedata.len.uint32

  result.width = width
  result.height = height

const
  LINEAR_SAMPLER* = Sampler(
    magnification: VK_FILTER_LINEAR,
    minification: VK_FILTER_LINEAR,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
  NEAREST_SAMPLER* = Sampler(
    magnification: VK_FILTER_NEAREST,
    minification: VK_FILTER_NEAREST,
    wrapModeS: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    wrapModeT: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  )
let
  INVALID_TEXTURE* = Texture(name: "Invalid texture", isGrayscale: false, colorImage: newImage(1, 1, @[[255'u8, 0'u8, 255'u8, 255'u8]]), sampler: NEAREST_SAMPLER)
  EMPTY_TEXTURE* = Texture(name: "Empty texture", isGrayscale: false, colorImage: newImage(1, 1, @[[255'u8, 255'u8, 255'u8, 255'u8]]), sampler: NEAREST_SAMPLER)
