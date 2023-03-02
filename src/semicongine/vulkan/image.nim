import ./api
import ./device

type
  Image* = object
    vk*: VkImage
    format*: VkFormat
    device*: Device
  ImageView* = object
    vk*: VkImageView
    image*: Image

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
