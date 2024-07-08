include ../platform/vulkan_extensions
include ../platform/window
include ../platform/surface

type
  VulkanGlobals* = object
    instance*: VkInstance
    device*: VkDevice
    physicalDevice*: VkPhysicalDevice
    surface: VkSurfaceKHR
    window: NativeWindow
    graphicsQueueFamily*: uint32
    graphicsQueue*: VkQueue
    anisotropy*: float32 = 0 # needs to be enable during device creation

var vulkan*: VulkanGlobals

proc GetBestPhysicalDevice(instance: VkInstance): VkPhysicalDevice =
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(nDevices), devices.ToCPointer)

  var score = 0'u32
  for pDevice in devices:
    var props: VkPhysicalDeviceProperties
    # CANNOT use svkGetPhysicalDeviceProperties (not initialized yet)
    vkGetPhysicalDeviceProperties(pDevice, addr(props))
    if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and props.limits.maxImageDimension2D > score:
      score = props.limits.maxImageDimension2D
      result = pDevice

  if score == 0:
    for pDevice in devices:
      var props: VkPhysicalDeviceProperties
      # CANNOT use svkGetPhysicalDeviceProperties (not initialized yet)
      vkGetPhysicalDeviceProperties(pDevice, addr(props))
      if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU and props.limits.maxImageDimension2D > score:
        score = props.limits.maxImageDimension2D
        result = pDevice

  assert score > 0, "Unable to find integrated or discrete GPU"

proc GetQueueFamily(pDevice: VkPhysicalDevice, qType: VkQueueFlagBits): uint32 =
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(pDevice, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(pDevice, addr nQueuefamilies, queuFamilies.ToCPointer)
  for i in 0'u32 ..< nQueuefamilies:
    if qType in toEnums(queuFamilies[i].queueFlags):
      return i
  assert false, &"Queue of type {qType} not found"

proc svkGetDeviceQueue*(device: VkDevice, queueFamilyIndex: uint32, qType: VkQueueFlagBits): VkQueue =
  vkGetDeviceQueue(
    device,
    queueFamilyIndex,
    0,
    addr(result),
  )

proc hasValidationLayer*(): bool =
  var n_layers: uint32
  checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), nil)
  if n_layers > 0:
    var layers = newSeq[VkLayerProperties](n_layers)
    checkVkResult vkEnumerateInstanceLayerProperties(addr(n_layers), layers.ToCPointer)
    for layer in layers:
      if layer.layerName.CleanString == "VK_LAYER_KHRONOS_validation":
        return true
  return false

proc initVulkan*(platformLayers: seq[string], appName: string = "semicongine app") =

  # instance creation
  #
  when not defined(release):
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface", "VK_EXT_debug_utils"]
    let layers: seq[string] = if hasValidationLayer(): @["VK_LAYER_KHRONOS_validation"] else: @[]
  else:
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface"]
    let layers: seq[string]

  var
    layersC = allocCStringArray(layers)
    instanceExtensionsC = allocCStringArray(requiredExtensions)
  defer:
    deallocCStringArray(layersC)
    deallocCStringArray(instanceExtensionsC)

  var
    appinfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: appName,
      pEngineName: "semicongine",
      apiVersion: VK_MAKE_API_VERSION(0, 1, 3, 0),
    )
    createinfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: addr(appinfo),
      enabledLayerCount: layers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: requiredExtensions.len.uint32,
      ppEnabledExtensionNames: instanceExtensionsC
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(vulkan.instance))
  loadVulkan(vulkan.instance)

  # load extensions
  #
  for extension in requiredExtensions:
    loadExtension(vulkan.instance, $extension)
  vulkan.window = CreateWindow(appName)
  vulkan.surface = CreateNativeSurface(vulkan.instance, vulkan.window)




  # logical device creation




  # TODO: allowing support for physical devices without hasUniformBufferStandardLayout
  # would require us to ship different shaders, so we don't support standard layout
  # if that will be added, check the function vulkan/shaders.nim:glslUniforms and update accordingly
  # let hasUniformBufferStandardLayout = "VK_KHR_uniform_buffer_standard_layout" in physicalDevice.getExtensions()
  # var deviceExtensions  = @["VK_KHR_swapchain", "VK_KHR_uniform_buffer_standard_layout"]
  var deviceExtensions = @["VK_KHR_swapchain"]
  for extension in deviceExtensions:
    loadExtension(vulkan.instance, extension)

  # get physical device and graphics queue family
  vulkan.physicalDevice = GetBestPhysicalDevice(vulkan.instance)
  vulkan.graphicsQueueFamily = GetQueueFamily(vulkan.physicalDevice, VK_QUEUE_GRAPHICS_BIT)

  let
    priority = cfloat(1)
    queueInfo = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: vulkan.graphicsQueueFamily,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )
    deviceExtensionsC = allocCStringArray(deviceExtensions)
  defer: deallocCStringArray(deviceExtensionsC)
  var createDeviceInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: 1,
    pQueueCreateInfos: addr(queueInfo),
    enabledLayerCount: 0,
    ppEnabledLayerNames: nil,
    enabledExtensionCount: uint32(deviceExtensions.len),
    ppEnabledExtensionNames: deviceExtensionsC,
    pEnabledFeatures: nil,
  )
  checkVkResult vkCreateDevice(
    physicalDevice = vulkan.physicalDevice,
    pCreateInfo = addr createDeviceInfo,
    pAllocator = nil,
    pDevice = addr vulkan.device
  )
  vulkan.graphicsQueue = svkGetDeviceQueue(vulkan.device, vulkan.graphicsQueueFamily, VK_QUEUE_GRAPHICS_BIT)


