import ./api
import ./utils
import ./instance

type
  PhysicalDevice* = object
    vk: VkPhysicalDevice
  Device* = object
    physicalDevice: PhysicalDevice
    vk: VkDevice
  QueueFamily* = object
    properties: VkQueueFamilyProperties
    index: uint32
  Queue* = object
    vk: VkQueue

proc getPhysicalDevices*(instance: Instance): seq[PhysicalDevice] =
  assert instance.vk.valid
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), devices.toCPointer)
  for i in 0 ..< nDevices:
    result.add PhysicalDevice(vk: devices[i])

proc getExtensions*(device: PhysicalDevice): seq[string] =
  assert device.vk.valid
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateDeviceExtensionProperties(device.vk, nil, addr(extensionCount), extensions.toCPointer)
    for extension in extensions:
      result.add(cleanString(extension.extensionName))

proc getQueueFamilies*(device: PhysicalDevice): seq[QueueFamily] =
  assert device.vk.valid
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies , queuFamilies.toCPointer)
  for i in 0 ..< nQueuefamilies:
    result.add QueueFamily(properties: queuFamilies[i], index: i)

func canGraphics*(family: QueueFamily): bool =
  VK_QUEUE_GRAPHICS_BIT in family.properties.queueFlags.toEnums
func canTransfer*(family: QueueFamily): bool =
  VK_QUEUE_TRANSFER_BIT in family.properties.queueFlags.toEnums
func canCompute*(family: QueueFamily): bool =
  VK_QUEUE_COMPUTE_BIT in family.properties.queueFlags.toEnums

proc createDevice*(
  physicalDevice: PhysicalDevice,
  enabledLayers: openArray[string],
  enabledExtensions: openArray[string],
  queueFamilies: openArray[QueueFamily],
): Device =
  assert physicalDevice.vk.valid
  assert queueFamilies.len > 0
  result.physicalDevice = physicalDevice
  var
    enabledLayersC = allocCStringArray(enabledLayers)
    enabledExtensionsC = allocCStringArray(enabledExtensions)
    priority = 1'f32
  var deviceQueues: seq[VkDeviceQueueCreateInfo]
  for family in queueFamilies:
    deviceQueues.add VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: family.index,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )

  var createInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: uint32(deviceQueues.len),
    pQueueCreateInfos: deviceQueues.toCPointer,
    enabledLayerCount: uint32(enabledLayers.len),
    ppEnabledLayerNames: enabledLayersC,
    enabledExtensionCount: uint32(enabledExtensions.len),
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

proc destroy*(device: var Device) =
  assert device.vk.valid
  device.vk.vkDestroyDevice(nil)
  device.vk.reset()
