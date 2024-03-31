import ../core
import ./device

type
  Semaphore* = object
    vk*: VkSemaphore
    device: Device
  Fence* = object
    vk*: VkFence
    device: Device
    awaitAction: proc() = nil

proc createSemaphore*(device: Device): Semaphore =
  assert device.vk.valid
  var semaphoreInfo = VkSemaphoreCreateInfo(sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO)
  result.device = device
  checkVkResult device.vk.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result.vk))

proc createFence*(device: Device, awaitAction: proc() = nil): Fence =
  assert device.vk.valid
  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: toBits [VK_FENCE_CREATE_SIGNALED_BIT]
  )
  result.device = device
  result.awaitAction = awaitAction
  checkVkResult device.vk.vkCreateFence(addr(fenceInfo), nil, addr(result.vk))

proc await*(fence: var Fence) =
  assert fence.device.vk.valid
  assert fence.vk.valid
  checkVkResult vkWaitForFences(fence.device.vk, 1, addr fence.vk, false, high(uint64))
  if fence.awaitAction != nil:
    fence.awaitAction()

proc reset*(fence: var Fence) =
  assert fence.device.vk.valid
  assert fence.vk.valid
  checkVkResult fence.device.vk.vkResetFences(1, addr fence.vk)

proc destroy*(semaphore: var Semaphore) =
  assert semaphore.device.vk.valid
  assert semaphore.vk.valid
  semaphore.device.vk.vkDestroySemaphore(semaphore.vk, nil)
  semaphore.vk.reset

proc destroy*(fence: var Fence) =
  assert fence.device.vk.valid
  assert fence.vk.valid
  fence.device.vk.vkDestroyFence(fence.vk, nil)
  fence.vk.reset
