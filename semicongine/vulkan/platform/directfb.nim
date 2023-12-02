type
  VkDirectFBSurfaceCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDirectFBSurfaceCreateFlagsEXT
    dfb*: ptr IDirectFB
    surface*: ptr IDirectFBSurface
  IDirectFB *{.header: "directfb.h".} = object
  IDirectFBSurface *{.header: "directfb.h".} = object
# extension VK_EXT_directfb_surface
var
  vkCreateDirectFBSurfaceEXT*: proc(instance: VkInstance, pCreateInfo: ptr VkDirectFBSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceDirectFBPresentationSupportEXT*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, dfb: ptr IDirectFB): VkBool32 {.stdcall.}
proc loadVK_EXT_directfb_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateDirectFBSurfaceEXT = cast[proc(instance: VkInstance, pCreateInfo: ptr VkDirectFBSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDirectFBSurfaceEXT"))
  vkGetPhysicalDeviceDirectFBPresentationSupportEXT = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, dfb: ptr IDirectFB): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceDirectFBPresentationSupportEXT"))
