import ./api

type
  MemoryHeap = object
    size*: uint64
    flags*: seq[VkMemoryHeapFlagBits]
    index*: uint32
  MemoryType = object
    heap*: MemoryHeap
    flags*: seq[VkMemoryPropertyFlagBits]
    index*: uint32
  PhyscialDeviceMemoryProperties = object
    heaps*: seq[MemoryHeap]
    types*: seq[MemoryType]
  DeviceMemory = object
    device*: VkDevice
    size*: uint64
    vk*: VkDeviceMemory

proc getPhysicalDeviceMemoryProperties(physicalDevice: VkPhysicalDevice): PhyscialDeviceMemoryProperties =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr physicalProperties)
  for i in 0 ..< physicalProperties.memoryHeapCount:
    result.heaps.add MemoryHeap(
      size: physicalProperties.memoryHeaps[i].size,
      flags: toEnums(physicalProperties.memoryHeaps[i].flags),
      index: i,
    )
  for i in 0 ..< physicalProperties.memoryTypeCount:
    result.types.add MemoryType(
      heap: result.heaps[physicalProperties.memoryTypes[i].heapIndex],
      flags: toEnums(physicalProperties.memoryTypes[i].propertyFlags),
      index: i,
    )

proc allocateMemory(device: VkDevice, size: uint64, memoryType: MemoryType): DeviceMemory =
  result.device = device
  result.size = size

  var allocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: size,
    memoryTypeIndex: memoryType.index,
  )

  checkVkResult vkAllocateMemory(
    device,
    addr allocationInfo,
    nil,
    addr result.vk
  )
