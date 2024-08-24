import std/os
import std/typetraits
import std/streams
import std/strutils

import ./core
import ./resources
import ./rendering/vulkan/api

{.emit: "#define STB_IMAGE_STATIC".}
{.emit: "#define STB_IMAGE_IMPLEMENTATION".}
{.
  emit: "#include \"" & currentSourcePath.parentDir() & "/thirdparty/stb/stb_image.h\""
.}

proc stbi_load_from_memory(
  buffer: ptr uint8,
  len: cint,
  x, y: ptr cint,
  channels_in_file: ptr cint,
  desired_channels: cint,
): ptr uint8 {.importc, nodecl.}

type
  Gray* = TVec1[uint8]
  BGRA* = TVec4[uint8]
  PixelType* = Gray | BGRA

  ImageObject*[T: PixelType, IsArray: static bool] = object
    width*: uint32
    height*: uint32
    minInterpolation*: VkFilter = VK_FILTER_LINEAR
    magInterpolation*: VkFilter = VK_FILTER_LINEAR
    wrapU*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    wrapV*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    data*: seq[T]
    vk*: VkImage
    imageview*: VkImageView
    sampler*: VkSampler
    isRenderTarget*: bool = false
    samples*: VkSampleCountFlagBits = VK_SAMPLE_COUNT_1_BIT
    when IsArray:
      nLayers*: uint32

  Image*[T: PixelType] = ImageObject[T, false]
  ImageArray*[T: PixelType] = ImageObject[T, true]

template nLayers*(image: Image): untyped =
  1'u32

proc `=copy`[S, T](dest: var ImageObject[S, T], source: ImageObject[S, T]) {.error.}

func `$`*[S, IsArray](img: ImageObject[S, IsArray]): string =
  let pixelTypeName = S.name
  if IsArray == false:
    &"{img.width}x{img.height} {pixelTypeName}"
  else:
    &"{img.width}x{img.height}[{img.nLayers}] {pixelTypeName}"

func copy*[S, T](img: ImageObject[S, T]): ImageObject[S, T] =
  for bf, rf in fields(img, result):
    rf = bf


# loads single layer image
proc loadImageData*[T: PixelType](
    pngData: string | seq[uint8]
): tuple[width: uint32, height: uint32, data: seq[T]] =
  when T is Gray:
    let nChannels = 1.cint
  elif T is BGRA:
    let nChannels = 4.cint

  var w, h, c: cint

  let data = stbi_load_from_memory(
    buffer = cast[ptr uint8](pngData.ToCPointer),
    len = pngData.len.cint,
    x = addr(w),
    y = addr(h),
    channels_in_file = addr(c),
    desired_channels = nChannels,
  )
  if data == nil:
    raise newException(Exception, "An error occured while loading PNG file")

  let imagesize = w * h * nChannels
  result = (width: w.uint32, height: h.uint32, data: newSeq[T](w * h))
  copyMem(result.data.ToCPointer, data, imagesize)
  nativeFree(data)

  when T is BGRA: # convert to BGRA
    for i in 0 ..< result.data.len:
      swap(result.data[i][0], result.data[i][2])

proc addImageLayer*[T: PixelType](
    image: var ImageArray[T], pngData: string | seq[uint8]
) =
  let (w, h, data) = loadImageData[T](pngData)

  assert w == image.width,
    "New image layer has dimension {(w, y)} but image has dimension {(image.width, image.height)}"
  assert h == image.height,
    "New image layer has dimension {(w, y)} but image has dimension {(image.width, image.height)}"

  inc image.nLayers
  image.data.add data

proc loadImage*[T: PixelType](path: string, package = DEFAULT_PACKAGE): Image[T] =
  assert path.splitFile().ext.toLowerAscii == ".png",
    "Unsupported image type: " & path.splitFile().ext.toLowerAscii
  when T is Gray:
    let pngType = 0.cint
  elif T is BGRA:
    let pngType = 6.cint

  let (width, height, data) =
    loadImageData[T](loadResource_intern(path, package = package).readAll())
  result = Image[T](width: width, height: height, data: data)

proc loadImageArray*[T: PixelType](
    paths: openArray[string], package = DEFAULT_PACKAGE
): ImageArray[T] =
  assert paths.len > 0, "Image array cannot contain 0 images"
  for path in paths:
    assert path.splitFile().ext.toLowerAscii == ".png",
      "Unsupported image type: " & path.splitFile().ext.toLowerAscii
  when T is Gray:
    let pngType = 0.cint
  elif T is BGRA:
    let pngType = 6.cint

  let (width, height, data) =
    loadImageData[T](loadResource_intern(paths[0], package = package).readAll())
  result = ImageArray[T](width: width, height: height, data: data, nLayers: 1)
  for path in paths[1 .. ^1]:
    result.addImageLayer(loadResource_intern(path, package = package).readAll())

proc `[]`*(image: Image, x, y: uint32): auto =
  assert x < image.width, &"{x} < {image.width} is not true"
  assert y < image.height, &"{y} < {image.height} is not true"

  image.data[y * image.width + x]

proc `[]=`*[T](image: var Image[T], x, y: uint32, value: T) =
  assert x < image.width
  assert y < image.height

  image.data[y * image.width + x] = value

proc `[]`*(image: ImageArray, layer, x, y: uint32): auto =
  assert layer < image.nLayers,
    &"Tried to access image layer {layer}, but image has only {image.nLayers} layers"
  assert x < image.width,
    &"Tried to access pixel coordinate {(x, y)} but image has size {(image.width, image.height)}"
  assert y < image.height,
    &"Tried to access pixel coordinate {(x, y)} but image has size {(image.width, image.height)}"

  image.data[layer * (image.width * image.height) + y * image.width + x]

proc `[]=`*[T](image: var ImageArray[T], layer, x, y: uint32, value: T) =
  assert layer < image.nLayers,
    &"Tried to access image layer {layer}, but image has only {image.nLayers} layers"
  assert x < image.width,
    &"Tried to access pixel coordinate {(x, y)} but image has size {(image.width, image.height)}"
  assert y < image.height,
    &"Tried to access pixel coordinate {(x, y)} but image has size {(image.width, image.height)}"

  image.data[layer * (image.width * image.height) + y * image.width + x] = value

# stb_image.h has no encoding support, maybe check stb_image_write or similar
#
# proc lodepng_encode_memory(out_data: ptr cstring, outsize: ptr csize_t, image: cstring, w: cuint, h: cuint, colorType: cint, bitdepth: cuint): cuint {.importc.}
#
#[
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
]#
