import ./vulkan
import ./vulkan_helpers

type
  BufferType* = enum
    VertexBuffer = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
  Buffer* = object
    device*: VkDevice
    vkBuffer*: VkBuffer
    size*: uint64
    memoryRequirements*: VkMemoryRequirements
    memory*: VkDeviceMemory

proc findMemoryType(buffer: Buffer, physicalDevice: VkPhysicalDevice, properties: VkMemoryPropertyFlags): uint32 =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr(physicalProperties))

  for i in 0'u32 ..< physicalProperties.memoryTypeCount:
    if bool(buffer.memoryRequirements.memoryTypeBits and (1'u32 shl i)) and (uint32(physicalProperties.memoryTypes[i].propertyFlags) and uint32(properties)) == uint32(properties):
        return i

proc InitBuffer*(device: VkDevice, physicalDevice: VkPhysicalDevice, size: uint64, bufferType: BufferType): Buffer =
  result.device = device
  result.size = size
  var bufferInfo = VkBufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    size: VkDeviceSize(result.size),
    usage: VkBufferUsageFlags(bufferType),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,

  )
  checkVkResult vkCreateBuffer(result.device, addr(bufferInfo), nil, addr(result.vkBuffer))
  vkGetBufferMemoryRequirements(result.device, result.vkBuffer, addr(result.memoryRequirements))

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: result.memoryRequirements.size,
    memoryTypeIndex: result.findMemoryType(
      physicalDevice,
      VkMemoryPropertyFlags(uint32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) or uint32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
    )
  )
  checkVkResult result.device.vkAllocateMemory(addr(allocInfo), nil, addr(result.memory))
  checkVkResult result.device.vkBindBufferMemory(result.vkBuffer, result.memory, VkDeviceSize(0))


template withMapping*(buffer: Buffer, data: pointer, body: untyped): untyped =
  checkVkResult buffer.device.vkMapMemory(buffer.memory, offset=VkDeviceSize(0), VkDeviceSize(buffer.size), VkMemoryMapFlags(0), addr(data));
  body
  buffer.device.vkUnmapMemory(buffer.memory);


proc `=copy`(a: var Buffer, b: Buffer){.error.}

proc `=destroy`*(buffer: var Buffer) =
  vkDestroyBuffer(buffer.device, buffer.vkBuffer, nil)
  vkFreeMemory(buffer.device, buffer.memory, nil);
