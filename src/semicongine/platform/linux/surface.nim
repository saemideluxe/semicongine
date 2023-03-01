import ../../vulkan/api
import ../../platform/window

proc createNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  assert instance.valid
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr api.Display](window.display),
    window: cast[api.Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
