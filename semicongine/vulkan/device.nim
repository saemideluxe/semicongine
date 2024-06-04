import std/sequtils
import std/options
import std/tables

import ../core
import ./instance
import ./physicaldevice

type
  Device* = object
    physicalDevice*: PhysicalDevice
    vk*: VkDevice
    queues*: Table[QueueFamily, Queue]
    enabledFeatures*: VkPhysicalDeviceFeatures
  Queue* = object
    vk*: VkQueue
    family*: QueueFamily
    presentation: bool
    graphics: bool

proc `$`*(device: Device): string =
  "Device: vk=" & $device.vk

proc CreateDevice*(
  instance: Instance,
  physicalDevice: PhysicalDevice,
  enabledExtensions: seq[string],
  queueFamilies: seq[QueueFamily],
): Device =
  assert instance.vk.valid
  assert physicalDevice.vk.valid
  assert queueFamilies.len > 0

  result.physicalDevice = physicalDevice
  # TODO: allowing support for physical devices without hasUniformBufferStandardLayout
  # would require us to ship different shaders, so we don't support standard layout
  # if that will be added, check the function vulkan/shaders.nim:glslUniforms and update accordingly
  # let hasUniformBufferStandardLayout = "VK_KHR_uniform_buffer_standard_layout" in physicalDevice.getExtensions()
  let hasUniformBufferStandardLayout = false

  var allExtensions = enabledExtensions & @["VK_KHR_swapchain"]
  if hasUniformBufferStandardLayout:
    allExtensions.add "VK_KHR_uniform_buffer_standard_layout"
  for extension in allExtensions:
    instance.vk.loadExtension(extension)

  var
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

  var uniformBufferLayoutFeature = VkPhysicalDeviceUniformBufferStandardLayoutFeatures(
    stype: VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_UNIFORM_BUFFER_STANDARD_LAYOUT_FEATURES,
    uniformBufferStandardLayout: true,
  )
  var features2 = VkPhysicalDeviceFeatures2(
    stype: VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
    features: result.enabledFeatures,
    pnext: if hasUniformBufferStandardLayout: addr uniformBufferLayoutFeature else: nil,
  )
  var createInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: uint32(queueList.len),
    pQueueCreateInfos: queueList.ToCPointer,
    enabledLayerCount: 0,
    ppEnabledLayerNames: nil,
    enabledExtensionCount: uint32(allExtensions.len),
    ppEnabledExtensionNames: enabledExtensionsC,
    pEnabledFeatures: nil,
    pnext: addr features2,
  )

  checkVkResult vkCreateDevice(
    physicalDevice = physicalDevice.vk,
    pCreateInfo = addr createInfo,
    pAllocator = nil,
    pDevice = addr result.vk
  )
  deallocCStringArray(enabledExtensionsC)
  for family in deviceQueues.keys:
    var queue: VkQueue
    vkGetDeviceQueue(result.vk, family.index, 0, addr queue)
    result.queues[family] = Queue(vk: queue, family: family, presentation: family.CanDoPresentation(physicalDevice.surface), graphics: family.CanDoGraphics())

func FirstGraphicsQueue*(device: Device): Option[Queue] =
  assert device.vk.valid
  for family, queue in device.queues:
    if queue.graphics:
      return some(queue)

proc FirstPresentationQueue*(device: Device): Option[Queue] =
  assert device.vk.valid
  for family, queue in device.queues:
    if queue.presentation:
      return some(queue)

proc Destroy*(device: var Device) =
  assert device.vk.valid
  device.vk.vkDestroyDevice(nil)
  device.vk.reset()
