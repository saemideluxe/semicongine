const N_FRAMEBUFFERS = 3'32

proc svkCreateSwapchainKHR(vSync: bool, oldSwapchain = VkSwapchainKHR(0)): VkSwapchainKHR =

  var capabilities: VkSurfaceCapabilitiesKHR
  checkVkResult device.vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vulkan.surface, addr(capabilities))

  if capabilities.currentExtent.width == 0 or capabilities.currentExtent.height == 0:
    return VkSwapchainKHR(0)

  # following is according to vulkan specs
  var minFramebufferCount = N_FRAMEBUFFERS
  minFramebufferCount = max(minFramebufferCount, capabilities.minImageCount)
  if capabilities.maxImageCount != 0:
    minFramebufferCount = min(minFramebufferCount, capabilities.maxImageCount)

  svkGetPhysicalDeviceSurfaceFormatsKHR()

  let hasTripleBuffering = VK_PRESENT_MODE_MAILBOX_KHR in svkGetPhysicalDeviceSurfacePresentModesKHR()
  var createInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: device.physicalDevice.surface,
    minImageCount: minFramebufferCount,
    imageFormat: DefaultSurfaceFormat(),
    imageColorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR, # only one supported without special extensions
    imageExtent: capabilities.currentExtent,
    imageArrayLayers: 1,
    imageUsage: toBits [VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,  # only used for blending with other windows, can be opaque
    presentMode: if (vSync or not hasTripleBuffering): VK_PRESENT_MODE_FIFO_KHR else: VK_PRESENT_MODE_MAILBOX_KHR,
    clipped: true,
    oldSwapchain: oldSwapchain,
  )
  if device.vk.vkCreateSwapchainKHR(addr(createInfo), nil, addr(result)) != VK_SUCCESS:
    return VkSwapchainKHR(0)

  if samples != VK_SAMPLE_COUNT_1_BIT:
    vulkan.msaaImage = svkCreate2DImage(
      width = capabilities.currentExtent.width,
      height = capabilities.currentExtent.height,
      format = DefaultSurfaceFormat(),
      usage = [VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
    )
    # TODO: memory
    vk: svkAllocateMemory(size, mType),
    checkVkResult vkBindImageMemory(
      vulkan.device,
      vulkan.msaaImage,
      selectedBlock.vk,
      0,
    )



    vulkan.msaaImageView = svkCreate2DImageView(vulkan.msaaImageView, DefaultSurfaceFormat())
