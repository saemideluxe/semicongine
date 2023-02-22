type
  VkMetalSurfaceCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkMetalSurfaceCreateFlagsEXT
    pLayer*: ptr CAMetalLayer
  VkExportMetalObjectCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    exportObjectType*: VkExportMetalObjectTypeFlagBitsEXT
  VkExportMetalObjectsInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
  VkExportMetalDeviceInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mtlDevice*: MTLDevice_id
  VkExportMetalCommandQueueInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    queue*: VkQueue
    mtlCommandQueue*: MTLCommandQueue_id
  VkExportMetalBufferInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    mtlBuffer*: MTLBuffer_id
  VkImportMetalBufferInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mtlBuffer*: MTLBuffer_id
  VkExportMetalTextureInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
    imageView*: VkImageView
    bufferView*: VkBufferView
    plane*: VkImageAspectFlagBits
    mtlTexture*: MTLTexture_id
  VkImportMetalTextureInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    plane*: VkImageAspectFlagBits
    mtlTexture*: MTLTexture_id
  VkExportMetalIOSurfaceInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
    ioSurface*: IOSurfaceRef
  VkImportMetalIOSurfaceInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    ioSurface*: IOSurfaceRef
  VkExportMetalSharedEventInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    event*: VkEvent
    mtlSharedEvent*: MTLSharedEvent_id
  VkImportMetalSharedEventInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mtlSharedEvent*: MTLSharedEvent_id
# extension VK_EXT_metal_objects
var
  vkExportMetalObjectsEXT*: proc(device: VkDevice, pMetalObjectsInfo: ptr VkExportMetalObjectsInfoEXT): void {.stdcall.}
proc loadVK_EXT_metal_objects*(instance: VkInstance) =
  vkExportMetalObjectsEXT = cast[proc(device: VkDevice, pMetalObjectsInfo: ptr VkExportMetalObjectsInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkExportMetalObjectsEXT"))

# extension VK_EXT_metal_surface
var
  vkCreateMetalSurfaceEXT*: proc(instance: VkInstance, pCreateInfo: ptr VkMetalSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_EXT_metal_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateMetalSurfaceEXT = cast[proc(instance: VkInstance, pCreateInfo: ptr VkMetalSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateMetalSurfaceEXT"))
