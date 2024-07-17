type
  VkStreamDescriptorSurfaceCreateInfoGGP* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkStreamDescriptorSurfaceCreateFlagsGGP
    streamDescriptor*: GgpStreamDescriptor
  VkPresentFrameTokenGGP* = object
    sType*: VkStructureType
    pNext*: pointer
    frameToken*: GgpFrameToken
  GgpStreamDescriptor *{.header: "ggp_c/vulkan_types.h".} = object
  GgpFrameToken *{.header: "ggp_c/vulkan_types.h".} = object
# extension VK_GGP_stream_descriptor_surface
var
  vkCreateStreamDescriptorSurfaceGGP*: proc(instance: VkInstance, pCreateInfo: ptr VkStreamDescriptorSurfaceCreateInfoGGP, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_GGP_stream_descriptor_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateStreamDescriptorSurfaceGGP = cast[proc(instance: VkInstance, pCreateInfo: ptr VkStreamDescriptorSurfaceCreateInfoGGP, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateStreamDescriptorSurfaceGGP"))

proc loadVK_GGP_frame_token*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_GGP_stream_descriptor_surface(instance)
