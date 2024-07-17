const N_FRAMEBUFFERS = 3'u32

proc InitSwapchain*(
  renderPass: VkRenderPass,
  vSync: bool = false,
  samples = VK_SAMPLE_COUNT_1_BIT,
  oldSwapchain: ref Swapchain = nil,
): Option[Swapchain] =
  assert vulkan.instance.Valid, "Vulkan not initialized"

  var capabilities: VkSurfaceCapabilitiesKHR
  checkVkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vulkan.physicalDevice, vulkan.surface, addr(capabilities))
  let
    format = DefaultSurfaceFormat()
    width = capabilities.currentExtent.width
    height = capabilities.currentExtent.height

  if width == 0 or height == 0:
    return none(Swapchain)

  # following "count" is established according to vulkan specs
  var minFramebufferCount = N_FRAMEBUFFERS
  minFramebufferCount = max(minFramebufferCount, capabilities.minImageCount)
  if capabilities.maxImageCount != 0:
    minFramebufferCount = min(minFramebufferCount, capabilities.maxImageCount)

  # create swapchain
  let hasTripleBuffering = VK_PRESENT_MODE_MAILBOX_KHR in svkGetPhysicalDeviceSurfacePresentModesKHR()
  var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: vulkan.surface,
    minImageCount: minFramebufferCount,
    imageFormat: format,
    imageColorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR, # only one supported without special extensions
    imageExtent: capabilities.currentExtent,
    imageArrayLayers: 1,
    imageUsage: toBits [VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,  # only used for blending with other windows, can be opaque
    presentMode: if (vSync or not hasTripleBuffering): VK_PRESENT_MODE_FIFO_KHR else: VK_PRESENT_MODE_MAILBOX_KHR,
    clipped: true,
    oldSwapchain: if oldSwapchain != nil: oldSwapchain.vk else: VkSwapchainKHR(0),
  )
  var swapchain: Swapchain
  if vkCreateSwapchainKHR(vulkan.device, addr(swapchainCreateInfo), nil, addr(swapchain.vk)) != VK_SUCCESS:
    return none(Swapchain)

  swapchain.width = width
  swapchain.height = height
  swapchain.renderPass = renderPass
  swapchain.vSync = vSync
  swapchain.samples = samples
  swapchain.oldSwapchain = oldSwapchain
  if swapchain.oldSwapchain != nil:
    swapchain.oldSwapchainCounter = INFLIGHTFRAMES.int * 2

  # create msaa image+view if desired
  if samples != VK_SAMPLE_COUNT_1_BIT:
    swapchain.msaaImage = svkCreate2DImage(
      width = width,
      height = height,
      format = format,
      usage = [VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
      samples = samples,
    )
    let requirements = svkGetImageMemoryRequirements(swapchain.msaaImage)
    swapchain.msaaMemory = svkAllocateMemory(
      requirements.size,
      BestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(
      vulkan.device,
      swapchain.msaaImage,
      swapchain.msaaMemory,
      0,
    )
    swapchain.msaaImageView = svkCreate2DImageView(swapchain.msaaImage, format)

  # create framebuffers
  var actualNFramebuffers: uint32
  checkVkResult vkGetSwapchainImagesKHR(vulkan.device, swapchain.vk, addr(actualNFramebuffers), nil)
  var framebuffers = newSeq[VkImage](actualNFramebuffers)
  checkVkResult vkGetSwapchainImagesKHR(vulkan.device, swapchain.vk, addr(actualNFramebuffers), framebuffers.ToCPointer)

  for framebuffer in framebuffers:
    swapchain.framebufferViews.add svkCreate2DImageView(framebuffer, format)
    if samples == VK_SAMPLE_COUNT_1_BIT:
      swapchain.framebuffers.add svkCreateFramebuffer(renderPass, width, height, [swapchain.framebufferViews[^1]])
    else:
      swapchain.framebuffers.add svkCreateFramebuffer(renderPass, width, height, [swapchain.msaaImageView, swapchain.framebufferViews[^1]])

  # create sync primitives
  for i in 0 ..< INFLIGHTFRAMES:
    swapchain.queueFinishedFence[i] = svkCreateFence(signaled = true)
    swapchain.imageAvailableSemaphore[i] = svkCreateSemaphore()
    swapchain.renderFinishedSemaphore[i] = svkCreateSemaphore()

  # command buffers
  var commandPoolCreateInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
    queueFamilyIndex: vulkan.graphicsQueueFamily,
  )
  checkVkResult vkCreateCommandPool(vulkan.device, addr(commandPoolCreateInfo), nil, addr(swapchain.commandBufferPool))
  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: swapchain.commandBufferPool,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: INFLIGHTFRAMES,
  )
  checkVkResult vkAllocateCommandBuffers(vulkan.device, addr(allocInfo), swapchain.commandBuffers.ToCPointer)

  return some(swapchain)

