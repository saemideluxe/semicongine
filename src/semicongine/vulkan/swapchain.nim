import std/options
import std/strformat
import std/logging

import ../core
import ./device
import ./physicaldevice
import ./image
import ./framebuffer
import ./commandbuffer
import ./syncing

type
  Swapchain* = object
    device*: Device
    vk*: VkSwapchainKHR
    dimension*: TVec2[uint32]
    nImages*: uint32
    imageviews*: seq[ImageView]
    framebuffers*: seq[Framebuffer]
    currentInFlight*: int
    currentFramebufferIndex: uint32
    framesRendered*: uint64
    queueFinishedFence*: seq[Fence]
    imageAvailableSemaphore*: seq[Semaphore]
    renderFinishedSemaphore*: seq[Semaphore]
    commandBufferPool: CommandBufferPool
    # required for recreation:
    renderPass: VkRenderPass
    surfaceFormat: VkSurfaceFormatKHR
    queueFamily: QueueFamily
    imageCount: uint32
    presentMode: VkPresentModeKHR
    inFlightFrames*: int


proc createSwapchain*(
  device: Device,
  renderPass: VkRenderPass,
  surfaceFormat: VkSurfaceFormatKHR,
  queueFamily: QueueFamily,
  desiredNumberOfImages=3'u32,
  preferedPresentMode: VkPresentModeKHR=VK_PRESENT_MODE_MAILBOX_KHR,
  inFlightFrames=2,
  oldSwapchain=VkSwapchainKHR(0)
): Option[Swapchain] =
  assert device.vk.valid
  assert device.physicalDevice.vk.valid
  assert renderPass.valid
  assert inFlightFrames > 0

  var capabilities = device.physicalDevice.getSurfaceCapabilities()
  if capabilities.currentExtent.width == 0 or capabilities.currentExtent.height == 0:
    return none(Swapchain)

  var imageCount = desiredNumberOfImages

  const PRESENTMODES_BY_PREFERENCE = [
    VK_PRESENT_MODE_MAILBOX_KHR,
    VK_PRESENT_MODE_FIFO_RELAXED_KHR,
    VK_PRESENT_MODE_FIFO_KHR,
    VK_PRESENT_MODE_IMMEDIATE_KHR,
    VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR,
    VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR,
  ]
  var supportedModes = device.physicalDevice.getSurfacePresentModes()
  var presentMode: VkPresentModeKHR
  for mode in PRESENTMODES_BY_PREFERENCE:
    if mode in supportedModes:
      presentMode = mode
      break

  # following is according to vulkan specs
  if presentMode in [VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR, VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR]:
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
    presentMode: presentMode,
    clipped: true,
    oldSwapchain: oldSwapchain,
  )
  var
    swapchain = Swapchain(
      device: device,
      surfaceFormat: surfaceFormat,
      dimension: TVec2[uint32]([capabilities.currentExtent.width, capabilities.currentExtent.height]),
      inFlightFrames: inFlightFrames,
      queueFamily: queueFamily,
      renderPass: renderPass
    )

  if device.vk.vkCreateSwapchainKHR(addr(createInfo), nil, addr(swapchain.vk)) == VK_SUCCESS:
    var nImages: uint32
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), nil)
    swapchain.nImages = nImages
    var images = newSeq[VkImage](nImages)
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), images.toCPointer)
    for vkimage in images:
      let image = GPUImage(vk: vkimage, format: surfaceFormat.format, device: device)
      let imageview = image.createImageView()
      swapChain.imageviews.add imageview
      swapChain.framebuffers.add swapchain.device.createFramebuffer(renderPass, [imageview], swapchain.dimension)
    for i in 0 ..< swapchain.inFlightFrames:
      swapchain.queueFinishedFence.add device.createFence()
      swapchain.imageAvailableSemaphore.add device.createSemaphore()
      swapchain.renderFinishedSemaphore.add device.createSemaphore()
    swapchain.commandBufferPool = device.createCommandBufferPool(queueFamily, swapchain.inFlightFrames)
    debug &"Created swapchain with: {nImages} framebuffers, {inFlightFrames} in-flight frames, {swapchain.dimension.x}x{swapchain.dimension.y}"
    result = some(swapchain)
  else:
    result = none(Swapchain)

