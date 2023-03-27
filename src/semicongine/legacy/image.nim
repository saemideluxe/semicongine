import ./buffer
import ./math/vector
import ./vulkan
import ./vulkan_helpers

type
  ImageUsage* = enum
    TransferDst = VK_IMAGE_USAGE_TRANSFER_DST_BIT
    SampledBit = VK_IMAGE_USAGE_SAMPLED_BIT
  ImageUsages = set[ImageUsage]
  Image = object
    buffer: Buffer
    image: VkImage
    memory: VkDeviceMemory

proc InitImage(data: var seq[byte], size: TVec2[uint32], format: VkFormat,
    tiling: VkImageTiling, usage: ImageUsages, properties: MemoryProperties,
        device: VkDevice,
    physicalDevice: VkPhysicalDevice): Image =
  result.buffer = InitBuffer(device, physicalDevice, uint64(data.len), {
      TransferSrc}, {HostVisible, HostCoherent})
  copyMem(result.buffer.data, addr(data[0]), data.len)

  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    extent: VkExtent3D(width: size.x, height: size.y, depth: 1),
    mipLevels: 1,
    arrayLayers: 1,
    format: format,
    tiling: tiling,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    usage: cast[VkImageUsageFlags](usage),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    samples: VK_SAMPLE_COUNT_1_BIT,
  )
  checkVkResult vkCreateImage(device, addr(imageInfo), nil, addr(result.image))

  var memRequirements: VkMemoryRequirements
  vkGetImageMemoryRequirements(device, result.image, addr(memRequirements))

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: memRequirements.size,
    memoryTypeIndex: memRequirements.findMemoryType(physicalDevice, properties)
  )

  checkVkResult vkAllocateMemory(device, addr(allocInfo), nil, addr(result.memory))
  checkVkResult vkBindImageMemory(device, result.image, result.memory,
      VkDeviceSize(0))
