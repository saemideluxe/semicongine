import ./api

type
  Buffer = object
    device: VkDevice
    vk: VkBuffer
    size: uint64

# currently no support for extended structure and concurrent/shared use
# (shardingMode = VK_SHARING_MODE_CONCURRENT not supported)
proc createBuffer(device: VkDevice, size: uint64, flags: openArray[VkBufferCreateFlagBits], usage: openArray[VkBufferUsageFlagBits]): Buffer =
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
    device=device,
    pCreateInfo=addr createInfo,
    pAllocator=nil,
    pBuffer=addr result.vk
  )

proc destroy(buffer: Buffer) =
  if uint(buffer.vk) != 0:
    vkDestroyBuffer(buffer.device, buffer.vk, nil)
