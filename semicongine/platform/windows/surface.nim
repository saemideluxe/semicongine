import ../../core
import ../../platform/window

proc createNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  assert instance.valid
  var surfaceCreateInfo = VkWin32SurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    hinstance: cast[HINSTANCE](window.hinstance),
    hwnd: cast[HWND](window.hwnd),
  )
  checkVkResult vkCreateWin32SurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
