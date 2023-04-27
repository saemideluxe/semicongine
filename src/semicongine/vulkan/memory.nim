import std/strformat
import std/algorithm

import ./api
import ./device

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
  DeviceMemory* = object
    device*: Device
    vk*: VkDeviceMemory
    size*: uint64
    memoryType*: MemoryType
    case canMap*: bool
      of false: discard
      of true: data*: pointer
    needsFlushing*: bool

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

proc hasMemoryWith*(device: Device, requiredFlags: openArray[VkMemoryPropertyFlagBits]): bool =
  for mtype in device.physicalDevice.vk.getPhysicalDeviceMemoryProperties.types:
    var hasAllFlags = true
    for flag in requiredFlags:
      if not (flag in mtype.flags):
        hasAllFlags = false
        break
    if hasAllFlags:
      return true

proc allocate*(device: Device, size: uint64, flags: openArray[VkMemoryPropertyFlagBits]): DeviceMemory =
  assert device.vk.valid
  assert size > 0

  result.device = device
  result.size = size

  var
    hasAllFlags: bool
    matchingTypes: seq[MemoryType]
  for mtype in device.physicalDevice.vk.getPhysicalDeviceMemoryProperties.types:
    hasAllFlags = true
    for flag in flags:
      if not (flag in mtype.flags):
        hasAllFlags = false
        break
    if hasAllFlags:
      matchingTypes.add mtype
  if matchingTypes.len == 0:
    raise newException(Exception, &"No memory with support for {flags}")
  matchingTypes.sort(cmp= proc(a, b: MemoryType): int = cmp(a.heap.size, b.heap.size))

  result.memoryType = matchingTypes[^1]
  result.canMap = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in result.memoryType.flags
  result.needsFlushing = not (VK_MEMORY_PROPERTY_HOST_COHERENT_BIT in result.memoryType.flags)

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

#[ 
proc allocate*(device: Device, size: uint64, useVRAM: bool, mappable: bool, autoFlush: bool): DeviceMemory =
  var flags: seq[VkMemoryPropertyFlagBits]
  if useVRAM:
    flags.add VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
  if mappable:
    flags.add VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
  if autoFlush:
    flags.add VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
  device.allocate(size=size, flags=flags)
]#

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
