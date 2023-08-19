import std/strformat

import ../core
import ./device

type
  MemoryHeap = object
    size*: uint64
    flags*: seq[VkMemoryHeapFlagBits]
    index*: uint32
  MemoryType* = object
    heap*: MemoryHeap
    flags*: seq[VkMemoryPropertyFlagBits]
    index*: uint32
  PhyscialDeviceMemoryProperties = object
    heaps*: seq[MemoryHeap]
    types*: seq[MemoryType]
  DeviceMemory* = object
    device*: Device
    vk*: VkDeviceMemory
    size*: uint64
    memoryType*: MemoryType
    case canMap*: bool
      of false: discard
      of true: data*: pointer
    needsFlushing*: bool
  MemoryRequirements* = object
    size*: uint64
    alignment*: uint64
    memoryTypes*: seq[MemoryType]

func `$`*(memoryType: MemoryType): string =
  &"Memorytype {memoryType.flags} (heap size: {memoryType.heap.size}, heap flags: {memoryType.heap.flags})"

proc selectBestMemoryType*(types: seq[MemoryType], requireMappable: bool, preferVRAM: bool, preferAutoFlush: bool): MemoryType =
  # todo: we assume there is always at least one memory type that is mappable
  assert types.len > 0
  var highestRating = 0'f
  result = types[0]
  for t in types:
    var rating = float(t.heap.size) / 1_000_000'f # select biggest heap if all else equal
    if requireMappable and VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in t.flags:
      rating += 1000
    if preferVRAM and VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT in t.flags:
      rating += 500
    if preferAutoFlush and VK_MEMORY_PROPERTY_HOST_COHERENT_BIT in t.flags:
      rating += 100
    if rating > highestRating:
      highestRating = rating
      result = t

proc getMemoryProperties*(physicalDevice: VkPhysicalDevice): PhyscialDeviceMemoryProperties =
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

proc allocate*(device: Device, size: uint64, memoryType: MemoryType): DeviceMemory =
  assert device.vk.valid
  assert size > 0
  result = DeviceMemory(
    device: device,
    size: size,
    memoryType: memoryType,
    canMap: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in memoryType.flags,
    needsFlushing: not (VK_MEMORY_PROPERTY_HOST_COHERENT_BIT in memoryType.flags),
  )

  var allocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: size,
    memoryTypeIndex: result.memoryType.index,
  )

  checkVkResult vkAllocateMemory(
    device.vk,
    addr allocationInfo,
    nil,
    addr result.vk
  )

  if result.canMap:
    checkVkResult result.device.vk.vkMapMemory(
      memory=result.vk,
      offset=VkDeviceSize(0),
      size=VkDeviceSize(result.size),
      flags=VkMemoryMapFlags(0), # unused up to Vulkan 1.3
      ppData=addr(result.data)
    )

# flush host -> device
proc flush*(memory: DeviceMemory, offset=0'u64, size=0'u64) =
  assert memory.device.vk.valid
  assert memory.vk.valid
  assert memory.needsFlushing

  var actualSize = size
  if actualSize == 0:
    actualSize = memory.size
  var flushrange = VkMappedMemoryRange(
    sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
    memory: memory.vk,
    offset: VkDeviceSize(offset),
    size: VkDeviceSize(size)
  )
  checkVkResult memory.device.vk.vkFlushMappedMemoryRanges(memoryRangeCount=1, pMemoryRanges=addr(flushrange))

# flush device -> host
proc invalidate*(memory: DeviceMemory, offset=0'u64, size=0'u64) =
  assert memory.device.vk.valid
  assert memory.vk.valid
  assert memory.needsFlushing

  var actualSize = size
  if actualSize == 0:
    actualSize = memory.size
  var flushrange = VkMappedMemoryRange(
    sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
    memory: memory.vk,
    offset: VkDeviceSize(offset),
    size: VkDeviceSize(size)
  )
  checkVkResult memory.device.vk.vkInvalidateMappedMemoryRanges(memoryRangeCount=1, pMemoryRanges=addr(flushrange))

proc free*(memory: var DeviceMemory) =
  assert memory.device.vk.valid
  assert memory.vk.valid

  memory.device.vk.vkFreeMemory(memory.vk, nil)
  memory.vk.reset
