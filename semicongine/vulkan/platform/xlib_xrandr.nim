type
  Display *{.header: "X11/Xlib.h".} = object
  VisualID *{.header: "X11/Xlib.h".} = object
  Window *{.header: "X11/Xlib.h".} = object
  RROutput *{.header: "X11/extensions/Xrandr.h".} = object
# extension VK_EXT_acquire_xlib_display
var
  vkAcquireXlibDisplayEXT*: proc(physicalDevice: VkPhysicalDevice, dpy: ptr Display, display: VkDisplayKHR): VkResult {.stdcall.}
  vkGetRandROutputDisplayEXT*: proc(physicalDevice: VkPhysicalDevice, dpy: ptr Display, rrOutput: RROutput, pDisplay: ptr VkDisplayKHR): VkResult {.stdcall.}
proc loadVK_EXT_acquire_xlib_display*(instance: VkInstance) =
  loadVK_EXT_direct_mode_display(instance)
  vkAcquireXlibDisplayEXT = cast[proc(physicalDevice: VkPhysicalDevice, dpy: ptr Display, display: VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireXlibDisplayEXT"))
  vkGetRandROutputDisplayEXT = cast[proc(physicalDevice: VkPhysicalDevice, dpy: ptr Display, rrOutput: RROutput, pDisplay: ptr VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRandROutputDisplayEXT"))
