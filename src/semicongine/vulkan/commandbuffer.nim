import ./api
import ./device
import ./physicaldevice
import ./renderpass
import ./framebuffer
import ./utils

import ../math

type
  CommandBufferPool* = object
    vk*: VkCommandPool
    family*: QueueFamily
    buffers*: seq[VkCommandBuffer]
    device: Device

proc createCommandBufferPool*(device: Device, family: QueueFamily, nBuffers: int): CommandBufferPool =
  assert device.vk.valid
  var createInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
    queueFamilyIndex: family.index,
  )
  result.family = family
  result.device = device
  checkVkResult device.vk.vkCreateCommandPool(addr(createInfo), nil, addr(result.vk))

  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: result.vk,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: uint32(nBuffers),
  )
  result.buffers = newSeq[VkCommandBuffer](nBuffers)
  checkVkResult device.vk.vkAllocateCommandBuffers(addr(allocInfo), result.buffers.toCPointer)

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


proc destroy*(commandpool: var CommandBufferPool) =
  assert commandpool.device.vk.valid
  assert commandpool.vk.valid
  commandpool.device.vk.vkDestroyCommandPool(commandpool.vk, nil)
  commandpool.vk.reset
