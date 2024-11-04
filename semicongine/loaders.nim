import std/json
import std/parsecfg
import std/strutils
import std/sequtils
import std/os
import std/streams

import ./audio
import ./background_loader
import ./core
import ./gltf
import ./image
import ./resources

proc loadBytes*(path, package: string): seq[byte] {.gcsafe.} =
  cast[seq[byte]](toSeq(path.loadResource_intern(package = package).readAll()))

proc loadJson*(path: string, package = DEFAULT_PACKAGE): JsonNode {.gcsafe.} =
  path.loadResource_intern(package = package).readAll().parseJson()

proc loadConfig*(path: string, package = DEFAULT_PACKAGE): Config {.gcsafe.} =
  path.loadResource_intern(package = package).loadConfig(filename = path)

proc loadImage*[T: PixelType](
    path: string, package = DEFAULT_PACKAGE
): Image[T] {.gcsafe.} =
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
): ImageArray[T] {.gcsafe.} =
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
  result =
    ImageArray[T](width: width, height: height, data: data, nLayers: paths.len.uint32)
  for path in paths[1 .. ^1]:
    let (w, h, data) =
      loadImageData[T](loadResource_intern(path, package = package).readAll())
    assert w == result.width,
      "New image layer has dimension {(w, y)} but image has dimension {(result.width, result.height)}"
    assert h == result.height,
      "New image layer has dimension {(w, y)} but image has dimension {(result.width, result.height)}"
    result.data.add data

proc loadImageArray*[T: PixelType](
    path: string, tilesize: uint32, package = DEFAULT_PACKAGE
): ImageArray[T] {.gcsafe.} =
  assert path.splitFile().ext.toLowerAscii == ".png",
    "Unsupported image type: " & path.splitFile().ext.toLowerAscii
  when T is Gray:
    let pngType = 0.cint
  elif T is BGRA:
    let pngType = 6.cint

  let (width, height, data) =
    loadImageData[T](loadResource_intern(path, package = package).readAll())
  let
    tilesX = width div tilesize
    tilesY = height div tilesize
  result = ImageArray[T](width: tilesize, height: tilesize)
  var tile = newSeq[T](tilesize * tilesize)
  for ty in 0 ..< tilesY:
    for tx in 0 ..< tilesY:
      var hasNonTransparent = when T is BGRA: false else: true
      let baseI = ty * tilesize * width + tx * tilesize
      for y in 0 ..< tilesize:
        for x in 0 ..< tilesize:
          tile[y * tilesize + x] = data[baseI + y * width + x]
          when T is BGRA:
            hasNonTransparent = hasNonTransparent or tile[y * tilesize + x].a > 0
      if hasNonTransparent:
        result.data.add tile
        result.nLayers.inc

proc loadAudio*(path: string, package = DEFAULT_PACKAGE): SoundData {.gcsafe.} =
  if path.splitFile().ext.toLowerAscii == ".au":
    loadResource_intern(path, package = package).readAU()
  elif path.splitFile().ext.toLowerAscii == ".ogg":
    loadResource_intern(path, package = package).readVorbis()
  else:
    raise newException(Exception, "Unsupported audio file type: " & path)

proc loadMeshes*[TMesh, TMaterial](
    path: string,
    meshAttributesMapping: static MeshAttributeNames,
    materialAttributesMapping: static MaterialAttributeNames,
    package = DEFAULT_PACKAGE,
): GltfData[TMesh, TMaterial] {.gcsafe.} =
  ReadglTF[TMesh, TMaterial](
    stream = loadResource_intern(path, package = package),
    meshAttributesMapping = meshAttributesMapping,
    materialAttributesMapping = materialAttributesMapping,
  )

# background loaders

type ResourceType =
  seq[byte] | JsonNode | Config | Image[Gray] | Image[BGRA] | SoundData

var rawLoader = initBackgroundLoader(loadBytes)
var jsonLoader = initBackgroundLoader(loadJson)
var configLoader = initBackgroundLoader(loadConfig)
var grayImageLoader = initBackgroundLoader(loadImage[Gray])
var imageLoader = initBackgroundLoader(loadImage[BGRA])
var audioLoader = initBackgroundLoader(loadAudio)

proc loadAsync*[T: ResourceType](path: string, package = DEFAULT_PACKAGE) =
  when T is seq[byte]:
    requestLoading(rawLoader[], path, package)
  elif T is JsonNode:
    requestLoading(jsonLoader[], path, package)
  elif T is Config:
    requestLoading(configLoader[], path, package)
  elif T is Image[Gray]:
    requestLoading(grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    requestLoading(imageLoader[], path, package)
  elif T is SoundData:
    requestLoading(audioLoader[], path, package)
  else:
    {.error: "Unknown type".}

proc isLoaded*[T: ResourceType](path: string, package = DEFAULT_PACKAGE): bool =
  when T is seq[byte]:
    isLoaded(rawLoader[], path, package)
  elif T is JsonNode:
    isLoaded(jsonLoader[], path, package)
  elif T is Config:
    isLoaded(configLoader[], path, package)
  elif T is Image[Gray]:
    isLoaded(grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    isLoaded(imageLoader[], path, package)
  elif T is SoundData:
    isLoaded(audioLoader[], path, package)
  else:
    {.error: "Unknown type".}

proc getLoaded*[T: ResourceType](path: string, package = DEFAULT_PACKAGE): T =
  when T is seq[byte]:
    getLoadedData(rawLoader[], path, package)
  elif T is JsonNode:
    getLoadedData(jsonLoader[], path, package)
  elif T is Config:
    getLoadedData(configLoader[], path, package)
  elif T is Image[Gray]:
    getLoadedData(grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    getLoadedData(imageLoader[], path, package)
  elif T is SoundData:
    getLoadedData(audioLoader[], path, package)
  else:
    {.error: "Unknown type".}
