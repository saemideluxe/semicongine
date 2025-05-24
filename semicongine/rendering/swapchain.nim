import std/options

import ../core
import ./vulkan_wrappers

proc initSwapchain(
    renderPass: RenderPass,
    vSync: bool,
    tripleBuffering: bool,
    oldSwapchain: Swapchain = nil,
): Swapchain =
  var capabilities: VkSurfaceCapabilitiesKHR
  checkVkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    engine().vulkan.physicalDevice, engine().vulkan.surface, addr(capabilities)
  )
  let
    width = capabilities.currentExtent.width
    height = capabilities.currentExtent.height

  if width == 0 or height == 0:
    return nil

  # following "count" is established according to vulkan specs
  var minFramebufferCount = if tripleBuffering: 3'u32 else: 2'u32
  minFramebufferCount = max(minFramebufferCount, capabilities.minImageCount)
  if capabilities.maxImageCount != 0:
    minFramebufferCount = min(minFramebufferCount, capabilities.maxImageCount)

  # create swapchain
  let hasTripleBuffering =
    VK_PRESENT_MODE_MAILBOX_KHR in svkGetPhysicalDeviceSurfacePresentModesKHR()
  var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: engine().vulkan.surface,
    minImageCount: minFramebufferCount,
    imageFormat: SURFACE_FORMAT,
    imageColorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
      # only one supported without special extensions
    imageExtent: capabilities.currentExtent,
    imageArrayLayers: 1,
    imageUsage: toBits [VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    presentMode:
      if (vSync or not hasTripleBuffering):
        VK_PRESENT_MODE_FIFO_KHR
      else:
        VK_PRESENT_MODE_MAILBOX_KHR,
    clipped: true,
    oldSwapchain:
      if oldSwapchain != nil:
        oldSwapchain.vk
      else:
        VkSwapchainKHR(0),
  )
  var swapchain = Swapchain(
    width: width,
    height: height,
    renderPass: renderPass,
    vSync: vSync,
    tripleBuffering: tripleBuffering,
    oldSwapchain: oldSwapchain,
  )

  if vkCreateSwapchainKHR(
    engine().vulkan.device, addr(swapchainCreateInfo), nil, addr(swapchain.vk)
  ) != VK_SUCCESS:
    return nil

  if swapchain.oldSwapchain != nil:
    swapchain.oldSwapchainCounter = INFLIGHTFRAMES.int * 2

  # create depth buffer image+view if desired
  if renderPass.depthBuffer:
    swapchain.depthImage = svkCreate2DImage(
      width = width,
      height = height,
      format = DEPTH_FORMAT,
      usage = [VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT],
      samples = renderPass.samples,
    )
    let requirements = svkGetImageMemoryRequirements(swapchain.depthImage)
    swapchain.depthMemory = svkAllocateMemory(
      requirements.size, bestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(
      engine().vulkan.device, swapchain.depthImage, swapchain.depthMemory, 0
    )
    swapchain.depthImageView = svkCreate2DImageView(
      image = swapchain.depthImage,
      format = DEPTH_FORMAT,
      aspect = VK_IMAGE_ASPECT_DEPTH_BIT,
    )

  # create msaa image+view if desired
  if renderPass.samples != VK_SAMPLE_COUNT_1_BIT:
    swapchain.msaaImage = svkCreate2DImage(
      width = width,
      height = height,
      format = SURFACE_FORMAT,
      usage =
        [VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
      samples = renderPass.samples,
    )
    let requirements = svkGetImageMemoryRequirements(swapchain.msaaImage)
    swapchain.msaaMemory = svkAllocateMemory(
      requirements.size, bestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(
      engine().vulkan.device, swapchain.msaaImage, swapchain.msaaMemory, 0
    )
    swapchain.msaaImageView =
      svkCreate2DImageView(image = swapchain.msaaImage, format = SURFACE_FORMAT)

  # create framebuffers
  var actualNFramebuffers: uint32
  checkVkResult vkGetSwapchainImagesKHR(
    engine().vulkan.device, swapchain.vk, addr(actualNFramebuffers), nil
  )
  var framebuffers = newSeq[VkImage](actualNFramebuffers)
  checkVkResult vkGetSwapchainImagesKHR(
    engine().vulkan.device,
    swapchain.vk,
    addr(actualNFramebuffers),
    framebuffers.ToCPointer,
  )

  for framebuffer in framebuffers:
    swapchain.framebufferViews.add svkCreate2DImageView(framebuffer, SURFACE_FORMAT)
    var attachments: seq[VkImageView]
    if renderPass.samples == VK_SAMPLE_COUNT_1_BIT:
      if renderPass.depthBuffer:
        attachments = @[swapchain.framebufferViews[^1], swapchain.depthImageView]
      else:
        attachments = @[swapchain.framebufferViews[^1]]
    else:
      if renderPass.depthBuffer:
        attachments =
          @[
            swapchain.msaaImageView,
            swapchain.depthImageView,
            swapchain.framebufferViews[^1],
          ]
      else:
        attachments = @[swapchain.msaaImageView, swapchain.framebufferViews[^1]]

    swapchain.framebuffers.add svkCreateFramebuffer(
      renderpass = renderPass.vk,
      width = width,
      height = height,
      attachments = attachments,
    )

  # create sync primitives
  for i in 0 ..< INFLIGHTFRAMES:
    swapchain.queueFinishedFence[i] = svkCreateFence(signaled = true)
    swapchain.imageAvailableSemaphore[i] = svkCreateSemaphore()
    swapchain.renderFinishedSemaphore[i] = svkCreateSemaphore()

  # command buffers
  var commandPoolCreateInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
    queueFamilyIndex: engine().vulkan.graphicsQueueFamily,
  )
  checkVkResult vkCreateCommandPool(
    engine().vulkan.device,
    addr(commandPoolCreateInfo),
    nil,
    addr(swapchain.commandBufferPool),
  )
  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: swapchain.commandBufferPool,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: INFLIGHTFRAMES,
  )
  checkVkResult vkAllocateCommandBuffers(
    engine().vulkan.device, addr(allocInfo), swapchain.commandBuffers.ToCPointer
  )

  return swapchain

proc destroySwapchain*(swapchain: Swapchain) =
  if swapchain.oldSwapchain != nil:
    destroySwapchain(swapchain.oldSwapchain)

  if swapchain.msaaImage.Valid:
    vkDestroyImageView(engine().vulkan.device, swapchain.msaaImageView, nil)
    vkDestroyImage(engine().vulkan.device, swapchain.msaaImage, nil)
    vkFreeMemory(engine().vulkan.device, swapchain.msaaMemory, nil)

  if swapchain.depthImage.Valid:
    vkDestroyImageView(engine().vulkan.device, swapchain.depthImageView, nil)
    vkDestroyImage(engine().vulkan.device, swapchain.depthImage, nil)
    vkFreeMemory(engine().vulkan.device, swapchain.depthMemory, nil)

  for fence in swapchain.queueFinishedFence:
    vkDestroyFence(engine().vulkan.device, fence, nil)

  for semaphore in swapchain.imageAvailableSemaphore:
    vkDestroySemaphore(engine().vulkan.device, semaphore, nil)

  for semaphore in swapchain.renderFinishedSemaphore:
    vkDestroySemaphore(engine().vulkan.device, semaphore, nil)

  for imageView in swapchain.framebufferViews:
    vkDestroyImageView(engine().vulkan.device, imageView, nil)

  for framebuffer in swapchain.framebuffers:
    vkDestroyFramebuffer(engine().vulkan.device, framebuffer, nil)

  vkDestroyCommandPool(engine().vulkan.device, swapchain.commandBufferPool, nil)

  vkDestroySwapchainKHR(engine().vulkan.device, swapchain.vk, nil)

proc tryAcquireNextImage(swapchain: Swapchain): Option[VkFramebuffer] =
  if not swapchain.queueFinishedFence[swapchain.currentFiF].await(100_000_000):
    return none(VkFramebuffer)

  let nextImageResult = vkAcquireNextImageKHR(
    engine().vulkan.device,
    swapchain.vk,
    # high(uint64),
    10_000_000'u64, # wait max 10ms
    swapchain.imageAvailableSemaphore[swapchain.currentFiF],
    VkFence(0),
    addr(swapchain.currentFramebufferIndex),
  )

  swapchain.queueFinishedFence[swapchain.currentFiF].svkResetFences()

  if nextImageResult != VK_SUCCESS:
    return none(VkFramebuffer)
  return some(swapchain.framebuffers[swapchain.currentFramebufferIndex])

proc swap(swapchain: Swapchain, commandBuffer: VkCommandBuffer): bool =
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
    queue = engine().vulkan.graphicsQueue,
    submitCount = 1,
    pSubmits = addr(submitInfo),
    fence = swapchain.queueFinishedFence[swapchain.currentFiF],
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
  let presentResult =
    vkQueuePresentKHR(engine().vulkan.graphicsQueue, addr(presentInfo))

  if swapchain.oldSwapchain != nil:
    dec swapchain.oldSwapchainCounter
    if swapchain.oldSwapchainCounter <= 0:
      destroySwapchain(swapchain.oldSwapchain)
      swapchain.oldSwapchain = nil

  if presentResult != VK_SUCCESS:
    return false

  swapchain.currentFiF = (uint32(swapchain.currentFiF) + 1) mod INFLIGHTFRAMES
  return true

# for re-creation with same settings, e.g. window resized
proc recreateSwapchain*() =
  let newSwapchain = initSwapchain(
    renderPass = engine().vulkan.swapchain.renderPass,
    vSync = engine().vulkan.swapchain.vSync,
    tripleBuffering = engine().vulkan.swapchain.tripleBuffering,
    oldSwapchain = engine().vulkan.swapchain,
  )
  if newSwapchain != nil:
    engine().vulkan.swapchain = newSwapchain

# for re-creation with different settings
proc recreateSwapchain*(vSync: bool, tripleBuffering: bool) =
  let newSwapchain = initSwapchain(
    renderPass = engine().vulkan.swapchain.renderPass,
    vSync = vSync,
    tripleBuffering = tripleBuffering,
    oldSwapchain = engine().vulkan.swapchain,
  )
  if newSwapchain != nil:
    engine().vulkan.swapchain = newSwapchain

template withNextFrame*(framebufferName, commandBufferName, body: untyped): untyped =
  var maybeFramebuffer = tryAcquireNextImage(engine().vulkan.swapchain)
  if maybeFramebuffer.isSome:
    block:
      let `framebufferName` {.inject.} = maybeFramebuffer.get
      let `commandBufferName` {.inject.} =
        engine().vulkan.swapchain.commandBuffers[engine().vulkan.swapchain.currentFiF]
      let beginInfo = VkCommandBufferBeginInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
      )
      checkVkResult vkResetCommandBuffer(
        `commandBufferName`, VkCommandBufferResetFlags(0)
      )
      checkVkResult vkBeginCommandBuffer(`commandBufferName`, addr(beginInfo))

      body

      checkVkResult vkEndCommandBuffer(`commandBufferName`)
      discard
        swap(swapchain = engine().vulkan.swapchain, commandBuffer = `commandBufferName`)
  else:
    recreateSwapchain()

proc clearSwapchain*() =
  assert engine().vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  destroySwapchain(engine().vulkan.swapchain)
  engine().vulkan.swapchain = nil

proc setupSwapchain*(renderPass: RenderPass, vSync: bool, tripleBuffering: bool) =
  assert engine().vulkan.swapchain == nil, "Swapchain has already been initialized yet"
  engine().vulkan.swapchain =
    initSwapchain(renderPass, vSync = vSync, tripleBuffering = tripleBuffering)

proc frameWidth*(): uint32 =
  engine().vulkan.swapchain.width

proc frameHeight*(): uint32 =
  engine().vulkan.swapchain.height
