import std/options

import ./vulkan/api
import ./entity
import ./vulkan/buffer

type
  Drawable* = object
    buffers*: seq[Buffer]
    elementCount*: uint32
    instanceCount*: uint32
    case indexed*: bool
    of true:
      indexBuffer*: Buffer
      indexType*: VkIndexType
    of false:
      discard

  Scene* = object
    root*: Entity
    drawables: seq[Drawable]

proc getDrawables*(scene: Scene): seq[Drawable] =
  # TODO: create and fill buffers
  result