proc currentFramebuffer*(swapchain: Swapchain): Framebuffer =
  assert swapchain.device.vk.valid
  assert swapchain.vk.valid
  swapchain.framebuffers[swapchain.currentFramebufferIndex]

proc nextFrame*(swapchain: var Swapchain): Option[VkCommandBuffer] =
  assert swapchain.device.vk.valid
  assert swapchain.vk.valid

  swapchain.currentInFlight = (swapchain.currentInFlight + 1) mod swapchain.inFlightFrames
  swapchain.queueFinishedFence[swapchain.currentInFlight].wait()

  let nextImageResult = swapchain.device.vk.vkAcquireNextImageKHR(
    swapchain.vk,
    high(uint64),
    swapchain.imageAvailableSemaphore[swapchain.currentInFlight].vk,
    VkFence(0),
    addr(swapchain.currentFramebufferIndex)
  )

  if nextImageResult == VK_SUCCESS:
    swapchain.queueFinishedFence[swapchain.currentInFlight].reset()
    result = some(swapchain.commandBufferPool.buffers[swapchain.currentInFlight])
  else:
    result = none(VkCommandBuffer)

proc swap*(swapchain: var Swapchain): bool =
  assert swapchain.device.vk.valid
  assert swapchain.vk.valid
  assert swapchain.device.firstGraphicsQueue().isSome
  assert swapchain.device.firstPresentationQueue().isSome

  var
    commandBuffer = swapchain.commandBufferPool.buffers[swapchain.currentInFlight]
    waitSemaphores = [swapchain.imageAvailableSemaphore[swapchain.currentInFlight].vk]
    waitStages = [VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)]
    submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      waitSemaphoreCount: 1,
      pWaitSemaphores: addr(waitSemaphores[0]),
      pWaitDstStageMask: addr(waitStages[0]),
      commandBufferCount: 1,
      pCommandBuffers: addr(commandBuffer),
      signalSemaphoreCount: 1,
      pSignalSemaphores: addr(swapchain.renderFinishedSemaphore[swapchain.currentInFlight].vk),
    )
  checkVkResult vkQueueSubmit(
    swapchain.device.firstGraphicsQueue().get.vk,
    1,
    addr(submitInfo),
    swapchain.queueFinishedFence[swapchain.currentInFlight].vk
  )

  var presentInfo = VkPresentInfoKHR(
    sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    waitSemaphoreCount: 1,
    pWaitSemaphores: addr(swapchain.renderFinishedSemaphore[swapchain.currentInFlight].vk),
    swapchainCount: 1,
    pSwapchains: addr(swapchain.vk),
    pImageIndices: addr(swapchain.currentFramebufferIndex),
    pResults: nil,
  )
  let presentResult = vkQueuePresentKHR(swapchain.device.firstPresentationQueue().get().vk, addr(presentInfo))
  if presentResult != VK_SUCCESS:
    return false

  inc swapchain.framesRendered
  return true


proc destroy*(swapchain: var Swapchain) =
  assert swapchain.vk.valid
  assert swapchain.commandBufferPool.vk.valid

  for imageview in swapchain.imageviews.mitems:
    assert imageview.vk.valid
    imageview.destroy()
  for framebuffer in swapchain.framebuffers.mitems:
    assert framebuffer.vk.valid
    framebuffer.destroy()
  swapchain.commandBufferPool.destroy()
  for i in 0 ..< swapchain.inFlightFrames:
    assert swapchain.queueFinishedFence[i].vk.valid
    assert swapchain.imageAvailableSemaphore[i].vk.valid
    assert swapchain.renderFinishedSemaphore[i].vk.valid
    swapchain.queueFinishedFence[i].destroy()
    swapchain.imageAvailableSemaphore[i].destroy()
    swapchain.renderFinishedSemaphore[i].destroy()

  swapchain.device.vk.vkDestroySwapchainKHR(swapchain.vk, nil)
  swapchain.vk.reset()

proc recreate*(swapchain: var Swapchain): Option[Swapchain] =
  assert swapchain.vk.valid
  assert swapchain.device.vk.valid
  result = createSwapchain(
    device=swapchain.device,
    renderPass=swapchain.renderPass,
    surfaceFormat=swapchain.surfaceFormat,
    queueFamily=swapchain.queueFamily,
    desiredNumberOfImages=swapchain.imageCount,
    inFlightFrames=swapchain.inFlightFrames,
    oldSwapchain=swapchain.vk,
  )
