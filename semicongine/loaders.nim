import std/json
import std/strutils
import std/sequtils
import std/os
import std/streams

import ./audio
import ./background_loaders
import ./core
import ./gltf
import ./images
import ./resources
import ./thirdparty/parsetoml

# necessary, so we don't need to import parsetoml extra when using this module
export parsetoml

proc loadBytes*(path, package: string): seq[byte] {.gcsafe.} =
  cast[seq[byte]](toSeq(path.loadResource_intern(package = package).readAll()))

proc loadJson*(path: string, package = DEFAULT_PACKAGE): JsonNode {.gcsafe.} =
  path.loadResource_intern(package = package).readAll().parseJson()

proc loadConfig*(path: string, package = DEFAULT_PACKAGE): TomlValueRef {.gcsafe.} =
  path.loadResource_intern(package = package).parseStream(filename = path)

# background loaders

type ResourceType =
  seq[byte] | JsonNode | TomlValueRef | Image[Gray] | Image[BGRA] | SoundData

proc loadAsync*[T: ResourceType](path: string, package = DEFAULT_PACKAGE) =
  when T is seq[byte]:
    requestLoading(engine().rawLoader[], path, package)
  elif T is JsonNode:
    requestLoading(engine().jsonLoader[], path, package)
  elif T is TomlValueRef:
    requestLoading(engine().configLoader[], path, package)
  elif T is Image[Gray]:
    requestLoading(engine().grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    requestLoading(engine().imageLoader[], path, package)
  elif T is SoundData:
    requestLoading(engine().audioLoader[], path, package)
  else:
    {.error: "Unknown type".}

proc isLoaded*[T: ResourceType](path: string, package = DEFAULT_PACKAGE): bool =
  when T is seq[byte]:
    isLoaded(engine().rawLoader[], path, package)
  elif T is JsonNode:
    isLoaded(engine().jsonLoader[], path, package)
  elif T is TomlValueRef:
    isLoaded(engine().configLoader[], path, package)
  elif T is Image[Gray]:
    isLoaded(engine().grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    isLoaded(engine().imageLoader[], path, package)
  elif T is SoundData:
    isLoaded(engine().audioLoader[], path, package)
  else:
    {.error: "Unknown type".}

proc getLoaded*[T: ResourceType](path: string, package = DEFAULT_PACKAGE): T =
  when T is seq[byte]:
    getLoadedData(engine().rawLoader[], path, package)
  elif T is JsonNode:
    getLoadedData(engine().jsonLoader[], path, package)
  elif T is TomlValueRef:
    getLoadedData(engine().configLoader[], path, package)
  elif T is Image[Gray]:
    getLoadedData(engine().grayImageLoader[], path, package)
  elif T is Image[BGRA]:
    getLoadedData(engine().imageLoader[], path, package)
  elif T is SoundData:
    getLoadedData(engine().audioLoader[], path, package)
  else:
    {.error: "Unknown type".}
