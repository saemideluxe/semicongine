import std/strformat
import std/tables
import std/logging

import ../core
import ./device
import ./physicaldevice
import ./buffer
import ./memory
import ./commandbuffer

type
  PixelDepth = 1 .. 4
  VulkanImage* = object
    device*: Device
    vk*: VkImage
    width*: uint32  # pixel
    height*: uint32 # pixel
    depth*: PixelDepth
    format*: VkFormat
    usage*: seq[VkImageUsageFlagBits]
    case memoryAllocated*: bool
      of false: discard
      of true:
        memory*: DeviceMemory
  VulkanSampler* = object
    device*: Device
    vk*: VkSampler
  ImageView* = object
    vk*: VkImageView
    image*: VulkanImage
  VulkanTexture* = object
    image*: VulkanImage
    imageView*: ImageView
    sampler*: VulkanSampler

const DEPTH_FORMAT_MAP = {
  PixelDepth(1): [VK_FORMAT_R8_SRGB, VK_FORMAT_R8_UNORM],
  PixelDepth(2): [VK_FORMAT_R8G8_SRGB, VK_FORMAT_R8G8_UNORM],
  PixelDepth(3): [VK_FORMAT_R8G8B8_SRGB, VK_FORMAT_R8G8B8_UNORM],
  PixelDepth(4): [VK_FORMAT_R8G8B8A8_SRGB, VK_FORMAT_R8G8B8A8_UNORM],
}.toTable

const LINEAR_FORMATS = [
  VK_FORMAT_R8_UNORM,
  VK_FORMAT_R8G8_UNORM,
  VK_FORMAT_R8G8B8_UNORM,
  VK_FORMAT_R8G8B8A8_UNORM,
]


proc requirements(image: VulkanImage): MemoryRequirements =
  assert image.vk.Valid
  assert image.device.vk.Valid
  var req: VkMemoryRequirements
  image.device.vk.vkGetImageMemoryRequirements(image.vk, addr req)
  result.size = req.size
  result.alignment = req.alignment
  let memorytypes = image.device.physicaldevice.vk.GetMemoryProperties().types
  for i in 0 ..< sizeof(req.memoryTypeBits) * 8:
    if ((req.memoryTypeBits shr i) and 1) == 1:
      result.memoryTypes.add memorytypes[i]

proc allocateMemory(image: var VulkanImage, requireMappable: bool, preferVRAM: bool, preferAutoFlush: bool) =
  assert image.device.vk.Valid
  assert image.memoryAllocated == false

  let requirements = image.requirements()
  let memoryType = requirements.memoryTypes.SelectBestMemoryType(
    requireMappable = requireMappable,
    preferVRAM = preferVRAM,
    preferAutoFlush = preferAutoFlush
  )

  debug "Allocating memory for image: ", image.width, "x", image.height, "x", image.depth, ", ", requirements.size, " bytes of type ", memoryType
  image = VulkanImage(
    device: image.device,
    vk: image.vk,
    width: image.width,
    height: image.height,
    depth: image.depth,
    format: image.format,
    usage: image.usage,
    memoryAllocated: true,
    memory: image.device.Allocate(requirements.size, memoryType),
  )
  checkVkResult image.device.vk.vkBindImageMemory(image.vk, image.memory.vk, VkDeviceSize(0))

proc transitionImageLayout(image: VulkanImage, queue: Queue, oldLayout, newLayout: VkImageLayout) =
  var
    barrier = VkImageMemoryBarrier(
      sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
      oldLayout: oldLayout,
      newLayout: newLayout,
      srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      image: image.vk,
      subresourceRange: VkImageSubresourceRange(
        aspectMask: toBits [VK_IMAGE_ASPECT_COLOR_BIT],
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1,
      ),
    )
    srcStage: VkPipelineStageFlagBits
    dstStage: VkPipelineStageFlagBits
  if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED and newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
    barrier.srcAccessMask = VkAccessFlags(0)
    dstStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.dstAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
  elif oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.srcAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
    dstStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
    barrier.dstAccessMask = [VK_ACCESS_SHADER_READ_BIT].toBits
  else:
    raise newException(Exception, "Unsupported layout transition!")

  WithSingleUseCommandBuffer(image.device, queue, commandBuffer):
    commandBuffer.PipelineBarrier([srcStage], [dstStage], imageBarriers = [barrier])

