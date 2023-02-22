type
  VkScreenSurfaceCreateInfoQNX* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkScreenSurfaceCreateFlagsQNX
    context*: ptr screen_context
    window*: ptr screen_window
  screen_context *{.header: "screen/screen.h".} = object
  screen_window *{.header: "screen/screen.h".} = object
# extension VK_QNX_screen_surface
var
  vkCreateScreenSurfaceQNX*: proc(instance: VkInstance, pCreateInfo: ptr VkScreenSurfaceCreateInfoQNX, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceScreenPresentationSupportQNX*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, window: ptr screen_window): VkBool32 {.stdcall.}
proc loadVK_QNX_screen_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateScreenSurfaceQNX = cast[proc(instance: VkInstance, pCreateInfo: ptr VkScreenSurfaceCreateInfoQNX, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateScreenSurfaceQNX"))
  vkGetPhysicalDeviceScreenPresentationSupportQNX = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, window: ptr screen_window): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceScreenPresentationSupportQNX"))
