import std/tables
import std/logging

import ./api
import ./device
import ./physicaldevice
import ./buffer
import ./memory
import ./commandbuffer

type
  PixelDepth = 1'u32 .. 4'u32
  Image* = object
    device*: Device
    vk*: VkImage
    width*: uint32 # pixel
    height*: uint32 # pixel
    depth*: PixelDepth
    format*: VkFormat
    usage*: seq[VkImageUsageFlagBits]
    case memoryAllocated*: bool
      of false: discard
      of true:
        memory*: DeviceMemory
  Sampler* = object
    device*: Device
    vk*: VkSampler
  ImageView* = object
    vk*: VkImageView
    image*: Image
  Texture* = object
    image*: Image
    imageView*: ImageView
    sampler*: Sampler

const DEPTH_FORMAT_MAP = {
  PixelDepth(1): VK_FORMAT_R8_SRGB,
  PixelDepth(2): VK_FORMAT_R8G8_SRGB,
  PixelDepth(3): VK_FORMAT_R8G8B8_SRGB,
  PixelDepth(4): VK_FORMAT_R8G8B8A8_SRGB,
}.toTable


proc requirements(image: Image): MemoryRequirements =
  assert image.vk.valid
  assert image.device.vk.valid
  var req: VkMemoryRequirements
  image.device.vk.vkGetImageMemoryRequirements(image.vk, addr req)
  result.size = req.size
  result.alignment = req.alignment
  let memorytypes = image.device.physicaldevice.vk.getMemoryProperties().types
  for i in 0 ..< sizeof(req.memoryTypeBits) * 8:
    if ((req.memoryTypeBits shr i) and 1) == 1:
      result.memoryTypes.add memorytypes[i]

proc allocateMemory(image: var Image, requireMappable: bool, preferVRAM: bool, preferAutoFlush: bool) =
  assert image.device.vk.valid
  assert image.memoryAllocated == false

  let requirements = image.requirements()
  let memoryType = requirements.memoryTypes.selectBestMemoryType(
    requireMappable=requireMappable,
    preferVRAM=preferVRAM,
    preferAutoFlush=preferAutoFlush
  )
  image.memoryAllocated = true
  debug "Allocating memory for image: ", image.width, "x", image.height, "x", image.depth, " bytes of type ", memoryType
  image.memory = image.device.allocate(requirements.size, memoryType)
  checkVkResult image.device.vk.vkBindImageMemory(image.vk, image.memory.vk, VkDeviceSize(0))

proc transitionImageLayout*(image: Image, oldLayout, newLayout: VkImageLayout) =
  var barrier = VkImageMemoryBarrier(
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
  var
    sourceStage, destinationStage: VkPipelineStageFlagBits
  if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED and newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
    barrier.srcAccessMask = VkAccessFlags(0)
    barrier.dstAccessMask = toBits [VK_ACCESS_TRANSFER_WRITE_BIT]
    sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
    destinationStage = VK_PIPELINE_STAGE_TRANSFER_BIT
  elif oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
      barrier.srcAccessMask = toBits [VK_ACCESS_TRANSFER_WRITE_BIT]
      barrier.dstAccessMask = toBits [VK_ACCESS_SHADER_READ_BIT]
      sourceStage = VK_PIPELINE_STAGE_TRANSFER_BIT
      destinationStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
  else:
    raise newException(Exception, "Unsupported layout transition!")

  withSingleUseCommandBuffer(image.device, false, commandBuffer):
    vkCmdPipelineBarrier(
      commandBuffer,
      toBits [sourceStage], toBits [destinationStage],
      VkDependencyFlags(0),
      0, nil,
      0, nil,
      1, addr barrier
    )

proc copy*(src: Buffer, dst: Image) =
  assert src.device.vk.valid
  assert dst.device.vk.valid
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
  withSingleUseCommandBuffer(src.device, true, commandBuffer):
    commandBuffer.vkCmdCopyBufferToImage(
      src.vk,
      dst.vk,
      VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
      1,
      addr region
    )

# currently only usable for texture access from shader
proc createImage*(device: Device, width, height: uint32, depth: PixelDepth, data: pointer): Image =
  assert device.vk.valid
  assert width > 0
  assert height > 0
  assert depth != 2
  assert data != nil

  let size = width * height * depth
  result.device = device
  result.width = width
  result.height = height
  result.depth = depth
  result.format = DEPTH_FORMAT_MAP[depth]
  result.usage = @[VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_IMAGE_USAGE_SAMPLED_BIT]

  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    extent: VkExtent3D(width: width, height: height, depth: 1),
    mipLevels: 1,
    arrayLayers: 1,
    format: result.format,
    tiling: VK_IMAGE_TILING_OPTIMAL,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    usage: toBits result.usage,
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    samples: VK_SAMPLE_COUNT_1_BIT,
  )
  checkVkResult device.vk.vkCreateImage(addr imageInfo, nil, addr result.vk)
  result.allocateMemory(requireMappable=false, preferVRAM=true, preferAutoFlush=false)
  result.transitionImageLayout(VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)

  var stagingBuffer = device.createBuffer(size=size, usage=[VK_BUFFER_USAGE_TRANSFER_SRC_BIT], requireMappable=true, preferVRAM=false, preferAutoFlush=true)
  stagingBuffer.setData(src=data, size=size)
  stagingBuffer.copy(result)
  result.transitionImageLayout(VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
  stagingBuffer.destroy()

proc destroy*(image: var Image) =
  assert image.device.vk.valid
  assert image.vk.valid
  image.device.vk.vkDestroyImage(image.vk, nil)
  if image.memoryAllocated:
    assert image.memory.vk.valid
    image.memory.free
    image.memoryAllocated = false
  image.vk.reset

proc createSampler*(device: Device, interpolation: VkFilter): Sampler =
  assert device.vk.valid
  var samplerInfo = VkSamplerCreateInfo(
    sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
    magFilter: interpolation,
    minFilter: interpolation,
    addressModeU: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    addressModeV: VK_SAMPLER_ADDRESS_MODE_REPEAT,
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

proc destroy*(sampler: var Sampler) =
  assert sampler.device.vk.valid
  assert sampler.vk.valid
  sampler.device.vk.vkDestroySampler(sampler.vk, nil)
  sampler.vk.reset

proc createImageView*(
  image: Image,
  imageviewtype=VK_IMAGE_VIEW_TYPE_2D,
  baseMipLevel=0'u32,
  levelCount=1'u32,
  baseArrayLayer=0'u32,
  layerCount=1'u32
): ImageView =
  assert image.device.vk.valid
  assert image.vk.valid

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

proc destroy*(imageview: var ImageView) =
  assert imageview.image.device.vk.valid
  assert imageview.vk.valid
  imageview.image.device.vk.vkDestroyImageView(imageview.vk, nil)
  imageview.vk.reset()

proc createTexture*(device: Device, width, height: uint32, depth: PixelDepth, data: pointer, interpolation: VkFilter): Texture =
  assert device.vk.valid
  
  result.image = createImage(device=device, width=width, height=height, depth=depth, data=data)
  result.imageView = result.image.createImageView()
  result.sampler = result.image.device.createSampler(interpolation)

proc destroy*(texture: var Texture) =
  texture.image.destroy()
  texture.imageView.destroy()
  texture.sampler.destroy()
