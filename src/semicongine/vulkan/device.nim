import std/sequtils
import std/options
import std/tables

import ./api
import ./utils
import ./instance
import ./physicaldevice

type
  Device* = object
    physicalDevice*: PhysicalDevice
    vk*: VkDevice
    queues*: Table[QueueFamily, Queue]
  Queue* = object
    vk*: VkQueue
    family*: QueueFamily
    presentation: bool
    graphics: bool

proc createDevice*(
  instance: Instance,
  physicalDevice: PhysicalDevice,
  enabledLayers: seq[string],
  enabledExtensions: seq[string],
  queueFamilies: seq[QueueFamily],
): Device =
  assert instance.vk.valid
  assert physicalDevice.vk.valid
  assert queueFamilies.len > 0

  result.physicalDevice = physicalDevice
  var allExtensions = enabledExtensions & @["VK_KHR_swapchain"]
  for extension in allExtensions:
    instance.vk.loadExtension(extension)
  var
    enabledLayersC = allocCStringArray(enabledLayers)
    enabledExtensionsC = allocCStringArray(allExtensions)
    priority = 1'f32
  var deviceQueues: Table[QueueFamily, VkDeviceQueueCreateInfo]
  for family in queueFamilies:
    deviceQueues[family] = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: family.index,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )

  var queueList = deviceQueues.values.toSeq
  var createInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: uint32(queueList.len),
    pQueueCreateInfos: queueList.toCPointer,
    enabledLayerCount: uint32(enabledLayers.len),
    ppEnabledLayerNames: enabledLayersC,
    enabledExtensionCount: uint32(allExtensions.len),
    ppEnabledExtensionNames: enabledExtensionsC,
    pEnabledFeatures: nil,
  )

  checkVkResult vkCreateDevice(
    physicalDevice=physicalDevice.vk,
    pCreateInfo=addr createInfo,
    pAllocator=nil,
    pDevice=addr result.vk
  )
  deallocCStringArray(enabledLayersC)
  deallocCStringArray(enabledExtensionsC)
  for family in deviceQueues.keys:
    var queue: VkQueue
    vkGetDeviceQueue(result.vk, family.index, 0, addr queue)
    result.queues[family] = Queue(vk: queue, family: family, presentation: family.hasPresentation(physicalDevice.surface), graphics: family.hasGraphics())

func firstGraphicsQueue*(device: Device): Option[Queue] =
  assert device.vk.valid
  for family, queue in device.queues:
    if queue.graphics:
      return some(queue)

proc firstPresentationQueue*(device: Device): Option[Queue] =
  assert device.vk.valid
  for family, queue in device.queues:
    if queue.presentation:
      return some(queue)

proc destroy*(device: var Device) =
  assert device.vk.valid
  device.vk.vkDestroyDevice(nil)
  device.vk.reset()
