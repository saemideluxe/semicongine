import ./api
import ./device

type
  Semaphore* = object
    vk*: VkSemaphore
    device: Device
  Fence* = object
    vk*: VkFence
    device: Device

proc createSemaphore*(device: Device): Semaphore =
  assert device.vk.valid
  var semaphoreInfo = VkSemaphoreCreateInfo(sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO)
  result.device = device
  checkVkResult device.vk.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result.vk))

proc createFence*(device: Device): Fence =
  assert device.vk.valid
  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: toBits [VK_FENCE_CREATE_SIGNALED_BIT]
  )
  result.device = device
  checkVkResult device.vk.vkCreateFence(addr(fenceInfo), nil, addr(result.vk))

proc wait*(fence: Fence) =
  assert fence.device.vk.valid
  assert fence.vk.valid
  var varFence = fence.vk
  checkVkResult vkWaitForFences(fence.device.vk, 1, addr(varFence), false, high(uint64))

proc reset*(fence: Fence) =
  assert fence.device.vk.valid
  assert fence.vk.valid
  var varFence = fence.vk
  checkVkResult vkResetFences(fence.device.vk, 1, addr(varFence))

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
