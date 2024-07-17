type
  VkImagePipeSurfaceCreateInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkImagePipeSurfaceCreateFlagsFUCHSIA
    imagePipeHandle*: zx_handle_t
  VkImportMemoryZirconHandleInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
    handle*: zx_handle_t
  VkMemoryZirconHandlePropertiesFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
  VkMemoryGetZirconHandleInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkImportSemaphoreZirconHandleInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    flags*: VkSemaphoreImportFlags
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
    zirconHandle*: zx_handle_t
  VkSemaphoreGetZirconHandleInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
  VkImportMemoryBufferCollectionFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    collection*: VkBufferCollectionFUCHSIA
    index*: uint32
  VkBufferCollectionImageCreateInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    collection*: VkBufferCollectionFUCHSIA
    index*: uint32
  VkBufferCollectionBufferCreateInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    collection*: VkBufferCollectionFUCHSIA
    index*: uint32
  VkBufferCollectionCreateInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    collectionToken*: zx_handle_t
  VkBufferCollectionPropertiesFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
    bufferCount*: uint32
    createInfoIndex*: uint32
    sysmemPixelFormat*: uint64
    formatFeatures*: VkFormatFeatureFlags
    sysmemColorSpaceIndex*: VkSysmemColorSpaceFUCHSIA
    samplerYcbcrConversionComponents*: VkComponentMapping
    suggestedYcbcrModel*: VkSamplerYcbcrModelConversion
    suggestedYcbcrRange*: VkSamplerYcbcrRange
    suggestedXChromaOffset*: VkChromaLocation
    suggestedYChromaOffset*: VkChromaLocation
  VkBufferConstraintsInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    createInfo*: VkBufferCreateInfo
    requiredFormatFeatures*: VkFormatFeatureFlags
    bufferCollectionConstraints*: VkBufferCollectionConstraintsInfoFUCHSIA
  VkSysmemColorSpaceFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    colorSpace*: uint32
  VkImageFormatConstraintsInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    imageCreateInfo*: VkImageCreateInfo
    requiredFormatFeatures*: VkFormatFeatureFlags
    flags*: VkImageFormatConstraintsFlagsFUCHSIA
    sysmemPixelFormat*: uint64
    colorSpaceCount*: uint32
    pColorSpaces*: ptr VkSysmemColorSpaceFUCHSIA
  VkImageConstraintsInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    formatConstraintsCount*: uint32
    pFormatConstraints*: ptr VkImageFormatConstraintsInfoFUCHSIA
    bufferCollectionConstraints*: VkBufferCollectionConstraintsInfoFUCHSIA
    flags*: VkImageConstraintsInfoFlagsFUCHSIA
  VkBufferCollectionConstraintsInfoFUCHSIA* = object
    sType*: VkStructureType
    pNext*: pointer
    minBufferCount*: uint32
    maxBufferCount*: uint32
    minBufferCountForCamping*: uint32
    minBufferCountForDedicatedSlack*: uint32
    minBufferCountForSharedSlack*: uint32
  zx_handle_t *{.header: "zircon/types.h".} = object
# extension VK_FUCHSIA_external_memory
var
  vkGetMemoryZirconHandleFUCHSIA*: proc(device: VkDevice, pGetZirconHandleInfo: ptr VkMemoryGetZirconHandleInfoFUCHSIA, pZirconHandle: ptr zx_handle_t): VkResult {.stdcall.}
  vkGetMemoryZirconHandlePropertiesFUCHSIA*: proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, zirconHandle: zx_handle_t, pMemoryZirconHandleProperties: ptr VkMemoryZirconHandlePropertiesFUCHSIA): VkResult {.stdcall.}
