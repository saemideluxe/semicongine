type
  VkAndroidSurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkAndroidSurfaceCreateFlagsKHR
    window*: ptr ANativeWindow
  VkNativeBufferUsage2ANDROID* = object
    consumer*: uint64
    producer*: uint64
  VkNativeBufferANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    handle*: pointer
    stride*: cint
    format*: cint
    usage*: cint
    usage2*: VkNativeBufferUsage2ANDROID
  VkSwapchainImageCreateInfoANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    usage*: VkSwapchainImageUsageFlagsANDROID
  VkPhysicalDevicePresentationPropertiesANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    sharedImage*: VkBool32
  VkImportAndroidHardwareBufferInfoANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: ptr AHardwareBuffer
  VkAndroidHardwareBufferUsageANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    androidHardwareBufferUsage*: uint64
  VkAndroidHardwareBufferPropertiesANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    allocationSize*: VkDeviceSize
    memoryTypeBits*: uint32
  VkMemoryGetAndroidHardwareBufferInfoANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
  VkAndroidHardwareBufferFormatPropertiesANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    externalFormat*: uint64
    formatFeatures*: VkFormatFeatureFlags
    samplerYcbcrConversionComponents*: VkComponentMapping
    suggestedYcbcrModel*: VkSamplerYcbcrModelConversion
    suggestedYcbcrRange*: VkSamplerYcbcrRange
    suggestedXChromaOffset*: VkChromaLocation
    suggestedYChromaOffset*: VkChromaLocation
  VkExternalFormatANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    externalFormat*: uint64
  VkAndroidHardwareBufferFormatProperties2ANDROID* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    externalFormat*: uint64
    formatFeatures*: VkFormatFeatureFlags2
    samplerYcbcrConversionComponents*: VkComponentMapping
    suggestedYcbcrModel*: VkSamplerYcbcrModelConversion
    suggestedYcbcrRange*: VkSamplerYcbcrRange
    suggestedXChromaOffset*: VkChromaLocation
    suggestedYChromaOffset*: VkChromaLocation
# extension VK_ANDROID_external_memory_android_hardware_buffer
var
  vkGetAndroidHardwareBufferPropertiesANDROID*: proc(device: VkDevice, buffer: ptr AHardwareBuffer, pProperties: ptr VkAndroidHardwareBufferPropertiesANDROID): VkResult {.stdcall.}
  vkGetMemoryAndroidHardwareBufferANDROID*: proc(device: VkDevice, pInfo: ptr VkMemoryGetAndroidHardwareBufferInfoANDROID, pBuffer: ptr ptr AHardwareBuffer): VkResult {.stdcall.}
proc loadVK_ANDROID_external_memory_android_hardware_buffer*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)
  loadVK_EXT_queue_family_foreign(instance)
  loadVK_VERSION_1_1(instance)
  vkGetAndroidHardwareBufferPropertiesANDROID = cast[proc(device: VkDevice, buffer: ptr AHardwareBuffer, pProperties: ptr VkAndroidHardwareBufferPropertiesANDROID): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAndroidHardwareBufferPropertiesANDROID"))
  vkGetMemoryAndroidHardwareBufferANDROID = cast[proc(device: VkDevice, pInfo: ptr VkMemoryGetAndroidHardwareBufferInfoANDROID, pBuffer: ptr ptr AHardwareBuffer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryAndroidHardwareBufferANDROID"))

# extension VK_KHR_android_surface
var
  vkCreateAndroidSurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkAndroidSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_KHR_android_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateAndroidSurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkAndroidSurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateAndroidSurfaceKHR"))
