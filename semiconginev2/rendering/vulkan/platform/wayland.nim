type
  VkWaylandSurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkWaylandSurfaceCreateFlagsKHR
    display*: ptr wl_display
    surface*: ptr wl_surface
  wl_display *{.header: "wayland-client.h".} = object
  wl_surface *{.header: "wayland-client.h".} = object
# extension VK_KHR_wayland_surface
var
  vkCreateWaylandSurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkWaylandSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceWaylandPresentationSupportKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, display: ptr wl_display): VkBool32 {.stdcall.}
proc loadVK_KHR_wayland_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateWaylandSurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkWaylandSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateWaylandSurfaceKHR"))
  vkGetPhysicalDeviceWaylandPresentationSupportKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, display: ptr wl_display): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceWaylandPresentationSupportKHR"))
