import std/strformat

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

proc allocate*(device: Device, size: uint64, flags: openArray[VkMemoryPropertyFlagBits]): DeviceMemory =
  assert device.vk.valid

  result.device = device
  result.size = size

  var
    memtype: MemoryType
    hasAllFlags: bool
  for mtype in device.physicalDevice.vk.getPhysicalDeviceMemoryProperties.types:
    hasAllFlags = true
    for flag in flags:
      if not (flag in mtype.flags):
        hasAllFlags = false
        break
    if hasAllFlags:
      memtype = mtype
      break
  if not hasAllFlags:
    raise newException(Exception, &"No memory with support for {flags}")

  var allocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: size,
    memoryTypeIndex: memtype.index,
  )

  checkVkResult vkAllocateMemory(
    device.vk,
    addr allocationInfo,
    nil,
    addr result.vk
  )

proc map*(memory: DeviceMemory, offset=0'u64, size=0'u64): pointer =
  assert memory.device.vk.valid
  assert memory.vk.valid
  
  var thesize = size
  if thesize == 0:
    thesize = memory.size

  checkVkResult memory.device.vk.vkMapMemory(
    memory=memory.vk,
    offset=VkDeviceSize(offset),
    size=VkDeviceSize(thesize),
    flags=VkMemoryMapFlags(0), # unused up to Vulkan 1.3
    ppData=addr(result)
  )

proc free*(memory: var DeviceMemory) =
  assert memory.device.vk.valid
  assert memory.vk.valid

  memory.device.vk.vkFreeMemory(memory.vk, nil)
  memory = default(DeviceMemory)
