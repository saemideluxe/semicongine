import ../core
import ./device
import ./physicaldevice

type
  CommandBufferPool* = object
    device: Device
    vk*: VkCommandPool
    family*: QueueFamily
    buffers*: seq[VkCommandBuffer]

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


template withSingleUseCommandBuffer*(device: Device, needsTransfer: bool, commandBuffer, body: untyped): untyped =
  assert device.vk.valid

  var queue: Queue
  for q in device.queues.values:
    if q.family.canDoTransfer or not needsTransfer:
      queue = q
      break
  if not queue.vk.valid:
    raise newException(Exception, "No queue that supports buffer transfer")

  var
    commandBufferPool = createCommandBufferPool(device, queue.family, 1)
    commandBuffer = commandBufferPool.buffers[0]
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
    )
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))

  block:
    body

  checkVkResult commandBuffer.vkEndCommandBuffer()
  var submitInfo = VkSubmitInfo(
    sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
    commandBufferCount: 1,
    pCommandBuffers: addr(commandBuffer),
  )
  checkVkResult queue.vk.vkQueueSubmit(1, addr(submitInfo), VkFence(0))
  checkVkResult queue.vk.vkQueueWaitIdle()
  commandBufferPool.destroy()

proc destroy*(commandpool: var CommandBufferPool) =
  assert commandpool.device.vk.valid
  assert commandpool.vk.valid
  commandpool.device.vk.vkDestroyCommandPool(commandpool.vk, nil)
  commandpool.vk.reset