proc DestroySwapchain*(swapchain: Swapchain) =

  if swapchain.samples != VK_SAMPLE_COUNT_1_BIT:
    vkDestroyImageView(vulkan.device, swapchain.msaaImageView, nil)
    vkDestroyImage(vulkan.device, swapchain.msaaImage, nil)
    vkFreeMemory(vulkan.device, swapchain.msaaMemory, nil)

  for fence in swapchain.queueFinishedFence:
    vkDestroyFence(vulkan.device, fence, nil)

  for semaphore in swapchain.imageAvailableSemaphore:
    vkDestroySemaphore(vulkan.device, semaphore, nil)

  for semaphore in swapchain.renderFinishedSemaphore:
    vkDestroySemaphore(vulkan.device, semaphore, nil)

  for imageView in swapchain.framebufferViews:
    vkDestroyImageView(vulkan.device, imageView, nil)

  for framebuffer in swapchain.framebuffers:
    vkDestroyFramebuffer(vulkan.device, framebuffer, nil)

  vkDestroyCommandPool(vulkan.device, swapchain.commandBufferPool, nil)

  vkDestroySwapchainKHR(vulkan.device, swapchain.vk, nil)

proc TryAcquireNextImage(swapchain: var Swapchain): Option[VkFramebuffer] =
  if not swapchain.queueFinishedFence[swapchain.currentFiF].Await(100_000_000):
    return none(VkFramebuffer)

  let nextImageResult = vkAcquireNextImageKHR(
    vulkan.device,
    swapchain.vk,
    high(uint64),
    swapchain.imageAvailableSemaphore[swapchain.currentFiF],
    VkFence(0),
    addr(swapchain.currentFramebufferIndex),
  )

  swapchain.queueFinishedFence[swapchain.currentFiF].svkResetFences()

  if nextImageResult != VK_SUCCESS:
    return none(VkFramebuffer)
  return some(swapchain.framebuffers[swapchain.currentFramebufferIndex])

proc Swap(swapchain: var Swapchain, commandBuffer: VkCommandBuffer): bool =
  var
    waitStage = VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
    submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      waitSemaphoreCount: 1,
      pWaitSemaphores: addr(swapchain.imageAvailableSemaphore[swapchain.currentFiF]),
      pWaitDstStageMask: addr(waitStage),
      commandBufferCount: 1,
      pCommandBuffers: addr(commandBuffer),
      signalSemaphoreCount: 1,
      pSignalSemaphores: addr(swapchain.renderFinishedSemaphore[swapchain.currentFiF]),
    )
  checkVkResult vkQueueSubmit(
    queue = vulkan.graphicsQueue,
    submitCount = 1,
    pSubmits = addr(submitInfo),
    fence = swapchain.queueFinishedFence[swapchain.currentFiF]
  )

  var presentInfo = VkPresentInfoKHR(
    sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    waitSemaphoreCount: 1,
    pWaitSemaphores: addr(swapchain.renderFinishedSemaphore[swapchain.currentFiF]),
    swapchainCount: 1,
    pSwapchains: addr(swapchain.vk),
    pImageIndices: addr(swapchain.currentFramebufferIndex),
    pResults: nil,
  )
  let presentResult = vkQueuePresentKHR(vulkan.graphicsQueue, addr(presentInfo))

  if swapchain.oldSwapchain != nil:
    dec swapchain.oldSwapchainCounter
    if swapchain.oldSwapchainCounter <= 0:
      DestroySwapchain(swapchain.oldSwapchain[])
      swapchain.oldSwapchain = nil

  if presentResult != VK_SUCCESS:
    return false

  swapchain.currentFiF = (uint32(swapchain.currentFiF) + 1) mod INFLIGHTFRAMES
  return true

proc Recreate(swapchain: Swapchain): Option[Swapchain] =
  var oldSwapchain = new Swapchain
  oldSwapchain[] = swapchain
  InitSwapchain(
    renderPass = swapchain.renderPass,
    vSync = swapchain.vSync,
    samples = swapchain.samples,
    oldSwapchain = oldSwapchain,
  )

template WithNextFrame*(swapchain: var Swapchain, framebufferName, commandBufferName, body: untyped): untyped =
  var maybeFramebuffer = TryAcquireNextImage(swapchain)
  if maybeFramebuffer.isSome:
    block:
      let `framebufferName` {.inject.} = maybeFramebuffer.get
      let `commandBufferName` {.inject.} = swapchain.commandBuffers[swapchain.currentFiF]
      let beginInfo = VkCommandBufferBeginInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
      )
      checkVkResult vkResetCommandBuffer(`commandBufferName`, VkCommandBufferResetFlags(0))
      checkVkResult vkBeginCommandBuffer(`commandBufferName`, addr(beginInfo))

      body

      checkVkResult vkEndCommandBuffer(`commandBufferName`)
      discard Swap(swapchain = swapchain, commandBuffer = `commandBufferName`)
  else:
    let maybeNewSwapchain = Recreate(swapchain)
    if maybeNewSwapchain.isSome:
      swapchain = maybeNewSwapchain.get