proc svkGetPhysicalDeviceProperties*(): VkPhysicalDeviceProperties =
  vkGetPhysicalDeviceProperties(vulkan.physicalDevice, addr(result))

proc svkCreateBuffer*(size: uint64, usage: openArray[VkBufferUsageFlagBits]): VkBuffer =
  var createInfo = VkBufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    flags: VkBufferCreateFlags(0),
    size: size,
    usage: usage.toBits,
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
  )
  checkVkResult vkCreateBuffer(
    device = vulkan.device,
    pCreateInfo = addr(createInfo),
    pAllocator = nil,
    pBuffer = addr(result),
  )

proc svkAllocateMemory*(size: uint64, typeIndex: uint32): VkDeviceMemory =
  var memoryAllocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: size,
    memoryTypeIndex: typeIndex,
  )
  checkVkResult vkAllocateMemory(
    vulkan.device,
    addr(memoryAllocationInfo),
    nil,
    addr(result),
  )

proc svkCreate2DImage*(width, height: uint32, format: VkFormat, usage: openArray[VkImageUsageFlagBits]): VkImage =
  var imageProps: VkImageFormatProperties
  checkVkResult vkGetPhysicalDeviceImageFormatProperties(
    vulkan.physicalDevice,
    format,
    VK_IMAGE_TYPE_2D,
    VK_IMAGE_TILING_OPTIMAL,
    usage.toBits,
    VkImageCreateFlags(0),
    addr(imageProps)
  )

  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    extent: VkExtent3D(width: width, height: height, depth: 1),
    mipLevels: min(1'u32, imageProps.maxMipLevels),
    arrayLayers: min(1'u32, imageProps.maxArrayLayers),
    format: format,
    tiling: VK_IMAGE_TILING_OPTIMAL,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    usage: usage.toBits,
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    samples: VK_SAMPLE_COUNT_1_BIT,
  )
  checkVkResult vkCreateImage(vulkan.device, addr imageInfo, nil, addr(result))

proc svkGetBufferMemoryRequirements*(buffer: VkBuffer): tuple[size: uint64, alignment: uint64, memoryTypes: seq[uint32]] =
  var reqs: VkMemoryRequirements
  vkGetBufferMemoryRequirements(vulkan.device, buffer, addr(reqs))
  result.size = reqs.size
  result.alignment = reqs.alignment
  for i in 0'u32 ..< VK_MAX_MEMORY_TYPES:
    if ((1'u32 shl i) and reqs.memoryTypeBits) > 0:
      result.memoryTypes.add i

proc svkGetImageMemoryRequirements*(image: VkImage): tuple[size: uint64, alignment: uint64, memoryTypes: seq[uint32]] =
  var reqs: VkMemoryRequirements
  vkGetImageMemoryRequirements(vulkan.device, image, addr(reqs))
  result.size = reqs.size
  result.alignment = reqs.alignment
  for i in 0'u32 ..< VK_MAX_MEMORY_TYPES:
    if ((1'u32 shl i) and reqs.memoryTypeBits) > 0:
      result.memoryTypes.add i

proc BestMemory*(mappable: bool, filter: seq[uint32] = @[]): uint32 =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(vulkan.physicalDevice, addr(physicalProperties))

  var maxScore: float = -1
  var maxIndex: uint32 = 0
  for index in 0'u32 ..< physicalProperties.memoryTypeCount:
    if filter.len == 0 or index in filter:
      let flags = toEnums(physicalProperties.memoryTypes[index].propertyFlags)
      if not mappable or VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags:
        var score: float = 0
        if VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT in flags: score += 1_000_000
        if VK_MEMORY_PROPERTY_HOST_CACHED_BIT in flags: score += 1_000
        score += float(physicalProperties.memoryHeaps[physicalProperties.memoryTypes[index].heapIndex].size) / 1_000_000_000
        if score > maxScore:
          maxScore = score
          maxIndex = index
  assert maxScore > 0, &"Unable to find memory type (mappable: {mappable}, filter: {filter})"
  return maxIndex

template WithSingleUseCommandBuffer*(cmd, body: untyped): untyped =
  block:
    var
      commandBufferPool: VkCommandPool
      createInfo = VkCommandPoolCreateInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
        queueFamilyIndex: vulkan.graphicsQueueFamily,
      )
    checkVkResult vkCreateCommandPool(vulkan.device, addr createInfo, nil, addr(commandBufferPool))
    var
      `cmd` {.inject.}: VkCommandBuffer
      allocInfo = VkCommandBufferAllocateInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool: commandBufferPool,
        level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount: 1,
      )
    checkVkResult vulkan.device.vkAllocateCommandBuffers(addr allocInfo, addr(`cmd`))
    var beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
    )
    checkVkResult `cmd`.vkBeginCommandBuffer(addr beginInfo)

    body

    checkVkResult `cmd`.vkEndCommandBuffer()
    var submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      commandBufferCount: 1,
      pCommandBuffers: addr(`cmd`),
    )

    var
      fence: VkFence
      fenceInfo = VkFenceCreateInfo(
        sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        # flags: toBits [VK_FENCE_CREATE_SIGNALED_BIT]
      )
    checkVkResult vulkan.device.vkCreateFence(addr(fenceInfo), nil, addr(fence))
    checkVkResult vkQueueSubmit(vulkan.graphicsQueue, 1, addr(submitInfo), fence)
    checkVkResult vkWaitForFences(vulkan.device, 1, addr fence, false, high(uint64))
    vkDestroyCommandPool(vulkan.device, commandBufferPool, nil)

template WithStagingBuffer*[T: (VkBuffer, uint64)|(VkImage, uint32, uint32)](
  target: T,
  bufferSize: uint64,
  dataPointer,
  body: untyped
): untyped =
  var `dataPointer` {.inject.}: pointer
  let stagingBuffer = svkCreateBuffer(bufferSize, [VK_BUFFER_USAGE_TRANSFER_SRC_BIT])
  let memoryRequirements = svkGetBufferMemoryRequirements(stagingBuffer)
  let memoryType = BestMemory(mappable = true, filter = memoryRequirements.memoryTypes)
  let stagingMemory = svkAllocateMemory(memoryRequirements.size, memoryType)
  checkVkResult vkMapMemory(
    device = vulkan.device,
    memory = stagingMemory,
    offset = 0'u64,
    size = VK_WHOLE_SIZE,
    flags = VkMemoryMapFlags(0),
    ppData = addr(`dataPointer`)
  )
  checkVkResult vkBindBufferMemory(vulkan.device, stagingBuffer, stagingMemory, 0)

  block:
    # usually: write data to dataPointer in body
    body

  var stagingRange = VkMappedMemoryRange(
    sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
    memory: stagingMemory,
    size: VK_WHOLE_SIZE,
  )
  checkVkResult vkFlushMappedMemoryRanges(vulkan.device, 1, addr(stagingRange))

  WithSingleUseCommandBuffer(commandBuffer):
    when T is (VkBuffer, uint64):
      let copyRegion = VkBufferCopy(
        size: bufferSize,
        dstOffset: target[1],
        srcOffset: 0
      )
      vkCmdCopyBuffer(
        commandBuffer = commandBuffer,
        srcBuffer = stagingBuffer,
        dstBuffer = target[0],
        regionCount = 1,
        pRegions = addr(copyRegion)
      )
    elif T is (VkImage, uint32, uint32):
      let region = VkBufferImageCopy(
        bufferOffset: 0,
        bufferRowLength: 0,
        bufferImageHeight: 0,
        imageSubresource: VkImageSubresourceLayers(
          aspectMask: toBits [VK_IMAGE_ASPECT_COLOR_BIT],
          mipLevel: 0,
          baseArrayLayer: 0,
          layerCount: 1,
        ),
        imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
        imageExtent: VkExtent3D(width: target[1], height: target[2], depth: 1)
      )
      vkCmdCopyBufferToImage(
        commandBuffer = commandBuffer,
        srcBuffer = stagingBuffer,
        dstImage = target[0],
        dstImageLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        regionCount = 1,
        pRegions = addr(region)
      )

  vkDestroyBuffer(vulkan.device, stagingBuffer, nil)
  vkFreeMemory(vulkan.device, stagingMemory, nil)

