type
  VkMacOSSurfaceCreateInfoMVK* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkMacOSSurfaceCreateFlagsMVK
    pView*: pointer
# extension VK_MVK_macos_surface
var
  vkCreateMacOSSurfaceMVK*: proc(instance: VkInstance, pCreateInfo: ptr VkMacOSSurfaceCreateInfoMVK, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_MVK_macos_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateMacOSSurfaceMVK = cast[proc(instance: VkInstance, pCreateInfo: ptr VkMacOSSurfaceCreateInfoMVK, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateMacOSSurfaceMVK"))
