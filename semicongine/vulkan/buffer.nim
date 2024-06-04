import std/strformat
import std/typetraits
import std/sequtils
import std/tables
import std/logging

import ../core
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
  let memorytypes = buffer.device.physicaldevice.vk.GetMemoryProperties().types
  for i in 0 ..< sizeof(req.memoryTypeBits) * 8:
    if ((req.memoryTypeBits shr i) and 1) == 1:
      result.memoryTypes.add memorytypes[i]

proc allocateMemory(buffer: var Buffer, requireMappable: bool, preferVRAM: bool, preferAutoFlush: bool) =
  assert buffer.device.vk.valid
  assert buffer.memoryAllocated == false

  let requirements = buffer.requirements()
  let memoryType = requirements.memoryTypes.SelectBestMemoryType(
    requireMappable = requireMappable,
    preferVRAM = preferVRAM,
    preferAutoFlush = preferAutoFlush
  )

  debug "Allocating memory for buffer: ", buffer.size, " bytes of type ", memoryType
  # need to replace the whole buffer object, due to case statement
  buffer = Buffer(
    device: buffer.device,
    vk: buffer.vk,
    size: buffer.size,
    usage: buffer.usage,
    memoryAllocated: true,
    memory: buffer.device.Allocate(requirements.size, memoryType)
  )
  checkVkResult buffer.device.vk.vkBindBufferMemory(buffer.vk, buffer.memory.vk, VkDeviceSize(0))

# currently no support for extended structure and concurrent/shared use
# (shardingMode = VK_SHARING_MODE_CONCURRENT not supported)
proc CreateBuffer*(
  device: Device,
  size: uint64,
  usage: openArray[VkBufferUsageFlagBits],
  requireMappable: bool,
  preferVRAM: bool,
  preferAutoFlush = true,
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
    device = device.vk,
    pCreateInfo = addr createInfo,
    pAllocator = nil,
    pBuffer = addr result.vk
  )
  result.allocateMemory(requireMappable = requireMappable, preferVRAM = preferVRAM, preferAutoFlush = preferAutoFlush)


proc Copy*(src, dst: Buffer, queue: Queue, dstOffset = 0'u64) =
  assert src.device.vk.valid
  assert dst.device.vk.valid
  assert src.device == dst.device
  assert src.size + dstOffset <= dst.size
  assert VK_BUFFER_USAGE_TRANSFER_SRC_BIT in src.usage
  assert VK_BUFFER_USAGE_TRANSFER_DST_BIT in dst.usage

  var copyRegion = VkBufferCopy(size: VkDeviceSize(src.size), dstOffset: VkDeviceSize(dstOffset))
  WithSingleUseCommandBuffer(src.device, queue, commandBuffer):
    commandBuffer.vkCmdCopyBuffer(src.vk, dst.vk, 1, addr(copyRegion))

proc Destroy*(buffer: var Buffer) =
  assert buffer.device.vk.valid
  assert buffer.vk.valid
  buffer.device.vk.vkDestroyBuffer(buffer.vk, nil)
  if buffer.memoryAllocated:
    assert buffer.memory.vk.valid
    buffer.memory.Free()
    buffer = Buffer(
      device: buffer.device,
      vk: buffer.vk,
      size: buffer.size,
      usage: buffer.usage,
      memoryAllocated: false,
    )
  buffer.vk.reset

template CanMap*(buffer: Buffer): bool =
  buffer.memory.canMap

proc SetData*(dst: Buffer, queue: Queue, src: pointer, size: uint64, bufferOffset = 0'u64) =
  assert bufferOffset + size <= dst.size
  if dst.CanMap:
    copyMem(cast[pointer](cast[uint](dst.memory.data) + bufferOffset), src, size)
    if dst.memory.needsFlushing:
      dst.memory.Flush()
  else: # use staging buffer, slower but required if memory is not host visible
    var stagingBuffer = dst.device.CreateBuffer(size, [VK_BUFFER_USAGE_TRANSFER_SRC_BIT], requireMappable = true, preferVRAM = false, preferAutoFlush = true)
    SetData(stagingBuffer, queue, src, size, 0)
    stagingBuffer.Copy(dst, queue, bufferOffset)
    stagingBuffer.Destroy()

proc SetData*[T: seq](dst: Buffer, queue: Queue, src: ptr T, offset = 0'u64) =
  dst.setData(queue, src, sizeof(get(genericParams(T), 0)) * src[].len, offset = offset)

proc SetData*[T](dst: Buffer, queue: Queue, src: ptr T, offset = 0'u64) =
  dst.setData(queue, src, sizeof(T), offset = offset)

