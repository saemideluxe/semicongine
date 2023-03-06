import ./api
import ./device
import ./physicaldevice
import ./utils

type
  CommandPool = object
    vk*: VkCommandPool
    family*: QueueFamily
    buffers: seq[VkCommandBuffer]
    device: Device

proc createCommandPool*(device: Device, family: QueueFamily, nBuffers: int): CommandPool =
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

proc destroy*(commandpool: var CommandPool) =
  assert commandpool.device.vk.valid
  assert commandpool.vk.valid
  commandpool.device.vk.vkDestroyCommandPool(commandpool.vk, nil)
  commandpool.vk.reset
