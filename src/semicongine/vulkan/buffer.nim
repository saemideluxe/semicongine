import std/strformat
import std/typetraits
import std/sequtils
import std/tables
import std/logging

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
    case memoryAllocated*: bool
      of false: discard
      of true:
        memory*: DeviceMemory
  MemoryRequirements = object
    size: uint64
    alignment: uint64
    memoryTypes: seq[MemoryType]


proc `==`*(a, b: Buffer): bool =
  a.vk == b.vk

func `$`*(buffer: Buffer): string =
  &"Buffer(vk: {buffer.vk}, size: {buffer.size}, usage: {buffer.usage})"

proc requirements(buffer: Buffer): MemoryRequirements =
  assert buffer.vk.valid
  assert buffer.device.vk.valid
  var req: VkMemoryRequirements
  buffer.device.vk.vkGetBufferMemoryRequirements(buffer.vk, addr req)
  result.size = req.size
  result.alignment = req.alignment
  let memorytypes = buffer.device.physicaldevice.vk.getMemoryProperties().types
  for i in 0 ..< sizeof(req.memoryTypeBits) * 8:
    if ((req.memoryTypeBits shr i) and 1) == 1:
      result.memoryTypes.add memorytypes[i]

proc allocateMemory(buffer: var Buffer, requireMappable: bool, preferVRAM: bool, preferAutoFlush: bool) =
  assert buffer.device.vk.valid
  assert buffer.memoryAllocated == false

  let requirements = buffer.requirements()
  let memoryType = requirements.memoryTypes.selectBestMemoryType(
    requireMappable=requireMappable,
    preferVRAM=preferVRAM,
    preferAutoFlush=preferAutoFlush
  )
  buffer.memoryAllocated = true
  debug "Allocating memory for buffer: ", buffer.size, " bytes of type ", memoryType
  buffer.memory = buffer.device.allocate(requirements.size, memoryType)
  checkVkResult buffer.device.vk.vkBindBufferMemory(buffer.vk, buffer.memory.vk, VkDeviceSize(0))

# currently no support for extended structure and concurrent/shared use
# (shardingMode = VK_SHARING_MODE_CONCURRENT not supported)
proc createBuffer*(
  device: Device,
  size: uint64,
  usage: openArray[VkBufferUsageFlagBits],
  requireMappable: bool,
  preferVRAM: bool,
  preferAutoFlush=true,
): Buffer =
  assert device.vk.valid
  assert size > 0

  result.device = device
  result.size = size
  result.usage = usage.toSeq
  if not requireMappable:
    result.usage.add VK_BUFFER_USAGE_TRANSFER_DST_BIT
  var createInfo = VkBufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    flags: VkBufferCreateFlags(0),
    size: size,
    usage: toBits(result.usage),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
  )

  checkVkResult vkCreateBuffer(
    device=device.vk,
    pCreateInfo=addr createInfo,
    pAllocator=nil,
    pBuffer=addr result.vk
  )
  result.allocateMemory(requireMappable=requireMappable, preferVRAM=preferVRAM, preferAutoFlush=preferAutoFlush)
  echo "New Buffer ", result


proc copy*(src, dst: Buffer) =
  assert src.device.vk.valid
  assert dst.device.vk.valid
  assert src.device == dst.device
  assert src.size < dst.size
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
  echo "B ", dst
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
  if buffer.memoryAllocated:
    assert buffer.memory.vk.valid
    buffer.memory.free
  buffer.device.vk.vkDestroyBuffer(buffer.vk, nil)
  buffer.vk.reset

proc setData*(dst: Buffer, src: pointer, size: uint64, bufferOffset=0'u64) =
  assert bufferOffset + size <= dst.size
  if dst.memory.canMap:
    copyMem(cast[pointer](cast[uint64](dst.memory.data) + bufferOffset), src, size)
    if dst.memory.needsFlushing:
      dst.memory.flush()
  else: # use staging buffer, slower but required if memory is not host visible
    var stagingBuffer = dst.device.createBuffer(size, [VK_BUFFER_USAGE_TRANSFER_SRC_BIT], requireMappable=true, preferVRAM=false, preferAutoFlush=true)
    stagingBuffer.setData(src, size, 0)
    echo "B ", dst
    stagingBuffer.copy(dst)
    stagingBuffer.destroy()

proc setData*[T: seq](dst: Buffer, src: ptr T, offset=0'u64) =
  dst.setData(src, sizeof(get(genericParams(T), 0)) * src[].len, offset=offset)

proc setData*[T](dst: Buffer, src: ptr T, offset=0'u64) =
  dst.setData(src, sizeof(T), offset=offset)

