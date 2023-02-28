import ../../vulkan/api
import ../../vulkan/instance
import ../../platform/window

proc createNativeSurface*(instance: Instance, window: NativeWindow): VkSurfaceKHR =
  assert instance.vk.valid
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr api.Display](window.display),
    window: cast[api.Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance.vk, addr(surfaceCreateInfo), nil, addr(result))
