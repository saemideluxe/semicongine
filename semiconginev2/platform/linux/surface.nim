proc CreateNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr Display](window.display),
    window: cast[Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
