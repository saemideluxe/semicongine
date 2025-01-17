import std/os
import std/typetraits
import std/strformat

import ./core

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

func `$`*[S, IsArray](img: ImageObject[S, IsArray]): string =
  let pixelTypeName = S.name
  if IsArray == false:
    $img.width & "x" & $img.height & " " & pixelTypeName
  else:
    $img.width & "x" & $img.height & "[" & $img.nLayers & "] " & pixelTypeName

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

# TODO: static versions to check for existing of files during compilation
proc addImage*[T: PixelType](imageArray: var ImageArray[T], image: sink Image[T]) =
  assert image.width == imageArray.width,
    &"Image needs to have same dimension as ImageArray to be added (array has {imageArray.width}x{imageArray.height} but image has {image.width}x{image.height})"
  assert image.height == imageArray.height,
    &"Image needs to have same dimension as ImageArray to be added (array has {imageArray.width}x{imageArray.height} but image has {image.width}x{image.height})"

  inc imageArray.nLayers
  imageArray.data.add image.data

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
