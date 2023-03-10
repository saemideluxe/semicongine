import ./api
import ./utils
import ./device
import ./physicaldevice
import ./image
import ../math

type
  Swapchain = object
    vk*: VkSwapchainKHR
    device*: Device
    imageviews*: seq[ImageView]
    format*: VkFormat
    dimension*: TVec2[uint32]


proc createSwapchain*(
  device: Device,
  surfaceFormat: VkSurfaceFormatKHR,
  nBuffers=3'u32,
  presentationMode: VkPresentModeKHR=VK_PRESENT_MODE_MAILBOX_KHR
): (Swapchain, VkResult) =
  assert device.vk.valid
  assert device.physicalDevice.vk.valid
  var capabilities = device.physicalDevice.getSurfaceCapabilities()

  var imageCount = nBuffers
  # following is according to vulkan specs
  if presentationMode in [VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR, VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR]:
    imageCount = 1
  else:
    imageCount = max(imageCount, capabilities.minImageCount)
    if capabilities.maxImageCount != 0:
      imageCount = min(imageCount, capabilities.maxImageCount)

  var createInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: device.physicalDevice.surface,
    minImageCount: imageCount,
    imageFormat: surfaceFormat.format,
    imageColorSpace: surfaceFormat.colorSpace,
    imageExtent: capabilities.currentExtent,
    imageArrayLayers: 1,
    imageUsage: toBits [VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
    # VK_SHARING_MODE_CONCURRENT no supported currently
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, # only used for blending with other windows, can be opaque
    presentMode: presentationMode,
    clipped: true,
  )
  var
    swapchain = Swapchain(
      device: device,
      format: surfaceFormat.format,
      dimension: TVec2[uint32]([capabilities.currentExtent.width, capabilities.currentExtent.height]))
    createResult = device.vk.vkCreateSwapchainKHR(addr(createInfo), nil, addr(swapchain.vk))

  if createResult == VK_SUCCESS:
    var nImages: uint32
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), nil)
    var images = newSeq[VkImage](nImages)
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), images.toCPointer)
    for vkimage in images:
      let image = Image(vk: vkimage, format: surfaceFormat.format, device: device)
      swapChain.imageviews.add image.createImageView()

  return (swapchain, createResult)

proc getImages*(device: VkDevice, swapChain: VkSwapchainKHR): seq[VkImage] =
  var n_images: uint32
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), nil)
  result = newSeq[VkImage](n_images)
  checkVkResult vkGetSwapchainImagesKHR(device, swapChain, addr(n_images), addr(
      result[0]))

proc destroy*(swapchain: var Swapchain) =
  assert swapchain.vk.valid
  for imageview in swapchain.imageviews.mitems:
    imageview.destroy()
  swapchain.device.vk.vkDestroySwapchainKHR(swapchain.vk, nil)
  swapchain.vk.reset()