proc loadVK_FUCHSIA_external_memory*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)
  vkGetMemoryZirconHandleFUCHSIA = cast[proc(device: VkDevice, pGetZirconHandleInfo: ptr VkMemoryGetZirconHandleInfoFUCHSIA, pZirconHandle: ptr zx_handle_t): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryZirconHandleFUCHSIA"))
  vkGetMemoryZirconHandlePropertiesFUCHSIA = cast[proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, zirconHandle: zx_handle_t, pMemoryZirconHandleProperties: ptr VkMemoryZirconHandlePropertiesFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryZirconHandlePropertiesFUCHSIA"))

# extension VK_FUCHSIA_external_semaphore
var
  vkImportSemaphoreZirconHandleFUCHSIA*: proc(device: VkDevice, pImportSemaphoreZirconHandleInfo: ptr VkImportSemaphoreZirconHandleInfoFUCHSIA): VkResult {.stdcall.}
  vkGetSemaphoreZirconHandleFUCHSIA*: proc(device: VkDevice, pGetZirconHandleInfo: ptr VkSemaphoreGetZirconHandleInfoFUCHSIA, pZirconHandle: ptr zx_handle_t): VkResult {.stdcall.}
proc loadVK_FUCHSIA_external_semaphore*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)
  vkImportSemaphoreZirconHandleFUCHSIA = cast[proc(device: VkDevice, pImportSemaphoreZirconHandleInfo: ptr VkImportSemaphoreZirconHandleInfoFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkImportSemaphoreZirconHandleFUCHSIA"))
  vkGetSemaphoreZirconHandleFUCHSIA = cast[proc(device: VkDevice, pGetZirconHandleInfo: ptr VkSemaphoreGetZirconHandleInfoFUCHSIA, pZirconHandle: ptr zx_handle_t): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSemaphoreZirconHandleFUCHSIA"))

# extension VK_FUCHSIA_buffer_collection
var
  vkCreateBufferCollectionFUCHSIA*: proc(device: VkDevice, pCreateInfo: ptr VkBufferCollectionCreateInfoFUCHSIA, pAllocator: ptr VkAllocationCallbacks, pCollection: ptr VkBufferCollectionFUCHSIA): VkResult {.stdcall.}
  vkSetBufferCollectionImageConstraintsFUCHSIA*: proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pImageConstraintsInfo: ptr VkImageConstraintsInfoFUCHSIA): VkResult {.stdcall.}
  vkSetBufferCollectionBufferConstraintsFUCHSIA*: proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pBufferConstraintsInfo: ptr VkBufferConstraintsInfoFUCHSIA): VkResult {.stdcall.}
  vkDestroyBufferCollectionFUCHSIA*: proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetBufferCollectionPropertiesFUCHSIA*: proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pProperties: ptr VkBufferCollectionPropertiesFUCHSIA): VkResult {.stdcall.}
proc loadVK_FUCHSIA_buffer_collection*(instance: VkInstance) =
  loadVK_FUCHSIA_external_memory(instance)
  loadVK_VERSION_1_1(instance)
  vkCreateBufferCollectionFUCHSIA = cast[proc(device: VkDevice, pCreateInfo: ptr VkBufferCollectionCreateInfoFUCHSIA, pAllocator: ptr VkAllocationCallbacks, pCollection: ptr VkBufferCollectionFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateBufferCollectionFUCHSIA"))
  vkSetBufferCollectionImageConstraintsFUCHSIA = cast[proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pImageConstraintsInfo: ptr VkImageConstraintsInfoFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetBufferCollectionImageConstraintsFUCHSIA"))
  vkSetBufferCollectionBufferConstraintsFUCHSIA = cast[proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pBufferConstraintsInfo: ptr VkBufferConstraintsInfoFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetBufferCollectionBufferConstraintsFUCHSIA"))
  vkDestroyBufferCollectionFUCHSIA = cast[proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyBufferCollectionFUCHSIA"))
  vkGetBufferCollectionPropertiesFUCHSIA = cast[proc(device: VkDevice, collection: VkBufferCollectionFUCHSIA, pProperties: ptr VkBufferCollectionPropertiesFUCHSIA): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferCollectionPropertiesFUCHSIA"))

# extension VK_FUCHSIA_imagepipe_surface
var
  vkCreateImagePipeSurfaceFUCHSIA*: proc(instance: VkInstance, pCreateInfo: ptr VkImagePipeSurfaceCreateInfoFUCHSIA, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_FUCHSIA_imagepipe_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateImagePipeSurfaceFUCHSIA = cast[proc(instance: VkInstance, pCreateInfo: ptr VkImagePipeSurfaceCreateInfoFUCHSIA, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateImagePipeSurfaceFUCHSIA"))
