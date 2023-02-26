import ./api
import ./utils
import ./instance

type
  PhysicalDevice = object
    vk: VkPhysicalDevice
  Device = object
    physicalDevice: PhysicalDevice
    vk: VkDevice
  QueueFamily = object
    vk: VkQueueFamilyProperties
    index: uint32
  Queue = object
    vk: VkQueue

proc getDeviceExtensions*(device: VkPhysicalDevice): seq[string] =
  var extensionCount: uint32
  checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), nil)
  if extensionCount > 0:
    var extensions = newSeq[VkExtensionProperties](extensionCount)
    checkVkResult vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), addr extensions[0])
    for extension in extensions:
      result.add(cleanString(extension.extensionName))

proc getVulkanPhysicalDevices*(instance: Instance): seq[PhysicalDevice] =
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), addr devices[0])
  for i in 0 ..< nDevices:
    result.add PhysicalDevice(vk: devices[i])

proc getQueueFamilies*(device: PhysicalDevice): seq[QueueFamily] =
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies , addr queuFamilies[0])
  for i in 0 ..< nQueuefamilies:
    result.add QueueFamily(vk: queuFamilies[i], index: i)

proc createDevice(
  physicalDevice: PhysicalDevice,
  enabledLayers: openArray[string],
  enabledExtensions: openArray[string],
  queueFamilies: openArray[QueueFamily],
): Device =
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
    pQueueCreateInfos: addr deviceQueues[0],
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
