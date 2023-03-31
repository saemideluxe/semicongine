import std/typetraits

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
  MemoryProperty* = enum
    DeviceLocal = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
    HostVisible = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
    HostCoherent = VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
  MemoryProperties* = set[MemoryProperty]
  Buffer* = object
    device*: VkDevice
    vkBuffer*: VkBuffer
    size*: uint64
    memoryRequirements*: VkMemoryRequirements
    memoryProperties*: MemoryProperties
    memory*: VkDeviceMemory
    bufferTypes*: set[BufferType]
    data*: pointer

proc trash*(buffer: var Buffer) =
  if int64(buffer.vkBuffer) != 0 and int64(buffer.memory) != 0:
    vkUnmapMemory(buffer.device, buffer.memory)
  if int64(buffer.vkBuffer) != 0:
    vkDestroyBuffer(buffer.device, buffer.vkBuffer, nil)
    buffer.vkBuffer = VkBuffer(0)
  if int64(buffer.memory) != 0:
    vkFreeMemory(buffer.device, buffer.memory, nil)
    buffer.memory = VkDeviceMemory(0)

proc findMemoryType*(memoryRequirements: VkMemoryRequirements,
    physicalDevice: VkPhysicalDevice, properties: MemoryProperties): uint32 =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr(physicalProperties))

  for i in 0'u32 ..< physicalProperties.memoryTypeCount:
    if bool(memoryRequirements.memoryTypeBits and (1'u32 shl i)):
      if (uint32(physicalProperties.memoryTypes[i].propertyFlags) and cast[
          uint32](properties)) == cast[uint32](properties):
        return i

proc InitBuffer*(
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  size: uint64,
  bufferTypes: set[BufferType],
  properties: MemoryProperties,
): Buffer =
  result = Buffer(device: device, size: size, bufferTypes: bufferTypes, memoryProperties: properties)
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

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: result.memoryRequirements.size,
    memoryTypeIndex: result.memoryRequirements.findMemoryType(physicalDevice, properties)
  )
  if result.size > 0:
    checkVkResult result.device.vkAllocateMemory(addr(allocInfo), nil, addr(result.memory))
  checkVkResult result.device.vkBindBufferMemory(result.vkBuffer, result.memory, VkDeviceSize(0))
  checkVkResult vkMapMemory(
    result.device,
    result.memory,
    offset = VkDeviceSize(0),
    VkDeviceSize(result.size),
    VkMemoryMapFlags(0),
    addr(result.data)
  )


proc transferBuffer*(commandPool: VkCommandPool, queue: VkQueue, src, dst: Buffer, size: uint64) =
  assert uint64(src.device) == uint64(dst.device)
  assert TransferSrc in src.bufferTypes
  assert TransferDst in dst.bufferTypes
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

