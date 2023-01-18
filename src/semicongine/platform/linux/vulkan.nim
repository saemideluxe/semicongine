# included in vulkan_helpers
const REQUIRED_PLATFORM_EXTENSIONS = @["VK_KHR_xlib_surface".cstring]

proc load_platform_extensions() =
  loadVK_KHR_xlib_surface()

proc createVulkanSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: window.display,
    window: window.window,
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