proc Copy*(src: Buffer, dst: VulkanImage, queue: Queue) =
  assert src.device.vk.Valid
  assert dst.device.vk.Valid
  assert src.device == dst.device
  assert VK_BUFFER_USAGE_TRANSFER_SRC_BIT in src.usage
  assert VK_IMAGE_USAGE_TRANSFER_DST_BIT in dst.usage

  var region = VkBufferImageCopy(
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
    imageExtent: VkExtent3D(width: dst.width, height: dst.height, depth: 1)
  )
  WithSingleUseCommandBuffer(src.device, queue, commandBuffer):
    commandBuffer.vkCmdCopyBufferToImage(
      src.vk,
      dst.vk,
      VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
      1,
      addr region
    )

# currently only usable for texture access from shader
proc createImage[T](device: Device, queue: Queue, width, height: uint32, depth: PixelDepth, image: Image[T]): VulkanImage =
  assert device.vk.Valid
  assert width > 0
  assert height > 0
  assert depth != 2

  result.device = device
  result.usage = @[VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_IMAGE_USAGE_SAMPLED_BIT]

  let size: uint64 = width * height * uint32(depth)
  let usageBits = toBits result.usage
  var formatList = DEPTH_FORMAT_MAP[depth]
  var selectedFormat: VkFormat
  var formatProperties = VkImageFormatProperties2(sType: VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2)

  for format in formatList:
    var formatInfo = VkPhysicalDeviceImageFormatInfo2(
      sType: VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
      format: format,
      thetype: VK_IMAGE_TYPE_2D,
      tiling: VK_IMAGE_TILING_OPTIMAL,
      usage: usageBits,
    )
    let formatCheck = device.physicalDevice.vk.vkGetPhysicalDeviceImageFormatProperties2(
      addr formatInfo,
      addr formatProperties,
    )
    if formatCheck == VK_SUCCESS: # found suitable format
      selectedFormat = format
      break
    elif formatCheck == VK_ERROR_FORMAT_NOT_SUPPORTED: # nope, try to find other format
      continue
    else: # raise error
      checkVkResult formatCheck

  # assumption: images comes in sRGB color space
  # convert to linear space if there is not support for sRGB
  var data = addr image.imagedata[0]
  if selectedFormat in LINEAR_FORMATS:
    let linearImage = image.AsLinear()
    data = addr linearImage.imagedata[0]

  assert size <= uint64(formatProperties.imageFormatProperties.maxResourceSize)
  assert width <= uint64(formatProperties.imageFormatProperties.maxExtent.width)
  assert height <= uint64(formatProperties.imageFormatProperties.maxExtent.height)

  result.width = width
  result.height = height
  result.depth = depth
  result.format = selectedFormat

  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    extent: VkExtent3D(width: uint32(width), height: uint32(height), depth: 1),
    mipLevels: min(1'u32, formatProperties.imageFormatProperties.maxMipLevels),
    arrayLayers: min(1'u32, formatProperties.imageFormatProperties.maxArrayLayers),
    format: result.format,
    tiling: VK_IMAGE_TILING_OPTIMAL,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    usage: usageBits,
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    samples: VK_SAMPLE_COUNT_1_BIT,
  )
  checkVkResult device.vk.vkCreateImage(addr imageInfo, nil, addr result.vk)
  result.allocateMemory(requireMappable = false, preferVRAM = true, preferAutoFlush = false)
  result.transitionImageLayout(queue, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)

  var stagingBuffer = device.CreateBuffer(size = size, usage = [VK_BUFFER_USAGE_TRANSFER_SRC_BIT], requireMappable = true, preferVRAM = false, preferAutoFlush = true)
  stagingBuffer.SetData(queue, src = data, size = size)
  stagingBuffer.Copy(result, queue)
  result.transitionImageLayout(queue, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
  stagingBuffer.Destroy()

proc Destroy*(image: var VulkanImage) =
  assert image.device.vk.Valid
  assert image.vk.Valid
  image.device.vk.vkDestroyImage(image.vk, nil)
  if image.memoryAllocated:
    assert image.memory.vk.Valid
    image.memory.Free()
    image = VulkanImage(
      device: image.device,
      vk: image.vk,
      width: image.width,
      height: image.height,
      depth: image.depth,
      format: image.format,
      usage: image.usage,
      memoryAllocated: false,
    )
  image.vk.Reset

proc CreateSampler*(device: Device, sampler: Sampler): VulkanSampler =
  assert device.vk.Valid
  var samplerInfo = VkSamplerCreateInfo(
    sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
    magFilter: sampler.magnification,
    minFilter: sampler.minification,
    addressModeU: sampler.wrapModeS,
    addressModeV: sampler.wrapModeT,
    addressModeW: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    anisotropyEnable: device.enabledFeatures.samplerAnisotropy,
    maxAnisotropy: device.physicalDevice.properties.limits.maxSamplerAnisotropy,
    borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
    unnormalizedCoordinates: VK_FALSE,
    compareEnable: VK_FALSE,
    compareOp: VK_COMPARE_OP_ALWAYS,
    mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
    mipLodBias: 0,
    minLod: 0,
    maxLod: 0,
  )
  result.device = device
  checkVkResult device.vk.vkCreateSampler(addr samplerInfo, nil, addr result.vk)

proc Destroy*(sampler: var VulkanSampler) =
  assert sampler.device.vk.Valid
  assert sampler.vk.Valid
  sampler.device.vk.vkDestroySampler(sampler.vk, nil)
  sampler.vk.Reset

proc CreateImageView*(
  image: VulkanImage,
  imageviewtype = VK_IMAGE_VIEW_TYPE_2D,
  baseMipLevel = 0'u32,
  levelCount = 1'u32,
  baseArrayLayer = 0'u32,
  layerCount = 1'u32
): ImageView =
  assert image.device.vk.Valid
  assert image.vk.Valid

  var createInfo = VkImageViewCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    image: image.vk,
    viewType: imageviewtype,
    format: image.format,
    components: VkComponentMapping(
      r: VK_COMPONENT_SWIZZLE_IDENTITY,
      g: VK_COMPONENT_SWIZZLE_IDENTITY,
      b: VK_COMPONENT_SWIZZLE_IDENTITY,
      a: VK_COMPONENT_SWIZZLE_IDENTITY,
    ),
    subresourceRange: VkImageSubresourceRange(
      aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
      baseMipLevel: baseMipLevel,
      levelCount: levelCount,
      baseArrayLayer: baseArrayLayer,
      layerCount: layerCount,
    ),
  )
  result.image = image
  checkVkResult image.device.vk.vkCreateImageView(addr(createInfo), nil, addr(result.vk))

proc Destroy*(imageview: var ImageView) =
  assert imageview.image.device.vk.Valid
  assert imageview.vk.Valid
  imageview.image.device.vk.vkDestroyImageView(imageview.vk, nil)
  imageview.vk.Reset()

func `$`*(texture: VulkanTexture): string =
  &"VulkanTexture({texture.image.width}x{texture.image.height})"


proc UploadTexture*(device: Device, queue: Queue, texture: Texture): VulkanTexture =
  assert device.vk.Valid
  if texture.isGrayscale:
    result.image = createImage(device = device, queue = queue, width = texture.grayImage.width, height = texture.grayImage.height, depth = 1, image = texture.grayImage)
  else:
    result.image = createImage(device = device, queue = queue, width = texture.colorImage.width, height = texture.colorImage.height, depth = 4, image = texture.colorImage)
  result.imageView = result.image.CreateImageView()
  result.sampler = result.image.device.CreateSampler(texture.sampler)

proc Destroy*(texture: var VulkanTexture) =
  texture.image.Destroy()
  texture.imageView.Destroy()
  texture.sampler.Destroy()
