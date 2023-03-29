import std/options

import ./vulkan/api
import ./entity
import ./vulkan/buffer

type
  Scene* = object
    root*: Entity

# attribute_buffers, number_of_vertices, number_of_instances, (indexbuffer, indextype)
proc getBufferSets*(scene: Scene): seq[(seq[Buffer], uint32, uint32, Option[(Buffer, VkIndexType)])] =
  result
