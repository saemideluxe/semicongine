type
  VkXcbSurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkXcbSurfaceCreateFlagsKHR
    connection*: ptr xcb_connection_t
    window*: xcb_window_t
  xcb_connection_t *{.header: "xcb/xcb.h".} = object
  xcb_visualid_t *{.header: "xcb/xcb.h".} = object
  xcb_window_t *{.header: "xcb/xcb.h".} = object
# extension VK_KHR_xcb_surface
var
  vkCreateXcbSurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkXcbSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceXcbPresentationSupportKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, connection: ptr xcb_connection_t, visual_id: xcb_visualid_t): VkBool32 {.stdcall.}
proc loadVK_KHR_xcb_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateXcbSurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkXcbSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateXcbSurfaceKHR"))
  vkGetPhysicalDeviceXcbPresentationSupportKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, connection: ptr xcb_connection_t, visual_id: xcb_visualid_t): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceXcbPresentationSupportKHR"))
