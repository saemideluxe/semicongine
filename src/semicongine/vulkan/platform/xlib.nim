type
  VkXlibSurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkXlibSurfaceCreateFlagsKHR
    dpy*: ptr Display
    window*: Window
  Display *{.header: "X11/Xlib.h".} = object
  VisualID *{.header: "X11/Xlib.h".} = object
  Window *{.header: "X11/Xlib.h".} = object
# extension VK_KHR_xlib_surface
var
  vkCreateXlibSurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkXlibSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceXlibPresentationSupportKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, dpy: ptr Display, visualID: VisualID): VkBool32 {.stdcall.}
proc loadVK_KHR_xlib_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateXlibSurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkXlibSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateXlibSurfaceKHR"))
  vkGetPhysicalDeviceXlibPresentationSupportKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, dpy: ptr Display, visualID: VisualID): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceXlibPresentationSupportKHR"))
