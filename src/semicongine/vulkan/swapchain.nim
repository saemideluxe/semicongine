import std/options
import std/logging

import ./api
import ./utils
import ./device
import ./physicaldevice
import ./image
import ./renderpass
import ./framebuffer
import ./commandbuffer
import ./syncing

import ../scene
import ../math

type
  Swapchain* = object
    device*: Device
    vk*: VkSwapchainKHR
    format*: VkFormat
    dimension*: TVec2[uint32]
    renderPass*: RenderPass
    nImages*: uint32
    imageviews*: seq[ImageView]
    framebuffers*: seq[Framebuffer]
    currentInFlight*: int
    framesRendered*: int
    queueFinishedFence: seq[Fence]
    imageAvailableSemaphore*: seq[Semaphore]
    renderFinishedSemaphore*: seq[Semaphore]
    commandBufferPool: CommandBufferPool
    inFlightFrames: int


proc createSwapchain*(
  device: Device,
  renderPass: RenderPass,
  surfaceFormat: VkSurfaceFormatKHR,
  queueFamily: QueueFamily,
  desiredNumberOfImages=3'u32,
  presentationMode: VkPresentModeKHR=VK_PRESENT_MODE_MAILBOX_KHR,
  inFlightFrames=2
): (Swapchain, VkResult) =
  assert device.vk.valid
  assert device.physicalDevice.vk.valid
  assert renderPass.vk.valid
  assert inFlightFrames > 0

  var capabilities = device.physicalDevice.getSurfaceCapabilities()

  var imageCount = desiredNumberOfImages
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
      dimension: TVec2[uint32]([capabilities.currentExtent.width, capabilities.currentExtent.height]),
      renderPass: renderPass,
      inFlightFrames: inFlightFrames
    )
    createResult = device.vk.vkCreateSwapchainKHR(addr(createInfo), nil, addr(swapchain.vk))

  if createResult == VK_SUCCESS:
    var nImages: uint32
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), nil)
    swapchain.nImages = nImages
    var images = newSeq[VkImage](nImages)
    checkVkResult device.vk.vkGetSwapchainImagesKHR(swapChain.vk, addr(nImages), images.toCPointer)
    for vkimage in images:
      let image = Image(vk: vkimage, format: surfaceFormat.format, device: device)
      let imageview = image.createImageView()
      swapChain.imageviews.add imageview
      swapChain.framebuffers.add swapchain.device.createFramebuffer(renderPass.vk, [imageview], swapchain.dimension)
    for i in 0 ..< swapchain.inFlightFrames:
      swapchain.queueFinishedFence.add device.createFence()
      swapchain.imageAvailableSemaphore.add device.createSemaphore()
      swapchain.renderFinishedSemaphore.add device.createSemaphore()
    swapchain.commandBufferPool = device.createCommandBufferPool(queueFamily, swapchain.inFlightFrames)

  return (swapchain, createResult)


proc drawScene*(swapchain: var Swapchain, scene: Scene): bool =
  assert swapchain.device.vk.valid
  assert swapchain.vk.valid
  assert swapchain.device.firstGraphicsQueue().isSome
  assert swapchain.device.firstPresentationQueue().isSome

  swapchain.currentInFlight = (swapchain.currentInFlight + 1) mod swapchain.inFlightFrames
  swapchain.queueFinishedFence[swapchain.currentInFlight].wait()

  var currentFramebufferIndex: uint32

  let nextImageResult = swapchain.device.vk.vkAcquireNextImageKHR(
    swapchain.vk,
    high(uint64),
    swapchain.imageAvailableSemaphore[swapchain.currentInFlight].vk,
    VkFence(0),
    addr(currentFramebufferIndex)
  )
  if not (nextImageResult in [VK_SUCCESS, VK_TIMEOUT, VK_NOT_READY, VK_SUBOPTIMAL_KHR]):
    return false

  swapchain.queueFinishedFence[swapchain.currentInFlight].reset()

  var commandBuffer = swapchain.commandBufferPool.buffers[swapchain.currentInFlight]
  commandBuffer.draw(renderPass=swapchain.renderPass, framebuffer=swapchain.framebuffers[currentFramebufferIndex], rootEntity=scene.root, drawables=scene.drawables, vertexBuffers=scene.vertexBuffers, indexBuffer=scene.indexBuffer, currentInFlight=swapchain.currentInFlight)

  var
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
    pImageIndices: addr(currentFramebufferIndex),
    pResults: nil,
  )
  let presentResult = vkQueuePresentKHR(swapchain.device.firstPresentationQueue().get().vk, addr(presentInfo))
  if not (presentResult in [VK_SUCCESS, VK_SUBOPTIMAL_KHR]):
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
