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

proc CreateSemaphore*(device: Device): Semaphore =
  assert device.vk.Valid
  var semaphoreInfo = VkSemaphoreCreateInfo(sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO)
  result.device = device
  checkVkResult device.vk.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result.vk))

proc CreateFence*(device: Device, awaitAction: proc() = nil): Fence =
  assert device.vk.Valid
  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: toBits [VK_FENCE_CREATE_SIGNALED_BIT]
  )
  result.device = device
  result.awaitAction = awaitAction
  checkVkResult device.vk.vkCreateFence(addr(fenceInfo), nil, addr(result.vk))

proc Await*(fence: var Fence) =
  assert fence.device.vk.Valid
  assert fence.vk.Valid
  checkVkResult vkWaitForFences(fence.device.vk, 1, addr fence.vk, false, high(uint64))
  if fence.awaitAction != nil:
    fence.awaitAction()

proc Reset*(fence: var Fence) =
  assert fence.device.vk.Valid
  assert fence.vk.Valid
  checkVkResult fence.device.vk.vkResetFences(1, addr fence.vk)

proc Destroy*(semaphore: var Semaphore) =
  assert semaphore.device.vk.Valid
  assert semaphore.vk.Valid
  semaphore.device.vk.vkDestroySemaphore(semaphore.vk, nil)
  semaphore.vk.Reset

proc Destroy*(fence: var Fence) =
  assert fence.device.vk.Valid
  assert fence.vk.Valid
  fence.device.vk.vkDestroyFence(fence.vk, nil)
  fence.vk.Reset
