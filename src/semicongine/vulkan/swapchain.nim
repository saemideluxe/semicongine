import std/tables
import std/options
import std/logging

import ./api
import ./utils
import ./device
import ./physicaldevice
import ./image
import ./buffer
import ./renderpass
import ./descriptor
import ./framebuffer
import ./commandbuffer
import ./pipeline
import ./syncing

import ../scene
import ../entity
import ../gpu_data
import ../math

type
  Swapchain = object
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
    uniformBuffers: Table[VkPipeline, seq[Buffer]]


proc createSwapchain*(
  device: Device,
  renderPass: RenderPass,
  surfaceFormat: VkSurfaceFormatKHR,
  queueFamily: QueueFamily,
  desiredNumberOfImages=3'u32,
  presentationMode: VkPresentModeKHR=VK_PRESENT_MODE_MAILBOX_KHR
): (Swapchain, VkResult) =
  assert device.vk.valid
  assert device.physicalDevice.vk.valid
  assert renderPass.vk.valid
  assert renderPass.inFlightFrames > 0

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
      swapChain.framebuffers.add swapchain.device.createFramebuffer(renderPass, [imageview], swapchain.dimension)
    for i in 0 ..< swapchain.renderPass.inFlightFrames:
      swapchain.queueFinishedFence.add device.createFence()
      swapchain.imageAvailableSemaphore.add device.createSemaphore()
      swapchain.renderFinishedSemaphore.add device.createSemaphore()
    swapchain.commandBufferPool = device.createCommandBufferPool(queueFamily, swapchain.renderPass.inFlightFrames)

  return (swapchain, createResult)

proc setupUniforms(swapChain: var Swapchain, scene: var Scene, pipeline: var Pipeline) =
  assert pipeline.vk.valid
  assert not (pipeline.vk in swapChain.uniformBuffers)

  swapChain.uniformBuffers[pipeline.vk] = @[]

  var uniformBufferSize = 0'u64
  for uniform in pipeline.uniforms:
    uniformBufferSize += uniform.thetype.size

  for i in 0 ..< swapChain.renderPass.inFlightFrames:
    var buffer = pipeline.device.createBuffer(
      size=uniformBufferSize,
      usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
      useVRAM=true,
      mappable=true,
    )
    swapChain.uniformBuffers[pipeline.vk].add buffer
    pipeline.descriptorSets[i].setDescriptorSet(buffer)

proc setupUniforms*(swapChain: var Swapchain, scene: var Scene) =
  for subpass in swapChain.renderPass.subpasses.mitems:
    for pipeline in subpass.pipelines.mitems:
      swapChain.setupUniforms(scene, pipeline)

proc updateUniforms*(swapChain: var Swapchain, scene: Scene, pipeline: Pipeline) =
  assert pipeline.vk.valid
  assert swapChain.uniformBuffers[pipeline.vk][swapChain.currentInFlight].vk.valid

  var globalsByName: Table[string, DataValue]
  for component in allComponentsOfType[ShaderGlobal](scene.root):
    globalsByName[component.name] = component.value

  var offset = 0'u64
  for uniform in pipeline.uniforms:
    assert uniform.thetype == globalsByName[uniform.name].thetype
    let (pdata, size) = globalsByName[uniform.name].getRawData()
    swapChain.uniformBuffers[pipeline.vk][swapChain.currentInFlight].setData(pdata, size, offset)
    offset += size


proc beginRenderCommands*(commandBuffer: VkCommandBuffer, renderpass: RenderPass, framebuffer: Framebuffer) =
  assert commandBuffer.valid
  assert renderpass.vk.valid
  assert framebuffer.vk.valid
  let
    w = framebuffer.dimension.x
    h = framebuffer.dimension.y

  var clearColors: seq[VkClearValue]
  for subpass in renderpass.subpasses:
    clearColors.add(VkClearValue(color: VkClearColorValue(float32: subpass.clearColor)))
  var
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pInheritanceInfo: nil,
    )
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: renderPass.vk,
      framebuffer: framebuffer.vk,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: w, height: h),
      ),
      clearValueCount: uint32(clearColors.len),
      pClearValues: clearColors.toCPointer(),
    )
    viewport = VkViewport(
      x: 0.0,
      y: 0.0,
      width: (float)w,
      height: (float)h,
      minDepth: 0.0,
      maxDepth: 1.0,
    )
    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: VkExtent2D(width: w, height: h)
    )
  checkVkResult commandBuffer.vkResetCommandBuffer(VkCommandBufferResetFlags(0))
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))
  commandBuffer.vkCmdBeginRenderPass(addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)
  commandBuffer.vkCmdSetViewport(firstViewport=0, viewportCount=1, addr(viewport))
  commandBuffer.vkCmdSetScissor(firstScissor=0, scissorCount=1, addr(scissor))

