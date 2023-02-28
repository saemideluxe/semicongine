import ./api
import ./device

type
  Buffer = object
    device: Device
    vk: VkBuffer
    size: uint64

# currently no support for extended structure and concurrent/shared use
# (shardingMode = VK_SHARING_MODE_CONCURRENT not supported)
proc createBuffer(device: Device, size: uint64, flags: openArray[VkBufferCreateFlagBits], usage: openArray[VkBufferUsageFlagBits]): Buffer =
  result.device = device
  result.size = size
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

proc destroy(buffer: Buffer) =
  assert buffer.device.vk.valid
  assert buffer.vk.valid
  buffer.device.vk.vkDestroyBuffer(buffer.vk, nil)
