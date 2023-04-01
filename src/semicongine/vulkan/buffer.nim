import std/strformat
import std/typetraits
import std/sequtils
import std/tables

import ./api
import ./device
import ./memory
import ./physicaldevice
import ./commandbuffer

type
  Buffer* = object
    device*: Device
    vk*: VkBuffer
    size*: uint64
    usage*: seq[VkBufferUsageFlagBits]
    case hasMemory*: bool
      of false: discard
      of true:
        memory*: DeviceMemory
        data*: pointer

func `$`*(buffer: Buffer): string = &"Buffer(size: {buffer.size}, usage: {buffer.usage})"

proc setData*(dst: Buffer, src: pointer, len: uint64, offset=0'u64) =
  assert offset + len <= dst.size
  copyMem(cast[pointer](cast[uint64](dst.data) + offset), src, len)

proc setData*[T: seq](dst: Buffer, src: ptr T, offset=0'u64) =
  dst.setData(src, sizeof(get(genericParams(T), 0)) * src[].len, offset=offset)

proc setData*[T](dst: Buffer, src: ptr T, offset=0'u64) =
  dst.setData(src, sizeof(T), offset=offset)

proc allocateMemory(buffer: var Buffer, flags: openArray[VkMemoryPropertyFlagBits]) =
  assert buffer.device.vk.valid
  assert buffer.hasMemory == false

  buffer.hasMemory = true
  buffer.memory = buffer.device.allocate(buffer.size, flags)
  checkVkResult buffer.device.vk.vkBindBufferMemory(buffer.vk, buffer.memory.vk, VkDeviceSize(0))
  buffer.data = buffer.memory.map()

# currently no support for extended structure and concurrent/shared use
# (shardingMode = VK_SHARING_MODE_CONCURRENT not supported)
proc createBuffer*(
  device: Device,
  size: uint64,
  usage: openArray[VkBufferUsageFlagBits],
  flags: openArray[VkBufferCreateFlagBits] = @[],
  memoryFlags: openArray[VkMemoryPropertyFlagBits] = @[],
): Buffer =
  assert device.vk.valid
  assert size > 0

  result.device = device
  result.size = size
  result.usage = usage.toSeq
  var createInfo = VkBufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    flags: toBits(flags),
    size: size,
    usage: toBits(usage),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
  )

  checkVkResult vkCreateBuffer(
    device=device.vk,
    pCreateInfo=addr createInfo,
    pAllocator=nil,
    pBuffer=addr result.vk
  )
  result.allocateMemory(memoryFlags)


proc copy*(src, dst: Buffer) =
  assert src.device.vk.valid
  assert dst.device.vk.valid
  assert src.device == dst.device
  assert src.size == dst.size
  assert VK_BUFFER_USAGE_TRANSFER_SRC_BIT in src.usage
  assert VK_BUFFER_USAGE_TRANSFER_DST_BIT in dst.usage

  var queue: Queue
  for q in src.device.queues.values:
    if q.family.canDoTransfer:
      queue = q
  if not queue.vk.valid:
    raise newException(Exception, "No queue that supports buffer transfer")

  var
    commandBufferPool = src.device.createCommandBufferPool(family=queue.family, nBuffers=1)
    commandBuffer = commandBufferPool.buffers[0]

    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
    )
    copyRegion = VkBufferCopy(size: VkDeviceSize(src.size))
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))
  commandBuffer.vkCmdCopyBuffer(src.vk, dst.vk, 1, addr(copyRegion))
  checkVkResult commandBuffer.vkEndCommandBuffer()

  var submitInfo = VkSubmitInfo(
    sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
    commandBufferCount: 1,
    pCommandBuffers: addr(commandBuffer),
  )
  checkVkResult queue.vk.vkQueueSubmit(1, addr(submitInfo), VkFence(0))
  checkVkResult queue.vk.vkQueueWaitIdle()
  commandBufferPool.destroy()

proc destroy*(buffer: var Buffer) =
  assert buffer.device.vk.valid
  assert buffer.vk.valid
  if buffer.hasMemory:
    assert buffer.memory.vk.valid
    buffer.memory.free
  buffer.device.vk.vkDestroyBuffer(buffer.vk, nil)
  buffer.vk.reset()
