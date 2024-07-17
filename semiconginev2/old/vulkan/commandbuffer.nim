import ../core
import ./device
import ./physicaldevice
import ./syncing

type
  CommandBufferPool* = object
    device: Device
    vk*: VkCommandPool
    family*: QueueFamily
    buffers*: seq[VkCommandBuffer]

proc CreateCommandBufferPool*(device: Device, family: QueueFamily, nBuffers: int): CommandBufferPool =
  assert device.vk.Valid
  var createInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
    queueFamilyIndex: family.index,
  )
  result.family = family
  result.device = device
  checkVkResult device.vk.vkCreateCommandPool(addr createInfo, nil, addr result.vk)

  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: result.vk,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: uint32(nBuffers),
  )
  result.buffers = newSeq[VkCommandBuffer](nBuffers)
  checkVkResult device.vk.vkAllocateCommandBuffers(addr allocInfo, result.buffers.ToCPointer)

proc PipelineBarrier*(
  commandBuffer: VkCommandBuffer,
  srcStages: openArray[VkPipelineStageFlagBits],
  dstStages: openArray[VkPipelineStageFlagBits],
  memoryBarriers: openArray[VkMemoryBarrier] = [],
  bufferMemoryBarriers: openArray[VkBufferMemoryBarrier] = [],
  imageBarriers: openArray[VkImageMemoryBarrier] = [],
) =

  vkCmdPipelineBarrier(
    commandBuffer,
    srcStageMask = srcStages.toBits,
    dstStageMask = dstStages.toBits,
    dependencyFlags = VkDependencyFlags(0),
    memoryBarrierCount = uint32(memoryBarriers.len),
    pMemoryBarriers = memoryBarriers.ToCPointer,
    bufferMemoryBarrierCount = uint32(bufferMemoryBarriers.len),
    pBufferMemoryBarriers = bufferMemoryBarriers.ToCPointer,
    imageMemoryBarrierCount = uint32(imageBarriers.len),
    pImageMemoryBarriers = imageBarriers.ToCPointer,
  )


template WithSingleUseCommandBuffer*(device: Device, queue: Queue, commandBuffer, body: untyped): untyped =
  # TODO? This is super slow, because we call vkQueueWaitIdle
  block:
    assert device.vk.Valid
    assert queue.vk.Valid

    var
      commandBufferPool = CreateCommandBufferPool(device, queue.family, 1)
      commandBuffer = commandBufferPool.buffers[0]
      beginInfo = VkCommandBufferBeginInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
      )
    checkVkResult commandBuffer.vkBeginCommandBuffer(addr beginInfo)

    block:
      body

    checkVkResult commandBuffer.vkEndCommandBuffer()
    var submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      commandBufferCount: 1,
      pCommandBuffers: addr commandBuffer,
    )
    checkVkResult queue.vk.vkQueueSubmit(1, addr submitInfo, VkFence(0))
    checkVkResult queue.vk.vkQueueWaitIdle()
    commandBufferPool.Destroy()


proc Destroy*(commandpool: var CommandBufferPool) =
  assert commandpool.device.vk.Valid
  assert commandpool.vk.Valid
  commandpool.device.vk.vkDestroyCommandPool(commandpool.vk, nil)
  commandpool.vk.Reset