proc endRenderCommands*(commandBuffer: VkCommandBuffer) =
  commandBuffer.vkCmdEndRenderPass()
  checkVkResult commandBuffer.vkEndCommandBuffer()

template renderCommands*(commandBuffer: VkCommandBuffer, renderpass: RenderPass, framebuffer: Framebuffer, body: untyped) =
  commandBuffer.beginRenderCommands(renderpass, framebuffer)
  body
  commandBuffer.endRenderCommands()

proc draw*(commandBuffer: VkCommandBuffer, drawables: seq[Drawable], scene: Scene) =

  debug "Scene buffers:"
  for (location, buffer) in scene.vertexBuffers.pairs:
    echo "  ", location, ": ", buffer
  echo "  Index buffer: ", scene.indexBuffer

  for drawable in drawables:
    debug "Draw ", drawable

    var buffers: seq[VkBuffer]
    var offsets: seq[VkDeviceSize]

    for (location, bufferOffsets) in drawable.bufferOffsets.pairs:
      for offset in bufferOffsets:
        buffers.add scene.vertexBuffers[location].vk
        offsets.add VkDeviceSize(offset)

    commandBuffer.vkCmdBindVertexBuffers(
      firstBinding=0'u32,
      bindingCount=uint32(buffers.len),
      pBuffers=buffers.toCPointer(),
      pOffsets=offsets.toCPointer()
    )
    if drawable.indexed:
      commandBuffer.vkCmdBindIndexBuffer(scene.indexBuffer.vk, VkDeviceSize(drawable.indexBufferOffset), drawable.indexType)
      commandBuffer.vkCmdDrawIndexed(
        indexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstIndex=0,
        vertexOffset=0,
        firstInstance=0
      )
    else:
      commandBuffer.vkCmdDraw(
        vertexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstVertex=0,
        firstInstance=0
      )

proc drawScene*(swapchain: var Swapchain, scene: Scene): bool =
  assert swapchain.device.vk.valid
  assert swapchain.vk.valid
  assert swapchain.device.firstGraphicsQueue().isSome
  assert swapchain.device.firstPresentationQueue().isSome

  swapchain.currentInFlight = (swapchain.currentInFlight + 1) mod swapchain.renderPass.inFlightFrames
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

  renderCommands(
    commandBuffer,
    swapchain.renderpass,
    swapchain.framebuffers[currentFramebufferIndex]
  ):
    for i in 0 ..< swapchain.renderpass.subpasses.len:
      for pipeline in swapchain.renderpass.subpasses[i].pipelines.mitems:
        commandBuffer.vkCmdBindPipeline(swapchain.renderpass.subpasses[i].pipelineBindPoint, pipeline.vk)
        commandBuffer.vkCmdBindDescriptorSets(swapchain.renderpass.subpasses[i].pipelineBindPoint, pipeline.layout, 0, 1, addr(pipeline.descriptorSets[swapchain.currentInFlight].vk), 0, nil)
        swapchain.updateUniforms(scene, pipeline)
        commandBuffer.draw(scene.getDrawables(pipeline), scene)
      if i < swapchain.renderpass.subpasses.len - 1:
        commandBuffer.vkCmdNextSubpass(VK_SUBPASS_CONTENTS_INLINE)

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
  for i in 0 ..< swapchain.renderPass.inFlightFrames:
    assert swapchain.queueFinishedFence[i].vk.valid
    assert swapchain.imageAvailableSemaphore[i].vk.valid
    assert swapchain.renderFinishedSemaphore[i].vk.valid
    swapchain.queueFinishedFence[i].destroy()
    swapchain.imageAvailableSemaphore[i].destroy()
    swapchain.renderFinishedSemaphore[i].destroy()
  for buffers in swapchain.uniformBuffers.mvalues:
    for buffer in buffers.mitems:
      buffer.destroy()

  swapchain.device.vk.vkDestroySwapchainKHR(swapchain.vk, nil)
  swapchain.vk.reset()
