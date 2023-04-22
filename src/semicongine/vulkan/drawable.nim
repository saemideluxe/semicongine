import std/tables
import std/strformat
import std/logging

import ./api
import ./utils
import ./buffer

import ../gpu_data

type
  Drawable* = object
    elementCount*: uint32 # number of vertices or indices
    bufferOffsets*: seq[(MemoryLocation, uint64)] # list of buffers and list of offset for each attribute in that buffer
    instanceCount*: uint32 # number of instance
    case indexed*: bool
    of true:
      indexType*: VkIndexType
      indexBufferOffset*: uint64
    of false:
      discard

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets}, indexType: {drawable.indexType}, indexBufferOffset: {drawable.indexBufferOffset})"
  else:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets})"

proc draw*(commandBuffer: VkCommandBuffer, drawable: Drawable, vertexBuffers: Table[MemoryLocation, Buffer], indexBuffer: BUffer) =
    debug "Draw ", drawable

    var buffers: seq[VkBuffer]
    var offsets: seq[VkDeviceSize]

    for (location, offset) in drawable.bufferOffsets:
      buffers.add vertexBuffers[location].vk
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
        indexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstIndex=0,
        vertexOffset=0,
        firstInstance=0
      )
    else:
      commandBuffer.vkCmdDraw(
        vertexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstVertex=0,
        firstInstance=0
      )
