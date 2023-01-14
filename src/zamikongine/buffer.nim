import ./vulkan
import ./vulkan_helpers

type
  BufferType* = enum
    None = 0
    TransferSrc = VK_BUFFER_USAGE_TRANSFER_SRC_BIT
    TransferDst = VK_BUFFER_USAGE_TRANSFER_DST_BIT
    UniformBuffer = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT
    IndexBuffer = VK_BUFFER_USAGE_INDEX_BUFFER_BIT
    VertexBuffer = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
  Buffer* = object
    device*: VkDevice
    vkBuffer*: VkBuffer
    size*: uint64
    memoryRequirements*: VkMemoryRequirements
    memory*: VkDeviceMemory
    bufferTypes*: set[BufferType]
    persistentMapping: bool
    mapped: pointer

proc trash*(buffer: var Buffer) =
  assert int64(buffer.vkBuffer) != 0
  assert int64(buffer.memory) != 0
  vkDestroyBuffer(buffer.device, buffer.vkBuffer, nil)
  buffer.vkBuffer = VkBuffer(0)
  vkFreeMemory(buffer.device, buffer.memory, nil)
  buffer.memory = VkDeviceMemory(0)

proc findMemoryType(buffer: Buffer, physicalDevice: VkPhysicalDevice, properties: VkMemoryPropertyFlags): uint32 =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr(physicalProperties))

  for i in 0'u32 ..< physicalProperties.memoryTypeCount:
    if bool(buffer.memoryRequirements.memoryTypeBits and (1'u32 shl i)) and (uint32(physicalProperties.memoryTypes[i].propertyFlags) and uint32(properties)) == uint32(properties):
        return i

proc InitBuffer*(
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  size: uint64,
  bufferTypes: set[BufferType],
  properties: set[VkMemoryPropertyFlagBits],
  persistentMapping: bool = false
): Buffer =
  result = Buffer(device: device, size: size, bufferTypes: bufferTypes, persistentMapping: persistentMapping)
  var usageFlags = 0
  for usage in bufferTypes:
    usageFlags = ord(usageFlags) or ord(usage)
  var bufferInfo = VkBufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    size: VkDeviceSize(result.size),
    usage: VkBufferUsageFlags(usageFlags),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
  )
  checkVkResult vkCreateBuffer(result.device, addr(bufferInfo), nil, addr(result.vkBuffer))
  vkGetBufferMemoryRequirements(result.device, result.vkBuffer, addr(result.memoryRequirements))

  var memoryProperties = 0'u32
  for prop in properties:
    memoryProperties = memoryProperties or uint32(prop)

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: result.memoryRequirements.size,
    memoryTypeIndex: result.findMemoryType(physicalDevice, VkMemoryPropertyFlags(memoryProperties))
  )
  checkVkResult result.device.vkAllocateMemory(addr(allocInfo), nil, addr(result.memory))
  checkVkResult result.device.vkBindBufferMemory(result.vkBuffer, result.memory, VkDeviceSize(0))
  if persistentMapping:
    checkVkResult vkMapMemory(
      result.device,
      result.memory,
      offset=VkDeviceSize(0),
      VkDeviceSize(result.size),
      VkMemoryMapFlags(0),
      addr(result.mapped)
    )


template withMapping*(buffer: Buffer, data: pointer, body: untyped): untyped =
  assert not buffer.persistentMapping
  checkVkResult vkMapMemory(buffer.device, buffer.memory, offset=VkDeviceSize(0), VkDeviceSize(buffer.size), VkMemoryMapFlags(0), addr(data))
  body
  vkUnmapMemory(buffer.device, buffer.memory)

# note: does not work with seq
proc updateData*[T](buffer: Buffer, data: var T) =
  if buffer.persistentMapping:
    copyMem(buffer.mapped, addr(data), sizeof(T))
  else:
    var p: pointer
    buffer.withMapping(p):
      copyMem(p, addr(data), sizeof(T))

proc copyBuffer*(commandPool: VkCommandPool, queue: VkQueue, src, dst: Buffer, size: uint64) =
  assert uint64(src.device) == uint64(dst.device)
  var
    allocInfo = VkCommandBufferAllocateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      commandPool: commandPool,
      commandBufferCount: 1,
    )
    commandBuffer: VkCommandBuffer
  checkVkResult vkAllocateCommandBuffers(src.device, addr(allocInfo), addr(commandBuffer))

  var beginInfo = VkCommandBufferBeginInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
  )
  checkVkResult vkBeginCommandBuffer(commandBuffer, addr(beginInfo))
  var copyRegion = VkBufferCopy(size: VkDeviceSize(size))
  vkCmdCopyBuffer(commandBuffer, src.vkBuffer, dst.vkBuffer, 1, addr(copyRegion))
  checkVkResult vkEndCommandBuffer(commandBuffer)

  var submitInfo = VkSubmitInfo(
    sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
    commandBufferCount: 1,
    pCommandBuffers: addr(commandBuffer),
  )

  checkVkResult vkQueueSubmit(queue, 1, addr(submitInfo), VkFence(0))
  checkVkResult vkQueueWaitIdle(queue)
  vkFreeCommandBuffers(src.device, commandPool, 1, addr(commandBuffer))
