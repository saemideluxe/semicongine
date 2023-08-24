import std/tables
import std/strformat
import std/logging

import ../core
import ./buffer

type
  Drawable* = object
    elementCount*: int # number of vertices or indices
    bufferOffsets*: Table[VkPipeline, seq[(string, MemoryPerformanceHint, int)]] # list of buffers and list of offset for each attribute in that buffer
    instanceCount*: int # number of instance
    case indexed*: bool
    of true:
      indexType*: VkIndexType
      indexBufferOffset*: int
    of false:
      discard

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets}, indexType: {drawable.indexType}, indexBufferOffset: {drawable.indexBufferOffset})"
  else:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets})"

proc draw*(drawable: Drawable, commandBuffer: VkCommandBuffer, vertexBuffers: Table[MemoryPerformanceHint, Buffer], indexBuffer: Buffer, pipeline: VkPipeline) =
    debug "Draw ", drawable

    var buffers: seq[VkBuffer]
    var offsets: seq[VkDeviceSize]

    for (name, performanceHint, offset) in drawable.bufferOffsets[pipeline]:
      buffers.add vertexBuffers[performanceHint].vk
      offsets.add VkDeviceSize(offset)

    commandBuffer.vkCmdBindVertexBuffers(
      firstBinding=0'u32,
      bindingCount=uint32(buffers.len),
      pBuffers=buffers.toCPointer(),
      pOffsets=offsets.toCPointer()
    )
    if drawable.indexed:
      commandBuffer.vkCmdBindIndexBuffer(indexBuffer.vk, VkDeviceSize(drawable.indexBufferOffset), drawable.indexType)
      commandBuffer.vkCmdDrawIndexed(
        indexCount=uint32(drawable.elementCount),
        instanceCount=uint32(drawable.instanceCount),
        firstIndex=0,
        vertexOffset=0,
        firstInstance=0
      )
    else:
      commandBuffer.vkCmdDraw(
        vertexCount=uint32(drawable.elementCount),
        instanceCount=uint32(drawable.instanceCount),
        firstVertex=0,
        firstInstance=0
      )
