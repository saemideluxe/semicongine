import std/tables

import ./vulkan/api
import ./entity
import ./vulkan/buffer
import ./vulkan/pipeline
import ./vulkan/renderpass

type
  Drawable* = object
    buffers*: seq[(Buffer, int)] # buffer + offset from buffer
    elementCount*: uint32 # vertices or indices
    instanceCount*: uint32
    case indexed*: bool
    of true:
      indexBuffer*: Buffer
      indexType*: VkIndexType
    of false:
      discard

  Scene* = object
    root*: Entity
    drawables: Table[VkPipeline, seq[Drawable]]

proc setupDrawables(scene: var Scene, pipeline: Pipeline) =
  # echo pipeline.descriptorSetLayout.descriptors
  # thetype*: VkDescriptorType
  # count*: uint32
  # itemsize*: uint32
  scene.drawables[pipeline.vk] = @[]

proc setupDrawables*(scene: var Scene, renderPass: var RenderPass) =
  for subpass in renderPass.subpasses.mitems:
    for pipeline in subpass.pipelines.mitems:
      scene.setupDrawables(pipeline)


proc getDrawables*(scene: Scene, pipeline: Pipeline): seq[Drawable] =
  scene.drawables.getOrDefault(pipeline.vk, @[])
