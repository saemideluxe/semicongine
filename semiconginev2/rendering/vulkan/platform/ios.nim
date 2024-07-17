type
  VkIOSSurfaceCreateInfoMVK* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkIOSSurfaceCreateFlagsMVK
    pView*: pointer
# extension VK_MVK_ios_surface
var
  vkCreateIOSSurfaceMVK*: proc(instance: VkInstance, pCreateInfo: ptr VkIOSSurfaceCreateInfoMVK, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_MVK_ios_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateIOSSurfaceMVK = cast[proc(instance: VkInstance, pCreateInfo: ptr VkIOSSurfaceCreateInfoMVK, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateIOSSurfaceMVK"))
