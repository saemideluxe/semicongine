type
  VkViSurfaceCreateInfoNN* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkViSurfaceCreateFlagsNN
    window*: pointer
# extension VK_NN_vi_surface
var
  vkCreateViSurfaceNN*: proc(instance: VkInstance, pCreateInfo: ptr VkViSurfaceCreateInfoNN, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_NN_vi_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateViSurfaceNN = cast[proc(instance: VkInstance, pCreateInfo: ptr VkViSurfaceCreateInfoNN, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateViSurfaceNN"))
