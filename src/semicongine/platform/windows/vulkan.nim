# included in vulkan_helpers
const REQUIRED_PLATFORM_EXTENSIONS* = @["VK_KHR_win32_surface".cstring]

proc createVulkanSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  var surfaceCreateInfo = VkWin32SurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    hinstance: window.hinstance,
    hwnd: window.hwnd,
  )
  checkVkResult vkCreateWin32SurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
