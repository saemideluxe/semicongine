import std/dynlib
import std/tables
import std/strutils
import std/logging
import std/typetraits
import std/macros
type
  VkHandle* = distinct uint
  VkNonDispatchableHandle* = distinct uint
when defined(linux):
  let vulkanLib* = loadLib("libvulkan.so.1")
when defined(windows):
  let vulkanLib* = loadLib("vulkan-1.dll")
if vulkanLib == nil:
  raise newException(Exception, "Unable to load vulkan library")
func VK_MAKE_API_VERSION*(variant: uint32, major: uint32, minor: uint32, patch: uint32): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch

template checkVkResult*(call: untyped) =
  when defined(release):
    discard call
  else:
    # yes, a bit cheap, but this is only for nice debug output
    var callstr = astToStr(call).replace("\n", "")
    while callstr.find("  ") >= 0:
      callstr = callstr.replace("  ", " ")
    debug "Calling vulkan: ", callstr
    let value = call
    if value != VK_SUCCESS:
      error "Vulkan error: ", astToStr(call), " returned ", $value
      raise newException(Exception, "Vulkan error: " & astToStr(call) &
          " returned " & $value)
# custom enum iteration (for enum values > 2^16)
macro enumFullRange(a: typed): untyped =
  newNimNode(nnkBracket).add(a.getType[1][1..^1])

iterator items*[T: HoleyEnum](E: typedesc[T]): T =
  for a in enumFullRange(E): yield a
const
  VK_MAX_PHYSICAL_DEVICE_NAME_SIZE*: uint32 = 256
  VK_UUID_SIZE*: uint32 = 16
  VK_LUID_SIZE*: uint32 = 8
  VK_LUID_SIZE_KHR* = VK_LUID_SIZE
  VK_MAX_EXTENSION_NAME_SIZE*: uint32 = 256
  VK_MAX_DESCRIPTION_SIZE*: uint32 = 256
  VK_MAX_MEMORY_TYPES*: uint32 = 32
  VK_MAX_MEMORY_HEAPS*: uint32 = 16
  VK_LOD_CLAMP_NONE*: float32 = 1000.0F
  VK_REMAINING_MIP_LEVELS*: uint32 = not 0'u32
  VK_REMAINING_ARRAY_LAYERS*: uint32 = not 0'u32
  VK_REMAINING_3D_SLICES_EXT*: uint32 = not 0'u32
  VK_WHOLE_SIZE*: uint64 = not 0'u64
  VK_ATTACHMENT_UNUSED*: uint32 = not 0'u32
  VK_TRUE*: uint32 = 1
  VK_FALSE*: uint32 = 0
  VK_QUEUE_FAMILY_IGNORED*: uint32 = not 0'u32
  VK_QUEUE_FAMILY_EXTERNAL*: uint32 = not 1'u32
  VK_QUEUE_FAMILY_EXTERNAL_KHR* = VK_QUEUE_FAMILY_EXTERNAL
  VK_QUEUE_FAMILY_FOREIGN_EXT*: uint32 = not 2'u32
  VK_SUBPASS_EXTERNAL*: uint32 = not 0'u32
  VK_MAX_DEVICE_GROUP_SIZE*: uint32 = 32
  VK_MAX_DEVICE_GROUP_SIZE_KHR* = VK_MAX_DEVICE_GROUP_SIZE
  VK_MAX_DRIVER_NAME_SIZE*: uint32 = 256
  VK_MAX_DRIVER_NAME_SIZE_KHR* = VK_MAX_DRIVER_NAME_SIZE
  VK_MAX_DRIVER_INFO_SIZE*: uint32 = 256
  VK_MAX_DRIVER_INFO_SIZE_KHR* = VK_MAX_DRIVER_INFO_SIZE
  VK_SHADER_UNUSED_KHR*: uint32 = not 0'u32
  VK_SHADER_UNUSED_NV* = VK_SHADER_UNUSED_KHR
  VK_MAX_GLOBAL_PRIORITY_SIZE_KHR*: uint32 = 16
  VK_MAX_GLOBAL_PRIORITY_SIZE_EXT* = VK_MAX_GLOBAL_PRIORITY_SIZE_KHR
  VK_MAX_SHADER_MODULE_IDENTIFIER_SIZE_EXT*: uint32 = 32
type
  ANativeWindow* = object
  AHardwareBuffer* = object
  CAMetalLayer* = object
  MTLDevice_id* = object
  MTLCommandQueue_id* = object
  MTLBuffer_id* = object
  MTLTexture_id* = object
  MTLSharedEvent_id* = object
  IOSurfaceRef* = object
  VkSampleMask* = uint32
  VkBool32* = uint32
  VkFlags* = uint32
  VkFlags64* = uint64
  VkDeviceSize* = uint64
  VkDeviceAddress* = uint64
  VkInstance* = distinct VkHandle
  VkPhysicalDevice* = distinct VkHandle
  VkDevice* = distinct VkHandle
  VkQueue* = distinct VkHandle
  VkCommandBuffer* = distinct VkHandle
  VkDeviceMemory* = distinct VkNonDispatchableHandle
  VkCommandPool* = distinct VkNonDispatchableHandle
  VkBuffer* = distinct VkNonDispatchableHandle
  VkBufferView* = distinct VkNonDispatchableHandle
  VkImage* = distinct VkNonDispatchableHandle
  VkImageView* = distinct VkNonDispatchableHandle
  VkShaderModule* = distinct VkNonDispatchableHandle
  VkPipeline* = distinct VkNonDispatchableHandle
  VkPipelineLayout* = distinct VkNonDispatchableHandle
  VkSampler* = distinct VkNonDispatchableHandle
  VkDescriptorSet* = distinct VkNonDispatchableHandle
  VkDescriptorSetLayout* = distinct VkNonDispatchableHandle
  VkDescriptorPool* = distinct VkNonDispatchableHandle
  VkFence* = distinct VkNonDispatchableHandle
  VkSemaphore* = distinct VkNonDispatchableHandle
  VkEvent* = distinct VkNonDispatchableHandle
  VkQueryPool* = distinct VkNonDispatchableHandle
  VkFramebuffer* = distinct VkNonDispatchableHandle
  VkRenderPass* = distinct VkNonDispatchableHandle
  VkPipelineCache* = distinct VkNonDispatchableHandle
  VkIndirectCommandsLayoutNV* = distinct VkNonDispatchableHandle
  VkDescriptorUpdateTemplate* = distinct VkNonDispatchableHandle
  VkSamplerYcbcrConversion* = distinct VkNonDispatchableHandle
  VkValidationCacheEXT* = distinct VkNonDispatchableHandle
  VkAccelerationStructureKHR* = distinct VkNonDispatchableHandle
  VkAccelerationStructureNV* = distinct VkNonDispatchableHandle
  VkPerformanceConfigurationINTEL* = distinct VkNonDispatchableHandle
  VkBufferCollectionFUCHSIA* = distinct VkNonDispatchableHandle
  VkDeferredOperationKHR* = distinct VkNonDispatchableHandle
  VkPrivateDataSlot* = distinct VkNonDispatchableHandle
  VkCuModuleNVX* = distinct VkNonDispatchableHandle
  VkCuFunctionNVX* = distinct VkNonDispatchableHandle
  VkOpticalFlowSessionNV* = distinct VkNonDispatchableHandle
  VkMicromapEXT* = distinct VkNonDispatchableHandle
  VkDisplayKHR* = distinct VkNonDispatchableHandle
  VkDisplayModeKHR* = distinct VkNonDispatchableHandle
  VkSurfaceKHR* = distinct VkNonDispatchableHandle
  VkSwapchainKHR* = distinct VkNonDispatchableHandle
  VkDebugReportCallbackEXT* = distinct VkNonDispatchableHandle
  VkDebugUtilsMessengerEXT* = distinct VkNonDispatchableHandle
  VkVideoSessionKHR* = distinct VkNonDispatchableHandle
  VkVideoSessionParametersKHR* = distinct VkNonDispatchableHandle
  VkSemaphoreSciSyncPoolNV* = distinct VkNonDispatchableHandle
  VkRemoteAddressNV* = pointer
proc `$`*(handle: VkInstance): string = "VkInstance(" & $(uint(handle)) & ")"
proc valid*(handle: VkInstance): bool = uint(handle) != 0
proc reset*(handle: var VkInstance) = handle = VkInstance(0)
proc `==`*(a, b: VkInstance): bool = uint(a) == uint(b)
proc `$`*(handle: VkPhysicalDevice): string = "VkPhysicalDevice(" & $(uint(handle)) & ")"
proc valid*(handle: VkPhysicalDevice): bool = uint(handle) != 0
proc reset*(handle: var VkPhysicalDevice) = handle = VkPhysicalDevice(0)
proc `==`*(a, b: VkPhysicalDevice): bool = uint(a) == uint(b)
proc `$`*(handle: VkDevice): string = "VkDevice(" & $(uint(handle)) & ")"
proc valid*(handle: VkDevice): bool = uint(handle) != 0
proc reset*(handle: var VkDevice) = handle = VkDevice(0)
proc `==`*(a, b: VkDevice): bool = uint(a) == uint(b)
proc `$`*(handle: VkQueue): string = "VkQueue(" & $(uint(handle)) & ")"
proc valid*(handle: VkQueue): bool = uint(handle) != 0
proc reset*(handle: var VkQueue) = handle = VkQueue(0)
proc `==`*(a, b: VkQueue): bool = uint(a) == uint(b)
proc `$`*(handle: VkCommandBuffer): string = "VkCommandBuffer(" & $(uint(handle)) & ")"
proc valid*(handle: VkCommandBuffer): bool = uint(handle) != 0
proc reset*(handle: var VkCommandBuffer) = handle = VkCommandBuffer(0)
proc `==`*(a, b: VkCommandBuffer): bool = uint(a) == uint(b)
proc `$`*(handle: VkDeviceMemory): string = "VkDeviceMemory(" & $(uint(handle)) & ")"
proc valid*(handle: VkDeviceMemory): bool = uint(handle) != 0
proc reset*(handle: var VkDeviceMemory) = handle = VkDeviceMemory(0)
proc `==`*(a, b: VkDeviceMemory): bool = uint(a) == uint(b)
proc `$`*(handle: VkCommandPool): string = "VkCommandPool(" & $(uint(handle)) & ")"
proc valid*(handle: VkCommandPool): bool = uint(handle) != 0
proc reset*(handle: var VkCommandPool) = handle = VkCommandPool(0)
proc `==`*(a, b: VkCommandPool): bool = uint(a) == uint(b)
proc `$`*(handle: VkBuffer): string = "VkBuffer(" & $(uint(handle)) & ")"
proc valid*(handle: VkBuffer): bool = uint(handle) != 0
proc reset*(handle: var VkBuffer) = handle = VkBuffer(0)
proc `==`*(a, b: VkBuffer): bool = uint(a) == uint(b)
proc `$`*(handle: VkBufferView): string = "VkBufferView(" & $(uint(handle)) & ")"
proc valid*(handle: VkBufferView): bool = uint(handle) != 0
proc reset*(handle: var VkBufferView) = handle = VkBufferView(0)
proc `==`*(a, b: VkBufferView): bool = uint(a) == uint(b)
proc `$`*(handle: VkImage): string = "VkImage(" & $(uint(handle)) & ")"
proc valid*(handle: VkImage): bool = uint(handle) != 0
proc reset*(handle: var VkImage) = handle = VkImage(0)
proc `==`*(a, b: VkImage): bool = uint(a) == uint(b)
proc `$`*(handle: VkImageView): string = "VkImageView(" & $(uint(handle)) & ")"
proc valid*(handle: VkImageView): bool = uint(handle) != 0
proc reset*(handle: var VkImageView) = handle = VkImageView(0)
proc `==`*(a, b: VkImageView): bool = uint(a) == uint(b)
proc `$`*(handle: VkShaderModule): string = "VkShaderModule(" & $(uint(handle)) & ")"
proc valid*(handle: VkShaderModule): bool = uint(handle) != 0
proc reset*(handle: var VkShaderModule) = handle = VkShaderModule(0)
proc `==`*(a, b: VkShaderModule): bool = uint(a) == uint(b)
proc `$`*(handle: VkPipeline): string = "VkPipeline(" & $(uint(handle)) & ")"
proc valid*(handle: VkPipeline): bool = uint(handle) != 0
proc reset*(handle: var VkPipeline) = handle = VkPipeline(0)
proc `==`*(a, b: VkPipeline): bool = uint(a) == uint(b)
proc `$`*(handle: VkPipelineLayout): string = "VkPipelineLayout(" & $(uint(handle)) & ")"
proc valid*(handle: VkPipelineLayout): bool = uint(handle) != 0
proc reset*(handle: var VkPipelineLayout) = handle = VkPipelineLayout(0)
proc `==`*(a, b: VkPipelineLayout): bool = uint(a) == uint(b)
proc `$`*(handle: VkSampler): string = "VkSampler(" & $(uint(handle)) & ")"
proc valid*(handle: VkSampler): bool = uint(handle) != 0
proc reset*(handle: var VkSampler) = handle = VkSampler(0)
proc `==`*(a, b: VkSampler): bool = uint(a) == uint(b)
proc `$`*(handle: VkDescriptorSet): string = "VkDescriptorSet(" & $(uint(handle)) & ")"
proc valid*(handle: VkDescriptorSet): bool = uint(handle) != 0
proc reset*(handle: var VkDescriptorSet) = handle = VkDescriptorSet(0)
proc `==`*(a, b: VkDescriptorSet): bool = uint(a) == uint(b)
proc `$`*(handle: VkDescriptorSetLayout): string = "VkDescriptorSetLayout(" & $(uint(handle)) & ")"
proc valid*(handle: VkDescriptorSetLayout): bool = uint(handle) != 0
proc reset*(handle: var VkDescriptorSetLayout) = handle = VkDescriptorSetLayout(0)
proc `==`*(a, b: VkDescriptorSetLayout): bool = uint(a) == uint(b)
proc `$`*(handle: VkDescriptorPool): string = "VkDescriptorPool(" & $(uint(handle)) & ")"
proc valid*(handle: VkDescriptorPool): bool = uint(handle) != 0
proc reset*(handle: var VkDescriptorPool) = handle = VkDescriptorPool(0)
proc `==`*(a, b: VkDescriptorPool): bool = uint(a) == uint(b)
proc `$`*(handle: VkFence): string = "VkFence(" & $(uint(handle)) & ")"
proc valid*(handle: VkFence): bool = uint(handle) != 0
proc reset*(handle: var VkFence) = handle = VkFence(0)
proc `==`*(a, b: VkFence): bool = uint(a) == uint(b)
proc `$`*(handle: VkSemaphore): string = "VkSemaphore(" & $(uint(handle)) & ")"
proc valid*(handle: VkSemaphore): bool = uint(handle) != 0
proc reset*(handle: var VkSemaphore) = handle = VkSemaphore(0)
proc `==`*(a, b: VkSemaphore): bool = uint(a) == uint(b)
proc `$`*(handle: VkEvent): string = "VkEvent(" & $(uint(handle)) & ")"
proc valid*(handle: VkEvent): bool = uint(handle) != 0
proc reset*(handle: var VkEvent) = handle = VkEvent(0)
proc `==`*(a, b: VkEvent): bool = uint(a) == uint(b)
proc `$`*(handle: VkQueryPool): string = "VkQueryPool(" & $(uint(handle)) & ")"
proc valid*(handle: VkQueryPool): bool = uint(handle) != 0
proc reset*(handle: var VkQueryPool) = handle = VkQueryPool(0)
proc `==`*(a, b: VkQueryPool): bool = uint(a) == uint(b)
proc `$`*(handle: VkFramebuffer): string = "VkFramebuffer(" & $(uint(handle)) & ")"
proc valid*(handle: VkFramebuffer): bool = uint(handle) != 0
proc reset*(handle: var VkFramebuffer) = handle = VkFramebuffer(0)
proc `==`*(a, b: VkFramebuffer): bool = uint(a) == uint(b)
proc `$`*(handle: VkRenderPass): string = "VkRenderPass(" & $(uint(handle)) & ")"
proc valid*(handle: VkRenderPass): bool = uint(handle) != 0
proc reset*(handle: var VkRenderPass) = handle = VkRenderPass(0)
proc `==`*(a, b: VkRenderPass): bool = uint(a) == uint(b)
proc `$`*(handle: VkPipelineCache): string = "VkPipelineCache(" & $(uint(handle)) & ")"
proc valid*(handle: VkPipelineCache): bool = uint(handle) != 0
proc reset*(handle: var VkPipelineCache) = handle = VkPipelineCache(0)
proc `==`*(a, b: VkPipelineCache): bool = uint(a) == uint(b)
proc `$`*(handle: VkIndirectCommandsLayoutNV): string = "VkIndirectCommandsLayoutNV(" & $(uint(handle)) & ")"
proc valid*(handle: VkIndirectCommandsLayoutNV): bool = uint(handle) != 0
proc reset*(handle: var VkIndirectCommandsLayoutNV) = handle = VkIndirectCommandsLayoutNV(0)
proc `==`*(a, b: VkIndirectCommandsLayoutNV): bool = uint(a) == uint(b)
proc `$`*(handle: VkDescriptorUpdateTemplate): string = "VkDescriptorUpdateTemplate(" & $(uint(handle)) & ")"
proc valid*(handle: VkDescriptorUpdateTemplate): bool = uint(handle) != 0
proc reset*(handle: var VkDescriptorUpdateTemplate) = handle = VkDescriptorUpdateTemplate(0)
proc `==`*(a, b: VkDescriptorUpdateTemplate): bool = uint(a) == uint(b)
proc `$`*(handle: VkSamplerYcbcrConversion): string = "VkSamplerYcbcrConversion(" & $(uint(handle)) & ")"
proc valid*(handle: VkSamplerYcbcrConversion): bool = uint(handle) != 0
proc reset*(handle: var VkSamplerYcbcrConversion) = handle = VkSamplerYcbcrConversion(0)
proc `==`*(a, b: VkSamplerYcbcrConversion): bool = uint(a) == uint(b)
proc `$`*(handle: VkValidationCacheEXT): string = "VkValidationCacheEXT(" & $(uint(handle)) & ")"
proc valid*(handle: VkValidationCacheEXT): bool = uint(handle) != 0
proc reset*(handle: var VkValidationCacheEXT) = handle = VkValidationCacheEXT(0)
proc `==`*(a, b: VkValidationCacheEXT): bool = uint(a) == uint(b)
proc `$`*(handle: VkAccelerationStructureKHR): string = "VkAccelerationStructureKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkAccelerationStructureKHR): bool = uint(handle) != 0
proc reset*(handle: var VkAccelerationStructureKHR) = handle = VkAccelerationStructureKHR(0)
proc `==`*(a, b: VkAccelerationStructureKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkAccelerationStructureNV): string = "VkAccelerationStructureNV(" & $(uint(handle)) & ")"
proc valid*(handle: VkAccelerationStructureNV): bool = uint(handle) != 0
proc reset*(handle: var VkAccelerationStructureNV) = handle = VkAccelerationStructureNV(0)
proc `==`*(a, b: VkAccelerationStructureNV): bool = uint(a) == uint(b)
proc `$`*(handle: VkPerformanceConfigurationINTEL): string = "VkPerformanceConfigurationINTEL(" & $(uint(handle)) & ")"
proc valid*(handle: VkPerformanceConfigurationINTEL): bool = uint(handle) != 0
proc reset*(handle: var VkPerformanceConfigurationINTEL) = handle = VkPerformanceConfigurationINTEL(0)
proc `==`*(a, b: VkPerformanceConfigurationINTEL): bool = uint(a) == uint(b)
proc `$`*(handle: VkBufferCollectionFUCHSIA): string = "VkBufferCollectionFUCHSIA(" & $(uint(handle)) & ")"
proc valid*(handle: VkBufferCollectionFUCHSIA): bool = uint(handle) != 0
proc reset*(handle: var VkBufferCollectionFUCHSIA) = handle = VkBufferCollectionFUCHSIA(0)
proc `==`*(a, b: VkBufferCollectionFUCHSIA): bool = uint(a) == uint(b)
proc `$`*(handle: VkDeferredOperationKHR): string = "VkDeferredOperationKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkDeferredOperationKHR): bool = uint(handle) != 0
proc reset*(handle: var VkDeferredOperationKHR) = handle = VkDeferredOperationKHR(0)
proc `==`*(a, b: VkDeferredOperationKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkPrivateDataSlot): string = "VkPrivateDataSlot(" & $(uint(handle)) & ")"
proc valid*(handle: VkPrivateDataSlot): bool = uint(handle) != 0
proc reset*(handle: var VkPrivateDataSlot) = handle = VkPrivateDataSlot(0)
proc `==`*(a, b: VkPrivateDataSlot): bool = uint(a) == uint(b)
proc `$`*(handle: VkCuModuleNVX): string = "VkCuModuleNVX(" & $(uint(handle)) & ")"
proc valid*(handle: VkCuModuleNVX): bool = uint(handle) != 0
proc reset*(handle: var VkCuModuleNVX) = handle = VkCuModuleNVX(0)
proc `==`*(a, b: VkCuModuleNVX): bool = uint(a) == uint(b)
proc `$`*(handle: VkCuFunctionNVX): string = "VkCuFunctionNVX(" & $(uint(handle)) & ")"
proc valid*(handle: VkCuFunctionNVX): bool = uint(handle) != 0
proc reset*(handle: var VkCuFunctionNVX) = handle = VkCuFunctionNVX(0)
proc `==`*(a, b: VkCuFunctionNVX): bool = uint(a) == uint(b)
proc `$`*(handle: VkOpticalFlowSessionNV): string = "VkOpticalFlowSessionNV(" & $(uint(handle)) & ")"
proc valid*(handle: VkOpticalFlowSessionNV): bool = uint(handle) != 0
proc reset*(handle: var VkOpticalFlowSessionNV) = handle = VkOpticalFlowSessionNV(0)
proc `==`*(a, b: VkOpticalFlowSessionNV): bool = uint(a) == uint(b)
proc `$`*(handle: VkMicromapEXT): string = "VkMicromapEXT(" & $(uint(handle)) & ")"
proc valid*(handle: VkMicromapEXT): bool = uint(handle) != 0
proc reset*(handle: var VkMicromapEXT) = handle = VkMicromapEXT(0)
proc `==`*(a, b: VkMicromapEXT): bool = uint(a) == uint(b)
proc `$`*(handle: VkDisplayKHR): string = "VkDisplayKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkDisplayKHR): bool = uint(handle) != 0
proc reset*(handle: var VkDisplayKHR) = handle = VkDisplayKHR(0)
proc `==`*(a, b: VkDisplayKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkDisplayModeKHR): string = "VkDisplayModeKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkDisplayModeKHR): bool = uint(handle) != 0
proc reset*(handle: var VkDisplayModeKHR) = handle = VkDisplayModeKHR(0)
proc `==`*(a, b: VkDisplayModeKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkSurfaceKHR): string = "VkSurfaceKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkSurfaceKHR): bool = uint(handle) != 0
proc reset*(handle: var VkSurfaceKHR) = handle = VkSurfaceKHR(0)
proc `==`*(a, b: VkSurfaceKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkSwapchainKHR): string = "VkSwapchainKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkSwapchainKHR): bool = uint(handle) != 0
proc reset*(handle: var VkSwapchainKHR) = handle = VkSwapchainKHR(0)
proc `==`*(a, b: VkSwapchainKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkDebugReportCallbackEXT): string = "VkDebugReportCallbackEXT(" & $(uint(handle)) & ")"
proc valid*(handle: VkDebugReportCallbackEXT): bool = uint(handle) != 0
proc reset*(handle: var VkDebugReportCallbackEXT) = handle = VkDebugReportCallbackEXT(0)
proc `==`*(a, b: VkDebugReportCallbackEXT): bool = uint(a) == uint(b)
proc `$`*(handle: VkDebugUtilsMessengerEXT): string = "VkDebugUtilsMessengerEXT(" & $(uint(handle)) & ")"
proc valid*(handle: VkDebugUtilsMessengerEXT): bool = uint(handle) != 0
proc reset*(handle: var VkDebugUtilsMessengerEXT) = handle = VkDebugUtilsMessengerEXT(0)
proc `==`*(a, b: VkDebugUtilsMessengerEXT): bool = uint(a) == uint(b)
proc `$`*(handle: VkVideoSessionKHR): string = "VkVideoSessionKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkVideoSessionKHR): bool = uint(handle) != 0
proc reset*(handle: var VkVideoSessionKHR) = handle = VkVideoSessionKHR(0)
proc `==`*(a, b: VkVideoSessionKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkVideoSessionParametersKHR): string = "VkVideoSessionParametersKHR(" & $(uint(handle)) & ")"
proc valid*(handle: VkVideoSessionParametersKHR): bool = uint(handle) != 0
proc reset*(handle: var VkVideoSessionParametersKHR) = handle = VkVideoSessionParametersKHR(0)
proc `==`*(a, b: VkVideoSessionParametersKHR): bool = uint(a) == uint(b)
proc `$`*(handle: VkSemaphoreSciSyncPoolNV): string = "VkSemaphoreSciSyncPoolNV(" & $(uint(handle)) & ")"
proc valid*(handle: VkSemaphoreSciSyncPoolNV): bool = uint(handle) != 0
proc reset*(handle: var VkSemaphoreSciSyncPoolNV) = handle = VkSemaphoreSciSyncPoolNV(0)
proc `==`*(a, b: VkSemaphoreSciSyncPoolNV): bool = uint(a) == uint(b)
type
  VkFramebufferCreateFlags* = distinct VkFlags
  VkQueryPoolCreateFlags* = distinct VkFlags
  VkRenderPassCreateFlags* = distinct VkFlags
  VkSamplerCreateFlags* = distinct VkFlags
  VkPipelineLayoutCreateFlags* = distinct VkFlags
  VkPipelineCacheCreateFlags* = distinct VkFlags
  VkPipelineDepthStencilStateCreateFlags* = distinct VkFlags
  VkPipelineDynamicStateCreateFlags* = distinct VkFlags
  VkPipelineColorBlendStateCreateFlags* = distinct VkFlags
  VkPipelineMultisampleStateCreateFlags* = distinct VkFlags
  VkPipelineRasterizationStateCreateFlags* = distinct VkFlags
  VkPipelineViewportStateCreateFlags* = distinct VkFlags
  VkPipelineTessellationStateCreateFlags* = distinct VkFlags
  VkPipelineInputAssemblyStateCreateFlags* = distinct VkFlags
  VkPipelineVertexInputStateCreateFlags* = distinct VkFlags
  VkPipelineShaderStageCreateFlags* = distinct VkFlags
  VkDescriptorSetLayoutCreateFlags* = distinct VkFlags
  VkBufferViewCreateFlags* = distinct VkFlags
  VkInstanceCreateFlags* = distinct VkFlags
  VkDeviceCreateFlags* = distinct VkFlags
  VkDeviceQueueCreateFlags* = distinct VkFlags
  VkQueueFlags* = distinct VkFlags
  VkMemoryPropertyFlags* = distinct VkFlags
  VkMemoryHeapFlags* = distinct VkFlags
  VkAccessFlags* = distinct VkFlags
  VkBufferUsageFlags* = distinct VkFlags
  VkBufferCreateFlags* = distinct VkFlags
  VkShaderStageFlags* = distinct VkFlags
  VkImageUsageFlags* = distinct VkFlags
  VkImageCreateFlags* = distinct VkFlags
  VkImageViewCreateFlags* = distinct VkFlags
  VkPipelineCreateFlags* = distinct VkFlags
  VkColorComponentFlags* = distinct VkFlags
  VkFenceCreateFlags* = distinct VkFlags
  VkSemaphoreCreateFlags* = distinct VkFlags
  VkFormatFeatureFlags* = distinct VkFlags
  VkQueryControlFlags* = distinct VkFlags
  VkQueryResultFlags* = distinct VkFlags
  VkShaderModuleCreateFlags* = distinct VkFlags
  VkEventCreateFlags* = distinct VkFlags
  VkCommandPoolCreateFlags* = distinct VkFlags
  VkCommandPoolResetFlags* = distinct VkFlags
  VkCommandBufferResetFlags* = distinct VkFlags
  VkCommandBufferUsageFlags* = distinct VkFlags
  VkQueryPipelineStatisticFlags* = distinct VkFlags
  VkMemoryMapFlags* = distinct VkFlags
  VkImageAspectFlags* = distinct VkFlags
  VkSparseMemoryBindFlags* = distinct VkFlags
  VkSparseImageFormatFlags* = distinct VkFlags
  VkSubpassDescriptionFlags* = distinct VkFlags
  VkPipelineStageFlags* = distinct VkFlags
  VkSampleCountFlags* = distinct VkFlags
  VkAttachmentDescriptionFlags* = distinct VkFlags
  VkStencilFaceFlags* = distinct VkFlags
  VkCullModeFlags* = distinct VkFlags
  VkDescriptorPoolCreateFlags* = distinct VkFlags
  VkDescriptorPoolResetFlags* = distinct VkFlags
  VkDependencyFlags* = distinct VkFlags
  VkSubgroupFeatureFlags* = distinct VkFlags
  VkIndirectCommandsLayoutUsageFlagsNV* = distinct VkFlags
  VkIndirectStateFlagsNV* = distinct VkFlags
  VkGeometryFlagsKHR* = distinct VkFlags
  VkGeometryInstanceFlagsKHR* = distinct VkFlags
  VkBuildAccelerationStructureFlagsKHR* = distinct VkFlags
  VkPrivateDataSlotCreateFlags* = distinct VkFlags
  VkAccelerationStructureCreateFlagsKHR* = distinct VkFlags
  VkDescriptorUpdateTemplateCreateFlags* = distinct VkFlags
  VkPipelineCreationFeedbackFlags* = distinct VkFlags
  VkPerformanceCounterDescriptionFlagsKHR* = distinct VkFlags
  VkAcquireProfilingLockFlagsKHR* = distinct VkFlags
  VkSemaphoreWaitFlags* = distinct VkFlags
  VkPipelineCompilerControlFlagsAMD* = distinct VkFlags
  VkShaderCorePropertiesFlagsAMD* = distinct VkFlags
  VkDeviceDiagnosticsConfigFlagsNV* = distinct VkFlags
  VkRefreshObjectFlagsKHR* = distinct VkFlags
  VkAccessFlags2* = distinct VkFlags
  VkPipelineStageFlags2* = distinct VkFlags
  VkAccelerationStructureMotionInfoFlagsNV* = distinct VkFlags
  VkAccelerationStructureMotionInstanceFlagsNV* = distinct VkFlags
  VkFormatFeatureFlags2* = distinct VkFlags
  VkRenderingFlags* = distinct VkFlags
  VkMemoryDecompressionMethodFlagsNV* = distinct VkFlags
  VkBuildMicromapFlagsEXT* = distinct VkFlags
  VkMicromapCreateFlagsEXT* = distinct VkFlags
  VkDirectDriverLoadingFlagsLUNARG* = distinct VkFlags
  VkCompositeAlphaFlagsKHR* = distinct VkFlags
  VkDisplayPlaneAlphaFlagsKHR* = distinct VkFlags
  VkSurfaceTransformFlagsKHR* = distinct VkFlags
  VkSwapchainCreateFlagsKHR* = distinct VkFlags
  VkDisplayModeCreateFlagsKHR* = distinct VkFlags
  VkDisplaySurfaceCreateFlagsKHR* = distinct VkFlags
  VkAndroidSurfaceCreateFlagsKHR* = distinct VkFlags
  VkViSurfaceCreateFlagsNN* = distinct VkFlags
  VkWaylandSurfaceCreateFlagsKHR* = distinct VkFlags
  VkWin32SurfaceCreateFlagsKHR* = distinct VkFlags
  VkXlibSurfaceCreateFlagsKHR* = distinct VkFlags
  VkXcbSurfaceCreateFlagsKHR* = distinct VkFlags
  VkDirectFBSurfaceCreateFlagsEXT* = distinct VkFlags
  VkIOSSurfaceCreateFlagsMVK* = distinct VkFlags
  VkMacOSSurfaceCreateFlagsMVK* = distinct VkFlags
  VkMetalSurfaceCreateFlagsEXT* = distinct VkFlags
  VkImagePipeSurfaceCreateFlagsFUCHSIA* = distinct VkFlags
  VkStreamDescriptorSurfaceCreateFlagsGGP* = distinct VkFlags
  VkHeadlessSurfaceCreateFlagsEXT* = distinct VkFlags
  VkScreenSurfaceCreateFlagsQNX* = distinct VkFlags
  VkPeerMemoryFeatureFlags* = distinct VkFlags
  VkMemoryAllocateFlags* = distinct VkFlags
  VkDeviceGroupPresentModeFlagsKHR* = distinct VkFlags
  VkDebugReportFlagsEXT* = distinct VkFlags
  VkCommandPoolTrimFlags* = distinct VkFlags
  VkExternalMemoryHandleTypeFlagsNV* = distinct VkFlags
  VkExternalMemoryFeatureFlagsNV* = distinct VkFlags
  VkExternalMemoryHandleTypeFlags* = distinct VkFlags
  VkExternalMemoryFeatureFlags* = distinct VkFlags
  VkExternalSemaphoreHandleTypeFlags* = distinct VkFlags
  VkExternalSemaphoreFeatureFlags* = distinct VkFlags
  VkSemaphoreImportFlags* = distinct VkFlags
  VkExternalFenceHandleTypeFlags* = distinct VkFlags
  VkExternalFenceFeatureFlags* = distinct VkFlags
  VkFenceImportFlags* = distinct VkFlags
  VkSurfaceCounterFlagsEXT* = distinct VkFlags
  VkPipelineViewportSwizzleStateCreateFlagsNV* = distinct VkFlags
  VkPipelineDiscardRectangleStateCreateFlagsEXT* = distinct VkFlags
  VkPipelineCoverageToColorStateCreateFlagsNV* = distinct VkFlags
  VkPipelineCoverageModulationStateCreateFlagsNV* = distinct VkFlags
  VkPipelineCoverageReductionStateCreateFlagsNV* = distinct VkFlags
  VkValidationCacheCreateFlagsEXT* = distinct VkFlags
  VkDebugUtilsMessageSeverityFlagsEXT* = distinct VkFlags
  VkDebugUtilsMessageTypeFlagsEXT* = distinct VkFlags
  VkDebugUtilsMessengerCreateFlagsEXT* = distinct VkFlags
  VkDebugUtilsMessengerCallbackDataFlagsEXT* = distinct VkFlags
  VkDeviceMemoryReportFlagsEXT* = distinct VkFlags
  VkPipelineRasterizationConservativeStateCreateFlagsEXT* = distinct VkFlags
  VkDescriptorBindingFlags* = distinct VkFlags
  VkConditionalRenderingFlagsEXT* = distinct VkFlags
  VkResolveModeFlags* = distinct VkFlags
  VkPipelineRasterizationStateStreamCreateFlagsEXT* = distinct VkFlags
  VkPipelineRasterizationDepthClipStateCreateFlagsEXT* = distinct VkFlags
  VkSwapchainImageUsageFlagsANDROID* = distinct VkFlags
  VkToolPurposeFlags* = distinct VkFlags
  VkSubmitFlags* = distinct VkFlags
  VkImageFormatConstraintsFlagsFUCHSIA* = distinct VkFlags
  VkImageConstraintsInfoFlagsFUCHSIA* = distinct VkFlags
  VkGraphicsPipelineLibraryFlagsEXT* = distinct VkFlags
  VkImageCompressionFlagsEXT* = distinct VkFlags
  VkImageCompressionFixedRateFlagsEXT* = distinct VkFlags
  VkExportMetalObjectTypeFlagsEXT* = distinct VkFlags
  VkDeviceAddressBindingFlagsEXT* = distinct VkFlags
  VkOpticalFlowGridSizeFlagsNV* = distinct VkFlags
  VkOpticalFlowUsageFlagsNV* = distinct VkFlags
  VkOpticalFlowSessionCreateFlagsNV* = distinct VkFlags
  VkOpticalFlowExecuteFlagsNV* = distinct VkFlags
  VkPresentScalingFlagsEXT* = distinct VkFlags
  VkPresentGravityFlagsEXT* = distinct VkFlags
  VkVideoCodecOperationFlagsKHR* = distinct VkFlags
  VkVideoCapabilityFlagsKHR* = distinct VkFlags
  VkVideoSessionCreateFlagsKHR* = distinct VkFlags
  VkVideoSessionParametersCreateFlagsKHR* = distinct VkFlags
  VkVideoBeginCodingFlagsKHR* = distinct VkFlags
  VkVideoEndCodingFlagsKHR* = distinct VkFlags
  VkVideoCodingControlFlagsKHR* = distinct VkFlags
  VkVideoDecodeUsageFlagsKHR* = distinct VkFlags
  VkVideoDecodeCapabilityFlagsKHR* = distinct VkFlags
  VkVideoDecodeFlagsKHR* = distinct VkFlags
  VkVideoDecodeH264PictureLayoutFlagsKHR* = distinct VkFlags
  VkVideoEncodeFlagsKHR* = distinct VkFlags
  VkVideoEncodeUsageFlagsKHR* = distinct VkFlags
  VkVideoEncodeContentFlagsKHR* = distinct VkFlags
  VkVideoEncodeCapabilityFlagsKHR* = distinct VkFlags
  VkVideoEncodeRateControlFlagsKHR* = distinct VkFlags
  VkVideoEncodeRateControlModeFlagsKHR* = distinct VkFlags
  VkVideoChromaSubsamplingFlagsKHR* = distinct VkFlags
  VkVideoComponentBitDepthFlagsKHR* = distinct VkFlags
  VkVideoEncodeH264CapabilityFlagsEXT* = distinct VkFlags
  VkVideoEncodeH264InputModeFlagsEXT* = distinct VkFlags
  VkVideoEncodeH264OutputModeFlagsEXT* = distinct VkFlags
  VkVideoEncodeH265CapabilityFlagsEXT* = distinct VkFlags
  VkVideoEncodeH265InputModeFlagsEXT* = distinct VkFlags
  VkVideoEncodeH265OutputModeFlagsEXT* = distinct VkFlags
  VkVideoEncodeH265CtbSizeFlagsEXT* = distinct VkFlags
  VkVideoEncodeH265TransformBlockSizeFlagsEXT* = distinct VkFlags
let vkGetInstanceProcAddr = cast[proc(instance: VkInstance, name: cstring): pointer {.stdcall.}](checkedSymAddr(vulkanLib, "vkGetInstanceProcAddr"))
type
  VkImageLayout* {.size: sizeof(cint).} = enum
    VK_IMAGE_LAYOUT_UNDEFINED = 0
    VK_IMAGE_LAYOUT_GENERAL = 1
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
    VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL = 3
    VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL = 4
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL = 5
    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL = 7
    VK_IMAGE_LAYOUT_PREINITIALIZED = 8
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
    VK_IMAGE_LAYOUT_VIDEO_DECODE_DST_KHR = 1000024000
    VK_IMAGE_LAYOUT_VIDEO_DECODE_SRC_KHR = 1000024001
    VK_IMAGE_LAYOUT_VIDEO_DECODE_DPB_KHR = 1000024002
    VK_IMAGE_LAYOUT_SHARED_PRESENT_KHR = 1000111000
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL = 1000117000
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL = 1000117001
    VK_IMAGE_LAYOUT_FRAGMENT_SHADING_RATE_ATTACHMENT_OPTIMAL_KHR = 1000164003
    VK_IMAGE_LAYOUT_FRAGMENT_DENSITY_MAP_OPTIMAL_EXT = 1000218000
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL = 1000241000
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL = 1000241001
    VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL = 1000241002
    VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL = 1000241003
    VK_IMAGE_LAYOUT_VIDEO_ENCODE_DST_KHR = 1000299000
    VK_IMAGE_LAYOUT_VIDEO_ENCODE_SRC_KHR = 1000299001
    VK_IMAGE_LAYOUT_VIDEO_ENCODE_DPB_KHR = 1000299002
    VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL = 1000314000
    VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL = 1000314001
    VK_IMAGE_LAYOUT_ATTACHMENT_FEEDBACK_LOOP_OPTIMAL_EXT = 1000339000
  VkAttachmentLoadOp* {.size: sizeof(cint).} = enum
    VK_ATTACHMENT_LOAD_OP_LOAD = 0
    VK_ATTACHMENT_LOAD_OP_CLEAR = 1
    VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
    VK_ATTACHMENT_LOAD_OP_NONE_EXT = 1000400000
  VkAttachmentStoreOp* {.size: sizeof(cint).} = enum
    VK_ATTACHMENT_STORE_OP_STORE = 0
    VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
    VK_ATTACHMENT_STORE_OP_NONE = 1000301000
  VkImageType* {.size: sizeof(cint).} = enum
    VK_IMAGE_TYPE_1D = 0
    VK_IMAGE_TYPE_2D = 1
    VK_IMAGE_TYPE_3D = 2
  VkImageTiling* {.size: sizeof(cint).} = enum
    VK_IMAGE_TILING_OPTIMAL = 0
    VK_IMAGE_TILING_LINEAR = 1
    VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT = 1000158000
  VkImageViewType* {.size: sizeof(cint).} = enum
    VK_IMAGE_VIEW_TYPE_1D = 0
    VK_IMAGE_VIEW_TYPE_2D = 1
    VK_IMAGE_VIEW_TYPE_3D = 2
    VK_IMAGE_VIEW_TYPE_CUBE = 3
    VK_IMAGE_VIEW_TYPE_1D_ARRAY = 4
    VK_IMAGE_VIEW_TYPE_2D_ARRAY = 5
    VK_IMAGE_VIEW_TYPE_CUBE_ARRAY = 6
  VkCommandBufferLevel* {.size: sizeof(cint).} = enum
    VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
    VK_COMMAND_BUFFER_LEVEL_SECONDARY = 1
  VkComponentSwizzle* {.size: sizeof(cint).} = enum
    VK_COMPONENT_SWIZZLE_IDENTITY = 0
    VK_COMPONENT_SWIZZLE_ZERO = 1
    VK_COMPONENT_SWIZZLE_ONE = 2
    VK_COMPONENT_SWIZZLE_R = 3
    VK_COMPONENT_SWIZZLE_G = 4
    VK_COMPONENT_SWIZZLE_B = 5
    VK_COMPONENT_SWIZZLE_A = 6
  VkDescriptorType* {.size: sizeof(cint).} = enum
    VK_DESCRIPTOR_TYPE_SAMPLER = 0
    VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER = 1
    VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE = 2
    VK_DESCRIPTOR_TYPE_STORAGE_IMAGE = 3
    VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER = 4
    VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER = 5
    VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6
    VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7
    VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC = 8
    VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC = 9
    VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT = 10
    VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK = 1000138000
    VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR = 1000150000
    VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_NV = 1000165000
    VK_DESCRIPTOR_TYPE_MUTABLE_EXT = 1000351000
    VK_DESCRIPTOR_TYPE_SAMPLE_WEIGHT_IMAGE_QCOM = 1000440000
    VK_DESCRIPTOR_TYPE_BLOCK_MATCH_IMAGE_QCOM = 1000440001
  VkQueryType* {.size: sizeof(cint).} = enum
    VK_QUERY_TYPE_OCCLUSION = 0
    VK_QUERY_TYPE_PIPELINE_STATISTICS = 1
    VK_QUERY_TYPE_TIMESTAMP = 2
    VK_QUERY_TYPE_RESULT_STATUS_ONLY_KHR = 1000023000
    VK_QUERY_TYPE_TRANSFORM_FEEDBACK_STREAM_EXT = 1000028004
    VK_QUERY_TYPE_PERFORMANCE_QUERY_KHR = 1000116000
    VK_QUERY_TYPE_ACCELERATION_STRUCTURE_COMPACTED_SIZE_KHR = 1000150000
    VK_QUERY_TYPE_ACCELERATION_STRUCTURE_SERIALIZATION_SIZE_KHR = 1000150001
    VK_QUERY_TYPE_ACCELERATION_STRUCTURE_COMPACTED_SIZE_NV = 1000165000
    VK_QUERY_TYPE_PERFORMANCE_QUERY_INTEL = 1000210000
    VK_QUERY_TYPE_VIDEO_ENCODE_BITSTREAM_BUFFER_RANGE_KHR = 1000299000
    VK_QUERY_TYPE_MESH_PRIMITIVES_GENERATED_EXT = 1000328000
    VK_QUERY_TYPE_PRIMITIVES_GENERATED_EXT = 1000382000
    VK_QUERY_TYPE_ACCELERATION_STRUCTURE_SERIALIZATION_BOTTOM_LEVEL_POINTERS_KHR = 1000386000
    VK_QUERY_TYPE_ACCELERATION_STRUCTURE_SIZE_KHR = 1000386001
    VK_QUERY_TYPE_MICROMAP_SERIALIZATION_SIZE_EXT = 1000396000
    VK_QUERY_TYPE_MICROMAP_COMPACTED_SIZE_EXT = 1000396001
  VkBorderColor* {.size: sizeof(cint).} = enum
    VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK = 0
    VK_BORDER_COLOR_INT_TRANSPARENT_BLACK = 1
    VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK = 2
    VK_BORDER_COLOR_INT_OPAQUE_BLACK = 3
    VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE = 4
    VK_BORDER_COLOR_INT_OPAQUE_WHITE = 5
    VK_BORDER_COLOR_FLOAT_CUSTOM_EXT = 1000287003
    VK_BORDER_COLOR_INT_CUSTOM_EXT = 1000287004
  VkPipelineBindPoint* {.size: sizeof(cint).} = enum
    VK_PIPELINE_BIND_POINT_GRAPHICS = 0
    VK_PIPELINE_BIND_POINT_COMPUTE = 1
    VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR = 1000165000
    VK_PIPELINE_BIND_POINT_SUBPASS_SHADING_HUAWEI = 1000369003
  VkPipelineCacheHeaderVersion* {.size: sizeof(cint).} = enum
    VK_PIPELINE_CACHE_HEADER_VERSION_ONE_ENUM = 1
    VK_PIPELINE_CACHE_HEADER_VERSION_SAFETY_CRITICAL_ONE_ENUM = 1000298001
  VkPipelineCacheCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT = 0b00000000000000000000000000000001
    VK_PIPELINE_CACHE_CREATE_RESERVED_1_BIT_EXT = 0b00000000000000000000000000000010
    VK_PIPELINE_CACHE_CREATE_USE_APPLICATION_STORAGE_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkPipelineCacheCreateFlagBits]): VkPipelineCacheCreateFlags =
    for flag in flags:
      result = VkPipelineCacheCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineCacheCreateFlags): seq[VkPipelineCacheCreateFlagBits] =
    for value in VkPipelineCacheCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineCacheCreateFlags): bool = cint(a) == cint(b)
type
  VkPrimitiveTopology* {.size: sizeof(cint).} = enum
    VK_PRIMITIVE_TOPOLOGY_POINT_LIST = 0
    VK_PRIMITIVE_TOPOLOGY_LINE_LIST = 1
    VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP = 4
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN = 5
    VK_PRIMITIVE_TOPOLOGY_LINE_LIST_WITH_ADJACENCY = 6
    VK_PRIMITIVE_TOPOLOGY_LINE_STRIP_WITH_ADJACENCY = 7
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST_WITH_ADJACENCY = 8
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP_WITH_ADJACENCY = 9
    VK_PRIMITIVE_TOPOLOGY_PATCH_LIST = 10
  VkSharingMode* {.size: sizeof(cint).} = enum
    VK_SHARING_MODE_EXCLUSIVE = 0
    VK_SHARING_MODE_CONCURRENT = 1
  VkIndexType* {.size: sizeof(cint).} = enum
    VK_INDEX_TYPE_UINT16 = 0
    VK_INDEX_TYPE_UINT32 = 1
    VK_INDEX_TYPE_NONE_KHR = 1000165000
    VK_INDEX_TYPE_UINT8_EXT = 1000265000
  VkFilter* {.size: sizeof(cint).} = enum
    VK_FILTER_NEAREST = 0
    VK_FILTER_LINEAR = 1
    VK_FILTER_CUBIC_EXT = 1000015000
  VkSamplerMipmapMode* {.size: sizeof(cint).} = enum
    VK_SAMPLER_MIPMAP_MODE_NEAREST = 0
    VK_SAMPLER_MIPMAP_MODE_LINEAR = 1
  VkSamplerAddressMode* {.size: sizeof(cint).} = enum
    VK_SAMPLER_ADDRESS_MODE_REPEAT = 0
    VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT = 1
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE = 2
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER = 3
    VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE = 4
  VkCompareOp* {.size: sizeof(cint).} = enum
    VK_COMPARE_OP_NEVER = 0
    VK_COMPARE_OP_LESS = 1
    VK_COMPARE_OP_EQUAL = 2
    VK_COMPARE_OP_LESS_OR_EQUAL = 3
    VK_COMPARE_OP_GREATER = 4
    VK_COMPARE_OP_NOT_EQUAL = 5
    VK_COMPARE_OP_GREATER_OR_EQUAL = 6
    VK_COMPARE_OP_ALWAYS = 7
  VkPolygonMode* {.size: sizeof(cint).} = enum
    VK_POLYGON_MODE_FILL = 0
    VK_POLYGON_MODE_LINE = 1
    VK_POLYGON_MODE_POINT = 2
    VK_POLYGON_MODE_FILL_RECTANGLE_NV = 1000153000
  VkFrontFace* {.size: sizeof(cint).} = enum
    VK_FRONT_FACE_COUNTER_CLOCKWISE = 0
    VK_FRONT_FACE_CLOCKWISE = 1
  VkBlendFactor* {.size: sizeof(cint).} = enum
    VK_BLEND_FACTOR_ZERO = 0
    VK_BLEND_FACTOR_ONE = 1
    VK_BLEND_FACTOR_SRC_COLOR = 2
    VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR = 3
    VK_BLEND_FACTOR_DST_COLOR = 4
    VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR = 5
    VK_BLEND_FACTOR_SRC_ALPHA = 6
    VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = 7
    VK_BLEND_FACTOR_DST_ALPHA = 8
    VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA = 9
    VK_BLEND_FACTOR_CONSTANT_COLOR = 10
    VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR = 11
    VK_BLEND_FACTOR_CONSTANT_ALPHA = 12
    VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA = 13
    VK_BLEND_FACTOR_SRC_ALPHA_SATURATE = 14
    VK_BLEND_FACTOR_SRC1_COLOR = 15
    VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR = 16
    VK_BLEND_FACTOR_SRC1_ALPHA = 17
    VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA = 18
  VkBlendOp* {.size: sizeof(cint).} = enum
    VK_BLEND_OP_ADD = 0
    VK_BLEND_OP_SUBTRACT = 1
    VK_BLEND_OP_REVERSE_SUBTRACT = 2
    VK_BLEND_OP_MIN = 3
    VK_BLEND_OP_MAX = 4
    VK_BLEND_OP_ZERO_EXT = 1000148000
    VK_BLEND_OP_SRC_EXT = 1000148001
    VK_BLEND_OP_DST_EXT = 1000148002
    VK_BLEND_OP_SRC_OVER_EXT = 1000148003
    VK_BLEND_OP_DST_OVER_EXT = 1000148004
    VK_BLEND_OP_SRC_IN_EXT = 1000148005
    VK_BLEND_OP_DST_IN_EXT = 1000148006
    VK_BLEND_OP_SRC_OUT_EXT = 1000148007
    VK_BLEND_OP_DST_OUT_EXT = 1000148008
    VK_BLEND_OP_SRC_ATOP_EXT = 1000148009
    VK_BLEND_OP_DST_ATOP_EXT = 1000148010
    VK_BLEND_OP_XOR_EXT = 1000148011
    VK_BLEND_OP_MULTIPLY_EXT = 1000148012
    VK_BLEND_OP_SCREEN_EXT = 1000148013
    VK_BLEND_OP_OVERLAY_EXT = 1000148014
    VK_BLEND_OP_DARKEN_EXT = 1000148015
    VK_BLEND_OP_LIGHTEN_EXT = 1000148016
    VK_BLEND_OP_COLORDODGE_EXT = 1000148017
    VK_BLEND_OP_COLORBURN_EXT = 1000148018
    VK_BLEND_OP_HARDLIGHT_EXT = 1000148019
    VK_BLEND_OP_SOFTLIGHT_EXT = 1000148020
    VK_BLEND_OP_DIFFERENCE_EXT = 1000148021
    VK_BLEND_OP_EXCLUSION_EXT = 1000148022
    VK_BLEND_OP_INVERT_EXT = 1000148023
    VK_BLEND_OP_INVERT_RGB_EXT = 1000148024
    VK_BLEND_OP_LINEARDODGE_EXT = 1000148025
    VK_BLEND_OP_LINEARBURN_EXT = 1000148026
    VK_BLEND_OP_VIVIDLIGHT_EXT = 1000148027
    VK_BLEND_OP_LINEARLIGHT_EXT = 1000148028
    VK_BLEND_OP_PINLIGHT_EXT = 1000148029
    VK_BLEND_OP_HARDMIX_EXT = 1000148030
    VK_BLEND_OP_HSL_HUE_EXT = 1000148031
    VK_BLEND_OP_HSL_SATURATION_EXT = 1000148032
    VK_BLEND_OP_HSL_COLOR_EXT = 1000148033
    VK_BLEND_OP_HSL_LUMINOSITY_EXT = 1000148034
    VK_BLEND_OP_PLUS_EXT = 1000148035
    VK_BLEND_OP_PLUS_CLAMPED_EXT = 1000148036
    VK_BLEND_OP_PLUS_CLAMPED_ALPHA_EXT = 1000148037
    VK_BLEND_OP_PLUS_DARKER_EXT = 1000148038
    VK_BLEND_OP_MINUS_EXT = 1000148039
    VK_BLEND_OP_MINUS_CLAMPED_EXT = 1000148040
    VK_BLEND_OP_CONTRAST_EXT = 1000148041
    VK_BLEND_OP_INVERT_OVG_EXT = 1000148042
    VK_BLEND_OP_RED_EXT = 1000148043
    VK_BLEND_OP_GREEN_EXT = 1000148044
    VK_BLEND_OP_BLUE_EXT = 1000148045
  VkStencilOp* {.size: sizeof(cint).} = enum
    VK_STENCIL_OP_KEEP = 0
    VK_STENCIL_OP_ZERO = 1
    VK_STENCIL_OP_REPLACE = 2
    VK_STENCIL_OP_INCREMENT_AND_CLAMP = 3
    VK_STENCIL_OP_DECREMENT_AND_CLAMP = 4
    VK_STENCIL_OP_INVERT = 5
    VK_STENCIL_OP_INCREMENT_AND_WRAP = 6
    VK_STENCIL_OP_DECREMENT_AND_WRAP = 7
  VkLogicOp* {.size: sizeof(cint).} = enum
    VK_LOGIC_OP_CLEAR = 0
    VK_LOGIC_OP_AND = 1
    VK_LOGIC_OP_AND_REVERSE = 2
    VK_LOGIC_OP_COPY = 3
    VK_LOGIC_OP_AND_INVERTED = 4
    VK_LOGIC_OP_NO_OP = 5
    VK_LOGIC_OP_XOR = 6
    VK_LOGIC_OP_OR = 7
    VK_LOGIC_OP_NOR = 8
    VK_LOGIC_OP_EQUIVALENT = 9
    VK_LOGIC_OP_INVERT = 10
    VK_LOGIC_OP_OR_REVERSE = 11
    VK_LOGIC_OP_COPY_INVERTED = 12
    VK_LOGIC_OP_OR_INVERTED = 13
    VK_LOGIC_OP_NAND = 14
    VK_LOGIC_OP_SET = 15
  VkInternalAllocationType* {.size: sizeof(cint).} = enum
    VK_INTERNAL_ALLOCATION_TYPE_EXECUTABLE = 0
  VkSystemAllocationScope* {.size: sizeof(cint).} = enum
    VK_SYSTEM_ALLOCATION_SCOPE_COMMAND = 0
    VK_SYSTEM_ALLOCATION_SCOPE_OBJECT = 1
    VK_SYSTEM_ALLOCATION_SCOPE_CACHE = 2
    VK_SYSTEM_ALLOCATION_SCOPE_DEVICE = 3
    VK_SYSTEM_ALLOCATION_SCOPE_INSTANCE = 4
  VkPhysicalDeviceType* {.size: sizeof(cint).} = enum
    VK_PHYSICAL_DEVICE_TYPE_OTHER = 0
    VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1
    VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2
    VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3
    VK_PHYSICAL_DEVICE_TYPE_CPU = 4
  VkVertexInputRate* {.size: sizeof(cint).} = enum
    VK_VERTEX_INPUT_RATE_VERTEX = 0
    VK_VERTEX_INPUT_RATE_INSTANCE = 1
  VkFormat* {.size: sizeof(cint).} = enum
    VK_FORMAT_UNDEFINED = 0
    VK_FORMAT_R4G4_UNORM_PACK8 = 1
    VK_FORMAT_R4G4B4A4_UNORM_PACK16 = 2
    VK_FORMAT_B4G4R4A4_UNORM_PACK16 = 3
    VK_FORMAT_R5G6B5_UNORM_PACK16 = 4
    VK_FORMAT_B5G6R5_UNORM_PACK16 = 5
    VK_FORMAT_R5G5B5A1_UNORM_PACK16 = 6
    VK_FORMAT_B5G5R5A1_UNORM_PACK16 = 7
    VK_FORMAT_A1R5G5B5_UNORM_PACK16 = 8
    VK_FORMAT_R8_UNORM = 9
    VK_FORMAT_R8_SNORM = 10
    VK_FORMAT_R8_USCALED = 11
    VK_FORMAT_R8_SSCALED = 12
    VK_FORMAT_R8_UINT = 13
    VK_FORMAT_R8_SINT = 14
    VK_FORMAT_R8_SRGB = 15
    VK_FORMAT_R8G8_UNORM = 16
    VK_FORMAT_R8G8_SNORM = 17
    VK_FORMAT_R8G8_USCALED = 18
    VK_FORMAT_R8G8_SSCALED = 19
    VK_FORMAT_R8G8_UINT = 20
    VK_FORMAT_R8G8_SINT = 21
    VK_FORMAT_R8G8_SRGB = 22
    VK_FORMAT_R8G8B8_UNORM = 23
    VK_FORMAT_R8G8B8_SNORM = 24
    VK_FORMAT_R8G8B8_USCALED = 25
    VK_FORMAT_R8G8B8_SSCALED = 26
    VK_FORMAT_R8G8B8_UINT = 27
    VK_FORMAT_R8G8B8_SINT = 28
    VK_FORMAT_R8G8B8_SRGB = 29
    VK_FORMAT_B8G8R8_UNORM = 30
    VK_FORMAT_B8G8R8_SNORM = 31
    VK_FORMAT_B8G8R8_USCALED = 32
    VK_FORMAT_B8G8R8_SSCALED = 33
    VK_FORMAT_B8G8R8_UINT = 34
    VK_FORMAT_B8G8R8_SINT = 35
    VK_FORMAT_B8G8R8_SRGB = 36
    VK_FORMAT_R8G8B8A8_UNORM = 37
    VK_FORMAT_R8G8B8A8_SNORM = 38
    VK_FORMAT_R8G8B8A8_USCALED = 39
    VK_FORMAT_R8G8B8A8_SSCALED = 40
    VK_FORMAT_R8G8B8A8_UINT = 41
    VK_FORMAT_R8G8B8A8_SINT = 42
    VK_FORMAT_R8G8B8A8_SRGB = 43
    VK_FORMAT_B8G8R8A8_UNORM = 44
    VK_FORMAT_B8G8R8A8_SNORM = 45
    VK_FORMAT_B8G8R8A8_USCALED = 46
    VK_FORMAT_B8G8R8A8_SSCALED = 47
    VK_FORMAT_B8G8R8A8_UINT = 48
    VK_FORMAT_B8G8R8A8_SINT = 49
    VK_FORMAT_B8G8R8A8_SRGB = 50
    VK_FORMAT_A8B8G8R8_UNORM_PACK32 = 51
    VK_FORMAT_A8B8G8R8_SNORM_PACK32 = 52
    VK_FORMAT_A8B8G8R8_USCALED_PACK32 = 53
    VK_FORMAT_A8B8G8R8_SSCALED_PACK32 = 54
    VK_FORMAT_A8B8G8R8_UINT_PACK32 = 55
    VK_FORMAT_A8B8G8R8_SINT_PACK32 = 56
    VK_FORMAT_A8B8G8R8_SRGB_PACK32 = 57
    VK_FORMAT_A2R10G10B10_UNORM_PACK32 = 58
    VK_FORMAT_A2R10G10B10_SNORM_PACK32 = 59
    VK_FORMAT_A2R10G10B10_USCALED_PACK32 = 60
    VK_FORMAT_A2R10G10B10_SSCALED_PACK32 = 61
    VK_FORMAT_A2R10G10B10_UINT_PACK32 = 62
    VK_FORMAT_A2R10G10B10_SINT_PACK32 = 63
    VK_FORMAT_A2B10G10R10_UNORM_PACK32 = 64
    VK_FORMAT_A2B10G10R10_SNORM_PACK32 = 65
    VK_FORMAT_A2B10G10R10_USCALED_PACK32 = 66
    VK_FORMAT_A2B10G10R10_SSCALED_PACK32 = 67
    VK_FORMAT_A2B10G10R10_UINT_PACK32 = 68
    VK_FORMAT_A2B10G10R10_SINT_PACK32 = 69
    VK_FORMAT_R16_UNORM = 70
    VK_FORMAT_R16_SNORM = 71
    VK_FORMAT_R16_USCALED = 72
    VK_FORMAT_R16_SSCALED = 73
    VK_FORMAT_R16_UINT = 74
    VK_FORMAT_R16_SINT = 75
    VK_FORMAT_R16_SFLOAT = 76
    VK_FORMAT_R16G16_UNORM = 77
    VK_FORMAT_R16G16_SNORM = 78
    VK_FORMAT_R16G16_USCALED = 79
    VK_FORMAT_R16G16_SSCALED = 80
    VK_FORMAT_R16G16_UINT = 81
    VK_FORMAT_R16G16_SINT = 82
    VK_FORMAT_R16G16_SFLOAT = 83
    VK_FORMAT_R16G16B16_UNORM = 84
    VK_FORMAT_R16G16B16_SNORM = 85
    VK_FORMAT_R16G16B16_USCALED = 86
    VK_FORMAT_R16G16B16_SSCALED = 87
    VK_FORMAT_R16G16B16_UINT = 88
    VK_FORMAT_R16G16B16_SINT = 89
    VK_FORMAT_R16G16B16_SFLOAT = 90
    VK_FORMAT_R16G16B16A16_UNORM = 91
    VK_FORMAT_R16G16B16A16_SNORM = 92
    VK_FORMAT_R16G16B16A16_USCALED = 93
    VK_FORMAT_R16G16B16A16_SSCALED = 94
    VK_FORMAT_R16G16B16A16_UINT = 95
    VK_FORMAT_R16G16B16A16_SINT = 96
    VK_FORMAT_R16G16B16A16_SFLOAT = 97
    VK_FORMAT_R32_UINT = 98
    VK_FORMAT_R32_SINT = 99
    VK_FORMAT_R32_SFLOAT = 100
    VK_FORMAT_R32G32_UINT = 101
    VK_FORMAT_R32G32_SINT = 102
    VK_FORMAT_R32G32_SFLOAT = 103
    VK_FORMAT_R32G32B32_UINT = 104
    VK_FORMAT_R32G32B32_SINT = 105
    VK_FORMAT_R32G32B32_SFLOAT = 106
    VK_FORMAT_R32G32B32A32_UINT = 107
    VK_FORMAT_R32G32B32A32_SINT = 108
    VK_FORMAT_R32G32B32A32_SFLOAT = 109
    VK_FORMAT_R64_UINT = 110
    VK_FORMAT_R64_SINT = 111
    VK_FORMAT_R64_SFLOAT = 112
    VK_FORMAT_R64G64_UINT = 113
    VK_FORMAT_R64G64_SINT = 114
    VK_FORMAT_R64G64_SFLOAT = 115
    VK_FORMAT_R64G64B64_UINT = 116
    VK_FORMAT_R64G64B64_SINT = 117
    VK_FORMAT_R64G64B64_SFLOAT = 118
    VK_FORMAT_R64G64B64A64_UINT = 119
    VK_FORMAT_R64G64B64A64_SINT = 120
    VK_FORMAT_R64G64B64A64_SFLOAT = 121
    VK_FORMAT_B10G11R11_UFLOAT_PACK32 = 122
    VK_FORMAT_E5B9G9R9_UFLOAT_PACK32 = 123
    VK_FORMAT_D16_UNORM = 124
    VK_FORMAT_X8_D24_UNORM_PACK32 = 125
    VK_FORMAT_D32_SFLOAT = 126
    VK_FORMAT_S8_UINT = 127
    VK_FORMAT_D16_UNORM_S8_UINT = 128
    VK_FORMAT_D24_UNORM_S8_UINT = 129
    VK_FORMAT_D32_SFLOAT_S8_UINT = 130
    VK_FORMAT_BC1_RGB_UNORM_BLOCK = 131
    VK_FORMAT_BC1_RGB_SRGB_BLOCK = 132
    VK_FORMAT_BC1_RGBA_UNORM_BLOCK = 133
    VK_FORMAT_BC1_RGBA_SRGB_BLOCK = 134
    VK_FORMAT_BC2_UNORM_BLOCK = 135
    VK_FORMAT_BC2_SRGB_BLOCK = 136
    VK_FORMAT_BC3_UNORM_BLOCK = 137
    VK_FORMAT_BC3_SRGB_BLOCK = 138
    VK_FORMAT_BC4_UNORM_BLOCK = 139
    VK_FORMAT_BC4_SNORM_BLOCK = 140
    VK_FORMAT_BC5_UNORM_BLOCK = 141
    VK_FORMAT_BC5_SNORM_BLOCK = 142
    VK_FORMAT_BC6H_UFLOAT_BLOCK = 143
    VK_FORMAT_BC6H_SFLOAT_BLOCK = 144
    VK_FORMAT_BC7_UNORM_BLOCK = 145
    VK_FORMAT_BC7_SRGB_BLOCK = 146
    VK_FORMAT_ETC2_R8G8B8_UNORM_BLOCK = 147
    VK_FORMAT_ETC2_R8G8B8_SRGB_BLOCK = 148
    VK_FORMAT_ETC2_R8G8B8A1_UNORM_BLOCK = 149
    VK_FORMAT_ETC2_R8G8B8A1_SRGB_BLOCK = 150
    VK_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK = 151
    VK_FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK = 152
    VK_FORMAT_EAC_R11_UNORM_BLOCK = 153
    VK_FORMAT_EAC_R11_SNORM_BLOCK = 154
    VK_FORMAT_EAC_R11G11_UNORM_BLOCK = 155
    VK_FORMAT_EAC_R11G11_SNORM_BLOCK = 156
    VK_FORMAT_ASTC_4x4_UNORM_BLOCK = 157
    VK_FORMAT_ASTC_4x4_SRGB_BLOCK = 158
    VK_FORMAT_ASTC_5x4_UNORM_BLOCK = 159
    VK_FORMAT_ASTC_5x4_SRGB_BLOCK = 160
    VK_FORMAT_ASTC_5x5_UNORM_BLOCK = 161
    VK_FORMAT_ASTC_5x5_SRGB_BLOCK = 162
    VK_FORMAT_ASTC_6x5_UNORM_BLOCK = 163
    VK_FORMAT_ASTC_6x5_SRGB_BLOCK = 164
    VK_FORMAT_ASTC_6x6_UNORM_BLOCK = 165
    VK_FORMAT_ASTC_6x6_SRGB_BLOCK = 166
    VK_FORMAT_ASTC_8x5_UNORM_BLOCK = 167
    VK_FORMAT_ASTC_8x5_SRGB_BLOCK = 168
    VK_FORMAT_ASTC_8x6_UNORM_BLOCK = 169
    VK_FORMAT_ASTC_8x6_SRGB_BLOCK = 170
    VK_FORMAT_ASTC_8x8_UNORM_BLOCK = 171
    VK_FORMAT_ASTC_8x8_SRGB_BLOCK = 172
    VK_FORMAT_ASTC_10x5_UNORM_BLOCK = 173
    VK_FORMAT_ASTC_10x5_SRGB_BLOCK = 174
    VK_FORMAT_ASTC_10x6_UNORM_BLOCK = 175
    VK_FORMAT_ASTC_10x6_SRGB_BLOCK = 176
    VK_FORMAT_ASTC_10x8_UNORM_BLOCK = 177
    VK_FORMAT_ASTC_10x8_SRGB_BLOCK = 178
    VK_FORMAT_ASTC_10x10_UNORM_BLOCK = 179
    VK_FORMAT_ASTC_10x10_SRGB_BLOCK = 180
    VK_FORMAT_ASTC_12x10_UNORM_BLOCK = 181
    VK_FORMAT_ASTC_12x10_SRGB_BLOCK = 182
    VK_FORMAT_ASTC_12x12_UNORM_BLOCK = 183
    VK_FORMAT_ASTC_12x12_SRGB_BLOCK = 184
    VK_FORMAT_PVRTC1_2BPP_UNORM_BLOCK_IMG = 1000054000
    VK_FORMAT_PVRTC1_4BPP_UNORM_BLOCK_IMG = 1000054001
    VK_FORMAT_PVRTC2_2BPP_UNORM_BLOCK_IMG = 1000054002
    VK_FORMAT_PVRTC2_4BPP_UNORM_BLOCK_IMG = 1000054003
    VK_FORMAT_PVRTC1_2BPP_SRGB_BLOCK_IMG = 1000054004
    VK_FORMAT_PVRTC1_4BPP_SRGB_BLOCK_IMG = 1000054005
    VK_FORMAT_PVRTC2_2BPP_SRGB_BLOCK_IMG = 1000054006
    VK_FORMAT_PVRTC2_4BPP_SRGB_BLOCK_IMG = 1000054007
    VK_FORMAT_ASTC_4x4_SFLOAT_BLOCK = 1000066000
    VK_FORMAT_ASTC_5x4_SFLOAT_BLOCK = 1000066001
    VK_FORMAT_ASTC_5x5_SFLOAT_BLOCK = 1000066002
    VK_FORMAT_ASTC_6x5_SFLOAT_BLOCK = 1000066003
    VK_FORMAT_ASTC_6x6_SFLOAT_BLOCK = 1000066004
    VK_FORMAT_ASTC_8x5_SFLOAT_BLOCK = 1000066005
    VK_FORMAT_ASTC_8x6_SFLOAT_BLOCK = 1000066006
    VK_FORMAT_ASTC_8x8_SFLOAT_BLOCK = 1000066007
    VK_FORMAT_ASTC_10x5_SFLOAT_BLOCK = 1000066008
    VK_FORMAT_ASTC_10x6_SFLOAT_BLOCK = 1000066009
    VK_FORMAT_ASTC_10x8_SFLOAT_BLOCK = 1000066010
    VK_FORMAT_ASTC_10x10_SFLOAT_BLOCK = 1000066011
    VK_FORMAT_ASTC_12x10_SFLOAT_BLOCK = 1000066012
    VK_FORMAT_ASTC_12x12_SFLOAT_BLOCK = 1000066013
    VK_FORMAT_G8B8G8R8_422_UNORM = 1000156000
    VK_FORMAT_B8G8R8G8_422_UNORM = 1000156001
    VK_FORMAT_G8_B8_R8_3PLANE_420_UNORM = 1000156002
    VK_FORMAT_G8_B8R8_2PLANE_420_UNORM = 1000156003
    VK_FORMAT_G8_B8_R8_3PLANE_422_UNORM = 1000156004
    VK_FORMAT_G8_B8R8_2PLANE_422_UNORM = 1000156005
    VK_FORMAT_G8_B8_R8_3PLANE_444_UNORM = 1000156006
    VK_FORMAT_R10X6_UNORM_PACK16 = 1000156007
    VK_FORMAT_R10X6G10X6_UNORM_2PACK16 = 1000156008
    VK_FORMAT_R10X6G10X6B10X6A10X6_UNORM_4PACK16 = 1000156009
    VK_FORMAT_G10X6B10X6G10X6R10X6_422_UNORM_4PACK16 = 1000156010
    VK_FORMAT_B10X6G10X6R10X6G10X6_422_UNORM_4PACK16 = 1000156011
    VK_FORMAT_G10X6_B10X6_R10X6_3PLANE_420_UNORM_3PACK16 = 1000156012
    VK_FORMAT_G10X6_B10X6R10X6_2PLANE_420_UNORM_3PACK16 = 1000156013
    VK_FORMAT_G10X6_B10X6_R10X6_3PLANE_422_UNORM_3PACK16 = 1000156014
    VK_FORMAT_G10X6_B10X6R10X6_2PLANE_422_UNORM_3PACK16 = 1000156015
    VK_FORMAT_G10X6_B10X6_R10X6_3PLANE_444_UNORM_3PACK16 = 1000156016
    VK_FORMAT_R12X4_UNORM_PACK16 = 1000156017
    VK_FORMAT_R12X4G12X4_UNORM_2PACK16 = 1000156018
    VK_FORMAT_R12X4G12X4B12X4A12X4_UNORM_4PACK16 = 1000156019
    VK_FORMAT_G12X4B12X4G12X4R12X4_422_UNORM_4PACK16 = 1000156020
    VK_FORMAT_B12X4G12X4R12X4G12X4_422_UNORM_4PACK16 = 1000156021
    VK_FORMAT_G12X4_B12X4_R12X4_3PLANE_420_UNORM_3PACK16 = 1000156022
    VK_FORMAT_G12X4_B12X4R12X4_2PLANE_420_UNORM_3PACK16 = 1000156023
    VK_FORMAT_G12X4_B12X4_R12X4_3PLANE_422_UNORM_3PACK16 = 1000156024
    VK_FORMAT_G12X4_B12X4R12X4_2PLANE_422_UNORM_3PACK16 = 1000156025
    VK_FORMAT_G12X4_B12X4_R12X4_3PLANE_444_UNORM_3PACK16 = 1000156026
    VK_FORMAT_G16B16G16R16_422_UNORM = 1000156027
    VK_FORMAT_B16G16R16G16_422_UNORM = 1000156028
    VK_FORMAT_G16_B16_R16_3PLANE_420_UNORM = 1000156029
    VK_FORMAT_G16_B16R16_2PLANE_420_UNORM = 1000156030
    VK_FORMAT_G16_B16_R16_3PLANE_422_UNORM = 1000156031
    VK_FORMAT_G16_B16R16_2PLANE_422_UNORM = 1000156032
    VK_FORMAT_G16_B16_R16_3PLANE_444_UNORM = 1000156033
    VK_FORMAT_ASTC_3x3x3_UNORM_BLOCK_EXT = 1000288000
    VK_FORMAT_ASTC_3x3x3_SRGB_BLOCK_EXT = 1000288001
    VK_FORMAT_ASTC_3x3x3_SFLOAT_BLOCK_EXT = 1000288002
    VK_FORMAT_ASTC_4x3x3_UNORM_BLOCK_EXT = 1000288003
    VK_FORMAT_ASTC_4x3x3_SRGB_BLOCK_EXT = 1000288004
    VK_FORMAT_ASTC_4x3x3_SFLOAT_BLOCK_EXT = 1000288005
    VK_FORMAT_ASTC_4x4x3_UNORM_BLOCK_EXT = 1000288006
    VK_FORMAT_ASTC_4x4x3_SRGB_BLOCK_EXT = 1000288007
    VK_FORMAT_ASTC_4x4x3_SFLOAT_BLOCK_EXT = 1000288008
    VK_FORMAT_ASTC_4x4x4_UNORM_BLOCK_EXT = 1000288009
    VK_FORMAT_ASTC_4x4x4_SRGB_BLOCK_EXT = 1000288010
    VK_FORMAT_ASTC_4x4x4_SFLOAT_BLOCK_EXT = 1000288011
    VK_FORMAT_ASTC_5x4x4_UNORM_BLOCK_EXT = 1000288012
    VK_FORMAT_ASTC_5x4x4_SRGB_BLOCK_EXT = 1000288013
    VK_FORMAT_ASTC_5x4x4_SFLOAT_BLOCK_EXT = 1000288014
    VK_FORMAT_ASTC_5x5x4_UNORM_BLOCK_EXT = 1000288015
    VK_FORMAT_ASTC_5x5x4_SRGB_BLOCK_EXT = 1000288016
    VK_FORMAT_ASTC_5x5x4_SFLOAT_BLOCK_EXT = 1000288017
    VK_FORMAT_ASTC_5x5x5_UNORM_BLOCK_EXT = 1000288018
    VK_FORMAT_ASTC_5x5x5_SRGB_BLOCK_EXT = 1000288019
    VK_FORMAT_ASTC_5x5x5_SFLOAT_BLOCK_EXT = 1000288020
    VK_FORMAT_ASTC_6x5x5_UNORM_BLOCK_EXT = 1000288021
    VK_FORMAT_ASTC_6x5x5_SRGB_BLOCK_EXT = 1000288022
    VK_FORMAT_ASTC_6x5x5_SFLOAT_BLOCK_EXT = 1000288023
    VK_FORMAT_ASTC_6x6x5_UNORM_BLOCK_EXT = 1000288024
    VK_FORMAT_ASTC_6x6x5_SRGB_BLOCK_EXT = 1000288025
    VK_FORMAT_ASTC_6x6x5_SFLOAT_BLOCK_EXT = 1000288026
    VK_FORMAT_ASTC_6x6x6_UNORM_BLOCK_EXT = 1000288027
    VK_FORMAT_ASTC_6x6x6_SRGB_BLOCK_EXT = 1000288028
    VK_FORMAT_ASTC_6x6x6_SFLOAT_BLOCK_EXT = 1000288029
    VK_FORMAT_G8_B8R8_2PLANE_444_UNORM = 1000330000
    VK_FORMAT_G10X6_B10X6R10X6_2PLANE_444_UNORM_3PACK16 = 1000330001
    VK_FORMAT_G12X4_B12X4R12X4_2PLANE_444_UNORM_3PACK16 = 1000330002
    VK_FORMAT_G16_B16R16_2PLANE_444_UNORM = 1000330003
    VK_FORMAT_A4R4G4B4_UNORM_PACK16 = 1000340000
    VK_FORMAT_A4B4G4R4_UNORM_PACK16 = 1000340001
    VK_FORMAT_R16G16_S10_5_NV = 1000464000
  VkStructureType* {.size: sizeof(cint).} = enum
    VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
    VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5
    VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE = 6
    VK_STRUCTURE_TYPE_BIND_SPARSE_INFO = 7
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9
    VK_STRUCTURE_TYPE_EVENT_CREATE_INFO = 10
    VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO = 11
    VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12
    VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO = 13
    VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
    VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO = 17
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
    VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO = 21
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
    VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO = 25
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
    VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
    VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO = 29
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
    VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO = 31
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO = 32
    VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO = 33
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO = 34
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET = 35
    VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET = 36
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO = 41
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER = 44
    VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER = 45
    VK_STRUCTURE_TYPE_MEMORY_BARRIER = 46
    VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO = 47
    VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO = 48
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES = 49
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES = 50
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES = 51
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES = 52
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES = 53
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES = 54
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001
    VK_STRUCTURE_TYPE_DISPLAY_MODE_CREATE_INFO_KHR = 1000002000
    VK_STRUCTURE_TYPE_DISPLAY_SURFACE_CREATE_INFO_KHR = 1000002001
    VK_STRUCTURE_TYPE_DISPLAY_PRESENT_INFO_KHR = 1000003000
    VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR = 1000004000
    VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR = 1000005000
    VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR = 1000006000
    VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR = 1000008000
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000
    VK_STRUCTURE_TYPE_NATIVE_BUFFER_ANDROID = 1000010000
    VK_STRUCTURE_TYPE_SWAPCHAIN_IMAGE_CREATE_INFO_ANDROID = 1000010001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENTATION_PROPERTIES_ANDROID = 1000010002
    VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT = 1000011000
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_RASTERIZATION_ORDER_AMD = 1000018000
    VK_STRUCTURE_TYPE_DEBUG_MARKER_OBJECT_NAME_INFO_EXT = 1000022000
    VK_STRUCTURE_TYPE_DEBUG_MARKER_OBJECT_TAG_INFO_EXT = 1000022001
    VK_STRUCTURE_TYPE_DEBUG_MARKER_MARKER_INFO_EXT = 1000022002
    VK_STRUCTURE_TYPE_VIDEO_PROFILE_INFO_KHR = 1000023000
    VK_STRUCTURE_TYPE_VIDEO_CAPABILITIES_KHR = 1000023001
    VK_STRUCTURE_TYPE_VIDEO_PICTURE_RESOURCE_INFO_KHR = 1000023002
    VK_STRUCTURE_TYPE_VIDEO_SESSION_MEMORY_REQUIREMENTS_KHR = 1000023003
    VK_STRUCTURE_TYPE_BIND_VIDEO_SESSION_MEMORY_INFO_KHR = 1000023004
    VK_STRUCTURE_TYPE_VIDEO_SESSION_CREATE_INFO_KHR = 1000023005
    VK_STRUCTURE_TYPE_VIDEO_SESSION_PARAMETERS_CREATE_INFO_KHR = 1000023006
    VK_STRUCTURE_TYPE_VIDEO_SESSION_PARAMETERS_UPDATE_INFO_KHR = 1000023007
    VK_STRUCTURE_TYPE_VIDEO_BEGIN_CODING_INFO_KHR = 1000023008
    VK_STRUCTURE_TYPE_VIDEO_END_CODING_INFO_KHR = 1000023009
    VK_STRUCTURE_TYPE_VIDEO_CODING_CONTROL_INFO_KHR = 1000023010
    VK_STRUCTURE_TYPE_VIDEO_REFERENCE_SLOT_INFO_KHR = 1000023011
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_VIDEO_PROPERTIES_KHR = 1000023012
    VK_STRUCTURE_TYPE_VIDEO_PROFILE_LIST_INFO_KHR = 1000023013
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VIDEO_FORMAT_INFO_KHR = 1000023014
    VK_STRUCTURE_TYPE_VIDEO_FORMAT_PROPERTIES_KHR = 1000023015
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_QUERY_RESULT_STATUS_PROPERTIES_KHR = 1000023016
    VK_STRUCTURE_TYPE_VIDEO_DECODE_INFO_KHR = 1000024000
    VK_STRUCTURE_TYPE_VIDEO_DECODE_CAPABILITIES_KHR = 1000024001
    VK_STRUCTURE_TYPE_VIDEO_DECODE_USAGE_INFO_KHR = 1000024002
    VK_STRUCTURE_TYPE_DEDICATED_ALLOCATION_IMAGE_CREATE_INFO_NV = 1000026000
    VK_STRUCTURE_TYPE_DEDICATED_ALLOCATION_BUFFER_CREATE_INFO_NV = 1000026001
    VK_STRUCTURE_TYPE_DEDICATED_ALLOCATION_MEMORY_ALLOCATE_INFO_NV = 1000026002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TRANSFORM_FEEDBACK_FEATURES_EXT = 1000028000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TRANSFORM_FEEDBACK_PROPERTIES_EXT = 1000028001
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_STREAM_CREATE_INFO_EXT = 1000028002
    VK_STRUCTURE_TYPE_CU_MODULE_CREATE_INFO_NVX = 1000029000
    VK_STRUCTURE_TYPE_CU_FUNCTION_CREATE_INFO_NVX = 1000029001
    VK_STRUCTURE_TYPE_CU_LAUNCH_INFO_NVX = 1000029002
    VK_STRUCTURE_TYPE_IMAGE_VIEW_HANDLE_INFO_NVX = 1000030000
    VK_STRUCTURE_TYPE_IMAGE_VIEW_ADDRESS_PROPERTIES_NVX = 1000030001
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_CAPABILITIES_EXT = 1000038000
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_SESSION_PARAMETERS_CREATE_INFO_EXT = 1000038001
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_SESSION_PARAMETERS_ADD_INFO_EXT = 1000038002
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_VCL_FRAME_INFO_EXT = 1000038003
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_DPB_SLOT_INFO_EXT = 1000038004
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_NALU_SLICE_INFO_EXT = 1000038005
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_EMIT_PICTURE_PARAMETERS_INFO_EXT = 1000038006
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_PROFILE_INFO_EXT = 1000038007
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_RATE_CONTROL_INFO_EXT = 1000038008
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_RATE_CONTROL_LAYER_INFO_EXT = 1000038009
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_REFERENCE_LISTS_INFO_EXT = 1000038010
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_CAPABILITIES_EXT = 1000039000
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_SESSION_PARAMETERS_CREATE_INFO_EXT = 1000039001
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_SESSION_PARAMETERS_ADD_INFO_EXT = 1000039002
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_VCL_FRAME_INFO_EXT = 1000039003
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_DPB_SLOT_INFO_EXT = 1000039004
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_NALU_SLICE_SEGMENT_INFO_EXT = 1000039005
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_EMIT_PICTURE_PARAMETERS_INFO_EXT = 1000039006
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_PROFILE_INFO_EXT = 1000039007
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_REFERENCE_LISTS_INFO_EXT = 1000039008
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_RATE_CONTROL_INFO_EXT = 1000039009
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_RATE_CONTROL_LAYER_INFO_EXT = 1000039010
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_CAPABILITIES_KHR = 1000040000
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_PICTURE_INFO_KHR = 1000040001
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_PROFILE_INFO_KHR = 1000040003
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_SESSION_PARAMETERS_CREATE_INFO_KHR = 1000040004
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_SESSION_PARAMETERS_ADD_INFO_KHR = 1000040005
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_DPB_SLOT_INFO_KHR = 1000040006
    VK_STRUCTURE_TYPE_TEXTURE_LOD_GATHER_FORMAT_PROPERTIES_AMD = 1000041000
    VK_STRUCTURE_TYPE_RENDERING_INFO = 1000044000
    VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO = 1000044001
    VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO = 1000044002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES = 1000044003
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_RENDERING_INFO = 1000044004
    VK_STRUCTURE_TYPE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_INFO_KHR = 1000044006
    VK_STRUCTURE_TYPE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_INFO_EXT = 1000044007
    VK_STRUCTURE_TYPE_ATTACHMENT_SAMPLE_COUNT_INFO_AMD = 1000044008
    VK_STRUCTURE_TYPE_MULTIVIEW_PER_VIEW_ATTRIBUTES_INFO_NVX = 1000044009
    VK_STRUCTURE_TYPE_STREAM_DESCRIPTOR_SURFACE_CREATE_INFO_GGP = 1000049000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CORNER_SAMPLED_IMAGE_FEATURES_NV = 1000050000
    VK_STRUCTURE_TYPE_PRIVATE_VENDOR_INFO_RESERVED_OFFSET_0_NV = 1000051000
    VK_STRUCTURE_TYPE_RENDER_PASS_MULTIVIEW_CREATE_INFO = 1000053000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_FEATURES = 1000053001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_PROPERTIES = 1000053002
    VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO_NV = 1000056000
    VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO_NV = 1000056001
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_WIN32_HANDLE_INFO_NV = 1000057000
    VK_STRUCTURE_TYPE_EXPORT_MEMORY_WIN32_HANDLE_INFO_NV = 1000057001
    VK_STRUCTURE_TYPE_WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_NV = 1000058000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 = 1000059000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2 = 1000059001
    VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2 = 1000059002
    VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2 = 1000059003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2 = 1000059004
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2 = 1000059005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2 = 1000059006
    VK_STRUCTURE_TYPE_SPARSE_IMAGE_FORMAT_PROPERTIES_2 = 1000059007
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SPARSE_IMAGE_FORMAT_INFO_2 = 1000059008
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO = 1000060000
    VK_STRUCTURE_TYPE_DEVICE_GROUP_RENDER_PASS_BEGIN_INFO = 1000060003
    VK_STRUCTURE_TYPE_DEVICE_GROUP_COMMAND_BUFFER_BEGIN_INFO = 1000060004
    VK_STRUCTURE_TYPE_DEVICE_GROUP_SUBMIT_INFO = 1000060005
    VK_STRUCTURE_TYPE_DEVICE_GROUP_BIND_SPARSE_INFO = 1000060006
    VK_STRUCTURE_TYPE_DEVICE_GROUP_PRESENT_CAPABILITIES_KHR = 1000060007
    VK_STRUCTURE_TYPE_IMAGE_SWAPCHAIN_CREATE_INFO_KHR = 1000060008
    VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_SWAPCHAIN_INFO_KHR = 1000060009
    VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR = 1000060010
    VK_STRUCTURE_TYPE_DEVICE_GROUP_PRESENT_INFO_KHR = 1000060011
    VK_STRUCTURE_TYPE_DEVICE_GROUP_SWAPCHAIN_CREATE_INFO_KHR = 1000060012
    VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_DEVICE_GROUP_INFO = 1000060013
    VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_DEVICE_GROUP_INFO = 1000060014
    VK_STRUCTURE_TYPE_VALIDATION_FLAGS_EXT = 1000061000
    VK_STRUCTURE_TYPE_VI_SURFACE_CREATE_INFO_NN = 1000062000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_DRAW_PARAMETERS_FEATURES = 1000063000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTC_HDR_FEATURES = 1000066000
    VK_STRUCTURE_TYPE_IMAGE_VIEW_ASTC_DECODE_MODE_EXT = 1000067000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ASTC_DECODE_FEATURES_EXT = 1000067001
    VK_STRUCTURE_TYPE_PIPELINE_ROBUSTNESS_CREATE_INFO_EXT = 1000068000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_ROBUSTNESS_FEATURES_EXT = 1000068001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_ROBUSTNESS_PROPERTIES_EXT = 1000068002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_GROUP_PROPERTIES = 1000070000
    VK_STRUCTURE_TYPE_DEVICE_GROUP_DEVICE_CREATE_INFO = 1000070001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO = 1000071000
    VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES = 1000071001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_BUFFER_INFO = 1000071002
    VK_STRUCTURE_TYPE_EXTERNAL_BUFFER_PROPERTIES = 1000071003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES = 1000071004
    VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_BUFFER_CREATE_INFO = 1000072000
    VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO = 1000072001
    VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO = 1000072002
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_WIN32_HANDLE_INFO_KHR = 1000073000
    VK_STRUCTURE_TYPE_EXPORT_MEMORY_WIN32_HANDLE_INFO_KHR = 1000073001
    VK_STRUCTURE_TYPE_MEMORY_WIN32_HANDLE_PROPERTIES_KHR = 1000073002
    VK_STRUCTURE_TYPE_MEMORY_GET_WIN32_HANDLE_INFO_KHR = 1000073003
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_FD_INFO_KHR = 1000074000
    VK_STRUCTURE_TYPE_MEMORY_FD_PROPERTIES_KHR = 1000074001
    VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR = 1000074002
    VK_STRUCTURE_TYPE_WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_KHR = 1000075000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_SEMAPHORE_INFO = 1000076000
    VK_STRUCTURE_TYPE_EXTERNAL_SEMAPHORE_PROPERTIES = 1000076001
    VK_STRUCTURE_TYPE_EXPORT_SEMAPHORE_CREATE_INFO = 1000077000
    VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR = 1000078000
    VK_STRUCTURE_TYPE_EXPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR = 1000078001
    VK_STRUCTURE_TYPE_D3D12_FENCE_SUBMIT_INFO_KHR = 1000078002
    VK_STRUCTURE_TYPE_SEMAPHORE_GET_WIN32_HANDLE_INFO_KHR = 1000078003
    VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_FD_INFO_KHR = 1000079000
    VK_STRUCTURE_TYPE_SEMAPHORE_GET_FD_INFO_KHR = 1000079001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PUSH_DESCRIPTOR_PROPERTIES_KHR = 1000080000
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_CONDITIONAL_RENDERING_INFO_EXT = 1000081000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CONDITIONAL_RENDERING_FEATURES_EXT = 1000081001
    VK_STRUCTURE_TYPE_CONDITIONAL_RENDERING_BEGIN_INFO_EXT = 1000081002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES = 1000082000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_16BIT_STORAGE_FEATURES = 1000083000
    VK_STRUCTURE_TYPE_PRESENT_REGIONS_KHR = 1000084000
    VK_STRUCTURE_TYPE_DESCRIPTOR_UPDATE_TEMPLATE_CREATE_INFO = 1000085000
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_W_SCALING_STATE_CREATE_INFO_NV = 1000087000
    VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_EXT = 1000090000
    VK_STRUCTURE_TYPE_DISPLAY_POWER_INFO_EXT = 1000091000
    VK_STRUCTURE_TYPE_DEVICE_EVENT_INFO_EXT = 1000091001
    VK_STRUCTURE_TYPE_DISPLAY_EVENT_INFO_EXT = 1000091002
    VK_STRUCTURE_TYPE_SWAPCHAIN_COUNTER_CREATE_INFO_EXT = 1000091003
    VK_STRUCTURE_TYPE_PRESENT_TIMES_INFO_GOOGLE = 1000092000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES = 1000094000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_PER_VIEW_ATTRIBUTES_PROPERTIES_NVX = 1000097000
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_SWIZZLE_STATE_CREATE_INFO_NV = 1000098000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DISCARD_RECTANGLE_PROPERTIES_EXT = 1000099000
    VK_STRUCTURE_TYPE_PIPELINE_DISCARD_RECTANGLE_STATE_CREATE_INFO_EXT = 1000099001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CONSERVATIVE_RASTERIZATION_PROPERTIES_EXT = 1000101000
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_CONSERVATIVE_STATE_CREATE_INFO_EXT = 1000101001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEPTH_CLIP_ENABLE_FEATURES_EXT = 1000102000
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_DEPTH_CLIP_STATE_CREATE_INFO_EXT = 1000102001
    VK_STRUCTURE_TYPE_HDR_METADATA_EXT = 1000105000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGELESS_FRAMEBUFFER_FEATURES = 1000108000
    VK_STRUCTURE_TYPE_FRAMEBUFFER_ATTACHMENTS_CREATE_INFO = 1000108001
    VK_STRUCTURE_TYPE_FRAMEBUFFER_ATTACHMENT_IMAGE_INFO = 1000108002
    VK_STRUCTURE_TYPE_RENDER_PASS_ATTACHMENT_BEGIN_INFO = 1000108003
    VK_STRUCTURE_TYPE_ATTACHMENT_DESCRIPTION_2 = 1000109000
    VK_STRUCTURE_TYPE_ATTACHMENT_REFERENCE_2 = 1000109001
    VK_STRUCTURE_TYPE_SUBPASS_DESCRIPTION_2 = 1000109002
    VK_STRUCTURE_TYPE_SUBPASS_DEPENDENCY_2 = 1000109003
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO_2 = 1000109004
    VK_STRUCTURE_TYPE_SUBPASS_BEGIN_INFO = 1000109005
    VK_STRUCTURE_TYPE_SUBPASS_END_INFO = 1000109006
    VK_STRUCTURE_TYPE_SHARED_PRESENT_SURFACE_CAPABILITIES_KHR = 1000111000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_FENCE_INFO = 1000112000
    VK_STRUCTURE_TYPE_EXTERNAL_FENCE_PROPERTIES = 1000112001
    VK_STRUCTURE_TYPE_EXPORT_FENCE_CREATE_INFO = 1000113000
    VK_STRUCTURE_TYPE_IMPORT_FENCE_WIN32_HANDLE_INFO_KHR = 1000114000
    VK_STRUCTURE_TYPE_EXPORT_FENCE_WIN32_HANDLE_INFO_KHR = 1000114001
    VK_STRUCTURE_TYPE_FENCE_GET_WIN32_HANDLE_INFO_KHR = 1000114002
    VK_STRUCTURE_TYPE_IMPORT_FENCE_FD_INFO_KHR = 1000115000
    VK_STRUCTURE_TYPE_FENCE_GET_FD_INFO_KHR = 1000115001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PERFORMANCE_QUERY_FEATURES_KHR = 1000116000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PERFORMANCE_QUERY_PROPERTIES_KHR = 1000116001
    VK_STRUCTURE_TYPE_QUERY_POOL_PERFORMANCE_CREATE_INFO_KHR = 1000116002
    VK_STRUCTURE_TYPE_PERFORMANCE_QUERY_SUBMIT_INFO_KHR = 1000116003
    VK_STRUCTURE_TYPE_ACQUIRE_PROFILING_LOCK_INFO_KHR = 1000116004
    VK_STRUCTURE_TYPE_PERFORMANCE_COUNTER_KHR = 1000116005
    VK_STRUCTURE_TYPE_PERFORMANCE_COUNTER_DESCRIPTION_KHR = 1000116006
    VK_STRUCTURE_TYPE_PERFORMANCE_QUERY_RESERVATION_INFO_KHR = 1000116007
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_POINT_CLIPPING_PROPERTIES = 1000117000
    VK_STRUCTURE_TYPE_RENDER_PASS_INPUT_ATTACHMENT_ASPECT_CREATE_INFO = 1000117001
    VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO = 1000117002
    VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_DOMAIN_ORIGIN_STATE_CREATE_INFO = 1000117003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SURFACE_INFO_2_KHR = 1000119000
    VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_KHR = 1000119001
    VK_STRUCTURE_TYPE_SURFACE_FORMAT_2_KHR = 1000119002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VARIABLE_POINTERS_FEATURES = 1000120000
    VK_STRUCTURE_TYPE_DISPLAY_PROPERTIES_2_KHR = 1000121000
    VK_STRUCTURE_TYPE_DISPLAY_PLANE_PROPERTIES_2_KHR = 1000121001
    VK_STRUCTURE_TYPE_DISPLAY_MODE_PROPERTIES_2_KHR = 1000121002
    VK_STRUCTURE_TYPE_DISPLAY_PLANE_INFO_2_KHR = 1000121003
    VK_STRUCTURE_TYPE_DISPLAY_PLANE_CAPABILITIES_2_KHR = 1000121004
    VK_STRUCTURE_TYPE_IOS_SURFACE_CREATE_INFO_MVK = 1000122000
    VK_STRUCTURE_TYPE_MACOS_SURFACE_CREATE_INFO_MVK = 1000123000
    VK_STRUCTURE_TYPE_MEMORY_DEDICATED_REQUIREMENTS = 1000127000
    VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO = 1000127001
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT = 1000128000
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_TAG_INFO_EXT = 1000128001
    VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT = 1000128002
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT = 1000128003
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004
    VK_STRUCTURE_TYPE_ANDROID_HARDWARE_BUFFER_USAGE_ANDROID = 1000129000
    VK_STRUCTURE_TYPE_ANDROID_HARDWARE_BUFFER_PROPERTIES_ANDROID = 1000129001
    VK_STRUCTURE_TYPE_ANDROID_HARDWARE_BUFFER_FORMAT_PROPERTIES_ANDROID = 1000129002
    VK_STRUCTURE_TYPE_IMPORT_ANDROID_HARDWARE_BUFFER_INFO_ANDROID = 1000129003
    VK_STRUCTURE_TYPE_MEMORY_GET_ANDROID_HARDWARE_BUFFER_INFO_ANDROID = 1000129004
    VK_STRUCTURE_TYPE_EXTERNAL_FORMAT_ANDROID = 1000129005
    VK_STRUCTURE_TYPE_ANDROID_HARDWARE_BUFFER_FORMAT_PROPERTIES_2_ANDROID = 1000129006
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SAMPLER_FILTER_MINMAX_PROPERTIES = 1000130000
    VK_STRUCTURE_TYPE_SAMPLER_REDUCTION_MODE_CREATE_INFO = 1000130001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_INLINE_UNIFORM_BLOCK_FEATURES = 1000138000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_INLINE_UNIFORM_BLOCK_PROPERTIES = 1000138001
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_INLINE_UNIFORM_BLOCK = 1000138002
    VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_INLINE_UNIFORM_BLOCK_CREATE_INFO = 1000138003
    VK_STRUCTURE_TYPE_SAMPLE_LOCATIONS_INFO_EXT = 1000143000
    VK_STRUCTURE_TYPE_RENDER_PASS_SAMPLE_LOCATIONS_BEGIN_INFO_EXT = 1000143001
    VK_STRUCTURE_TYPE_PIPELINE_SAMPLE_LOCATIONS_STATE_CREATE_INFO_EXT = 1000143002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SAMPLE_LOCATIONS_PROPERTIES_EXT = 1000143003
    VK_STRUCTURE_TYPE_MULTISAMPLE_PROPERTIES_EXT = 1000143004
    VK_STRUCTURE_TYPE_PROTECTED_SUBMIT_INFO = 1000145000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROTECTED_MEMORY_FEATURES = 1000145001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROTECTED_MEMORY_PROPERTIES = 1000145002
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_INFO_2 = 1000145003
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_REQUIREMENTS_INFO_2 = 1000146000
    VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2 = 1000146001
    VK_STRUCTURE_TYPE_IMAGE_SPARSE_MEMORY_REQUIREMENTS_INFO_2 = 1000146002
    VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2 = 1000146003
    VK_STRUCTURE_TYPE_SPARSE_IMAGE_MEMORY_REQUIREMENTS_2 = 1000146004
    VK_STRUCTURE_TYPE_IMAGE_FORMAT_LIST_CREATE_INFO = 1000147000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BLEND_OPERATION_ADVANCED_FEATURES_EXT = 1000148000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BLEND_OPERATION_ADVANCED_PROPERTIES_EXT = 1000148001
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_ADVANCED_STATE_CREATE_INFO_EXT = 1000148002
    VK_STRUCTURE_TYPE_PIPELINE_COVERAGE_TO_COLOR_STATE_CREATE_INFO_NV = 1000149000
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR = 1000150000
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR = 1000150002
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_AABBS_DATA_KHR = 1000150003
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR = 1000150004
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR = 1000150005
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR = 1000150006
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR = 1000150007
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_VERSION_INFO_KHR = 1000150009
    VK_STRUCTURE_TYPE_COPY_ACCELERATION_STRUCTURE_INFO_KHR = 1000150010
    VK_STRUCTURE_TYPE_COPY_ACCELERATION_STRUCTURE_TO_MEMORY_INFO_KHR = 1000150011
    VK_STRUCTURE_TYPE_COPY_MEMORY_TO_ACCELERATION_STRUCTURE_INFO_KHR = 1000150012
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR = 1000150013
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR = 1000150014
    VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR = 1000150015
    VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR = 1000150016
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR = 1000150017
    VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_INTERFACE_CREATE_INFO_KHR = 1000150018
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR = 1000150020
    VK_STRUCTURE_TYPE_PIPELINE_COVERAGE_MODULATION_STATE_CREATE_INFO_NV = 1000152000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_SM_BUILTINS_FEATURES_NV = 1000154000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_SM_BUILTINS_PROPERTIES_NV = 1000154001
    VK_STRUCTURE_TYPE_SAMPLER_YCBCR_CONVERSION_CREATE_INFO = 1000156000
    VK_STRUCTURE_TYPE_SAMPLER_YCBCR_CONVERSION_INFO = 1000156001
    VK_STRUCTURE_TYPE_BIND_IMAGE_PLANE_MEMORY_INFO = 1000156002
    VK_STRUCTURE_TYPE_IMAGE_PLANE_MEMORY_REQUIREMENTS_INFO = 1000156003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SAMPLER_YCBCR_CONVERSION_FEATURES = 1000156004
    VK_STRUCTURE_TYPE_SAMPLER_YCBCR_CONVERSION_IMAGE_FORMAT_PROPERTIES = 1000156005
    VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_INFO = 1000157000
    VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO = 1000157001
    VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT = 1000158000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT = 1000158002
    VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT = 1000158003
    VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_EXPLICIT_CREATE_INFO_EXT = 1000158004
    VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT = 1000158005
    VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_2_EXT = 1000158006
    VK_STRUCTURE_TYPE_VALIDATION_CACHE_CREATE_INFO_EXT = 1000160000
    VK_STRUCTURE_TYPE_SHADER_MODULE_VALIDATION_CACHE_CREATE_INFO_EXT = 1000160001
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO = 1000161000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES = 1000161001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_PROPERTIES = 1000161002
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO = 1000161003
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_LAYOUT_SUPPORT = 1000161004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PORTABILITY_SUBSET_FEATURES_KHR = 1000163000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PORTABILITY_SUBSET_PROPERTIES_KHR = 1000163001
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_SHADING_RATE_IMAGE_STATE_CREATE_INFO_NV = 1000164000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADING_RATE_IMAGE_FEATURES_NV = 1000164001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADING_RATE_IMAGE_PROPERTIES_NV = 1000164002
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_COARSE_SAMPLE_ORDER_STATE_CREATE_INFO_NV = 1000164005
    VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_NV = 1000165000
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_NV = 1000165001
    VK_STRUCTURE_TYPE_GEOMETRY_NV = 1000165003
    VK_STRUCTURE_TYPE_GEOMETRY_TRIANGLES_NV = 1000165004
    VK_STRUCTURE_TYPE_GEOMETRY_AABB_NV = 1000165005
    VK_STRUCTURE_TYPE_BIND_ACCELERATION_STRUCTURE_MEMORY_INFO_NV = 1000165006
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_NV = 1000165007
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_MEMORY_REQUIREMENTS_INFO_NV = 1000165008
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PROPERTIES_NV = 1000165009
    VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_NV = 1000165011
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_INFO_NV = 1000165012
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_REPRESENTATIVE_FRAGMENT_TEST_FEATURES_NV = 1000166000
    VK_STRUCTURE_TYPE_PIPELINE_REPRESENTATIVE_FRAGMENT_TEST_STATE_CREATE_INFO_NV = 1000166001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_3_PROPERTIES = 1000168000
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_SUPPORT = 1000168001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_VIEW_IMAGE_FORMAT_INFO_EXT = 1000170000
    VK_STRUCTURE_TYPE_FILTER_CUBIC_IMAGE_VIEW_IMAGE_FORMAT_PROPERTIES_EXT = 1000170001
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_GLOBAL_PRIORITY_CREATE_INFO_KHR = 1000174000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_SUBGROUP_EXTENDED_TYPES_FEATURES = 1000175000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_8BIT_STORAGE_FEATURES = 1000177000
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_HOST_POINTER_INFO_EXT = 1000178000
    VK_STRUCTURE_TYPE_MEMORY_HOST_POINTER_PROPERTIES_EXT = 1000178001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_MEMORY_HOST_PROPERTIES_EXT = 1000178002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES = 1000180000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CLOCK_FEATURES_KHR = 1000181000
    VK_STRUCTURE_TYPE_PIPELINE_COMPILER_CONTROL_CREATE_INFO_AMD = 1000183000
    VK_STRUCTURE_TYPE_CALIBRATED_TIMESTAMP_INFO_EXT = 1000184000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CORE_PROPERTIES_AMD = 1000185000
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_CAPABILITIES_KHR = 1000187000
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_SESSION_PARAMETERS_CREATE_INFO_KHR = 1000187001
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_SESSION_PARAMETERS_ADD_INFO_KHR = 1000187002
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_PROFILE_INFO_KHR = 1000187003
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_PICTURE_INFO_KHR = 1000187004
    VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_DPB_SLOT_INFO_KHR = 1000187005
    VK_STRUCTURE_TYPE_DEVICE_MEMORY_OVERALLOCATION_CREATE_INFO_AMD = 1000189000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VERTEX_ATTRIBUTE_DIVISOR_PROPERTIES_EXT = 1000190000
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_DIVISOR_STATE_CREATE_INFO_EXT = 1000190001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VERTEX_ATTRIBUTE_DIVISOR_FEATURES_EXT = 1000190002
    VK_STRUCTURE_TYPE_PRESENT_FRAME_TOKEN_GGP = 1000191000
    VK_STRUCTURE_TYPE_PIPELINE_CREATION_FEEDBACK_CREATE_INFO = 1000192000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES = 1000196000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FLOAT_CONTROLS_PROPERTIES = 1000197000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEPTH_STENCIL_RESOLVE_PROPERTIES = 1000199000
    VK_STRUCTURE_TYPE_SUBPASS_DESCRIPTION_DEPTH_STENCIL_RESOLVE = 1000199001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COMPUTE_SHADER_DERIVATIVES_FEATURES_NV = 1000201000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_NV = 1000202000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_PROPERTIES_NV = 1000202001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADER_BARYCENTRIC_FEATURES_KHR = 1000203000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_IMAGE_FOOTPRINT_FEATURES_NV = 1000204000
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_EXCLUSIVE_SCISSOR_STATE_CREATE_INFO_NV = 1000205000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXCLUSIVE_SCISSOR_FEATURES_NV = 1000205002
    VK_STRUCTURE_TYPE_CHECKPOINT_DATA_NV = 1000206000
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_CHECKPOINT_PROPERTIES_NV = 1000206001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES = 1000207000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_PROPERTIES = 1000207001
    VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO = 1000207002
    VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO = 1000207003
    VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO = 1000207004
    VK_STRUCTURE_TYPE_SEMAPHORE_SIGNAL_INFO = 1000207005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_INTEGER_FUNCTIONS_2_FEATURES_INTEL = 1000209000
    VK_STRUCTURE_TYPE_QUERY_POOL_PERFORMANCE_QUERY_CREATE_INFO_INTEL = 1000210000
    VK_STRUCTURE_TYPE_INITIALIZE_PERFORMANCE_API_INFO_INTEL = 1000210001
    VK_STRUCTURE_TYPE_PERFORMANCE_MARKER_INFO_INTEL = 1000210002
    VK_STRUCTURE_TYPE_PERFORMANCE_STREAM_MARKER_INFO_INTEL = 1000210003
    VK_STRUCTURE_TYPE_PERFORMANCE_OVERRIDE_INFO_INTEL = 1000210004
    VK_STRUCTURE_TYPE_PERFORMANCE_CONFIGURATION_ACQUIRE_INFO_INTEL = 1000210005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_MEMORY_MODEL_FEATURES = 1000211000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PCI_BUS_INFO_PROPERTIES_EXT = 1000212000
    VK_STRUCTURE_TYPE_DISPLAY_NATIVE_HDR_SURFACE_CAPABILITIES_AMD = 1000213000
    VK_STRUCTURE_TYPE_SWAPCHAIN_DISPLAY_NATIVE_HDR_CREATE_INFO_AMD = 1000213001
    VK_STRUCTURE_TYPE_IMAGEPIPE_SURFACE_CREATE_INFO_FUCHSIA = 1000214000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_TERMINATE_INVOCATION_FEATURES = 1000215000
    VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT = 1000217000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_FEATURES_EXT = 1000218000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_PROPERTIES_EXT = 1000218001
    VK_STRUCTURE_TYPE_RENDER_PASS_FRAGMENT_DENSITY_MAP_CREATE_INFO_EXT = 1000218002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SCALAR_BLOCK_LAYOUT_FEATURES = 1000221000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES = 1000225000
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO = 1000225001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES = 1000225002
    VK_STRUCTURE_TYPE_FRAGMENT_SHADING_RATE_ATTACHMENT_INFO_KHR = 1000226000
    VK_STRUCTURE_TYPE_PIPELINE_FRAGMENT_SHADING_RATE_STATE_CREATE_INFO_KHR = 1000226001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADING_RATE_PROPERTIES_KHR = 1000226002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADING_RATE_FEATURES_KHR = 1000226003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADING_RATE_KHR = 1000226004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CORE_PROPERTIES_2_AMD = 1000227000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COHERENT_MEMORY_FEATURES_AMD = 1000229000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT64_FEATURES_EXT = 1000234000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT = 1000237000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PRIORITY_FEATURES_EXT = 1000238000
    VK_STRUCTURE_TYPE_MEMORY_PRIORITY_ALLOCATE_INFO_EXT = 1000238001
    VK_STRUCTURE_TYPE_SURFACE_PROTECTED_CAPABILITIES_KHR = 1000239000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEDICATED_ALLOCATION_IMAGE_ALIASING_FEATURES_NV = 1000240000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SEPARATE_DEPTH_STENCIL_LAYOUTS_FEATURES = 1000241000
    VK_STRUCTURE_TYPE_ATTACHMENT_REFERENCE_STENCIL_LAYOUT = 1000241001
    VK_STRUCTURE_TYPE_ATTACHMENT_DESCRIPTION_STENCIL_LAYOUT = 1000241002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES_EXT = 1000244000
    VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO = 1000244001
    VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_CREATE_INFO_EXT = 1000244002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TOOL_PROPERTIES = 1000245000
    VK_STRUCTURE_TYPE_IMAGE_STENCIL_USAGE_CREATE_INFO = 1000246000
    VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT = 1000247000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_WAIT_FEATURES_KHR = 1000248000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_NV = 1000249000
    VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_NV = 1000249001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_PROPERTIES_NV = 1000249002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COVERAGE_REDUCTION_MODE_FEATURES_NV = 1000250000
    VK_STRUCTURE_TYPE_PIPELINE_COVERAGE_REDUCTION_STATE_CREATE_INFO_NV = 1000250001
    VK_STRUCTURE_TYPE_FRAMEBUFFER_MIXED_SAMPLES_COMBINATION_NV = 1000250002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADER_INTERLOCK_FEATURES_EXT = 1000251000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_YCBCR_IMAGE_ARRAYS_FEATURES_EXT = 1000252000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_UNIFORM_BUFFER_STANDARD_LAYOUT_FEATURES = 1000253000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROVOKING_VERTEX_FEATURES_EXT = 1000254000
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_PROVOKING_VERTEX_STATE_CREATE_INFO_EXT = 1000254001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROVOKING_VERTEX_PROPERTIES_EXT = 1000254002
    VK_STRUCTURE_TYPE_SURFACE_FULL_SCREEN_EXCLUSIVE_INFO_EXT = 1000255000
    VK_STRUCTURE_TYPE_SURFACE_FULL_SCREEN_EXCLUSIVE_WIN32_INFO_EXT = 1000255001
    VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_FULL_SCREEN_EXCLUSIVE_EXT = 1000255002
    VK_STRUCTURE_TYPE_HEADLESS_SURFACE_CREATE_INFO_EXT = 1000256000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES = 1000257000
    VK_STRUCTURE_TYPE_BUFFER_OPAQUE_CAPTURE_ADDRESS_CREATE_INFO = 1000257002
    VK_STRUCTURE_TYPE_MEMORY_OPAQUE_CAPTURE_ADDRESS_ALLOCATE_INFO = 1000257003
    VK_STRUCTURE_TYPE_DEVICE_MEMORY_OPAQUE_CAPTURE_ADDRESS_INFO = 1000257004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_LINE_RASTERIZATION_FEATURES_EXT = 1000259000
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_LINE_STATE_CREATE_INFO_EXT = 1000259001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_LINE_RASTERIZATION_PROPERTIES_EXT = 1000259002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_FEATURES_EXT = 1000260000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_HOST_QUERY_RESET_FEATURES = 1000261000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_INDEX_TYPE_UINT8_FEATURES_EXT = 1000265000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT = 1000267000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_EXECUTABLE_PROPERTIES_FEATURES_KHR = 1000269000
    VK_STRUCTURE_TYPE_PIPELINE_INFO_KHR = 1000269001
    VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_PROPERTIES_KHR = 1000269002
    VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INFO_KHR = 1000269003
    VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_STATISTIC_KHR = 1000269004
    VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INTERNAL_REPRESENTATION_KHR = 1000269005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_2_FEATURES_EXT = 1000273000
    VK_STRUCTURE_TYPE_SURFACE_PRESENT_MODE_EXT = 1000274000
    VK_STRUCTURE_TYPE_SURFACE_PRESENT_SCALING_CAPABILITIES_EXT = 1000274001
    VK_STRUCTURE_TYPE_SURFACE_PRESENT_MODE_COMPATIBILITY_EXT = 1000274002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT = 1000275000
    VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_FENCE_INFO_EXT = 1000275001
    VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_MODES_CREATE_INFO_EXT = 1000275002
    VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_MODE_INFO_EXT = 1000275003
    VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_SCALING_CREATE_INFO_EXT = 1000275004
    VK_STRUCTURE_TYPE_RELEASE_SWAPCHAIN_IMAGES_INFO_EXT = 1000275005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_DEMOTE_TO_HELPER_INVOCATION_FEATURES = 1000276000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEVICE_GENERATED_COMMANDS_PROPERTIES_NV = 1000277000
    VK_STRUCTURE_TYPE_GRAPHICS_SHADER_GROUP_CREATE_INFO_NV = 1000277001
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_SHADER_GROUPS_CREATE_INFO_NV = 1000277002
    VK_STRUCTURE_TYPE_INDIRECT_COMMANDS_LAYOUT_TOKEN_NV = 1000277003
    VK_STRUCTURE_TYPE_INDIRECT_COMMANDS_LAYOUT_CREATE_INFO_NV = 1000277004
    VK_STRUCTURE_TYPE_GENERATED_COMMANDS_INFO_NV = 1000277005
    VK_STRUCTURE_TYPE_GENERATED_COMMANDS_MEMORY_REQUIREMENTS_INFO_NV = 1000277006
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEVICE_GENERATED_COMMANDS_FEATURES_NV = 1000277007
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_INHERITED_VIEWPORT_SCISSOR_FEATURES_NV = 1000278000
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_VIEWPORT_SCISSOR_INFO_NV = 1000278001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_FEATURES = 1000280000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_PROPERTIES = 1000280001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TEXEL_BUFFER_ALIGNMENT_FEATURES_EXT = 1000281000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TEXEL_BUFFER_ALIGNMENT_PROPERTIES = 1000281001
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_RENDER_PASS_TRANSFORM_INFO_QCOM = 1000282000
    VK_STRUCTURE_TYPE_RENDER_PASS_TRANSFORM_BEGIN_INFO_QCOM = 1000282001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEVICE_MEMORY_REPORT_FEATURES_EXT = 1000284000
    VK_STRUCTURE_TYPE_DEVICE_DEVICE_MEMORY_REPORT_CREATE_INFO_EXT = 1000284001
    VK_STRUCTURE_TYPE_DEVICE_MEMORY_REPORT_CALLBACK_DATA_EXT = 1000284002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ROBUSTNESS_2_FEATURES_EXT = 1000286000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ROBUSTNESS_2_PROPERTIES_EXT = 1000286001
    VK_STRUCTURE_TYPE_SAMPLER_CUSTOM_BORDER_COLOR_CREATE_INFO_EXT = 1000287000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CUSTOM_BORDER_COLOR_PROPERTIES_EXT = 1000287001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CUSTOM_BORDER_COLOR_FEATURES_EXT = 1000287002
    VK_STRUCTURE_TYPE_PIPELINE_LIBRARY_CREATE_INFO_KHR = 1000290000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_BARRIER_FEATURES_NV = 1000292000
    VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_PRESENT_BARRIER_NV = 1000292001
    VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_BARRIER_CREATE_INFO_NV = 1000292002
    VK_STRUCTURE_TYPE_PRESENT_ID_KHR = 1000294000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR = 1000294001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRIVATE_DATA_FEATURES = 1000295000
    VK_STRUCTURE_TYPE_DEVICE_PRIVATE_DATA_CREATE_INFO = 1000295001
    VK_STRUCTURE_TYPE_PRIVATE_DATA_SLOT_CREATE_INFO = 1000295002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_CREATION_CACHE_CONTROL_FEATURES = 1000297000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_SC_1_0_FEATURES = 1000298000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_SC_1_0_PROPERTIES = 1000298001
    VK_STRUCTURE_TYPE_DEVICE_OBJECT_RESERVATION_CREATE_INFO = 1000298002
    VK_STRUCTURE_TYPE_COMMAND_POOL_MEMORY_RESERVATION_CREATE_INFO = 1000298003
    VK_STRUCTURE_TYPE_COMMAND_POOL_MEMORY_CONSUMPTION = 1000298004
    VK_STRUCTURE_TYPE_PIPELINE_POOL_SIZE = 1000298005
    VK_STRUCTURE_TYPE_FAULT_DATA = 1000298007
    VK_STRUCTURE_TYPE_FAULT_CALLBACK_INFO = 1000298008
    VK_STRUCTURE_TYPE_PIPELINE_OFFLINE_CREATE_INFO = 1000298010
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_INFO_KHR = 1000299000
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_RATE_CONTROL_INFO_KHR = 1000299001
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_RATE_CONTROL_LAYER_INFO_KHR = 1000299002
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_CAPABILITIES_KHR = 1000299003
    VK_STRUCTURE_TYPE_VIDEO_ENCODE_USAGE_INFO_KHR = 1000299004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DIAGNOSTICS_CONFIG_FEATURES_NV = 1000300000
    VK_STRUCTURE_TYPE_DEVICE_DIAGNOSTICS_CONFIG_CREATE_INFO_NV = 1000300001
    VK_STRUCTURE_TYPE_REFRESH_OBJECT_LIST_KHR = 1000308000
    VK_STRUCTURE_TYPE_RESERVED_QCOM = 1000309000
    VK_STRUCTURE_TYPE_EXPORT_METAL_OBJECT_CREATE_INFO_EXT = 1000311000
    VK_STRUCTURE_TYPE_EXPORT_METAL_OBJECTS_INFO_EXT = 1000311001
    VK_STRUCTURE_TYPE_EXPORT_METAL_DEVICE_INFO_EXT = 1000311002
    VK_STRUCTURE_TYPE_EXPORT_METAL_COMMAND_QUEUE_INFO_EXT = 1000311003
    VK_STRUCTURE_TYPE_EXPORT_METAL_BUFFER_INFO_EXT = 1000311004
    VK_STRUCTURE_TYPE_IMPORT_METAL_BUFFER_INFO_EXT = 1000311005
    VK_STRUCTURE_TYPE_EXPORT_METAL_TEXTURE_INFO_EXT = 1000311006
    VK_STRUCTURE_TYPE_IMPORT_METAL_TEXTURE_INFO_EXT = 1000311007
    VK_STRUCTURE_TYPE_EXPORT_METAL_IO_SURFACE_INFO_EXT = 1000311008
    VK_STRUCTURE_TYPE_IMPORT_METAL_IO_SURFACE_INFO_EXT = 1000311009
    VK_STRUCTURE_TYPE_EXPORT_METAL_SHARED_EVENT_INFO_EXT = 1000311010
    VK_STRUCTURE_TYPE_IMPORT_METAL_SHARED_EVENT_INFO_EXT = 1000311011
    VK_STRUCTURE_TYPE_MEMORY_BARRIER_2 = 1000314000
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2 = 1000314001
    VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2 = 1000314002
    VK_STRUCTURE_TYPE_DEPENDENCY_INFO = 1000314003
    VK_STRUCTURE_TYPE_SUBMIT_INFO_2 = 1000314004
    VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO = 1000314005
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO = 1000314006
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES = 1000314007
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_CHECKPOINT_PROPERTIES_2_NV = 1000314008
    VK_STRUCTURE_TYPE_CHECKPOINT_DATA_2_NV = 1000314009
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_PROPERTIES_EXT = 1000316000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_DENSITY_MAP_PROPERTIES_EXT = 1000316001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT = 1000316002
    VK_STRUCTURE_TYPE_DESCRIPTOR_ADDRESS_INFO_EXT = 1000316003
    VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT = 1000316004
    VK_STRUCTURE_TYPE_BUFFER_CAPTURE_DESCRIPTOR_DATA_INFO_EXT = 1000316005
    VK_STRUCTURE_TYPE_IMAGE_CAPTURE_DESCRIPTOR_DATA_INFO_EXT = 1000316006
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CAPTURE_DESCRIPTOR_DATA_INFO_EXT = 1000316007
    VK_STRUCTURE_TYPE_SAMPLER_CAPTURE_DESCRIPTOR_DATA_INFO_EXT = 1000316008
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CAPTURE_DESCRIPTOR_DATA_INFO_EXT = 1000316009
    VK_STRUCTURE_TYPE_OPAQUE_CAPTURE_DESCRIPTOR_DATA_CREATE_INFO_EXT = 1000316010
    VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT = 1000316011
    VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_PUSH_DESCRIPTOR_BUFFER_HANDLE_EXT = 1000316012
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_GRAPHICS_PIPELINE_LIBRARY_FEATURES_EXT = 1000320000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_GRAPHICS_PIPELINE_LIBRARY_PROPERTIES_EXT = 1000320001
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_LIBRARY_CREATE_INFO_EXT = 1000320002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_EARLY_AND_LATE_FRAGMENT_TESTS_FEATURES_AMD = 1000321000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADER_BARYCENTRIC_PROPERTIES_KHR = 1000322000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_SUBGROUP_UNIFORM_CONTROL_FLOW_FEATURES_KHR = 1000323000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ZERO_INITIALIZE_WORKGROUP_MEMORY_FEATURES = 1000325000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADING_RATE_ENUMS_PROPERTIES_NV = 1000326000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_SHADING_RATE_ENUMS_FEATURES_NV = 1000326001
    VK_STRUCTURE_TYPE_PIPELINE_FRAGMENT_SHADING_RATE_ENUM_STATE_CREATE_INFO_NV = 1000326002
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_MOTION_TRIANGLES_DATA_NV = 1000327000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_MOTION_BLUR_FEATURES_NV = 1000327001
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_MOTION_INFO_NV = 1000327002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT = 1000328000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_PROPERTIES_EXT = 1000328001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_YCBCR_2_PLANE_444_FORMATS_FEATURES_EXT = 1000330000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_2_FEATURES_EXT = 1000332000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_2_PROPERTIES_EXT = 1000332001
    VK_STRUCTURE_TYPE_COPY_COMMAND_TRANSFORM_INFO_QCOM = 1000333000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_ROBUSTNESS_FEATURES = 1000335000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_WORKGROUP_MEMORY_EXPLICIT_LAYOUT_FEATURES_KHR = 1000336000
    VK_STRUCTURE_TYPE_COPY_BUFFER_INFO_2 = 1000337000
    VK_STRUCTURE_TYPE_COPY_IMAGE_INFO_2 = 1000337001
    VK_STRUCTURE_TYPE_COPY_BUFFER_TO_IMAGE_INFO_2 = 1000337002
    VK_STRUCTURE_TYPE_COPY_IMAGE_TO_BUFFER_INFO_2 = 1000337003
    VK_STRUCTURE_TYPE_BLIT_IMAGE_INFO_2 = 1000337004
    VK_STRUCTURE_TYPE_RESOLVE_IMAGE_INFO_2 = 1000337005
    VK_STRUCTURE_TYPE_BUFFER_COPY_2 = 1000337006
    VK_STRUCTURE_TYPE_IMAGE_COPY_2 = 1000337007
    VK_STRUCTURE_TYPE_IMAGE_BLIT_2 = 1000337008
    VK_STRUCTURE_TYPE_BUFFER_IMAGE_COPY_2 = 1000337009
    VK_STRUCTURE_TYPE_IMAGE_RESOLVE_2 = 1000337010
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_COMPRESSION_CONTROL_FEATURES_EXT = 1000338000
    VK_STRUCTURE_TYPE_IMAGE_COMPRESSION_CONTROL_EXT = 1000338001
    VK_STRUCTURE_TYPE_SUBRESOURCE_LAYOUT_2_EXT = 1000338002
    VK_STRUCTURE_TYPE_IMAGE_SUBRESOURCE_2_EXT = 1000338003
    VK_STRUCTURE_TYPE_IMAGE_COMPRESSION_PROPERTIES_EXT = 1000338004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ATTACHMENT_FEEDBACK_LOOP_LAYOUT_FEATURES_EXT = 1000339000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_4444_FORMATS_FEATURES_EXT = 1000340000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FAULT_FEATURES_EXT = 1000341000
    VK_STRUCTURE_TYPE_DEVICE_FAULT_COUNTS_EXT = 1000341001
    VK_STRUCTURE_TYPE_DEVICE_FAULT_INFO_EXT = 1000341002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_FEATURES_EXT = 1000342000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RGBA10X6_FORMATS_FEATURES_EXT = 1000344000
    VK_STRUCTURE_TYPE_DIRECTFB_SURFACE_CREATE_INFO_EXT = 1000346000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR = 1000347000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR = 1000347001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR = 1000348013
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MUTABLE_DESCRIPTOR_TYPE_FEATURES_EXT = 1000351000
    VK_STRUCTURE_TYPE_MUTABLE_DESCRIPTOR_TYPE_CREATE_INFO_EXT = 1000351002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VERTEX_INPUT_DYNAMIC_STATE_FEATURES_EXT = 1000352000
    VK_STRUCTURE_TYPE_VERTEX_INPUT_BINDING_DESCRIPTION_2_EXT = 1000352001
    VK_STRUCTURE_TYPE_VERTEX_INPUT_ATTRIBUTE_DESCRIPTION_2_EXT = 1000352002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRM_PROPERTIES_EXT = 1000353000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ADDRESS_BINDING_REPORT_FEATURES_EXT = 1000354000
    VK_STRUCTURE_TYPE_DEVICE_ADDRESS_BINDING_CALLBACK_DATA_EXT = 1000354001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEPTH_CLIP_CONTROL_FEATURES_EXT = 1000355000
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_DEPTH_CLIP_CONTROL_CREATE_INFO_EXT = 1000355001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRIMITIVE_TOPOLOGY_LIST_RESTART_FEATURES_EXT = 1000356000
    VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_3 = 1000360000
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_ZIRCON_HANDLE_INFO_FUCHSIA = 1000364000
    VK_STRUCTURE_TYPE_MEMORY_ZIRCON_HANDLE_PROPERTIES_FUCHSIA = 1000364001
    VK_STRUCTURE_TYPE_MEMORY_GET_ZIRCON_HANDLE_INFO_FUCHSIA = 1000364002
    VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_ZIRCON_HANDLE_INFO_FUCHSIA = 1000365000
    VK_STRUCTURE_TYPE_SEMAPHORE_GET_ZIRCON_HANDLE_INFO_FUCHSIA = 1000365001
    VK_STRUCTURE_TYPE_BUFFER_COLLECTION_CREATE_INFO_FUCHSIA = 1000366000
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_BUFFER_COLLECTION_FUCHSIA = 1000366001
    VK_STRUCTURE_TYPE_BUFFER_COLLECTION_IMAGE_CREATE_INFO_FUCHSIA = 1000366002
    VK_STRUCTURE_TYPE_BUFFER_COLLECTION_PROPERTIES_FUCHSIA = 1000366003
    VK_STRUCTURE_TYPE_BUFFER_CONSTRAINTS_INFO_FUCHSIA = 1000366004
    VK_STRUCTURE_TYPE_BUFFER_COLLECTION_BUFFER_CREATE_INFO_FUCHSIA = 1000366005
    VK_STRUCTURE_TYPE_IMAGE_CONSTRAINTS_INFO_FUCHSIA = 1000366006
    VK_STRUCTURE_TYPE_IMAGE_FORMAT_CONSTRAINTS_INFO_FUCHSIA = 1000366007
    VK_STRUCTURE_TYPE_SYSMEM_COLOR_SPACE_FUCHSIA = 1000366008
    VK_STRUCTURE_TYPE_BUFFER_COLLECTION_CONSTRAINTS_INFO_FUCHSIA = 1000366009
    VK_STRUCTURE_TYPE_SUBPASS_SHADING_PIPELINE_CREATE_INFO_HUAWEI = 1000369000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBPASS_SHADING_FEATURES_HUAWEI = 1000369001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBPASS_SHADING_PROPERTIES_HUAWEI = 1000369002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_INVOCATION_MASK_FEATURES_HUAWEI = 1000370000
    VK_STRUCTURE_TYPE_MEMORY_GET_REMOTE_ADDRESS_INFO_NV = 1000371000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_MEMORY_RDMA_FEATURES_NV = 1000371001
    VK_STRUCTURE_TYPE_PIPELINE_PROPERTIES_IDENTIFIER_EXT = 1000372000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_PROPERTIES_FEATURES_EXT = 1000372001
    VK_STRUCTURE_TYPE_IMPORT_FENCE_SCI_SYNC_INFO_NV = 1000373000
    VK_STRUCTURE_TYPE_EXPORT_FENCE_SCI_SYNC_INFO_NV = 1000373001
    VK_STRUCTURE_TYPE_FENCE_GET_SCI_SYNC_INFO_NV = 1000373002
    VK_STRUCTURE_TYPE_SCI_SYNC_ATTRIBUTES_INFO_NV = 1000373003
    VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_SCI_SYNC_INFO_NV = 1000373004
    VK_STRUCTURE_TYPE_EXPORT_SEMAPHORE_SCI_SYNC_INFO_NV = 1000373005
    VK_STRUCTURE_TYPE_SEMAPHORE_GET_SCI_SYNC_INFO_NV = 1000373006
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_SCI_SYNC_FEATURES_NV = 1000373007
    VK_STRUCTURE_TYPE_IMPORT_MEMORY_SCI_BUF_INFO_NV = 1000374000
    VK_STRUCTURE_TYPE_EXPORT_MEMORY_SCI_BUF_INFO_NV = 1000374001
    VK_STRUCTURE_TYPE_MEMORY_GET_SCI_BUF_INFO_NV = 1000374002
    VK_STRUCTURE_TYPE_MEMORY_SCI_BUF_PROPERTIES_NV = 1000374003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_MEMORY_SCI_BUF_FEATURES_NV = 1000374004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTISAMPLED_RENDER_TO_SINGLE_SAMPLED_FEATURES_EXT = 1000376000
    VK_STRUCTURE_TYPE_SUBPASS_RESOLVE_PERFORMANCE_QUERY_EXT = 1000376001
    VK_STRUCTURE_TYPE_MULTISAMPLED_RENDER_TO_SINGLE_SAMPLED_INFO_EXT = 1000376002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_2_FEATURES_EXT = 1000377000
    VK_STRUCTURE_TYPE_SCREEN_SURFACE_CREATE_INFO_QNX = 1000378000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COLOR_WRITE_ENABLE_FEATURES_EXT = 1000381000
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_WRITE_CREATE_INFO_EXT = 1000381001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRIMITIVES_GENERATED_QUERY_FEATURES_EXT = 1000382000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_MAINTENANCE_1_FEATURES_KHR = 1000386000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_GLOBAL_PRIORITY_QUERY_FEATURES_KHR = 1000388000
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_GLOBAL_PRIORITY_PROPERTIES_KHR = 1000388001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_VIEW_MIN_LOD_FEATURES_EXT = 1000391000
    VK_STRUCTURE_TYPE_IMAGE_VIEW_MIN_LOD_CREATE_INFO_EXT = 1000391001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTI_DRAW_FEATURES_EXT = 1000392000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTI_DRAW_PROPERTIES_EXT = 1000392001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_2D_VIEW_OF_3D_FEATURES_EXT = 1000393000
    VK_STRUCTURE_TYPE_MICROMAP_BUILD_INFO_EXT = 1000396000
    VK_STRUCTURE_TYPE_MICROMAP_VERSION_INFO_EXT = 1000396001
    VK_STRUCTURE_TYPE_COPY_MICROMAP_INFO_EXT = 1000396002
    VK_STRUCTURE_TYPE_COPY_MICROMAP_TO_MEMORY_INFO_EXT = 1000396003
    VK_STRUCTURE_TYPE_COPY_MEMORY_TO_MICROMAP_INFO_EXT = 1000396004
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_OPACITY_MICROMAP_FEATURES_EXT = 1000396005
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_OPACITY_MICROMAP_PROPERTIES_EXT = 1000396006
    VK_STRUCTURE_TYPE_MICROMAP_CREATE_INFO_EXT = 1000396007
    VK_STRUCTURE_TYPE_MICROMAP_BUILD_SIZES_INFO_EXT = 1000396008
    VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_TRIANGLES_OPACITY_MICROMAP_EXT = 1000396009
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CLUSTER_CULLING_SHADER_FEATURES_HUAWEI = 1000404000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_CLUSTER_CULLING_SHADER_PROPERTIES_HUAWEI = 1000404001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BORDER_COLOR_SWIZZLE_FEATURES_EXT = 1000411000
    VK_STRUCTURE_TYPE_SAMPLER_BORDER_COLOR_COMPONENT_MAPPING_CREATE_INFO_EXT = 1000411001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PAGEABLE_DEVICE_LOCAL_MEMORY_FEATURES_EXT = 1000412000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_4_FEATURES = 1000413000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_4_PROPERTIES = 1000413001
    VK_STRUCTURE_TYPE_DEVICE_BUFFER_MEMORY_REQUIREMENTS = 1000413002
    VK_STRUCTURE_TYPE_DEVICE_IMAGE_MEMORY_REQUIREMENTS = 1000413003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CORE_PROPERTIES_ARM = 1000415000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_SLICED_VIEW_OF_3D_FEATURES_EXT = 1000418000
    VK_STRUCTURE_TYPE_IMAGE_VIEW_SLICED_CREATE_INFO_EXT = 1000418001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_SET_HOST_MAPPING_FEATURES_VALVE = 1000420000
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_BINDING_REFERENCE_VALVE = 1000420001
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_HOST_MAPPING_INFO_VALVE = 1000420002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DEPTH_CLAMP_ZERO_ONE_FEATURES_EXT = 1000421000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_NON_SEAMLESS_CUBE_MAP_FEATURES_EXT = 1000422000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_OFFSET_FEATURES_QCOM = 1000425000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FRAGMENT_DENSITY_MAP_OFFSET_PROPERTIES_QCOM = 1000425001
    VK_STRUCTURE_TYPE_SUBPASS_FRAGMENT_DENSITY_MAP_OFFSET_END_INFO_QCOM = 1000425002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COPY_MEMORY_INDIRECT_FEATURES_NV = 1000426000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COPY_MEMORY_INDIRECT_PROPERTIES_NV = 1000426001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_DECOMPRESSION_FEATURES_NV = 1000427000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_DECOMPRESSION_PROPERTIES_NV = 1000427001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_LINEAR_COLOR_ATTACHMENT_FEATURES_NV = 1000430000
    VK_STRUCTURE_TYPE_APPLICATION_PARAMETERS_EXT = 1000435000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_COMPRESSION_CONTROL_SWAPCHAIN_FEATURES_EXT = 1000437000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_PROCESSING_FEATURES_QCOM = 1000440000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_PROCESSING_PROPERTIES_QCOM = 1000440001
    VK_STRUCTURE_TYPE_IMAGE_VIEW_SAMPLE_WEIGHT_CREATE_INFO_QCOM = 1000440002
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT = 1000455000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_PROPERTIES_EXT = 1000455001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBPASS_MERGE_FEEDBACK_FEATURES_EXT = 1000458000
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATION_CONTROL_EXT = 1000458001
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATION_FEEDBACK_CREATE_INFO_EXT = 1000458002
    VK_STRUCTURE_TYPE_RENDER_PASS_SUBPASS_FEEDBACK_CREATE_INFO_EXT = 1000458003
    VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_INFO_LUNARG = 1000459000
    VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_LIST_LUNARG = 1000459001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_MODULE_IDENTIFIER_FEATURES_EXT = 1000462000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_MODULE_IDENTIFIER_PROPERTIES_EXT = 1000462001
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_MODULE_IDENTIFIER_CREATE_INFO_EXT = 1000462002
    VK_STRUCTURE_TYPE_SHADER_MODULE_IDENTIFIER_EXT = 1000462003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_OPTICAL_FLOW_FEATURES_NV = 1000464000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_OPTICAL_FLOW_PROPERTIES_NV = 1000464001
    VK_STRUCTURE_TYPE_OPTICAL_FLOW_IMAGE_FORMAT_INFO_NV = 1000464002
    VK_STRUCTURE_TYPE_OPTICAL_FLOW_IMAGE_FORMAT_PROPERTIES_NV = 1000464003
    VK_STRUCTURE_TYPE_OPTICAL_FLOW_SESSION_CREATE_INFO_NV = 1000464004
    VK_STRUCTURE_TYPE_OPTICAL_FLOW_EXECUTE_INFO_NV = 1000464005
    VK_STRUCTURE_TYPE_OPTICAL_FLOW_SESSION_CREATE_PRIVATE_DATA_INFO_NV = 1000464010
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_LEGACY_DITHERING_FEATURES_EXT = 1000465000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_PROTECTED_ACCESS_FEATURES_EXT = 1000466000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TILE_PROPERTIES_FEATURES_QCOM = 1000484000
    VK_STRUCTURE_TYPE_TILE_PROPERTIES_QCOM = 1000484001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_AMIGO_PROFILING_FEATURES_SEC = 1000485000
    VK_STRUCTURE_TYPE_AMIGO_PROFILING_SUBMIT_INFO_SEC = 1000485001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_PER_VIEW_VIEWPORTS_FEATURES_QCOM = 1000488000
    VK_STRUCTURE_TYPE_SEMAPHORE_SCI_SYNC_POOL_CREATE_INFO_NV = 1000489000
    VK_STRUCTURE_TYPE_SEMAPHORE_SCI_SYNC_CREATE_INFO_NV = 1000489001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_SCI_SYNC_2_FEATURES_NV = 1000489002
    VK_STRUCTURE_TYPE_DEVICE_SEMAPHORE_SCI_SYNC_POOL_RESERVATION_CREATE_INFO_NV = 1000489003
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_INVOCATION_REORDER_FEATURES_NV = 1000490000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_INVOCATION_REORDER_PROPERTIES_NV = 1000490001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CORE_BUILTINS_FEATURES_ARM = 1000497000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_CORE_BUILTINS_PROPERTIES_ARM = 1000497001
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PIPELINE_LIBRARY_GROUP_HANDLES_FEATURES_EXT = 1000498000
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_PER_VIEW_RENDER_AREAS_FEATURES_QCOM = 1000510000
    VK_STRUCTURE_TYPE_MULTIVIEW_PER_VIEW_RENDER_AREAS_RENDER_PASS_BEGIN_INFO_QCOM = 1000510001
  VkSubpassContents* {.size: sizeof(cint).} = enum
    VK_SUBPASS_CONTENTS_INLINE = 0
    VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS = 1
  VkResult* {.size: sizeof(cint).} = enum
    VK_ERROR_COMPRESSION_EXHAUSTED_EXT = -1000338000
    VK_ERROR_NO_PIPELINE_MATCH = -1000298001
    VK_ERROR_INVALID_PIPELINE_CACHE_DATA = -1000298000
    VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS = -1000257000
    VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT = -1000255000
    VK_ERROR_NOT_PERMITTED_KHR = -1000174001
    VK_ERROR_FRAGMENTATION = -1000161000
    VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT = -1000158000
    VK_ERROR_INVALID_EXTERNAL_HANDLE = -1000072003
    VK_ERROR_OUT_OF_POOL_MEMORY = -1000069000
    VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR = -1000023005
    VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR = -1000023004
    VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR = -1000023003
    VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR = -1000023002
    VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR = -1000023001
    VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR = -1000023000
    VK_ERROR_INVALID_SHADER_NV = -1000012000
    VK_ERROR_VALIDATION_FAILED_EXT = -1000011001
    VK_ERROR_INCOMPATIBLE_DISPLAY_KHR = -1000003001
    VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    VK_ERROR_NATIVE_WINDOW_IN_USE_KHR = -1000000001
    VK_ERROR_SURFACE_LOST_KHR = -1000000000
    VK_ERROR_UNKNOWN = -13
    VK_ERROR_FRAGMENTED_POOL = -12
    VK_ERROR_FORMAT_NOT_SUPPORTED = -11
    VK_ERROR_TOO_MANY_OBJECTS = -10
    VK_ERROR_INCOMPATIBLE_DRIVER = -9
    VK_ERROR_FEATURE_NOT_PRESENT = -8
    VK_ERROR_EXTENSION_NOT_PRESENT = -7
    VK_ERROR_LAYER_NOT_PRESENT = -6
    VK_ERROR_MEMORY_MAP_FAILED = -5
    VK_ERROR_DEVICE_LOST = -4
    VK_ERROR_INITIALIZATION_FAILED = -3
    VK_ERROR_OUT_OF_DEVICE_MEMORY = -2
    VK_ERROR_OUT_OF_HOST_MEMORY = -1
    VK_SUCCESS = 0
    VK_NOT_READY = 1
    VK_TIMEOUT = 2
    VK_EVENT_SET = 3
    VK_EVENT_RESET = 4
    VK_INCOMPLETE = 5
    VK_SUBOPTIMAL_KHR = 1000001003
    VK_THREAD_IDLE_KHR = 1000268000
    VK_THREAD_DONE_KHR = 1000268001
    VK_OPERATION_DEFERRED_KHR = 1000268002
    VK_OPERATION_NOT_DEFERRED_KHR = 1000268003
    VK_PIPELINE_COMPILE_REQUIRED = 1000297000
  VkDynamicState* {.size: sizeof(cint).} = enum
    VK_DYNAMIC_STATE_VIEWPORT = 0
    VK_DYNAMIC_STATE_SCISSOR = 1
    VK_DYNAMIC_STATE_LINE_WIDTH = 2
    VK_DYNAMIC_STATE_DEPTH_BIAS = 3
    VK_DYNAMIC_STATE_BLEND_CONSTANTS = 4
    VK_DYNAMIC_STATE_DEPTH_BOUNDS = 5
    VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK = 6
    VK_DYNAMIC_STATE_STENCIL_WRITE_MASK = 7
    VK_DYNAMIC_STATE_STENCIL_REFERENCE = 8
    VK_DYNAMIC_STATE_VIEWPORT_W_SCALING_NV = 1000087000
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_EXT = 1000099000
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_ENABLE_EXT = 1000099001
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_MODE_EXT = 1000099002
    VK_DYNAMIC_STATE_SAMPLE_LOCATIONS_EXT = 1000143000
    VK_DYNAMIC_STATE_VIEWPORT_SHADING_RATE_PALETTE_NV = 1000164004
    VK_DYNAMIC_STATE_VIEWPORT_COARSE_SAMPLE_ORDER_NV = 1000164006
    VK_DYNAMIC_STATE_EXCLUSIVE_SCISSOR_ENABLE_NV = 1000205000
    VK_DYNAMIC_STATE_EXCLUSIVE_SCISSOR_NV = 1000205001
    VK_DYNAMIC_STATE_FRAGMENT_SHADING_RATE_KHR = 1000226000
    VK_DYNAMIC_STATE_LINE_STIPPLE_EXT = 1000259000
    VK_DYNAMIC_STATE_CULL_MODE = 1000267000
    VK_DYNAMIC_STATE_FRONT_FACE = 1000267001
    VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY = 1000267002
    VK_DYNAMIC_STATE_VIEWPORT_WITH_COUNT = 1000267003
    VK_DYNAMIC_STATE_SCISSOR_WITH_COUNT = 1000267004
    VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE = 1000267005
    VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE = 1000267006
    VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE = 1000267007
    VK_DYNAMIC_STATE_DEPTH_COMPARE_OP = 1000267008
    VK_DYNAMIC_STATE_DEPTH_BOUNDS_TEST_ENABLE = 1000267009
    VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE = 1000267010
    VK_DYNAMIC_STATE_STENCIL_OP = 1000267011
    VK_DYNAMIC_STATE_RAY_TRACING_PIPELINE_STACK_SIZE_KHR = 1000347000
    VK_DYNAMIC_STATE_VERTEX_INPUT_EXT = 1000352000
    VK_DYNAMIC_STATE_PATCH_CONTROL_POINTS_EXT = 1000377000
    VK_DYNAMIC_STATE_RASTERIZER_DISCARD_ENABLE = 1000377001
    VK_DYNAMIC_STATE_DEPTH_BIAS_ENABLE = 1000377002
    VK_DYNAMIC_STATE_LOGIC_OP_EXT = 1000377003
    VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE = 1000377004
    VK_DYNAMIC_STATE_COLOR_WRITE_ENABLE_EXT = 1000381000
    VK_DYNAMIC_STATE_TESSELLATION_DOMAIN_ORIGIN_EXT = 1000455002
    VK_DYNAMIC_STATE_DEPTH_CLAMP_ENABLE_EXT = 1000455003
    VK_DYNAMIC_STATE_POLYGON_MODE_EXT = 1000455004
    VK_DYNAMIC_STATE_RASTERIZATION_SAMPLES_EXT = 1000455005
    VK_DYNAMIC_STATE_SAMPLE_MASK_EXT = 1000455006
    VK_DYNAMIC_STATE_ALPHA_TO_COVERAGE_ENABLE_EXT = 1000455007
    VK_DYNAMIC_STATE_ALPHA_TO_ONE_ENABLE_EXT = 1000455008
    VK_DYNAMIC_STATE_LOGIC_OP_ENABLE_EXT = 1000455009
    VK_DYNAMIC_STATE_COLOR_BLEND_ENABLE_EXT = 1000455010
    VK_DYNAMIC_STATE_COLOR_BLEND_EQUATION_EXT = 1000455011
    VK_DYNAMIC_STATE_COLOR_WRITE_MASK_EXT = 1000455012
    VK_DYNAMIC_STATE_RASTERIZATION_STREAM_EXT = 1000455013
    VK_DYNAMIC_STATE_CONSERVATIVE_RASTERIZATION_MODE_EXT = 1000455014
    VK_DYNAMIC_STATE_EXTRA_PRIMITIVE_OVERESTIMATION_SIZE_EXT = 1000455015
    VK_DYNAMIC_STATE_DEPTH_CLIP_ENABLE_EXT = 1000455016
    VK_DYNAMIC_STATE_SAMPLE_LOCATIONS_ENABLE_EXT = 1000455017
    VK_DYNAMIC_STATE_COLOR_BLEND_ADVANCED_EXT = 1000455018
    VK_DYNAMIC_STATE_PROVOKING_VERTEX_MODE_EXT = 1000455019
    VK_DYNAMIC_STATE_LINE_RASTERIZATION_MODE_EXT = 1000455020
    VK_DYNAMIC_STATE_LINE_STIPPLE_ENABLE_EXT = 1000455021
    VK_DYNAMIC_STATE_DEPTH_CLIP_NEGATIVE_ONE_TO_ONE_EXT = 1000455022
    VK_DYNAMIC_STATE_VIEWPORT_W_SCALING_ENABLE_NV = 1000455023
    VK_DYNAMIC_STATE_VIEWPORT_SWIZZLE_NV = 1000455024
    VK_DYNAMIC_STATE_COVERAGE_TO_COLOR_ENABLE_NV = 1000455025
    VK_DYNAMIC_STATE_COVERAGE_TO_COLOR_LOCATION_NV = 1000455026
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_MODE_NV = 1000455027
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_TABLE_ENABLE_NV = 1000455028
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_TABLE_NV = 1000455029
    VK_DYNAMIC_STATE_SHADING_RATE_IMAGE_ENABLE_NV = 1000455030
    VK_DYNAMIC_STATE_REPRESENTATIVE_FRAGMENT_TEST_ENABLE_NV = 1000455031
    VK_DYNAMIC_STATE_COVERAGE_REDUCTION_MODE_NV = 1000455032
  VkDescriptorUpdateTemplateType* {.size: sizeof(cint).} = enum
    VK_DESCRIPTOR_UPDATE_TEMPLATE_TYPE_DESCRIPTOR_SET = 0
    VK_DESCRIPTOR_UPDATE_TEMPLATE_TYPE_PUSH_DESCRIPTORS_KHR = 1
  VkObjectType* {.size: sizeof(cint).} = enum
    VK_OBJECT_TYPE_UNKNOWN = 0
    VK_OBJECT_TYPE_INSTANCE = 1
    VK_OBJECT_TYPE_PHYSICAL_DEVICE = 2
    VK_OBJECT_TYPE_DEVICE = 3
    VK_OBJECT_TYPE_QUEUE = 4
    VK_OBJECT_TYPE_SEMAPHORE = 5
    VK_OBJECT_TYPE_COMMAND_BUFFER = 6
    VK_OBJECT_TYPE_FENCE = 7
    VK_OBJECT_TYPE_DEVICE_MEMORY = 8
    VK_OBJECT_TYPE_BUFFER = 9
    VK_OBJECT_TYPE_IMAGE = 10
    VK_OBJECT_TYPE_EVENT = 11
    VK_OBJECT_TYPE_QUERY_POOL = 12
    VK_OBJECT_TYPE_BUFFER_VIEW = 13
    VK_OBJECT_TYPE_IMAGE_VIEW = 14
    VK_OBJECT_TYPE_SHADER_MODULE = 15
    VK_OBJECT_TYPE_PIPELINE_CACHE = 16
    VK_OBJECT_TYPE_PIPELINE_LAYOUT = 17
    VK_OBJECT_TYPE_RENDER_PASS = 18
    VK_OBJECT_TYPE_PIPELINE = 19
    VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT = 20
    VK_OBJECT_TYPE_SAMPLER = 21
    VK_OBJECT_TYPE_DESCRIPTOR_POOL = 22
    VK_OBJECT_TYPE_DESCRIPTOR_SET = 23
    VK_OBJECT_TYPE_FRAMEBUFFER = 24
    VK_OBJECT_TYPE_COMMAND_POOL = 25
    VK_OBJECT_TYPE_SURFACE_KHR = 1000000000
    VK_OBJECT_TYPE_SWAPCHAIN_KHR = 1000001000
    VK_OBJECT_TYPE_DISPLAY_KHR = 1000002000
    VK_OBJECT_TYPE_DISPLAY_MODE_KHR = 1000002001
    VK_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT = 1000011000
    VK_OBJECT_TYPE_VIDEO_SESSION_KHR = 1000023000
    VK_OBJECT_TYPE_VIDEO_SESSION_PARAMETERS_KHR = 1000023001
    VK_OBJECT_TYPE_CU_MODULE_NVX = 1000029000
    VK_OBJECT_TYPE_CU_FUNCTION_NVX = 1000029001
    VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE = 1000085000
    VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT = 1000128000
    VK_OBJECT_TYPE_ACCELERATION_STRUCTURE_KHR = 1000150000
    VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION = 1000156000
    VK_OBJECT_TYPE_VALIDATION_CACHE_EXT = 1000160000
    VK_OBJECT_TYPE_ACCELERATION_STRUCTURE_NV = 1000165000
    VK_OBJECT_TYPE_PERFORMANCE_CONFIGURATION_INTEL = 1000210000
    VK_OBJECT_TYPE_DEFERRED_OPERATION_KHR = 1000268000
    VK_OBJECT_TYPE_INDIRECT_COMMANDS_LAYOUT_NV = 1000277000
    VK_OBJECT_TYPE_PRIVATE_DATA_SLOT = 1000295000
    VK_OBJECT_TYPE_BUFFER_COLLECTION_FUCHSIA = 1000366000
    VK_OBJECT_TYPE_MICROMAP_EXT = 1000396000
    VK_OBJECT_TYPE_OPTICAL_FLOW_SESSION_NV = 1000464000
    VK_OBJECT_TYPE_SEMAPHORE_SCI_SYNC_POOL_NV = 1000489000
  VkRayTracingInvocationReorderModeNV* {.size: sizeof(cint).} = enum
    VK_RAY_TRACING_INVOCATION_REORDER_MODE_NONE_NV = 0
    VK_RAY_TRACING_INVOCATION_REORDER_MODE_REORDER_NV = 1
  VkDirectDriverLoadingModeLUNARG* {.size: sizeof(cint).} = enum
    VK_DIRECT_DRIVER_LOADING_MODE_EXCLUSIVE_LUNARG = 0
    VK_DIRECT_DRIVER_LOADING_MODE_INCLUSIVE_LUNARG = 1
  VkQueueFlagBits* {.size: sizeof(cint).} = enum
    VK_QUEUE_GRAPHICS_BIT = 0b00000000000000000000000000000001
    VK_QUEUE_COMPUTE_BIT = 0b00000000000000000000000000000010
    VK_QUEUE_TRANSFER_BIT = 0b00000000000000000000000000000100
    VK_QUEUE_SPARSE_BINDING_BIT = 0b00000000000000000000000000001000
    VK_QUEUE_PROTECTED_BIT = 0b00000000000000000000000000010000
    VK_QUEUE_VIDEO_DECODE_BIT_KHR = 0b00000000000000000000000000100000
    VK_QUEUE_VIDEO_ENCODE_BIT_KHR = 0b00000000000000000000000001000000
    VK_QUEUE_RESERVED_7_BIT_QCOM = 0b00000000000000000000000010000000
    VK_QUEUE_OPTICAL_FLOW_BIT_NV = 0b00000000000000000000000100000000
    VK_QUEUE_RESERVED_9_BIT_EXT = 0b00000000000000000000001000000000
func toBits*(flags: openArray[VkQueueFlagBits]): VkQueueFlags =
    for flag in flags:
      result = VkQueueFlags(uint(result) or uint(flag))
func toEnums*(number: VkQueueFlags): seq[VkQueueFlagBits] =
    for value in VkQueueFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkQueueFlags): bool = cint(a) == cint(b)
type
  VkCullModeFlagBits* {.size: sizeof(cint).} = enum
    VK_CULL_MODE_FRONT_BIT = 0b00000000000000000000000000000001
    VK_CULL_MODE_BACK_BIT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkCullModeFlagBits]): VkCullModeFlags =
    for flag in flags:
      result = VkCullModeFlags(uint(result) or uint(flag))
func toEnums*(number: VkCullModeFlags): seq[VkCullModeFlagBits] =
    for value in VkCullModeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCullModeFlags): bool = cint(a) == cint(b)
const
  VK_CULL_MODE_NONE* = 0
  VK_CULL_MODE_FRONT_AND_BACK* = 0x00000003
type
  VkRenderPassCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_RENDER_PASS_CREATE_RESERVED_0_BIT_KHR = 0b00000000000000000000000000000001
    VK_RENDER_PASS_CREATE_TRANSFORM_BIT_QCOM = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkRenderPassCreateFlagBits]): VkRenderPassCreateFlags =
    for flag in flags:
      result = VkRenderPassCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkRenderPassCreateFlags): seq[VkRenderPassCreateFlagBits] =
    for value in VkRenderPassCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkRenderPassCreateFlags): bool = cint(a) == cint(b)
type
  VkDeviceQueueCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_DEVICE_QUEUE_CREATE_PROTECTED_BIT = 0b00000000000000000000000000000001
    VK_DEVICE_QUEUE_CREATE_RESERVED_1_BIT_QCOM = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkDeviceQueueCreateFlagBits]): VkDeviceQueueCreateFlags =
    for flag in flags:
      result = VkDeviceQueueCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkDeviceQueueCreateFlags): seq[VkDeviceQueueCreateFlagBits] =
    for value in VkDeviceQueueCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDeviceQueueCreateFlags): bool = cint(a) == cint(b)
type
  VkMemoryPropertyFlagBits* {.size: sizeof(cint).} = enum
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0b00000000000000000000000000000001
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0b00000000000000000000000000000010
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0b00000000000000000000000000000100
    VK_MEMORY_PROPERTY_HOST_CACHED_BIT = 0b00000000000000000000000000001000
    VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT = 0b00000000000000000000000000010000
    VK_MEMORY_PROPERTY_PROTECTED_BIT = 0b00000000000000000000000000100000
    VK_MEMORY_PROPERTY_DEVICE_COHERENT_BIT_AMD = 0b00000000000000000000000001000000
    VK_MEMORY_PROPERTY_DEVICE_UNCACHED_BIT_AMD = 0b00000000000000000000000010000000
    VK_MEMORY_PROPERTY_RDMA_CAPABLE_BIT_NV = 0b00000000000000000000000100000000
func toBits*(flags: openArray[VkMemoryPropertyFlagBits]): VkMemoryPropertyFlags =
    for flag in flags:
      result = VkMemoryPropertyFlags(uint(result) or uint(flag))
func toEnums*(number: VkMemoryPropertyFlags): seq[VkMemoryPropertyFlagBits] =
    for value in VkMemoryPropertyFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkMemoryPropertyFlags): bool = cint(a) == cint(b)
type
  VkMemoryHeapFlagBits* {.size: sizeof(cint).} = enum
    VK_MEMORY_HEAP_DEVICE_LOCAL_BIT = 0b00000000000000000000000000000001
    VK_MEMORY_HEAP_MULTI_INSTANCE_BIT = 0b00000000000000000000000000000010
    VK_MEMORY_HEAP_SEU_SAFE_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkMemoryHeapFlagBits]): VkMemoryHeapFlags =
    for flag in flags:
      result = VkMemoryHeapFlags(uint(result) or uint(flag))
func toEnums*(number: VkMemoryHeapFlags): seq[VkMemoryHeapFlagBits] =
    for value in VkMemoryHeapFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkMemoryHeapFlags): bool = cint(a) == cint(b)
type
  VkAccessFlagBits* {.size: sizeof(cint).} = enum
    VK_ACCESS_INDIRECT_COMMAND_READ_BIT = 0b00000000000000000000000000000001
    VK_ACCESS_INDEX_READ_BIT = 0b00000000000000000000000000000010
    VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT = 0b00000000000000000000000000000100
    VK_ACCESS_UNIFORM_READ_BIT = 0b00000000000000000000000000001000
    VK_ACCESS_INPUT_ATTACHMENT_READ_BIT = 0b00000000000000000000000000010000
    VK_ACCESS_SHADER_READ_BIT = 0b00000000000000000000000000100000
    VK_ACCESS_SHADER_WRITE_BIT = 0b00000000000000000000000001000000
    VK_ACCESS_COLOR_ATTACHMENT_READ_BIT = 0b00000000000000000000000010000000
    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT = 0b00000000000000000000000100000000
    VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT = 0b00000000000000000000001000000000
    VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT = 0b00000000000000000000010000000000
    VK_ACCESS_TRANSFER_READ_BIT = 0b00000000000000000000100000000000
    VK_ACCESS_TRANSFER_WRITE_BIT = 0b00000000000000000001000000000000
    VK_ACCESS_HOST_READ_BIT = 0b00000000000000000010000000000000
    VK_ACCESS_HOST_WRITE_BIT = 0b00000000000000000100000000000000
    VK_ACCESS_MEMORY_READ_BIT = 0b00000000000000001000000000000000
    VK_ACCESS_MEMORY_WRITE_BIT = 0b00000000000000010000000000000000
    VK_ACCESS_COMMAND_PREPROCESS_READ_BIT_NV = 0b00000000000000100000000000000000
    VK_ACCESS_COMMAND_PREPROCESS_WRITE_BIT_NV = 0b00000000000001000000000000000000
    VK_ACCESS_COLOR_ATTACHMENT_READ_NONCOHERENT_BIT_EXT = 0b00000000000010000000000000000000
    VK_ACCESS_CONDITIONAL_RENDERING_READ_BIT_EXT = 0b00000000000100000000000000000000
    VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR = 0b00000000001000000000000000000000
    VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR = 0b00000000010000000000000000000000
    VK_ACCESS_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR = 0b00000000100000000000000000000000
    VK_ACCESS_FRAGMENT_DENSITY_MAP_READ_BIT_EXT = 0b00000001000000000000000000000000
    VK_ACCESS_TRANSFORM_FEEDBACK_WRITE_BIT_EXT = 0b00000010000000000000000000000000
    VK_ACCESS_TRANSFORM_FEEDBACK_COUNTER_READ_BIT_EXT = 0b00000100000000000000000000000000
    VK_ACCESS_TRANSFORM_FEEDBACK_COUNTER_WRITE_BIT_EXT = 0b00001000000000000000000000000000
func toBits*(flags: openArray[VkAccessFlagBits]): VkAccessFlags =
    for flag in flags:
      result = VkAccessFlags(uint(result) or uint(flag))
func toEnums*(number: VkAccessFlags): seq[VkAccessFlagBits] =
    for value in VkAccessFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkAccessFlags): bool = cint(a) == cint(b)
type
  VkBufferUsageFlagBits* {.size: sizeof(cint).} = enum
    VK_BUFFER_USAGE_TRANSFER_SRC_BIT = 0b00000000000000000000000000000001
    VK_BUFFER_USAGE_TRANSFER_DST_BIT = 0b00000000000000000000000000000010
    VK_BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT = 0b00000000000000000000000000000100
    VK_BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT = 0b00000000000000000000000000001000
    VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0b00000000000000000000000000010000
    VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0b00000000000000000000000000100000
    VK_BUFFER_USAGE_INDEX_BUFFER_BIT = 0b00000000000000000000000001000000
    VK_BUFFER_USAGE_VERTEX_BUFFER_BIT = 0b00000000000000000000000010000000
    VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT = 0b00000000000000000000000100000000
    VK_BUFFER_USAGE_CONDITIONAL_RENDERING_BIT_EXT = 0b00000000000000000000001000000000
    VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR = 0b00000000000000000000010000000000
    VK_BUFFER_USAGE_TRANSFORM_FEEDBACK_BUFFER_BIT_EXT = 0b00000000000000000000100000000000
    VK_BUFFER_USAGE_TRANSFORM_FEEDBACK_COUNTER_BUFFER_BIT_EXT = 0b00000000000000000001000000000000
    VK_BUFFER_USAGE_VIDEO_DECODE_SRC_BIT_KHR = 0b00000000000000000010000000000000
    VK_BUFFER_USAGE_VIDEO_DECODE_DST_BIT_KHR = 0b00000000000000000100000000000000
    VK_BUFFER_USAGE_VIDEO_ENCODE_DST_BIT_KHR = 0b00000000000000001000000000000000
    VK_BUFFER_USAGE_VIDEO_ENCODE_SRC_BIT_KHR = 0b00000000000000010000000000000000
    VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT = 0b00000000000000100000000000000000
    VK_BUFFER_USAGE_RESERVED_18_BIT_QCOM = 0b00000000000001000000000000000000
    VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR = 0b00000000000010000000000000000000
    VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR = 0b00000000000100000000000000000000
    VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT = 0b00000000001000000000000000000000
    VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT = 0b00000000010000000000000000000000
    VK_BUFFER_USAGE_MICROMAP_BUILD_INPUT_READ_ONLY_BIT_EXT = 0b00000000100000000000000000000000
    VK_BUFFER_USAGE_MICROMAP_STORAGE_BIT_EXT = 0b00000001000000000000000000000000
    VK_BUFFER_USAGE_RESERVED_25_BIT_AMD = 0b00000010000000000000000000000000
    VK_BUFFER_USAGE_PUSH_DESCRIPTORS_DESCRIPTOR_BUFFER_BIT_EXT = 0b00000100000000000000000000000000
func toBits*(flags: openArray[VkBufferUsageFlagBits]): VkBufferUsageFlags =
    for flag in flags:
      result = VkBufferUsageFlags(uint(result) or uint(flag))
func toEnums*(number: VkBufferUsageFlags): seq[VkBufferUsageFlagBits] =
    for value in VkBufferUsageFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkBufferUsageFlags): bool = cint(a) == cint(b)
type
  VkBufferCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_BUFFER_CREATE_SPARSE_BINDING_BIT = 0b00000000000000000000000000000001
    VK_BUFFER_CREATE_SPARSE_RESIDENCY_BIT = 0b00000000000000000000000000000010
    VK_BUFFER_CREATE_SPARSE_ALIASED_BIT = 0b00000000000000000000000000000100
    VK_BUFFER_CREATE_PROTECTED_BIT = 0b00000000000000000000000000001000
    VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT = 0b00000000000000000000000000010000
    VK_BUFFER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000000000000000100000
func toBits*(flags: openArray[VkBufferCreateFlagBits]): VkBufferCreateFlags =
    for flag in flags:
      result = VkBufferCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkBufferCreateFlags): seq[VkBufferCreateFlagBits] =
    for value in VkBufferCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkBufferCreateFlags): bool = cint(a) == cint(b)
type
  VkShaderStageFlagBits* {.size: sizeof(cint).} = enum
    VK_SHADER_STAGE_VERTEX_BIT = 0b00000000000000000000000000000001
    VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT = 0b00000000000000000000000000000010
    VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT = 0b00000000000000000000000000000100
    VK_SHADER_STAGE_GEOMETRY_BIT = 0b00000000000000000000000000001000
    VK_SHADER_STAGE_FRAGMENT_BIT = 0b00000000000000000000000000010000
    VK_SHADER_STAGE_COMPUTE_BIT = 0b00000000000000000000000000100000
    VK_SHADER_STAGE_TASK_BIT_EXT = 0b00000000000000000000000001000000
    VK_SHADER_STAGE_MESH_BIT_EXT = 0b00000000000000000000000010000000
    VK_SHADER_STAGE_RAYGEN_BIT_KHR = 0b00000000000000000000000100000000
    VK_SHADER_STAGE_ANY_HIT_BIT_KHR = 0b00000000000000000000001000000000
    VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR = 0b00000000000000000000010000000000
    VK_SHADER_STAGE_MISS_BIT_KHR = 0b00000000000000000000100000000000
    VK_SHADER_STAGE_INTERSECTION_BIT_KHR = 0b00000000000000000001000000000000
    VK_SHADER_STAGE_CALLABLE_BIT_KHR = 0b00000000000000000010000000000000
    VK_SHADER_STAGE_SUBPASS_SHADING_BIT_HUAWEI = 0b00000000000000000100000000000000
    VK_SHADER_STAGE_EXT_483_RESERVE_15 = 0b00000000000000001000000000000000
    VK_SHADER_STAGE_EXT_483_RESERVE_16 = 0b00000000000000010000000000000000
    VK_SHADER_STAGE_EXT_483_RESERVE_17 = 0b00000000000000100000000000000000
    VK_SHADER_STAGE_CLUSTER_CULLING_BIT_HUAWEI = 0b00000000000010000000000000000000
func toBits*(flags: openArray[VkShaderStageFlagBits]): VkShaderStageFlags =
    for flag in flags:
      result = VkShaderStageFlags(uint(result) or uint(flag))
func toEnums*(number: VkShaderStageFlags): seq[VkShaderStageFlagBits] =
    for value in VkShaderStageFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkShaderStageFlags): bool = cint(a) == cint(b)
const
  VK_SHADER_STAGE_ALL_GRAPHICS* = 0x0000001F
  VK_SHADER_STAGE_ALL* = 0x7FFFFFFF
type
  VkImageUsageFlagBits* {.size: sizeof(cint).} = enum
    VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0b00000000000000000000000000000001
    VK_IMAGE_USAGE_TRANSFER_DST_BIT = 0b00000000000000000000000000000010
    VK_IMAGE_USAGE_SAMPLED_BIT = 0b00000000000000000000000000000100
    VK_IMAGE_USAGE_STORAGE_BIT = 0b00000000000000000000000000001000
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0b00000000000000000000000000010000
    VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT = 0b00000000000000000000000000100000
    VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT = 0b00000000000000000000000001000000
    VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT = 0b00000000000000000000000010000000
    VK_IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b00000000000000000000000100000000
    VK_IMAGE_USAGE_FRAGMENT_DENSITY_MAP_BIT_EXT = 0b00000000000000000000001000000000
    VK_IMAGE_USAGE_VIDEO_DECODE_DST_BIT_KHR = 0b00000000000000000000010000000000
    VK_IMAGE_USAGE_VIDEO_DECODE_SRC_BIT_KHR = 0b00000000000000000000100000000000
    VK_IMAGE_USAGE_VIDEO_DECODE_DPB_BIT_KHR = 0b00000000000000000001000000000000
    VK_IMAGE_USAGE_VIDEO_ENCODE_DST_BIT_KHR = 0b00000000000000000010000000000000
    VK_IMAGE_USAGE_VIDEO_ENCODE_SRC_BIT_KHR = 0b00000000000000000100000000000000
    VK_IMAGE_USAGE_VIDEO_ENCODE_DPB_BIT_KHR = 0b00000000000000001000000000000000
    VK_IMAGE_USAGE_RESERVED_16_BIT_QCOM = 0b00000000000000010000000000000000
    VK_IMAGE_USAGE_RESERVED_17_BIT_QCOM = 0b00000000000000100000000000000000
    VK_IMAGE_USAGE_INVOCATION_MASK_BIT_HUAWEI = 0b00000000000001000000000000000000
    VK_IMAGE_USAGE_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT = 0b00000000000010000000000000000000
    VK_IMAGE_USAGE_SAMPLE_WEIGHT_BIT_QCOM = 0b00000000000100000000000000000000
    VK_IMAGE_USAGE_SAMPLE_BLOCK_MATCH_BIT_QCOM = 0b00000000001000000000000000000000
    VK_IMAGE_USAGE_RESERVED_22_BIT_EXT = 0b00000000010000000000000000000000
func toBits*(flags: openArray[VkImageUsageFlagBits]): VkImageUsageFlags =
    for flag in flags:
      result = VkImageUsageFlags(uint(result) or uint(flag))
func toEnums*(number: VkImageUsageFlags): seq[VkImageUsageFlagBits] =
    for value in VkImageUsageFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageUsageFlags): bool = cint(a) == cint(b)
type
  VkImageCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_IMAGE_CREATE_SPARSE_BINDING_BIT = 0b00000000000000000000000000000001
    VK_IMAGE_CREATE_SPARSE_RESIDENCY_BIT = 0b00000000000000000000000000000010
    VK_IMAGE_CREATE_SPARSE_ALIASED_BIT = 0b00000000000000000000000000000100
    VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT = 0b00000000000000000000000000001000
    VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT = 0b00000000000000000000000000010000
    VK_IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT = 0b00000000000000000000000000100000
    VK_IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT = 0b00000000000000000000000001000000
    VK_IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT = 0b00000000000000000000000010000000
    VK_IMAGE_CREATE_EXTENDED_USAGE_BIT = 0b00000000000000000000000100000000
    VK_IMAGE_CREATE_DISJOINT_BIT = 0b00000000000000000000001000000000
    VK_IMAGE_CREATE_ALIAS_BIT = 0b00000000000000000000010000000000
    VK_IMAGE_CREATE_PROTECTED_BIT = 0b00000000000000000000100000000000
    VK_IMAGE_CREATE_SAMPLE_LOCATIONS_COMPATIBLE_DEPTH_BIT_EXT = 0b00000000000000000001000000000000
    VK_IMAGE_CREATE_CORNER_SAMPLED_BIT_NV = 0b00000000000000000010000000000000
    VK_IMAGE_CREATE_SUBSAMPLED_BIT_EXT = 0b00000000000000000100000000000000
    VK_IMAGE_CREATE_FRAGMENT_DENSITY_MAP_OFFSET_BIT_QCOM = 0b00000000000000001000000000000000
    VK_IMAGE_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000010000000000000000
    VK_IMAGE_CREATE_2D_VIEW_COMPATIBLE_BIT_EXT = 0b00000000000000100000000000000000
    VK_IMAGE_CREATE_MULTISAMPLED_RENDER_TO_SINGLE_SAMPLED_BIT_EXT = 0b00000000000001000000000000000000
    VK_IMAGE_CREATE_RESERVED_19_BIT_EXT = 0b00000000000010000000000000000000
func toBits*(flags: openArray[VkImageCreateFlagBits]): VkImageCreateFlags =
    for flag in flags:
      result = VkImageCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkImageCreateFlags): seq[VkImageCreateFlagBits] =
    for value in VkImageCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageCreateFlags): bool = cint(a) == cint(b)
type
  VkImageViewCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DYNAMIC_BIT_EXT = 0b00000000000000000000000000000001
    VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DEFERRED_BIT_EXT = 0b00000000000000000000000000000010
    VK_IMAGE_VIEW_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkImageViewCreateFlagBits]): VkImageViewCreateFlags =
    for flag in flags:
      result = VkImageViewCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkImageViewCreateFlags): seq[VkImageViewCreateFlagBits] =
    for value in VkImageViewCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageViewCreateFlags): bool = cint(a) == cint(b)
type
  VkSamplerCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_SAMPLER_CREATE_SUBSAMPLED_BIT_EXT = 0b00000000000000000000000000000001
    VK_SAMPLER_CREATE_SUBSAMPLED_COARSE_RECONSTRUCTION_BIT_EXT = 0b00000000000000000000000000000010
    VK_SAMPLER_CREATE_NON_SEAMLESS_CUBE_MAP_BIT_EXT = 0b00000000000000000000000000000100
    VK_SAMPLER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000000000000000001000
    VK_SAMPLER_CREATE_IMAGE_PROCESSING_BIT_QCOM = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkSamplerCreateFlagBits]): VkSamplerCreateFlags =
    for flag in flags:
      result = VkSamplerCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkSamplerCreateFlags): seq[VkSamplerCreateFlagBits] =
    for value in VkSamplerCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSamplerCreateFlags): bool = cint(a) == cint(b)
type
  VkPipelineCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT = 0b00000000000000000000000000000001
    VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT = 0b00000000000000000000000000000010
    VK_PIPELINE_CREATE_DERIVATIVE_BIT = 0b00000000000000000000000000000100
    VK_PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT = 0b00000000000000000000000000001000
    VK_PIPELINE_CREATE_DISPATCH_BASE_BIT = 0b00000000000000000000000000010000
    VK_PIPELINE_CREATE_DEFER_COMPILE_BIT_NV = 0b00000000000000000000000000100000
    VK_PIPELINE_CREATE_CAPTURE_STATISTICS_BIT_KHR = 0b00000000000000000000000001000000
    VK_PIPELINE_CREATE_CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR = 0b00000000000000000000000010000000
    VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT = 0b00000000000000000000000100000000
    VK_PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT = 0b00000000000000000000001000000000
    VK_PIPELINE_CREATE_LINK_TIME_OPTIMIZATION_BIT_EXT = 0b00000000000000000000010000000000
    VK_PIPELINE_CREATE_LIBRARY_BIT_KHR = 0b00000000000000000000100000000000
    VK_PIPELINE_CREATE_RAY_TRACING_SKIP_TRIANGLES_BIT_KHR = 0b00000000000000000001000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_SKIP_AABBS_BIT_KHR = 0b00000000000000000010000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_ANY_HIT_SHADERS_BIT_KHR = 0b00000000000000000100000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_CLOSEST_HIT_SHADERS_BIT_KHR = 0b00000000000000001000000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_MISS_SHADERS_BIT_KHR = 0b00000000000000010000000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_INTERSECTION_SHADERS_BIT_KHR = 0b00000000000000100000000000000000
    VK_PIPELINE_CREATE_INDIRECT_BINDABLE_BIT_NV = 0b00000000000001000000000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_SHADER_GROUP_HANDLE_CAPTURE_REPLAY_BIT_KHR = 0b00000000000010000000000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_ALLOW_MOTION_BIT_NV = 0b00000000000100000000000000000000
    VK_PIPELINE_CREATE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b00000000001000000000000000000000
    VK_PIPELINE_CREATE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT = 0b00000000010000000000000000000000
    VK_PIPELINE_CREATE_RETAIN_LINK_TIME_OPTIMIZATION_INFO_BIT_EXT = 0b00000000100000000000000000000000
    VK_PIPELINE_CREATE_RAY_TRACING_OPACITY_MICROMAP_BIT_EXT = 0b00000001000000000000000000000000
    VK_PIPELINE_CREATE_COLOR_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT = 0b00000010000000000000000000000000
    VK_PIPELINE_CREATE_DEPTH_STENCIL_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT = 0b00000100000000000000000000000000
    VK_PIPELINE_CREATE_NO_PROTECTED_ACCESS_BIT_EXT = 0b00001000000000000000000000000000
    VK_PIPELINE_CREATE_RESERVED_BIT_28_NV = 0b00010000000000000000000000000000
    VK_PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT = 0b00100000000000000000000000000000
    VK_PIPELINE_CREATE_PROTECTED_ACCESS_ONLY_BIT_EXT = 0b01000000000000000000000000000000
func toBits*(flags: openArray[VkPipelineCreateFlagBits]): VkPipelineCreateFlags =
    for flag in flags:
      result = VkPipelineCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineCreateFlags): seq[VkPipelineCreateFlagBits] =
    for value in VkPipelineCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineCreateFlags): bool = cint(a) == cint(b)
type
  VkPipelineShaderStageCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT = 0b00000000000000000000000000000001
    VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT = 0b00000000000000000000000000000010
    VK_PIPELINE_SHADER_STAGE_CREATE_RESERVED_3_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkPipelineShaderStageCreateFlagBits]): VkPipelineShaderStageCreateFlags =
    for flag in flags:
      result = VkPipelineShaderStageCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineShaderStageCreateFlags): seq[VkPipelineShaderStageCreateFlagBits] =
    for value in VkPipelineShaderStageCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineShaderStageCreateFlags): bool = cint(a) == cint(b)
type
  VkColorComponentFlagBits* {.size: sizeof(cint).} = enum
    VK_COLOR_COMPONENT_R_BIT = 0b00000000000000000000000000000001
    VK_COLOR_COMPONENT_G_BIT = 0b00000000000000000000000000000010
    VK_COLOR_COMPONENT_B_BIT = 0b00000000000000000000000000000100
    VK_COLOR_COMPONENT_A_BIT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkColorComponentFlagBits]): VkColorComponentFlags =
    for flag in flags:
      result = VkColorComponentFlags(uint(result) or uint(flag))
func toEnums*(number: VkColorComponentFlags): seq[VkColorComponentFlagBits] =
    for value in VkColorComponentFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkColorComponentFlags): bool = cint(a) == cint(b)
type
  VkFenceCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_FENCE_CREATE_SIGNALED_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkFenceCreateFlagBits]): VkFenceCreateFlags =
    for flag in flags:
      result = VkFenceCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkFenceCreateFlags): seq[VkFenceCreateFlagBits] =
    for value in VkFenceCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkFenceCreateFlags): bool = cint(a) == cint(b)
type
  VkFormatFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT = 0b00000000000000000000000000000001
    VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT = 0b00000000000000000000000000000010
    VK_FORMAT_FEATURE_STORAGE_IMAGE_ATOMIC_BIT = 0b00000000000000000000000000000100
    VK_FORMAT_FEATURE_UNIFORM_TEXEL_BUFFER_BIT = 0b00000000000000000000000000001000
    VK_FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_BIT = 0b00000000000000000000000000010000
    VK_FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_ATOMIC_BIT = 0b00000000000000000000000000100000
    VK_FORMAT_FEATURE_VERTEX_BUFFER_BIT = 0b00000000000000000000000001000000
    VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT = 0b00000000000000000000000010000000
    VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BLEND_BIT = 0b00000000000000000000000100000000
    VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT = 0b00000000000000000000001000000000
    VK_FORMAT_FEATURE_BLIT_SRC_BIT = 0b00000000000000000000010000000000
    VK_FORMAT_FEATURE_BLIT_DST_BIT = 0b00000000000000000000100000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT = 0b00000000000000000001000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_CUBIC_BIT_EXT = 0b00000000000000000010000000000000
    VK_FORMAT_FEATURE_TRANSFER_SRC_BIT = 0b00000000000000000100000000000000
    VK_FORMAT_FEATURE_TRANSFER_DST_BIT = 0b00000000000000001000000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_MINMAX_BIT = 0b00000000000000010000000000000000
    VK_FORMAT_FEATURE_MIDPOINT_CHROMA_SAMPLES_BIT = 0b00000000000000100000000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT = 0b00000000000001000000000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT = 0b00000000000010000000000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT = 0b00000000000100000000000000000000
    VK_FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT = 0b00000000001000000000000000000000
    VK_FORMAT_FEATURE_DISJOINT_BIT = 0b00000000010000000000000000000000
    VK_FORMAT_FEATURE_COSITED_CHROMA_SAMPLES_BIT = 0b00000000100000000000000000000000
    VK_FORMAT_FEATURE_FRAGMENT_DENSITY_MAP_BIT_EXT = 0b00000001000000000000000000000000
    VK_FORMAT_FEATURE_VIDEO_DECODE_OUTPUT_BIT_KHR = 0b00000010000000000000000000000000
    VK_FORMAT_FEATURE_VIDEO_DECODE_DPB_BIT_KHR = 0b00000100000000000000000000000000
    VK_FORMAT_FEATURE_VIDEO_ENCODE_INPUT_BIT_KHR = 0b00001000000000000000000000000000
    VK_FORMAT_FEATURE_VIDEO_ENCODE_DPB_BIT_KHR = 0b00010000000000000000000000000000
    VK_FORMAT_FEATURE_ACCELERATION_STRUCTURE_VERTEX_BUFFER_BIT_KHR = 0b00100000000000000000000000000000
    VK_FORMAT_FEATURE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b01000000000000000000000000000000
func toBits*(flags: openArray[VkFormatFeatureFlagBits]): VkFormatFeatureFlags =
    for flag in flags:
      result = VkFormatFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkFormatFeatureFlags): seq[VkFormatFeatureFlagBits] =
    for value in VkFormatFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkFormatFeatureFlags): bool = cint(a) == cint(b)
type
  VkQueryControlFlagBits* {.size: sizeof(cint).} = enum
    VK_QUERY_CONTROL_PRECISE_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkQueryControlFlagBits]): VkQueryControlFlags =
    for flag in flags:
      result = VkQueryControlFlags(uint(result) or uint(flag))
func toEnums*(number: VkQueryControlFlags): seq[VkQueryControlFlagBits] =
    for value in VkQueryControlFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkQueryControlFlags): bool = cint(a) == cint(b)
type
  VkQueryResultFlagBits* {.size: sizeof(cint).} = enum
    VK_QUERY_RESULT_64_BIT = 0b00000000000000000000000000000001
    VK_QUERY_RESULT_WAIT_BIT = 0b00000000000000000000000000000010
    VK_QUERY_RESULT_WITH_AVAILABILITY_BIT = 0b00000000000000000000000000000100
    VK_QUERY_RESULT_PARTIAL_BIT = 0b00000000000000000000000000001000
    VK_QUERY_RESULT_WITH_STATUS_BIT_KHR = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkQueryResultFlagBits]): VkQueryResultFlags =
    for flag in flags:
      result = VkQueryResultFlags(uint(result) or uint(flag))
func toEnums*(number: VkQueryResultFlags): seq[VkQueryResultFlagBits] =
    for value in VkQueryResultFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkQueryResultFlags): bool = cint(a) == cint(b)
type
  VkCommandBufferUsageFlagBits* {.size: sizeof(cint).} = enum
    VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = 0b00000000000000000000000000000001
    VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT = 0b00000000000000000000000000000010
    VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkCommandBufferUsageFlagBits]): VkCommandBufferUsageFlags =
    for flag in flags:
      result = VkCommandBufferUsageFlags(uint(result) or uint(flag))
func toEnums*(number: VkCommandBufferUsageFlags): seq[VkCommandBufferUsageFlagBits] =
    for value in VkCommandBufferUsageFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCommandBufferUsageFlags): bool = cint(a) == cint(b)
type
  VkQueryPipelineStatisticFlagBits* {.size: sizeof(cint).} = enum
    VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_VERTICES_BIT = 0b00000000000000000000000000000001
    VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_PRIMITIVES_BIT = 0b00000000000000000000000000000010
    VK_QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_INVOCATIONS_BIT = 0b00000000000000000000000000000100
    VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_INVOCATIONS_BIT = 0b00000000000000000000000000001000
    VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_PRIMITIVES_BIT = 0b00000000000000000000000000010000
    VK_QUERY_PIPELINE_STATISTIC_CLIPPING_INVOCATIONS_BIT = 0b00000000000000000000000000100000
    VK_QUERY_PIPELINE_STATISTIC_CLIPPING_PRIMITIVES_BIT = 0b00000000000000000000000001000000
    VK_QUERY_PIPELINE_STATISTIC_FRAGMENT_SHADER_INVOCATIONS_BIT = 0b00000000000000000000000010000000
    VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_CONTROL_SHADER_PATCHES_BIT = 0b00000000000000000000000100000000
    VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_EVALUATION_SHADER_INVOCATIONS_BIT = 0b00000000000000000000001000000000
    VK_QUERY_PIPELINE_STATISTIC_COMPUTE_SHADER_INVOCATIONS_BIT = 0b00000000000000000000010000000000
    VK_QUERY_PIPELINE_STATISTIC_TASK_SHADER_INVOCATIONS_BIT_EXT = 0b00000000000000000000100000000000
    VK_QUERY_PIPELINE_STATISTIC_MESH_SHADER_INVOCATIONS_BIT_EXT = 0b00000000000000000001000000000000
    VK_QUERY_PIPELINE_STATISTIC_CLUSTER_CULLING_SHADER_INVOCATIONS_BIT_HUAWEI = 0b00000000000000000010000000000000
func toBits*(flags: openArray[VkQueryPipelineStatisticFlagBits]): VkQueryPipelineStatisticFlags =
    for flag in flags:
      result = VkQueryPipelineStatisticFlags(uint(result) or uint(flag))
func toEnums*(number: VkQueryPipelineStatisticFlags): seq[VkQueryPipelineStatisticFlagBits] =
    for value in VkQueryPipelineStatisticFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkQueryPipelineStatisticFlags): bool = cint(a) == cint(b)
type
  VkImageAspectFlagBits* {.size: sizeof(cint).} = enum
    VK_IMAGE_ASPECT_COLOR_BIT = 0b00000000000000000000000000000001
    VK_IMAGE_ASPECT_DEPTH_BIT = 0b00000000000000000000000000000010
    VK_IMAGE_ASPECT_STENCIL_BIT = 0b00000000000000000000000000000100
    VK_IMAGE_ASPECT_METADATA_BIT = 0b00000000000000000000000000001000
    VK_IMAGE_ASPECT_PLANE_0_BIT = 0b00000000000000000000000000010000
    VK_IMAGE_ASPECT_PLANE_1_BIT = 0b00000000000000000000000000100000
    VK_IMAGE_ASPECT_PLANE_2_BIT = 0b00000000000000000000000001000000
    VK_IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT = 0b00000000000000000000000010000000
    VK_IMAGE_ASPECT_MEMORY_PLANE_1_BIT_EXT = 0b00000000000000000000000100000000
    VK_IMAGE_ASPECT_MEMORY_PLANE_2_BIT_EXT = 0b00000000000000000000001000000000
    VK_IMAGE_ASPECT_MEMORY_PLANE_3_BIT_EXT = 0b00000000000000000000010000000000
func toBits*(flags: openArray[VkImageAspectFlagBits]): VkImageAspectFlags =
    for flag in flags:
      result = VkImageAspectFlags(uint(result) or uint(flag))
func toEnums*(number: VkImageAspectFlags): seq[VkImageAspectFlagBits] =
    for value in VkImageAspectFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageAspectFlags): bool = cint(a) == cint(b)
type
  VkSparseImageFormatFlagBits* {.size: sizeof(cint).} = enum
    VK_SPARSE_IMAGE_FORMAT_SINGLE_MIPTAIL_BIT = 0b00000000000000000000000000000001
    VK_SPARSE_IMAGE_FORMAT_ALIGNED_MIP_SIZE_BIT = 0b00000000000000000000000000000010
    VK_SPARSE_IMAGE_FORMAT_NONSTANDARD_BLOCK_SIZE_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkSparseImageFormatFlagBits]): VkSparseImageFormatFlags =
    for flag in flags:
      result = VkSparseImageFormatFlags(uint(result) or uint(flag))
func toEnums*(number: VkSparseImageFormatFlags): seq[VkSparseImageFormatFlagBits] =
    for value in VkSparseImageFormatFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSparseImageFormatFlags): bool = cint(a) == cint(b)
type
  VkSparseMemoryBindFlagBits* {.size: sizeof(cint).} = enum
    VK_SPARSE_MEMORY_BIND_METADATA_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSparseMemoryBindFlagBits]): VkSparseMemoryBindFlags =
    for flag in flags:
      result = VkSparseMemoryBindFlags(uint(result) or uint(flag))
func toEnums*(number: VkSparseMemoryBindFlags): seq[VkSparseMemoryBindFlagBits] =
    for value in VkSparseMemoryBindFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSparseMemoryBindFlags): bool = cint(a) == cint(b)
type
  VkPipelineStageFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT = 0b00000000000000000000000000000001
    VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT = 0b00000000000000000000000000000010
    VK_PIPELINE_STAGE_VERTEX_INPUT_BIT = 0b00000000000000000000000000000100
    VK_PIPELINE_STAGE_VERTEX_SHADER_BIT = 0b00000000000000000000000000001000
    VK_PIPELINE_STAGE_TESSELLATION_CONTROL_SHADER_BIT = 0b00000000000000000000000000010000
    VK_PIPELINE_STAGE_TESSELLATION_EVALUATION_SHADER_BIT = 0b00000000000000000000000000100000
    VK_PIPELINE_STAGE_GEOMETRY_SHADER_BIT = 0b00000000000000000000000001000000
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT = 0b00000000000000000000000010000000
    VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT = 0b00000000000000000000000100000000
    VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT = 0b00000000000000000000001000000000
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0b00000000000000000000010000000000
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT = 0b00000000000000000000100000000000
    VK_PIPELINE_STAGE_TRANSFER_BIT = 0b00000000000000000001000000000000
    VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT = 0b00000000000000000010000000000000
    VK_PIPELINE_STAGE_HOST_BIT = 0b00000000000000000100000000000000
    VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT = 0b00000000000000001000000000000000
    VK_PIPELINE_STAGE_ALL_COMMANDS_BIT = 0b00000000000000010000000000000000
    VK_PIPELINE_STAGE_COMMAND_PREPROCESS_BIT_NV = 0b00000000000000100000000000000000
    VK_PIPELINE_STAGE_CONDITIONAL_RENDERING_BIT_EXT = 0b00000000000001000000000000000000
    VK_PIPELINE_STAGE_TASK_SHADER_BIT_EXT = 0b00000000000010000000000000000000
    VK_PIPELINE_STAGE_MESH_SHADER_BIT_EXT = 0b00000000000100000000000000000000
    VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR = 0b00000000001000000000000000000000
    VK_PIPELINE_STAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b00000000010000000000000000000000
    VK_PIPELINE_STAGE_FRAGMENT_DENSITY_PROCESS_BIT_EXT = 0b00000000100000000000000000000000
    VK_PIPELINE_STAGE_TRANSFORM_FEEDBACK_BIT_EXT = 0b00000001000000000000000000000000
    VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR = 0b00000010000000000000000000000000
func toBits*(flags: openArray[VkPipelineStageFlagBits]): VkPipelineStageFlags =
    for flag in flags:
      result = VkPipelineStageFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineStageFlags): seq[VkPipelineStageFlagBits] =
    for value in VkPipelineStageFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineStageFlags): bool = cint(a) == cint(b)
type
  VkCommandPoolCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_COMMAND_POOL_CREATE_TRANSIENT_BIT = 0b00000000000000000000000000000001
    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0b00000000000000000000000000000010
    VK_COMMAND_POOL_CREATE_PROTECTED_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkCommandPoolCreateFlagBits]): VkCommandPoolCreateFlags =
    for flag in flags:
      result = VkCommandPoolCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkCommandPoolCreateFlags): seq[VkCommandPoolCreateFlagBits] =
    for value in VkCommandPoolCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCommandPoolCreateFlags): bool = cint(a) == cint(b)
type
  VkCommandPoolResetFlagBits* {.size: sizeof(cint).} = enum
    VK_COMMAND_POOL_RESET_RELEASE_RESOURCES_BIT = 0b00000000000000000000000000000001
    VK_COMMAND_POOL_RESET_RESERVED_1_BIT_COREAVI = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkCommandPoolResetFlagBits]): VkCommandPoolResetFlags =
    for flag in flags:
      result = VkCommandPoolResetFlags(uint(result) or uint(flag))
func toEnums*(number: VkCommandPoolResetFlags): seq[VkCommandPoolResetFlagBits] =
    for value in VkCommandPoolResetFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCommandPoolResetFlags): bool = cint(a) == cint(b)
type
  VkCommandBufferResetFlagBits* {.size: sizeof(cint).} = enum
    VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkCommandBufferResetFlagBits]): VkCommandBufferResetFlags =
    for flag in flags:
      result = VkCommandBufferResetFlags(uint(result) or uint(flag))
func toEnums*(number: VkCommandBufferResetFlags): seq[VkCommandBufferResetFlagBits] =
    for value in VkCommandBufferResetFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCommandBufferResetFlags): bool = cint(a) == cint(b)
type
  VkSampleCountFlagBits* {.size: sizeof(cint).} = enum
    VK_SAMPLE_COUNT_1_BIT = 0b00000000000000000000000000000001
    VK_SAMPLE_COUNT_2_BIT = 0b00000000000000000000000000000010
    VK_SAMPLE_COUNT_4_BIT = 0b00000000000000000000000000000100
    VK_SAMPLE_COUNT_8_BIT = 0b00000000000000000000000000001000
    VK_SAMPLE_COUNT_16_BIT = 0b00000000000000000000000000010000
    VK_SAMPLE_COUNT_32_BIT = 0b00000000000000000000000000100000
    VK_SAMPLE_COUNT_64_BIT = 0b00000000000000000000000001000000
func toBits*(flags: openArray[VkSampleCountFlagBits]): VkSampleCountFlags =
    for flag in flags:
      result = VkSampleCountFlags(uint(result) or uint(flag))
func toEnums*(number: VkSampleCountFlags): seq[VkSampleCountFlagBits] =
    for value in VkSampleCountFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSampleCountFlags): bool = cint(a) == cint(b)
type
  VkAttachmentDescriptionFlagBits* {.size: sizeof(cint).} = enum
    VK_ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkAttachmentDescriptionFlagBits]): VkAttachmentDescriptionFlags =
    for flag in flags:
      result = VkAttachmentDescriptionFlags(uint(result) or uint(flag))
func toEnums*(number: VkAttachmentDescriptionFlags): seq[VkAttachmentDescriptionFlagBits] =
    for value in VkAttachmentDescriptionFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkAttachmentDescriptionFlags): bool = cint(a) == cint(b)
type
  VkStencilFaceFlagBits* {.size: sizeof(cint).} = enum
    VK_STENCIL_FACE_FRONT_BIT = 0b00000000000000000000000000000001
    VK_STENCIL_FACE_BACK_BIT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkStencilFaceFlagBits]): VkStencilFaceFlags =
    for flag in flags:
      result = VkStencilFaceFlags(uint(result) or uint(flag))
func toEnums*(number: VkStencilFaceFlags): seq[VkStencilFaceFlagBits] =
    for value in VkStencilFaceFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkStencilFaceFlags): bool = cint(a) == cint(b)
const
  VK_STENCIL_FACE_FRONT_AND_BACK* = 0x00000003
type
  VkDescriptorPoolCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT = 0b00000000000000000000000000000001
    VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT = 0b00000000000000000000000000000010
    VK_DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkDescriptorPoolCreateFlagBits]): VkDescriptorPoolCreateFlags =
    for flag in flags:
      result = VkDescriptorPoolCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkDescriptorPoolCreateFlags): seq[VkDescriptorPoolCreateFlagBits] =
    for value in VkDescriptorPoolCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDescriptorPoolCreateFlags): bool = cint(a) == cint(b)
type
  VkDependencyFlagBits* {.size: sizeof(cint).} = enum
    VK_DEPENDENCY_BY_REGION_BIT = 0b00000000000000000000000000000001
    VK_DEPENDENCY_VIEW_LOCAL_BIT = 0b00000000000000000000000000000010
    VK_DEPENDENCY_DEVICE_GROUP_BIT = 0b00000000000000000000000000000100
    VK_DEPENDENCY_FEEDBACK_LOOP_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkDependencyFlagBits]): VkDependencyFlags =
    for flag in flags:
      result = VkDependencyFlags(uint(result) or uint(flag))
func toEnums*(number: VkDependencyFlags): seq[VkDependencyFlagBits] =
    for value in VkDependencyFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDependencyFlags): bool = cint(a) == cint(b)
type
  VkSemaphoreType* {.size: sizeof(cint).} = enum
    VK_SEMAPHORE_TYPE_BINARY = 0
    VK_SEMAPHORE_TYPE_TIMELINE = 1
  VkSemaphoreWaitFlagBits* {.size: sizeof(cint).} = enum
    VK_SEMAPHORE_WAIT_ANY_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSemaphoreWaitFlagBits]): VkSemaphoreWaitFlags =
    for flag in flags:
      result = VkSemaphoreWaitFlags(uint(result) or uint(flag))
func toEnums*(number: VkSemaphoreWaitFlags): seq[VkSemaphoreWaitFlagBits] =
    for value in VkSemaphoreWaitFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSemaphoreWaitFlags): bool = cint(a) == cint(b)
type
  VkPresentModeKHR* {.size: sizeof(cint).} = enum
    VK_PRESENT_MODE_IMMEDIATE_KHR = 0
    VK_PRESENT_MODE_MAILBOX_KHR = 1
    VK_PRESENT_MODE_FIFO_KHR = 2
    VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3
    VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR = 1000111000
    VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR = 1000111001
  VkColorSpaceKHR* {.size: sizeof(cint).} = enum
    VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
    VK_COLOR_SPACE_DISPLAY_P3_NONLINEAR_EXT = 1000104001
    VK_COLOR_SPACE_EXTENDED_SRGB_LINEAR_EXT = 1000104002
    VK_COLOR_SPACE_DISPLAY_P3_LINEAR_EXT = 1000104003
    VK_COLOR_SPACE_DCI_P3_NONLINEAR_EXT = 1000104004
    VK_COLOR_SPACE_BT709_LINEAR_EXT = 1000104005
    VK_COLOR_SPACE_BT709_NONLINEAR_EXT = 1000104006
    VK_COLOR_SPACE_BT2020_LINEAR_EXT = 1000104007
    VK_COLOR_SPACE_HDR10_ST2084_EXT = 1000104008
    VK_COLOR_SPACE_DOLBYVISION_EXT = 1000104009
    VK_COLOR_SPACE_HDR10_HLG_EXT = 1000104010
    VK_COLOR_SPACE_ADOBERGB_LINEAR_EXT = 1000104011
    VK_COLOR_SPACE_ADOBERGB_NONLINEAR_EXT = 1000104012
    VK_COLOR_SPACE_PASS_THROUGH_EXT = 1000104013
    VK_COLOR_SPACE_EXTENDED_SRGB_NONLINEAR_EXT = 1000104014
    VK_COLOR_SPACE_DISPLAY_NATIVE_AMD = 1000213000
  VkDisplayPlaneAlphaFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_DISPLAY_PLANE_ALPHA_OPAQUE_BIT_KHR = 0b00000000000000000000000000000001
    VK_DISPLAY_PLANE_ALPHA_GLOBAL_BIT_KHR = 0b00000000000000000000000000000010
    VK_DISPLAY_PLANE_ALPHA_PER_PIXEL_BIT_KHR = 0b00000000000000000000000000000100
    VK_DISPLAY_PLANE_ALPHA_PER_PIXEL_PREMULTIPLIED_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkDisplayPlaneAlphaFlagBitsKHR]): VkDisplayPlaneAlphaFlagsKHR =
    for flag in flags:
      result = VkDisplayPlaneAlphaFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkDisplayPlaneAlphaFlagsKHR): seq[VkDisplayPlaneAlphaFlagBitsKHR] =
    for value in VkDisplayPlaneAlphaFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDisplayPlaneAlphaFlagsKHR): bool = cint(a) == cint(b)
type
  VkCompositeAlphaFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0b00000000000000000000000000000001
    VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR = 0b00000000000000000000000000000010
    VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR = 0b00000000000000000000000000000100
    VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkCompositeAlphaFlagBitsKHR]): VkCompositeAlphaFlagsKHR =
    for flag in flags:
      result = VkCompositeAlphaFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkCompositeAlphaFlagsKHR): seq[VkCompositeAlphaFlagBitsKHR] =
    for value in VkCompositeAlphaFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkCompositeAlphaFlagsKHR): bool = cint(a) == cint(b)
type
  VkSurfaceTransformFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0b00000000000000000000000000000001
    VK_SURFACE_TRANSFORM_ROTATE_90_BIT_KHR = 0b00000000000000000000000000000010
    VK_SURFACE_TRANSFORM_ROTATE_180_BIT_KHR = 0b00000000000000000000000000000100
    VK_SURFACE_TRANSFORM_ROTATE_270_BIT_KHR = 0b00000000000000000000000000001000
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_BIT_KHR = 0b00000000000000000000000000010000
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_90_BIT_KHR = 0b00000000000000000000000000100000
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_180_BIT_KHR = 0b00000000000000000000000001000000
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_270_BIT_KHR = 0b00000000000000000000000010000000
    VK_SURFACE_TRANSFORM_INHERIT_BIT_KHR = 0b00000000000000000000000100000000
func toBits*(flags: openArray[VkSurfaceTransformFlagBitsKHR]): VkSurfaceTransformFlagsKHR =
    for flag in flags:
      result = VkSurfaceTransformFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkSurfaceTransformFlagsKHR): seq[VkSurfaceTransformFlagBitsKHR] =
    for value in VkSurfaceTransformFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSurfaceTransformFlagsKHR): bool = cint(a) == cint(b)
type
  VkSwapchainImageUsageFlagBitsANDROID* {.size: sizeof(cint).} = enum
    VK_SWAPCHAIN_IMAGE_USAGE_SHARED_BIT_ANDROID = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSwapchainImageUsageFlagBitsANDROID]): VkSwapchainImageUsageFlagsANDROID =
    for flag in flags:
      result = VkSwapchainImageUsageFlagsANDROID(uint(result) or uint(flag))
func toEnums*(number: VkSwapchainImageUsageFlagsANDROID): seq[VkSwapchainImageUsageFlagBitsANDROID] =
    for value in VkSwapchainImageUsageFlagBitsANDROID.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSwapchainImageUsageFlagsANDROID): bool = cint(a) == cint(b)
type
  VkTimeDomainEXT* {.size: sizeof(cint).} = enum
    VK_TIME_DOMAIN_DEVICE_EXT = 0
    VK_TIME_DOMAIN_CLOCK_MONOTONIC_EXT = 1
    VK_TIME_DOMAIN_CLOCK_MONOTONIC_RAW_EXT = 2
    VK_TIME_DOMAIN_QUERY_PERFORMANCE_COUNTER_EXT = 3
  VkDebugReportFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_DEBUG_REPORT_INFORMATION_BIT_EXT = 0b00000000000000000000000000000001
    VK_DEBUG_REPORT_WARNING_BIT_EXT = 0b00000000000000000000000000000010
    VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT = 0b00000000000000000000000000000100
    VK_DEBUG_REPORT_ERROR_BIT_EXT = 0b00000000000000000000000000001000
    VK_DEBUG_REPORT_DEBUG_BIT_EXT = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkDebugReportFlagBitsEXT]): VkDebugReportFlagsEXT =
    for flag in flags:
      result = VkDebugReportFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkDebugReportFlagsEXT): seq[VkDebugReportFlagBitsEXT] =
    for value in VkDebugReportFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDebugReportFlagsEXT): bool = cint(a) == cint(b)
type
  VkDebugReportObjectTypeEXT* {.size: sizeof(cint).} = enum
    VK_DEBUG_REPORT_OBJECT_TYPE_UNKNOWN_EXT = 0
    VK_DEBUG_REPORT_OBJECT_TYPE_INSTANCE_EXT = 1
    VK_DEBUG_REPORT_OBJECT_TYPE_PHYSICAL_DEVICE_EXT = 2
    VK_DEBUG_REPORT_OBJECT_TYPE_DEVICE_EXT = 3
    VK_DEBUG_REPORT_OBJECT_TYPE_QUEUE_EXT = 4
    VK_DEBUG_REPORT_OBJECT_TYPE_SEMAPHORE_EXT = 5
    VK_DEBUG_REPORT_OBJECT_TYPE_COMMAND_BUFFER_EXT = 6
    VK_DEBUG_REPORT_OBJECT_TYPE_FENCE_EXT = 7
    VK_DEBUG_REPORT_OBJECT_TYPE_DEVICE_MEMORY_EXT = 8
    VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_EXT = 9
    VK_DEBUG_REPORT_OBJECT_TYPE_IMAGE_EXT = 10
    VK_DEBUG_REPORT_OBJECT_TYPE_EVENT_EXT = 11
    VK_DEBUG_REPORT_OBJECT_TYPE_QUERY_POOL_EXT = 12
    VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_VIEW_EXT = 13
    VK_DEBUG_REPORT_OBJECT_TYPE_IMAGE_VIEW_EXT = 14
    VK_DEBUG_REPORT_OBJECT_TYPE_SHADER_MODULE_EXT = 15
    VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_CACHE_EXT = 16
    VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_LAYOUT_EXT = 17
    VK_DEBUG_REPORT_OBJECT_TYPE_RENDER_PASS_EXT = 18
    VK_DEBUG_REPORT_OBJECT_TYPE_PIPELINE_EXT = 19
    VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT_EXT = 20
    VK_DEBUG_REPORT_OBJECT_TYPE_SAMPLER_EXT = 21
    VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_POOL_EXT = 22
    VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_SET_EXT = 23
    VK_DEBUG_REPORT_OBJECT_TYPE_FRAMEBUFFER_EXT = 24
    VK_DEBUG_REPORT_OBJECT_TYPE_COMMAND_POOL_EXT = 25
    VK_DEBUG_REPORT_OBJECT_TYPE_SURFACE_KHR_EXT = 26
    VK_DEBUG_REPORT_OBJECT_TYPE_SWAPCHAIN_KHR_EXT = 27
    VK_DEBUG_REPORT_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT_EXT = 28
    VK_DEBUG_REPORT_OBJECT_TYPE_DISPLAY_KHR_EXT = 29
    VK_DEBUG_REPORT_OBJECT_TYPE_DISPLAY_MODE_KHR_EXT = 30
    VK_DEBUG_REPORT_OBJECT_TYPE_VALIDATION_CACHE_EXT_EXT = 33
    VK_DEBUG_REPORT_OBJECT_TYPE_CU_MODULE_NVX_EXT = 1000029000
    VK_DEBUG_REPORT_OBJECT_TYPE_CU_FUNCTION_NVX_EXT = 1000029001
    VK_DEBUG_REPORT_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE_EXT = 1000085000
    VK_DEBUG_REPORT_OBJECT_TYPE_ACCELERATION_STRUCTURE_KHR_EXT = 1000150000
    VK_DEBUG_REPORT_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION_EXT = 1000156000
    VK_DEBUG_REPORT_OBJECT_TYPE_ACCELERATION_STRUCTURE_NV_EXT = 1000165000
    VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_COLLECTION_FUCHSIA_EXT = 1000366000
  VkDeviceMemoryReportEventTypeEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_MEMORY_REPORT_EVENT_TYPE_ALLOCATE_EXT = 0
    VK_DEVICE_MEMORY_REPORT_EVENT_TYPE_FREE_EXT = 1
    VK_DEVICE_MEMORY_REPORT_EVENT_TYPE_IMPORT_EXT = 2
    VK_DEVICE_MEMORY_REPORT_EVENT_TYPE_UNIMPORT_EXT = 3
    VK_DEVICE_MEMORY_REPORT_EVENT_TYPE_ALLOCATION_FAILED_EXT = 4
  VkRasterizationOrderAMD* {.size: sizeof(cint).} = enum
    VK_RASTERIZATION_ORDER_STRICT_AMD = 0
    VK_RASTERIZATION_ORDER_RELAXED_AMD = 1
  VkExternalMemoryHandleTypeFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT_NV = 0b00000000000000000000000000000001
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT_NV = 0b00000000000000000000000000000010
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_IMAGE_BIT_NV = 0b00000000000000000000000000000100
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_IMAGE_KMT_BIT_NV = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkExternalMemoryHandleTypeFlagBitsNV]): VkExternalMemoryHandleTypeFlagsNV =
    for flag in flags:
      result = VkExternalMemoryHandleTypeFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkExternalMemoryHandleTypeFlagsNV): seq[VkExternalMemoryHandleTypeFlagBitsNV] =
    for value in VkExternalMemoryHandleTypeFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalMemoryHandleTypeFlagsNV): bool = cint(a) == cint(b)
type
  VkExternalMemoryFeatureFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT_NV = 0b00000000000000000000000000000001
    VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT_NV = 0b00000000000000000000000000000010
    VK_EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT_NV = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkExternalMemoryFeatureFlagBitsNV]): VkExternalMemoryFeatureFlagsNV =
    for flag in flags:
      result = VkExternalMemoryFeatureFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkExternalMemoryFeatureFlagsNV): seq[VkExternalMemoryFeatureFlagBitsNV] =
    for value in VkExternalMemoryFeatureFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalMemoryFeatureFlagsNV): bool = cint(a) == cint(b)
type
  VkValidationCheckEXT* {.size: sizeof(cint).} = enum
    VK_VALIDATION_CHECK_ALL_EXT = 0
    VK_VALIDATION_CHECK_SHADERS_EXT = 1
  VkValidationFeatureEnableEXT* {.size: sizeof(cint).} = enum
    VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT = 0
    VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_RESERVE_BINDING_SLOT_EXT = 1
    VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT = 2
    VK_VALIDATION_FEATURE_ENABLE_DEBUG_PRINTF_EXT = 3
    VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT = 4
  VkValidationFeatureDisableEXT* {.size: sizeof(cint).} = enum
    VK_VALIDATION_FEATURE_DISABLE_ALL_EXT = 0
    VK_VALIDATION_FEATURE_DISABLE_SHADERS_EXT = 1
    VK_VALIDATION_FEATURE_DISABLE_THREAD_SAFETY_EXT = 2
    VK_VALIDATION_FEATURE_DISABLE_API_PARAMETERS_EXT = 3
    VK_VALIDATION_FEATURE_DISABLE_OBJECT_LIFETIMES_EXT = 4
    VK_VALIDATION_FEATURE_DISABLE_CORE_CHECKS_EXT = 5
    VK_VALIDATION_FEATURE_DISABLE_UNIQUE_HANDLES_EXT = 6
    VK_VALIDATION_FEATURE_DISABLE_SHADER_VALIDATION_CACHE_EXT = 7
  VkSubgroupFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_SUBGROUP_FEATURE_BASIC_BIT = 0b00000000000000000000000000000001
    VK_SUBGROUP_FEATURE_VOTE_BIT = 0b00000000000000000000000000000010
    VK_SUBGROUP_FEATURE_ARITHMETIC_BIT = 0b00000000000000000000000000000100
    VK_SUBGROUP_FEATURE_BALLOT_BIT = 0b00000000000000000000000000001000
    VK_SUBGROUP_FEATURE_SHUFFLE_BIT = 0b00000000000000000000000000010000
    VK_SUBGROUP_FEATURE_SHUFFLE_RELATIVE_BIT = 0b00000000000000000000000000100000
    VK_SUBGROUP_FEATURE_CLUSTERED_BIT = 0b00000000000000000000000001000000
    VK_SUBGROUP_FEATURE_QUAD_BIT = 0b00000000000000000000000010000000
    VK_SUBGROUP_FEATURE_PARTITIONED_BIT_NV = 0b00000000000000000000000100000000
func toBits*(flags: openArray[VkSubgroupFeatureFlagBits]): VkSubgroupFeatureFlags =
    for flag in flags:
      result = VkSubgroupFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkSubgroupFeatureFlags): seq[VkSubgroupFeatureFlagBits] =
    for value in VkSubgroupFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSubgroupFeatureFlags): bool = cint(a) == cint(b)
type
  VkIndirectCommandsLayoutUsageFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_INDIRECT_COMMANDS_LAYOUT_USAGE_EXPLICIT_PREPROCESS_BIT_NV = 0b00000000000000000000000000000001
    VK_INDIRECT_COMMANDS_LAYOUT_USAGE_INDEXED_SEQUENCES_BIT_NV = 0b00000000000000000000000000000010
    VK_INDIRECT_COMMANDS_LAYOUT_USAGE_UNORDERED_SEQUENCES_BIT_NV = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkIndirectCommandsLayoutUsageFlagBitsNV]): VkIndirectCommandsLayoutUsageFlagsNV =
    for flag in flags:
      result = VkIndirectCommandsLayoutUsageFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkIndirectCommandsLayoutUsageFlagsNV): seq[VkIndirectCommandsLayoutUsageFlagBitsNV] =
    for value in VkIndirectCommandsLayoutUsageFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkIndirectCommandsLayoutUsageFlagsNV): bool = cint(a) == cint(b)
type
  VkIndirectStateFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_INDIRECT_STATE_FLAG_FRONTFACE_BIT_NV = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkIndirectStateFlagBitsNV]): VkIndirectStateFlagsNV =
    for flag in flags:
      result = VkIndirectStateFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkIndirectStateFlagsNV): seq[VkIndirectStateFlagBitsNV] =
    for value in VkIndirectStateFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkIndirectStateFlagsNV): bool = cint(a) == cint(b)
type
  VkIndirectCommandsTokenTypeNV* {.size: sizeof(cint).} = enum
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_SHADER_GROUP_NV = 0
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_STATE_FLAGS_NV = 1
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_INDEX_BUFFER_NV = 2
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_VERTEX_BUFFER_NV = 3
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_PUSH_CONSTANT_NV = 4
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_INDEXED_NV = 5
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_NV = 6
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_TASKS_NV = 7
    VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_MESH_TASKS_NV = 1000328000
  VkPrivateDataSlotCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PRIVATE_DATA_SLOT_CREATE_RESERVED_0_BIT_NV = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkPrivateDataSlotCreateFlagBits]): VkPrivateDataSlotCreateFlags =
    for flag in flags:
      result = VkPrivateDataSlotCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPrivateDataSlotCreateFlags): seq[VkPrivateDataSlotCreateFlagBits] =
    for value in VkPrivateDataSlotCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPrivateDataSlotCreateFlags): bool = cint(a) == cint(b)
type
  VkDescriptorSetLayoutCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR = 0b00000000000000000000000000000001
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT = 0b00000000000000000000000000000010
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_EXT = 0b00000000000000000000000000000100
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_RESERVED_3_BIT_AMD = 0b00000000000000000000000000001000
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT = 0b00000000000000000000000000010000
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_EMBEDDED_IMMUTABLE_SAMPLERS_BIT_EXT = 0b00000000000000000000000000100000
func toBits*(flags: openArray[VkDescriptorSetLayoutCreateFlagBits]): VkDescriptorSetLayoutCreateFlags =
    for flag in flags:
      result = VkDescriptorSetLayoutCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkDescriptorSetLayoutCreateFlags): seq[VkDescriptorSetLayoutCreateFlagBits] =
    for value in VkDescriptorSetLayoutCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDescriptorSetLayoutCreateFlags): bool = cint(a) == cint(b)
type
  VkExternalMemoryHandleTypeFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT = 0b00000000000000000000000000000010
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT = 0b00000000000000000000000000000100
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT = 0b00000000000000000000000000001000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_KMT_BIT = 0b00000000000000000000000000010000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_HEAP_BIT = 0b00000000000000000000000000100000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE_BIT = 0b00000000000000000000000001000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_HOST_ALLOCATION_BIT_EXT = 0b00000000000000000000000010000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_HOST_MAPPED_FOREIGN_MEMORY_BIT_EXT = 0b00000000000000000000000100000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT = 0b00000000000000000000001000000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_ANDROID_HARDWARE_BUFFER_BIT_ANDROID = 0b00000000000000000000010000000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_ZIRCON_VMO_BIT_FUCHSIA = 0b00000000000000000000100000000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_RDMA_ADDRESS_BIT_NV = 0b00000000000000000001000000000000
    VK_EXTERNAL_MEMORY_HANDLE_TYPE_SCI_BUF_BIT_NV = 0b00000000000000000010000000000000
func toBits*(flags: openArray[VkExternalMemoryHandleTypeFlagBits]): VkExternalMemoryHandleTypeFlags =
    for flag in flags:
      result = VkExternalMemoryHandleTypeFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalMemoryHandleTypeFlags): seq[VkExternalMemoryHandleTypeFlagBits] =
    for value in VkExternalMemoryHandleTypeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalMemoryHandleTypeFlags): bool = cint(a) == cint(b)
type
  VkExternalMemoryFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT = 0b00000000000000000000000000000010
    VK_EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkExternalMemoryFeatureFlagBits]): VkExternalMemoryFeatureFlags =
    for flag in flags:
      result = VkExternalMemoryFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalMemoryFeatureFlags): seq[VkExternalMemoryFeatureFlagBits] =
    for value in VkExternalMemoryFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalMemoryFeatureFlags): bool = cint(a) == cint(b)
type
  VkExternalSemaphoreHandleTypeFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT = 0b00000000000000000000000000000010
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT = 0b00000000000000000000000000000100
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT = 0b00000000000000000000000000001000
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_SYNC_FD_BIT = 0b00000000000000000000000000010000
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_SCI_SYNC_OBJ_BIT_NV = 0b00000000000000000000000000100000
    VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_ZIRCON_EVENT_BIT_FUCHSIA = 0b00000000000000000000000010000000
func toBits*(flags: openArray[VkExternalSemaphoreHandleTypeFlagBits]): VkExternalSemaphoreHandleTypeFlags =
    for flag in flags:
      result = VkExternalSemaphoreHandleTypeFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalSemaphoreHandleTypeFlags): seq[VkExternalSemaphoreHandleTypeFlagBits] =
    for value in VkExternalSemaphoreHandleTypeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalSemaphoreHandleTypeFlags): bool = cint(a) == cint(b)
type
  VkExternalSemaphoreFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_SEMAPHORE_FEATURE_EXPORTABLE_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_SEMAPHORE_FEATURE_IMPORTABLE_BIT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkExternalSemaphoreFeatureFlagBits]): VkExternalSemaphoreFeatureFlags =
    for flag in flags:
      result = VkExternalSemaphoreFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalSemaphoreFeatureFlags): seq[VkExternalSemaphoreFeatureFlagBits] =
    for value in VkExternalSemaphoreFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalSemaphoreFeatureFlags): bool = cint(a) == cint(b)
type
  VkSemaphoreImportFlagBits* {.size: sizeof(cint).} = enum
    VK_SEMAPHORE_IMPORT_TEMPORARY_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSemaphoreImportFlagBits]): VkSemaphoreImportFlags =
    for flag in flags:
      result = VkSemaphoreImportFlags(uint(result) or uint(flag))
func toEnums*(number: VkSemaphoreImportFlags): seq[VkSemaphoreImportFlagBits] =
    for value in VkSemaphoreImportFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSemaphoreImportFlags): bool = cint(a) == cint(b)
type
  VkExternalFenceHandleTypeFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_FD_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_BIT = 0b00000000000000000000000000000010
    VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT = 0b00000000000000000000000000000100
    VK_EXTERNAL_FENCE_HANDLE_TYPE_SYNC_FD_BIT = 0b00000000000000000000000000001000
    VK_EXTERNAL_FENCE_HANDLE_TYPE_SCI_SYNC_OBJ_BIT_NV = 0b00000000000000000000000000010000
    VK_EXTERNAL_FENCE_HANDLE_TYPE_SCI_SYNC_FENCE_BIT_NV = 0b00000000000000000000000000100000
func toBits*(flags: openArray[VkExternalFenceHandleTypeFlagBits]): VkExternalFenceHandleTypeFlags =
    for flag in flags:
      result = VkExternalFenceHandleTypeFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalFenceHandleTypeFlags): seq[VkExternalFenceHandleTypeFlagBits] =
    for value in VkExternalFenceHandleTypeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalFenceHandleTypeFlags): bool = cint(a) == cint(b)
type
  VkExternalFenceFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_EXTERNAL_FENCE_FEATURE_EXPORTABLE_BIT = 0b00000000000000000000000000000001
    VK_EXTERNAL_FENCE_FEATURE_IMPORTABLE_BIT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkExternalFenceFeatureFlagBits]): VkExternalFenceFeatureFlags =
    for flag in flags:
      result = VkExternalFenceFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkExternalFenceFeatureFlags): seq[VkExternalFenceFeatureFlagBits] =
    for value in VkExternalFenceFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExternalFenceFeatureFlags): bool = cint(a) == cint(b)
type
  VkFenceImportFlagBits* {.size: sizeof(cint).} = enum
    VK_FENCE_IMPORT_TEMPORARY_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkFenceImportFlagBits]): VkFenceImportFlags =
    for flag in flags:
      result = VkFenceImportFlags(uint(result) or uint(flag))
func toEnums*(number: VkFenceImportFlags): seq[VkFenceImportFlagBits] =
    for value in VkFenceImportFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkFenceImportFlags): bool = cint(a) == cint(b)
type
  VkSurfaceCounterFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_SURFACE_COUNTER_VBLANK_BIT_EXT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSurfaceCounterFlagBitsEXT]): VkSurfaceCounterFlagsEXT =
    for flag in flags:
      result = VkSurfaceCounterFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkSurfaceCounterFlagsEXT): seq[VkSurfaceCounterFlagBitsEXT] =
    for value in VkSurfaceCounterFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSurfaceCounterFlagsEXT): bool = cint(a) == cint(b)
type
  VkDisplayPowerStateEXT* {.size: sizeof(cint).} = enum
    VK_DISPLAY_POWER_STATE_OFF_EXT = 0
    VK_DISPLAY_POWER_STATE_SUSPEND_EXT = 1
    VK_DISPLAY_POWER_STATE_ON_EXT = 2
  VkDeviceEventTypeEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_EVENT_TYPE_DISPLAY_HOTPLUG_EXT = 0
  VkDisplayEventTypeEXT* {.size: sizeof(cint).} = enum
    VK_DISPLAY_EVENT_TYPE_FIRST_PIXEL_OUT_EXT = 0
  VkPeerMemoryFeatureFlagBits* {.size: sizeof(cint).} = enum
    VK_PEER_MEMORY_FEATURE_COPY_SRC_BIT = 0b00000000000000000000000000000001
    VK_PEER_MEMORY_FEATURE_COPY_DST_BIT = 0b00000000000000000000000000000010
    VK_PEER_MEMORY_FEATURE_GENERIC_SRC_BIT = 0b00000000000000000000000000000100
    VK_PEER_MEMORY_FEATURE_GENERIC_DST_BIT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkPeerMemoryFeatureFlagBits]): VkPeerMemoryFeatureFlags =
    for flag in flags:
      result = VkPeerMemoryFeatureFlags(uint(result) or uint(flag))
func toEnums*(number: VkPeerMemoryFeatureFlags): seq[VkPeerMemoryFeatureFlagBits] =
    for value in VkPeerMemoryFeatureFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPeerMemoryFeatureFlags): bool = cint(a) == cint(b)
type
  VkMemoryAllocateFlagBits* {.size: sizeof(cint).} = enum
    VK_MEMORY_ALLOCATE_DEVICE_MASK_BIT = 0b00000000000000000000000000000001
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT = 0b00000000000000000000000000000010
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkMemoryAllocateFlagBits]): VkMemoryAllocateFlags =
    for flag in flags:
      result = VkMemoryAllocateFlags(uint(result) or uint(flag))
func toEnums*(number: VkMemoryAllocateFlags): seq[VkMemoryAllocateFlagBits] =
    for value in VkMemoryAllocateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkMemoryAllocateFlags): bool = cint(a) == cint(b)
type
  VkDeviceGroupPresentModeFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_BIT_KHR = 0b00000000000000000000000000000001
    VK_DEVICE_GROUP_PRESENT_MODE_REMOTE_BIT_KHR = 0b00000000000000000000000000000010
    VK_DEVICE_GROUP_PRESENT_MODE_SUM_BIT_KHR = 0b00000000000000000000000000000100
    VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_MULTI_DEVICE_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkDeviceGroupPresentModeFlagBitsKHR]): VkDeviceGroupPresentModeFlagsKHR =
    for flag in flags:
      result = VkDeviceGroupPresentModeFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkDeviceGroupPresentModeFlagsKHR): seq[VkDeviceGroupPresentModeFlagBitsKHR] =
    for value in VkDeviceGroupPresentModeFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDeviceGroupPresentModeFlagsKHR): bool = cint(a) == cint(b)
type
  VkSwapchainCreateFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_SWAPCHAIN_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT_KHR = 0b00000000000000000000000000000001
    VK_SWAPCHAIN_CREATE_PROTECTED_BIT_KHR = 0b00000000000000000000000000000010
    VK_SWAPCHAIN_CREATE_MUTABLE_FORMAT_BIT_KHR = 0b00000000000000000000000000000100
    VK_SWAPCHAIN_CREATE_DEFERRED_MEMORY_ALLOCATION_BIT_EXT = 0b00000000000000000000000000001000
    VK_SWAPCHAIN_CREATE_RESERVED_4_BIT_EXT = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkSwapchainCreateFlagBitsKHR]): VkSwapchainCreateFlagsKHR =
    for flag in flags:
      result = VkSwapchainCreateFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkSwapchainCreateFlagsKHR): seq[VkSwapchainCreateFlagBitsKHR] =
    for value in VkSwapchainCreateFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSwapchainCreateFlagsKHR): bool = cint(a) == cint(b)
type
  VkViewportCoordinateSwizzleNV* {.size: sizeof(cint).} = enum
    VK_VIEWPORT_COORDINATE_SWIZZLE_POSITIVE_X_NV = 0
    VK_VIEWPORT_COORDINATE_SWIZZLE_NEGATIVE_X_NV = 1
    VK_VIEWPORT_COORDINATE_SWIZZLE_POSITIVE_Y_NV = 2
    VK_VIEWPORT_COORDINATE_SWIZZLE_NEGATIVE_Y_NV = 3
    VK_VIEWPORT_COORDINATE_SWIZZLE_POSITIVE_Z_NV = 4
    VK_VIEWPORT_COORDINATE_SWIZZLE_NEGATIVE_Z_NV = 5
    VK_VIEWPORT_COORDINATE_SWIZZLE_POSITIVE_W_NV = 6
    VK_VIEWPORT_COORDINATE_SWIZZLE_NEGATIVE_W_NV = 7
  VkDiscardRectangleModeEXT* {.size: sizeof(cint).} = enum
    VK_DISCARD_RECTANGLE_MODE_INCLUSIVE_EXT = 0
    VK_DISCARD_RECTANGLE_MODE_EXCLUSIVE_EXT = 1
  VkSubpassDescriptionFlagBits* {.size: sizeof(cint).} = enum
    VK_SUBPASS_DESCRIPTION_PER_VIEW_ATTRIBUTES_BIT_NVX = 0b00000000000000000000000000000001
    VK_SUBPASS_DESCRIPTION_PER_VIEW_POSITION_X_ONLY_BIT_NVX = 0b00000000000000000000000000000010
    VK_SUBPASS_DESCRIPTION_FRAGMENT_REGION_BIT_QCOM = 0b00000000000000000000000000000100
    VK_SUBPASS_DESCRIPTION_SHADER_RESOLVE_BIT_QCOM = 0b00000000000000000000000000001000
    VK_SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_COLOR_ACCESS_BIT_EXT = 0b00000000000000000000000000010000
    VK_SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT = 0b00000000000000000000000000100000
    VK_SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT = 0b00000000000000000000000001000000
    VK_SUBPASS_DESCRIPTION_ENABLE_LEGACY_DITHERING_BIT_EXT = 0b00000000000000000000000010000000
func toBits*(flags: openArray[VkSubpassDescriptionFlagBits]): VkSubpassDescriptionFlags =
    for flag in flags:
      result = VkSubpassDescriptionFlags(uint(result) or uint(flag))
func toEnums*(number: VkSubpassDescriptionFlags): seq[VkSubpassDescriptionFlagBits] =
    for value in VkSubpassDescriptionFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSubpassDescriptionFlags): bool = cint(a) == cint(b)
type
  VkPointClippingBehavior* {.size: sizeof(cint).} = enum
    VK_POINT_CLIPPING_BEHAVIOR_ALL_CLIP_PLANES = 0
    VK_POINT_CLIPPING_BEHAVIOR_USER_CLIP_PLANES_ONLY = 1
  VkSamplerReductionMode* {.size: sizeof(cint).} = enum
    VK_SAMPLER_REDUCTION_MODE_WEIGHTED_AVERAGE = 0
    VK_SAMPLER_REDUCTION_MODE_MIN = 1
    VK_SAMPLER_REDUCTION_MODE_MAX = 2
  VkTessellationDomainOrigin* {.size: sizeof(cint).} = enum
    VK_TESSELLATION_DOMAIN_ORIGIN_UPPER_LEFT = 0
    VK_TESSELLATION_DOMAIN_ORIGIN_LOWER_LEFT = 1
  VkSamplerYcbcrModelConversion* {.size: sizeof(cint).} = enum
    VK_SAMPLER_YCBCR_MODEL_CONVERSION_RGB_IDENTITY = 0
    VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_IDENTITY = 1
    VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_709 = 2
    VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_601 = 3
    VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_2020 = 4
  VkSamplerYcbcrRange* {.size: sizeof(cint).} = enum
    VK_SAMPLER_YCBCR_RANGE_ITU_FULL = 0
    VK_SAMPLER_YCBCR_RANGE_ITU_NARROW = 1
  VkChromaLocation* {.size: sizeof(cint).} = enum
    VK_CHROMA_LOCATION_COSITED_EVEN = 0
    VK_CHROMA_LOCATION_MIDPOINT = 1
  VkBlendOverlapEXT* {.size: sizeof(cint).} = enum
    VK_BLEND_OVERLAP_UNCORRELATED_EXT = 0
    VK_BLEND_OVERLAP_DISJOINT_EXT = 1
    VK_BLEND_OVERLAP_CONJOINT_EXT = 2
  VkCoverageModulationModeNV* {.size: sizeof(cint).} = enum
    VK_COVERAGE_MODULATION_MODE_NONE_NV = 0
    VK_COVERAGE_MODULATION_MODE_RGB_NV = 1
    VK_COVERAGE_MODULATION_MODE_ALPHA_NV = 2
    VK_COVERAGE_MODULATION_MODE_RGBA_NV = 3
  VkCoverageReductionModeNV* {.size: sizeof(cint).} = enum
    VK_COVERAGE_REDUCTION_MODE_MERGE_NV = 0
    VK_COVERAGE_REDUCTION_MODE_TRUNCATE_NV = 1
  VkValidationCacheHeaderVersionEXT* {.size: sizeof(cint).} = enum
    VK_VALIDATION_CACHE_HEADER_VERSION_ONE_EXT = 1
  VkShaderInfoTypeAMD* {.size: sizeof(cint).} = enum
    VK_SHADER_INFO_TYPE_STATISTICS_AMD = 0
    VK_SHADER_INFO_TYPE_BINARY_AMD = 1
    VK_SHADER_INFO_TYPE_DISASSEMBLY_AMD = 2
  VkQueueGlobalPriorityKHR* {.size: sizeof(cint).} = enum
    VK_QUEUE_GLOBAL_PRIORITY_LOW_KHR = 128
    VK_QUEUE_GLOBAL_PRIORITY_MEDIUM_KHR = 256
    VK_QUEUE_GLOBAL_PRIORITY_HIGH_KHR = 512
    VK_QUEUE_GLOBAL_PRIORITY_REALTIME_KHR = 1024
  VkDebugUtilsMessageSeverityFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = 0b00000000000000000000000000000001
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT = 0b00000000000000000000000000010000
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = 0b00000000000000000000000100000000
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT = 0b00000000000000000001000000000000
func toBits*(flags: openArray[VkDebugUtilsMessageSeverityFlagBitsEXT]): VkDebugUtilsMessageSeverityFlagsEXT =
    for flag in flags:
      result = VkDebugUtilsMessageSeverityFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkDebugUtilsMessageSeverityFlagsEXT): seq[VkDebugUtilsMessageSeverityFlagBitsEXT] =
    for value in VkDebugUtilsMessageSeverityFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDebugUtilsMessageSeverityFlagsEXT): bool = cint(a) == cint(b)
type
  VkDebugUtilsMessageTypeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT = 0b00000000000000000000000000000001
    VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT = 0b00000000000000000000000000000010
    VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = 0b00000000000000000000000000000100
    VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkDebugUtilsMessageTypeFlagBitsEXT]): VkDebugUtilsMessageTypeFlagsEXT =
    for flag in flags:
      result = VkDebugUtilsMessageTypeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkDebugUtilsMessageTypeFlagsEXT): seq[VkDebugUtilsMessageTypeFlagBitsEXT] =
    for value in VkDebugUtilsMessageTypeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDebugUtilsMessageTypeFlagsEXT): bool = cint(a) == cint(b)
type
  VkConservativeRasterizationModeEXT* {.size: sizeof(cint).} = enum
    VK_CONSERVATIVE_RASTERIZATION_MODE_DISABLED_EXT = 0
    VK_CONSERVATIVE_RASTERIZATION_MODE_OVERESTIMATE_EXT = 1
    VK_CONSERVATIVE_RASTERIZATION_MODE_UNDERESTIMATE_EXT = 2
  VkDescriptorBindingFlagBits* {.size: sizeof(cint).} = enum
    VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT = 0b00000000000000000000000000000001
    VK_DESCRIPTOR_BINDING_UPDATE_UNUSED_WHILE_PENDING_BIT = 0b00000000000000000000000000000010
    VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT = 0b00000000000000000000000000000100
    VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT = 0b00000000000000000000000000001000
    VK_DESCRIPTOR_BINDING_RESERVED_4_BIT_QCOM = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkDescriptorBindingFlagBits]): VkDescriptorBindingFlags =
    for flag in flags:
      result = VkDescriptorBindingFlags(uint(result) or uint(flag))
func toEnums*(number: VkDescriptorBindingFlags): seq[VkDescriptorBindingFlagBits] =
    for value in VkDescriptorBindingFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDescriptorBindingFlags): bool = cint(a) == cint(b)
type
  VkVendorId* {.size: sizeof(cint).} = enum
    VK_VENDOR_ID_VIV = 65537
    VK_VENDOR_ID_VSI = 65538
    VK_VENDOR_ID_KAZAN = 65539
    VK_VENDOR_ID_CODEPLAY = 65540
    VK_VENDOR_ID_MESA = 65541
    VK_VENDOR_ID_POCL = 65542
  VkDriverId* {.size: sizeof(cint).} = enum
    VK_DRIVER_ID_AMD_PROPRIETARY = 1
    VK_DRIVER_ID_AMD_OPEN_SOURCE = 2
    VK_DRIVER_ID_MESA_RADV = 3
    VK_DRIVER_ID_NVIDIA_PROPRIETARY = 4
    VK_DRIVER_ID_INTEL_PROPRIETARY_WINDOWS = 5
    VK_DRIVER_ID_INTEL_OPEN_SOURCE_MESA = 6
    VK_DRIVER_ID_IMAGINATION_PROPRIETARY = 7
    VK_DRIVER_ID_QUALCOMM_PROPRIETARY = 8
    VK_DRIVER_ID_ARM_PROPRIETARY = 9
    VK_DRIVER_ID_GOOGLE_SWIFTSHADER = 10
    VK_DRIVER_ID_GGP_PROPRIETARY = 11
    VK_DRIVER_ID_BROADCOM_PROPRIETARY = 12
    VK_DRIVER_ID_MESA_LLVMPIPE = 13
    VK_DRIVER_ID_MOLTENVK = 14
    VK_DRIVER_ID_COREAVI_PROPRIETARY = 15
    VK_DRIVER_ID_JUICE_PROPRIETARY = 16
    VK_DRIVER_ID_VERISILICON_PROPRIETARY = 17
    VK_DRIVER_ID_MESA_TURNIP = 18
    VK_DRIVER_ID_MESA_V3DV = 19
    VK_DRIVER_ID_MESA_PANVK = 20
    VK_DRIVER_ID_SAMSUNG_PROPRIETARY = 21
    VK_DRIVER_ID_MESA_VENUS = 22
    VK_DRIVER_ID_MESA_DOZEN = 23
    VK_DRIVER_ID_MESA_NVK = 24
    VK_DRIVER_ID_IMAGINATION_OPEN_SOURCE_MESA = 25
  VkConditionalRenderingFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_CONDITIONAL_RENDERING_INVERTED_BIT_EXT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkConditionalRenderingFlagBitsEXT]): VkConditionalRenderingFlagsEXT =
    for flag in flags:
      result = VkConditionalRenderingFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkConditionalRenderingFlagsEXT): seq[VkConditionalRenderingFlagBitsEXT] =
    for value in VkConditionalRenderingFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkConditionalRenderingFlagsEXT): bool = cint(a) == cint(b)
type
  VkResolveModeFlagBits* {.size: sizeof(cint).} = enum
    VK_RESOLVE_MODE_SAMPLE_ZERO_BIT = 0b00000000000000000000000000000001
    VK_RESOLVE_MODE_AVERAGE_BIT = 0b00000000000000000000000000000010
    VK_RESOLVE_MODE_MIN_BIT = 0b00000000000000000000000000000100
    VK_RESOLVE_MODE_MAX_BIT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkResolveModeFlagBits]): VkResolveModeFlags =
    for flag in flags:
      result = VkResolveModeFlags(uint(result) or uint(flag))
func toEnums*(number: VkResolveModeFlags): seq[VkResolveModeFlagBits] =
    for value in VkResolveModeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkResolveModeFlags): bool = cint(a) == cint(b)
const
  VK_RESOLVE_MODE_NONE* = 0
type
  VkShadingRatePaletteEntryNV* {.size: sizeof(cint).} = enum
    VK_SHADING_RATE_PALETTE_ENTRY_NO_INVOCATIONS_NV = 0
    VK_SHADING_RATE_PALETTE_ENTRY_16_INVOCATIONS_PER_PIXEL_NV = 1
    VK_SHADING_RATE_PALETTE_ENTRY_8_INVOCATIONS_PER_PIXEL_NV = 2
    VK_SHADING_RATE_PALETTE_ENTRY_4_INVOCATIONS_PER_PIXEL_NV = 3
    VK_SHADING_RATE_PALETTE_ENTRY_2_INVOCATIONS_PER_PIXEL_NV = 4
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_PIXEL_NV = 5
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X1_PIXELS_NV = 6
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_1X2_PIXELS_NV = 7
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X2_PIXELS_NV = 8
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_4X2_PIXELS_NV = 9
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X4_PIXELS_NV = 10
    VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_4X4_PIXELS_NV = 11
  VkCoarseSampleOrderTypeNV* {.size: sizeof(cint).} = enum
    VK_COARSE_SAMPLE_ORDER_TYPE_DEFAULT_NV = 0
    VK_COARSE_SAMPLE_ORDER_TYPE_CUSTOM_NV = 1
    VK_COARSE_SAMPLE_ORDER_TYPE_PIXEL_MAJOR_NV = 2
    VK_COARSE_SAMPLE_ORDER_TYPE_SAMPLE_MAJOR_NV = 3
  VkGeometryInstanceFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR = 0b00000000000000000000000000000001
    VK_GEOMETRY_INSTANCE_TRIANGLE_FLIP_FACING_BIT_KHR = 0b00000000000000000000000000000010
    VK_GEOMETRY_INSTANCE_FORCE_OPAQUE_BIT_KHR = 0b00000000000000000000000000000100
    VK_GEOMETRY_INSTANCE_FORCE_NO_OPAQUE_BIT_KHR = 0b00000000000000000000000000001000
    VK_GEOMETRY_INSTANCE_FORCE_OPACITY_MICROMAP_2_STATE_EXT = 0b00000000000000000000000000010000
    VK_GEOMETRY_INSTANCE_DISABLE_OPACITY_MICROMAPS_EXT = 0b00000000000000000000000000100000
func toBits*(flags: openArray[VkGeometryInstanceFlagBitsKHR]): VkGeometryInstanceFlagsKHR =
    for flag in flags:
      result = VkGeometryInstanceFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkGeometryInstanceFlagsKHR): seq[VkGeometryInstanceFlagBitsKHR] =
    for value in VkGeometryInstanceFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkGeometryInstanceFlagsKHR): bool = cint(a) == cint(b)
type
  VkGeometryFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_GEOMETRY_OPAQUE_BIT_KHR = 0b00000000000000000000000000000001
    VK_GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_KHR = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkGeometryFlagBitsKHR]): VkGeometryFlagsKHR =
    for flag in flags:
      result = VkGeometryFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkGeometryFlagsKHR): seq[VkGeometryFlagBitsKHR] =
    for value in VkGeometryFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkGeometryFlagsKHR): bool = cint(a) == cint(b)
type
  VkBuildAccelerationStructureFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR = 0b00000000000000000000000000000001
    VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_KHR = 0b00000000000000000000000000000010
    VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR = 0b00000000000000000000000000000100
    VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR = 0b00000000000000000000000000001000
    VK_BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_KHR = 0b00000000000000000000000000010000
    VK_BUILD_ACCELERATION_STRUCTURE_MOTION_BIT_NV = 0b00000000000000000000000000100000
    VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_UPDATE_EXT = 0b00000000000000000000000001000000
    VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_DISABLE_OPACITY_MICROMAPS_EXT = 0b00000000000000000000000010000000
    VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_DATA_UPDATE_EXT = 0b00000000000000000000000100000000
    VK_BUILD_ACCELERATION_STRUCTURE_RESERVED_BIT_9_NV = 0b00000000000000000000001000000000
    VK_BUILD_ACCELERATION_STRUCTURE_RESERVED_BIT_10_NV = 0b00000000000000000000010000000000
func toBits*(flags: openArray[VkBuildAccelerationStructureFlagBitsKHR]): VkBuildAccelerationStructureFlagsKHR =
    for flag in flags:
      result = VkBuildAccelerationStructureFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkBuildAccelerationStructureFlagsKHR): seq[VkBuildAccelerationStructureFlagBitsKHR] =
    for value in VkBuildAccelerationStructureFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkBuildAccelerationStructureFlagsKHR): bool = cint(a) == cint(b)
type
  VkAccelerationStructureCreateFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR = 0b00000000000000000000000000000001
    VK_ACCELERATION_STRUCTURE_CREATE_MOTION_BIT_NV = 0b00000000000000000000000000000100
    VK_ACCELERATION_STRUCTURE_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkAccelerationStructureCreateFlagBitsKHR]): VkAccelerationStructureCreateFlagsKHR =
    for flag in flags:
      result = VkAccelerationStructureCreateFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkAccelerationStructureCreateFlagsKHR): seq[VkAccelerationStructureCreateFlagBitsKHR] =
    for value in VkAccelerationStructureCreateFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkAccelerationStructureCreateFlagsKHR): bool = cint(a) == cint(b)
type
  VkCopyAccelerationStructureModeKHR* {.size: sizeof(cint).} = enum
    VK_COPY_ACCELERATION_STRUCTURE_MODE_CLONE_KHR = 0
    VK_COPY_ACCELERATION_STRUCTURE_MODE_COMPACT_KHR = 1
    VK_COPY_ACCELERATION_STRUCTURE_MODE_SERIALIZE_KHR = 2
    VK_COPY_ACCELERATION_STRUCTURE_MODE_DESERIALIZE_KHR = 3
  VkBuildAccelerationStructureModeKHR* {.size: sizeof(cint).} = enum
    VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR = 0
    VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR = 1
  VkAccelerationStructureTypeKHR* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR = 0
    VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR = 1
    VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR = 2
  VkGeometryTypeKHR* {.size: sizeof(cint).} = enum
    VK_GEOMETRY_TYPE_TRIANGLES_KHR = 0
    VK_GEOMETRY_TYPE_AABBS_KHR = 1
    VK_GEOMETRY_TYPE_INSTANCES_KHR = 2
  VkAccelerationStructureMemoryRequirementsTypeNV* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_MEMORY_REQUIREMENTS_TYPE_OBJECT_NV = 0
    VK_ACCELERATION_STRUCTURE_MEMORY_REQUIREMENTS_TYPE_BUILD_SCRATCH_NV = 1
    VK_ACCELERATION_STRUCTURE_MEMORY_REQUIREMENTS_TYPE_UPDATE_SCRATCH_NV = 2
  VkAccelerationStructureBuildTypeKHR* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_BUILD_TYPE_HOST_KHR = 0
    VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR = 1
    VK_ACCELERATION_STRUCTURE_BUILD_TYPE_HOST_OR_DEVICE_KHR = 2
  VkRayTracingShaderGroupTypeKHR* {.size: sizeof(cint).} = enum
    VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR = 0
    VK_RAY_TRACING_SHADER_GROUP_TYPE_TRIANGLES_HIT_GROUP_KHR = 1
    VK_RAY_TRACING_SHADER_GROUP_TYPE_PROCEDURAL_HIT_GROUP_KHR = 2
  VkAccelerationStructureCompatibilityKHR* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_COMPATIBILITY_COMPATIBLE_KHR = 0
    VK_ACCELERATION_STRUCTURE_COMPATIBILITY_INCOMPATIBLE_KHR = 1
  VkShaderGroupShaderKHR* {.size: sizeof(cint).} = enum
    VK_SHADER_GROUP_SHADER_GENERAL_KHR = 0
    VK_SHADER_GROUP_SHADER_CLOSEST_HIT_KHR = 1
    VK_SHADER_GROUP_SHADER_ANY_HIT_KHR = 2
    VK_SHADER_GROUP_SHADER_INTERSECTION_KHR = 3
  VkMemoryOverallocationBehaviorAMD* {.size: sizeof(cint).} = enum
    VK_MEMORY_OVERALLOCATION_BEHAVIOR_DEFAULT_AMD = 0
    VK_MEMORY_OVERALLOCATION_BEHAVIOR_ALLOWED_AMD = 1
    VK_MEMORY_OVERALLOCATION_BEHAVIOR_DISALLOWED_AMD = 2
  VkFramebufferCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_FRAMEBUFFER_CREATE_IMAGELESS_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkFramebufferCreateFlagBits]): VkFramebufferCreateFlags =
    for flag in flags:
      result = VkFramebufferCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkFramebufferCreateFlags): seq[VkFramebufferCreateFlagBits] =
    for value in VkFramebufferCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkFramebufferCreateFlags): bool = cint(a) == cint(b)
type
  VkScopeNV* {.size: sizeof(cint).} = enum
    VK_SCOPE_DEVICE_NV = 1
    VK_SCOPE_WORKGROUP_NV = 2
    VK_SCOPE_SUBGROUP_NV = 3
    VK_SCOPE_QUEUE_FAMILY_NV = 5
  VkComponentTypeNV* {.size: sizeof(cint).} = enum
    VK_COMPONENT_TYPE_FLOAT16_NV = 0
    VK_COMPONENT_TYPE_FLOAT32_NV = 1
    VK_COMPONENT_TYPE_FLOAT64_NV = 2
    VK_COMPONENT_TYPE_SINT8_NV = 3
    VK_COMPONENT_TYPE_SINT16_NV = 4
    VK_COMPONENT_TYPE_SINT32_NV = 5
    VK_COMPONENT_TYPE_SINT64_NV = 6
    VK_COMPONENT_TYPE_UINT8_NV = 7
    VK_COMPONENT_TYPE_UINT16_NV = 8
    VK_COMPONENT_TYPE_UINT32_NV = 9
    VK_COMPONENT_TYPE_UINT64_NV = 10
  VkDeviceDiagnosticsConfigFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_DEVICE_DIAGNOSTICS_CONFIG_ENABLE_SHADER_DEBUG_INFO_BIT_NV = 0b00000000000000000000000000000001
    VK_DEVICE_DIAGNOSTICS_CONFIG_ENABLE_RESOURCE_TRACKING_BIT_NV = 0b00000000000000000000000000000010
    VK_DEVICE_DIAGNOSTICS_CONFIG_ENABLE_AUTOMATIC_CHECKPOINTS_BIT_NV = 0b00000000000000000000000000000100
    VK_DEVICE_DIAGNOSTICS_CONFIG_ENABLE_SHADER_ERROR_REPORTING_BIT_NV = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkDeviceDiagnosticsConfigFlagBitsNV]): VkDeviceDiagnosticsConfigFlagsNV =
    for flag in flags:
      result = VkDeviceDiagnosticsConfigFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkDeviceDiagnosticsConfigFlagsNV): seq[VkDeviceDiagnosticsConfigFlagBitsNV] =
    for value in VkDeviceDiagnosticsConfigFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDeviceDiagnosticsConfigFlagsNV): bool = cint(a) == cint(b)
type
  VkPipelineCreationFeedbackFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_CREATION_FEEDBACK_VALID_BIT = 0b00000000000000000000000000000001
    VK_PIPELINE_CREATION_FEEDBACK_APPLICATION_PIPELINE_CACHE_HIT_BIT = 0b00000000000000000000000000000010
    VK_PIPELINE_CREATION_FEEDBACK_BASE_PIPELINE_ACCELERATION_BIT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkPipelineCreationFeedbackFlagBits]): VkPipelineCreationFeedbackFlags =
    for flag in flags:
      result = VkPipelineCreationFeedbackFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineCreationFeedbackFlags): seq[VkPipelineCreationFeedbackFlagBits] =
    for value in VkPipelineCreationFeedbackFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineCreationFeedbackFlags): bool = cint(a) == cint(b)
type
  VkFullScreenExclusiveEXT* {.size: sizeof(cint).} = enum
    VK_FULL_SCREEN_EXCLUSIVE_DEFAULT_EXT = 0
    VK_FULL_SCREEN_EXCLUSIVE_ALLOWED_EXT = 1
    VK_FULL_SCREEN_EXCLUSIVE_DISALLOWED_EXT = 2
    VK_FULL_SCREEN_EXCLUSIVE_APPLICATION_CONTROLLED_EXT = 3
  VkPerformanceCounterScopeKHR* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_COUNTER_SCOPE_COMMAND_BUFFER_KHR = 0
    VK_PERFORMANCE_COUNTER_SCOPE_RENDER_PASS_KHR = 1
    VK_PERFORMANCE_COUNTER_SCOPE_COMMAND_KHR = 2
  VkMemoryDecompressionMethodFlagBitsNV* {.size: 8.} = enum
    VK_MEMORY_DECOMPRESSION_METHOD_GDEFLATE_1_0_BIT_NV = 0b0000000000000000000000000000000000000000000000000000000000000001
func toBits*(flags: openArray[VkMemoryDecompressionMethodFlagBitsNV]): VkMemoryDecompressionMethodFlagsNV =
    for flag in flags:
      result = VkMemoryDecompressionMethodFlagsNV(uint64(result) or uint64(flag))
func toEnums*(number: VkMemoryDecompressionMethodFlagsNV): seq[VkMemoryDecompressionMethodFlagBitsNV] =
    for value in VkMemoryDecompressionMethodFlagBitsNV.items:
      if (cast[uint64](value) and uint64(number)) > 0:
        result.add value
proc `==`*(a, b: VkMemoryDecompressionMethodFlagsNV): bool = uint64(a) == uint64(b)
type
  VkPerformanceCounterUnitKHR* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_COUNTER_UNIT_GENERIC_KHR = 0
    VK_PERFORMANCE_COUNTER_UNIT_PERCENTAGE_KHR = 1
    VK_PERFORMANCE_COUNTER_UNIT_NANOSECONDS_KHR = 2
    VK_PERFORMANCE_COUNTER_UNIT_BYTES_KHR = 3
    VK_PERFORMANCE_COUNTER_UNIT_BYTES_PER_SECOND_KHR = 4
    VK_PERFORMANCE_COUNTER_UNIT_KELVIN_KHR = 5
    VK_PERFORMANCE_COUNTER_UNIT_WATTS_KHR = 6
    VK_PERFORMANCE_COUNTER_UNIT_VOLTS_KHR = 7
    VK_PERFORMANCE_COUNTER_UNIT_AMPS_KHR = 8
    VK_PERFORMANCE_COUNTER_UNIT_HERTZ_KHR = 9
    VK_PERFORMANCE_COUNTER_UNIT_CYCLES_KHR = 10
  VkPerformanceCounterStorageKHR* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_COUNTER_STORAGE_INT32_KHR = 0
    VK_PERFORMANCE_COUNTER_STORAGE_INT64_KHR = 1
    VK_PERFORMANCE_COUNTER_STORAGE_UINT32_KHR = 2
    VK_PERFORMANCE_COUNTER_STORAGE_UINT64_KHR = 3
    VK_PERFORMANCE_COUNTER_STORAGE_FLOAT32_KHR = 4
    VK_PERFORMANCE_COUNTER_STORAGE_FLOAT64_KHR = 5
  VkPerformanceCounterDescriptionFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_COUNTER_DESCRIPTION_PERFORMANCE_IMPACTING_BIT_KHR = 0b00000000000000000000000000000001
    VK_PERFORMANCE_COUNTER_DESCRIPTION_CONCURRENTLY_IMPACTED_BIT_KHR = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkPerformanceCounterDescriptionFlagBitsKHR]): VkPerformanceCounterDescriptionFlagsKHR =
    for flag in flags:
      result = VkPerformanceCounterDescriptionFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkPerformanceCounterDescriptionFlagsKHR): seq[VkPerformanceCounterDescriptionFlagBitsKHR] =
    for value in VkPerformanceCounterDescriptionFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPerformanceCounterDescriptionFlagsKHR): bool = cint(a) == cint(b)
type
  VkPerformanceConfigurationTypeINTEL* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_CONFIGURATION_TYPE_COMMAND_QUEUE_METRICS_DISCOVERY_ACTIVATED_INTEL = 0
  VkQueryPoolSamplingModeINTEL* {.size: sizeof(cint).} = enum
    VK_QUERY_POOL_SAMPLING_MODE_MANUAL_INTEL = 0
  VkPerformanceOverrideTypeINTEL* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_OVERRIDE_TYPE_NULL_HARDWARE_INTEL = 0
    VK_PERFORMANCE_OVERRIDE_TYPE_FLUSH_GPU_CACHES_INTEL = 1
  VkPerformanceParameterTypeINTEL* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_PARAMETER_TYPE_HW_COUNTERS_SUPPORTED_INTEL = 0
    VK_PERFORMANCE_PARAMETER_TYPE_STREAM_MARKER_VALID_BITS_INTEL = 1
  VkPerformanceValueTypeINTEL* {.size: sizeof(cint).} = enum
    VK_PERFORMANCE_VALUE_TYPE_UINT32_INTEL = 0
    VK_PERFORMANCE_VALUE_TYPE_UINT64_INTEL = 1
    VK_PERFORMANCE_VALUE_TYPE_FLOAT_INTEL = 2
    VK_PERFORMANCE_VALUE_TYPE_BOOL_INTEL = 3
    VK_PERFORMANCE_VALUE_TYPE_STRING_INTEL = 4
  VkShaderFloatControlsIndependence* {.size: sizeof(cint).} = enum
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_32_BIT_ONLY = 0
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_ALL = 1
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_NONE = 2
  VkPipelineExecutableStatisticFormatKHR* {.size: sizeof(cint).} = enum
    VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_BOOL32_KHR = 0
    VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_INT64_KHR = 1
    VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_UINT64_KHR = 2
    VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_FLOAT64_KHR = 3
  VkLineRasterizationModeEXT* {.size: sizeof(cint).} = enum
    VK_LINE_RASTERIZATION_MODE_DEFAULT_EXT = 0
    VK_LINE_RASTERIZATION_MODE_RECTANGULAR_EXT = 1
    VK_LINE_RASTERIZATION_MODE_BRESENHAM_EXT = 2
    VK_LINE_RASTERIZATION_MODE_RECTANGULAR_SMOOTH_EXT = 3
  VkFaultLevel* {.size: sizeof(cint).} = enum
    VK_FAULT_LEVEL_UNASSIGNED = 0
    VK_FAULT_LEVEL_CRITICAL = 1
    VK_FAULT_LEVEL_RECOVERABLE = 2
    VK_FAULT_LEVEL_WARNING = 3
  VkFaultType* {.size: sizeof(cint).} = enum
    VK_FAULT_TYPE_INVALID = 0
    VK_FAULT_TYPE_UNASSIGNED = 1
    VK_FAULT_TYPE_IMPLEMENTATION = 2
    VK_FAULT_TYPE_SYSTEM = 3
    VK_FAULT_TYPE_PHYSICAL_DEVICE = 4
    VK_FAULT_TYPE_COMMAND_BUFFER_FULL = 5
    VK_FAULT_TYPE_INVALID_API_USAGE = 6
  VkFaultQueryBehavior* {.size: sizeof(cint).} = enum
    VK_FAULT_QUERY_BEHAVIOR_GET_AND_CLEAR_ALL_FAULTS = 0
  VkToolPurposeFlagBits* {.size: sizeof(cint).} = enum
    VK_TOOL_PURPOSE_VALIDATION_BIT = 0b00000000000000000000000000000001
    VK_TOOL_PURPOSE_PROFILING_BIT = 0b00000000000000000000000000000010
    VK_TOOL_PURPOSE_TRACING_BIT = 0b00000000000000000000000000000100
    VK_TOOL_PURPOSE_ADDITIONAL_FEATURES_BIT = 0b00000000000000000000000000001000
    VK_TOOL_PURPOSE_MODIFYING_FEATURES_BIT = 0b00000000000000000000000000010000
    VK_TOOL_PURPOSE_DEBUG_REPORTING_BIT_EXT = 0b00000000000000000000000000100000
    VK_TOOL_PURPOSE_DEBUG_MARKERS_BIT_EXT = 0b00000000000000000000000001000000
func toBits*(flags: openArray[VkToolPurposeFlagBits]): VkToolPurposeFlags =
    for flag in flags:
      result = VkToolPurposeFlags(uint(result) or uint(flag))
func toEnums*(number: VkToolPurposeFlags): seq[VkToolPurposeFlagBits] =
    for value in VkToolPurposeFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkToolPurposeFlags): bool = cint(a) == cint(b)
type
  VkPipelineMatchControl* {.size: sizeof(cint).} = enum
    VK_PIPELINE_MATCH_CONTROL_APPLICATION_UUID_EXACT_MATCH = 0
  VkFragmentShadingRateCombinerOpKHR* {.size: sizeof(cint).} = enum
    VK_FRAGMENT_SHADING_RATE_COMBINER_OP_KEEP_KHR = 0
    VK_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE_KHR = 1
    VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MIN_KHR = 2
    VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MAX_KHR = 3
    VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MUL_KHR = 4
  VkFragmentShadingRateNV* {.size: sizeof(cint).} = enum
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_PIXEL_NV = 0
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_1X2_PIXELS_NV = 1
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X1_PIXELS_NV = 4
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X2_PIXELS_NV = 5
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X4_PIXELS_NV = 6
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_4X2_PIXELS_NV = 9
    VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_4X4_PIXELS_NV = 10
    VK_FRAGMENT_SHADING_RATE_2_INVOCATIONS_PER_PIXEL_NV = 11
    VK_FRAGMENT_SHADING_RATE_4_INVOCATIONS_PER_PIXEL_NV = 12
    VK_FRAGMENT_SHADING_RATE_8_INVOCATIONS_PER_PIXEL_NV = 13
    VK_FRAGMENT_SHADING_RATE_16_INVOCATIONS_PER_PIXEL_NV = 14
    VK_FRAGMENT_SHADING_RATE_NO_INVOCATIONS_NV = 15
  VkFragmentShadingRateTypeNV* {.size: sizeof(cint).} = enum
    VK_FRAGMENT_SHADING_RATE_TYPE_FRAGMENT_SIZE_NV = 0
    VK_FRAGMENT_SHADING_RATE_TYPE_ENUMS_NV = 1
  VkSubpassMergeStatusEXT* {.size: sizeof(cint).} = enum
    VK_SUBPASS_MERGE_STATUS_MERGED_EXT = 0
    VK_SUBPASS_MERGE_STATUS_DISALLOWED_EXT = 1
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_SIDE_EFFECTS_EXT = 2
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_SAMPLES_MISMATCH_EXT = 3
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_VIEWS_MISMATCH_EXT = 4
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_ALIASING_EXT = 5
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_DEPENDENCIES_EXT = 6
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_INCOMPATIBLE_INPUT_ATTACHMENT_EXT = 7
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_TOO_MANY_ATTACHMENTS_EXT = 8
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_INSUFFICIENT_STORAGE_EXT = 9
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_DEPTH_STENCIL_COUNT_EXT = 10
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_RESOLVE_ATTACHMENT_REUSE_EXT = 11
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_SINGLE_SUBPASS_EXT = 12
    VK_SUBPASS_MERGE_STATUS_NOT_MERGED_UNSPECIFIED_EXT = 13
  VkAccessFlagBits2* {.size: 8.} = enum
    VK_ACCESS_2_INDIRECT_COMMAND_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000000001
    VK_ACCESS_2_INDEX_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000000010
    VK_ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000000100
    VK_ACCESS_2_UNIFORM_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000001000
    VK_ACCESS_2_INPUT_ATTACHMENT_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000010000
    VK_ACCESS_2_SHADER_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000000100000
    VK_ACCESS_2_SHADER_WRITE_BIT = 0b0000000000000000000000000000000000000000000000000000000001000000
    VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT = 0b0000000000000000000000000000000000000000000000000000000010000000
    VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT = 0b0000000000000000000000000000000000000000000000000000000100000000
    VK_ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT = 0b0000000000000000000000000000000000000000000000000000001000000000
    VK_ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT = 0b0000000000000000000000000000000000000000000000000000010000000000
    VK_ACCESS_2_TRANSFER_READ_BIT = 0b0000000000000000000000000000000000000000000000000000100000000000
    VK_ACCESS_2_TRANSFER_WRITE_BIT = 0b0000000000000000000000000000000000000000000000000001000000000000
    VK_ACCESS_2_HOST_READ_BIT = 0b0000000000000000000000000000000000000000000000000010000000000000
    VK_ACCESS_2_HOST_WRITE_BIT = 0b0000000000000000000000000000000000000000000000000100000000000000
    VK_ACCESS_2_MEMORY_READ_BIT = 0b0000000000000000000000000000000000000000000000001000000000000000
    VK_ACCESS_2_MEMORY_WRITE_BIT = 0b0000000000000000000000000000000000000000000000010000000000000000
    VK_ACCESS_2_COMMAND_PREPROCESS_READ_BIT_NV = 0b0000000000000000000000000000000000000000000000100000000000000000
    VK_ACCESS_2_COMMAND_PREPROCESS_WRITE_BIT_NV = 0b0000000000000000000000000000000000000000000001000000000000000000
    VK_ACCESS_2_COLOR_ATTACHMENT_READ_NONCOHERENT_BIT_EXT = 0b0000000000000000000000000000000000000000000010000000000000000000
    VK_ACCESS_2_CONDITIONAL_RENDERING_READ_BIT_EXT = 0b0000000000000000000000000000000000000000000100000000000000000000
    VK_ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR = 0b0000000000000000000000000000000000000000001000000000000000000000
    VK_ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_KHR = 0b0000000000000000000000000000000000000000010000000000000000000000
    VK_ACCESS_2_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR = 0b0000000000000000000000000000000000000000100000000000000000000000
    VK_ACCESS_2_FRAGMENT_DENSITY_MAP_READ_BIT_EXT = 0b0000000000000000000000000000000000000001000000000000000000000000
    VK_ACCESS_2_TRANSFORM_FEEDBACK_WRITE_BIT_EXT = 0b0000000000000000000000000000000000000010000000000000000000000000
    VK_ACCESS_2_TRANSFORM_FEEDBACK_COUNTER_READ_BIT_EXT = 0b0000000000000000000000000000000000000100000000000000000000000000
    VK_ACCESS_2_TRANSFORM_FEEDBACK_COUNTER_WRITE_BIT_EXT = 0b0000000000000000000000000000000000001000000000000000000000000000
    VK_ACCESS_2_SHADER_SAMPLED_READ_BIT = 0b0000000000000000000000000000000100000000000000000000000000000000
    VK_ACCESS_2_SHADER_STORAGE_READ_BIT = 0b0000000000000000000000000000001000000000000000000000000000000000
    VK_ACCESS_2_SHADER_STORAGE_WRITE_BIT = 0b0000000000000000000000000000010000000000000000000000000000000000
    VK_ACCESS_2_VIDEO_DECODE_READ_BIT_KHR = 0b0000000000000000000000000000100000000000000000000000000000000000
    VK_ACCESS_2_VIDEO_DECODE_WRITE_BIT_KHR = 0b0000000000000000000000000001000000000000000000000000000000000000
    VK_ACCESS_2_VIDEO_ENCODE_READ_BIT_KHR = 0b0000000000000000000000000010000000000000000000000000000000000000
    VK_ACCESS_2_VIDEO_ENCODE_WRITE_BIT_KHR = 0b0000000000000000000000000100000000000000000000000000000000000000
    VK_ACCESS_2_INVOCATION_MASK_READ_BIT_HUAWEI = 0b0000000000000000000000001000000000000000000000000000000000000000
    VK_ACCESS_2_SHADER_BINDING_TABLE_READ_BIT_KHR = 0b0000000000000000000000010000000000000000000000000000000000000000
    VK_ACCESS_2_DESCRIPTOR_BUFFER_READ_BIT_EXT = 0b0000000000000000000000100000000000000000000000000000000000000000
    VK_ACCESS_2_OPTICAL_FLOW_READ_BIT_NV = 0b0000000000000000000001000000000000000000000000000000000000000000
    VK_ACCESS_2_OPTICAL_FLOW_WRITE_BIT_NV = 0b0000000000000000000010000000000000000000000000000000000000000000
    VK_ACCESS_2_MICROMAP_READ_BIT_EXT = 0b0000000000000000000100000000000000000000000000000000000000000000
    VK_ACCESS_2_MICROMAP_WRITE_BIT_EXT = 0b0000000000000000001000000000000000000000000000000000000000000000
    VK_ACCESS_2_RESERVED_46_BIT_EXT = 0b0000000000000000010000000000000000000000000000000000000000000000
func toBits*(flags: openArray[VkAccessFlagBits2]): VkAccessFlags2 =
    for flag in flags:
      result = VkAccessFlags2(uint64(result) or uint64(flag))
func toEnums*(number: VkAccessFlags2): seq[VkAccessFlagBits2] =
    for value in VkAccessFlagBits2.items:
      if (cast[uint64](value) and uint64(number)) > 0:
        result.add value
proc `==`*(a, b: VkAccessFlags2): bool = uint64(a) == uint64(b)
const
  VK_ACCESS_2_NONE* = 0
type
  VkPipelineStageFlagBits2* {.size: 8.} = enum
    VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT = 0b0000000000000000000000000000000000000000000000000000000000000001
    VK_PIPELINE_STAGE_2_DRAW_INDIRECT_BIT = 0b0000000000000000000000000000000000000000000000000000000000000010
    VK_PIPELINE_STAGE_2_VERTEX_INPUT_BIT = 0b0000000000000000000000000000000000000000000000000000000000000100
    VK_PIPELINE_STAGE_2_VERTEX_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000000000001000
    VK_PIPELINE_STAGE_2_TESSELLATION_CONTROL_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000000000010000
    VK_PIPELINE_STAGE_2_TESSELLATION_EVALUATION_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000000000100000
    VK_PIPELINE_STAGE_2_GEOMETRY_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000000001000000
    VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000000010000000
    VK_PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT = 0b0000000000000000000000000000000000000000000000000000000100000000
    VK_PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT = 0b0000000000000000000000000000000000000000000000000000001000000000
    VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT = 0b0000000000000000000000000000000000000000000000000000010000000000
    VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT = 0b0000000000000000000000000000000000000000000000000000100000000000
    VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT = 0b0000000000000000000000000000000000000000000000000001000000000000
    VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT = 0b0000000000000000000000000000000000000000000000000010000000000000
    VK_PIPELINE_STAGE_2_HOST_BIT = 0b0000000000000000000000000000000000000000000000000100000000000000
    VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT = 0b0000000000000000000000000000000000000000000000001000000000000000
    VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT = 0b0000000000000000000000000000000000000000000000010000000000000000
    VK_PIPELINE_STAGE_2_COMMAND_PREPROCESS_BIT_NV = 0b0000000000000000000000000000000000000000000000100000000000000000
    VK_PIPELINE_STAGE_2_CONDITIONAL_RENDERING_BIT_EXT = 0b0000000000000000000000000000000000000000000001000000000000000000
    VK_PIPELINE_STAGE_2_TASK_SHADER_BIT_EXT = 0b0000000000000000000000000000000000000000000010000000000000000000
    VK_PIPELINE_STAGE_2_MESH_SHADER_BIT_EXT = 0b0000000000000000000000000000000000000000000100000000000000000000
    VK_PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR = 0b0000000000000000000000000000000000000000001000000000000000000000
    VK_PIPELINE_STAGE_2_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b0000000000000000000000000000000000000000010000000000000000000000
    VK_PIPELINE_STAGE_2_FRAGMENT_DENSITY_PROCESS_BIT_EXT = 0b0000000000000000000000000000000000000000100000000000000000000000
    VK_PIPELINE_STAGE_2_TRANSFORM_FEEDBACK_BIT_EXT = 0b0000000000000000000000000000000000000001000000000000000000000000
    VK_PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR = 0b0000000000000000000000000000000000000010000000000000000000000000
    VK_PIPELINE_STAGE_2_VIDEO_DECODE_BIT_KHR = 0b0000000000000000000000000000000000000100000000000000000000000000
    VK_PIPELINE_STAGE_2_VIDEO_ENCODE_BIT_KHR = 0b0000000000000000000000000000000000001000000000000000000000000000
    VK_PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_COPY_BIT_KHR = 0b0000000000000000000000000000000000010000000000000000000000000000
    VK_PIPELINE_STAGE_2_OPTICAL_FLOW_BIT_NV = 0b0000000000000000000000000000000000100000000000000000000000000000
    VK_PIPELINE_STAGE_2_MICROMAP_BUILD_BIT_EXT = 0b0000000000000000000000000000000001000000000000000000000000000000
    VK_PIPELINE_STAGE_2_COPY_BIT = 0b0000000000000000000000000000000100000000000000000000000000000000
    VK_PIPELINE_STAGE_2_RESOLVE_BIT = 0b0000000000000000000000000000001000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_BLIT_BIT = 0b0000000000000000000000000000010000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_CLEAR_BIT = 0b0000000000000000000000000000100000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_INDEX_INPUT_BIT = 0b0000000000000000000000000001000000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT = 0b0000000000000000000000000010000000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_PRE_RASTERIZATION_SHADERS_BIT = 0b0000000000000000000000000100000000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_SUBPASS_SHADING_BIT_HUAWEI = 0b0000000000000000000000001000000000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_INVOCATION_MASK_BIT_HUAWEI = 0b0000000000000000000000010000000000000000000000000000000000000000
    VK_PIPELINE_STAGE_2_CLUSTER_CULLING_SHADER_BIT_HUAWEI = 0b0000000000000000000000100000000000000000000000000000000000000000
func toBits*(flags: openArray[VkPipelineStageFlagBits2]): VkPipelineStageFlags2 =
    for flag in flags:
      result = VkPipelineStageFlags2(uint64(result) or uint64(flag))
func toEnums*(number: VkPipelineStageFlags2): seq[VkPipelineStageFlagBits2] =
    for value in VkPipelineStageFlagBits2.items:
      if (cast[uint64](value) and uint64(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineStageFlags2): bool = uint64(a) == uint64(b)
const
  VK_PIPELINE_STAGE_2_NONE* = 0
type
  VkSubmitFlagBits* {.size: sizeof(cint).} = enum
    VK_SUBMIT_PROTECTED_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkSubmitFlagBits]): VkSubmitFlags =
    for flag in flags:
      result = VkSubmitFlags(uint(result) or uint(flag))
func toEnums*(number: VkSubmitFlags): seq[VkSubmitFlagBits] =
    for value in VkSubmitFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkSubmitFlags): bool = cint(a) == cint(b)
type
  VkEventCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_EVENT_CREATE_DEVICE_ONLY_BIT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkEventCreateFlagBits]): VkEventCreateFlags =
    for flag in flags:
      result = VkEventCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkEventCreateFlags): seq[VkEventCreateFlagBits] =
    for value in VkEventCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkEventCreateFlags): bool = cint(a) == cint(b)
type
  VkPipelineLayoutCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_LAYOUT_CREATE_RESERVED_0_BIT_AMD = 0b00000000000000000000000000000001
    VK_PIPELINE_LAYOUT_CREATE_INDEPENDENT_SETS_BIT_EXT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkPipelineLayoutCreateFlagBits]): VkPipelineLayoutCreateFlags =
    for flag in flags:
      result = VkPipelineLayoutCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineLayoutCreateFlags): seq[VkPipelineLayoutCreateFlagBits] =
    for value in VkPipelineLayoutCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineLayoutCreateFlags): bool = cint(a) == cint(b)
type
  VkSciSyncClientTypeNV* {.size: sizeof(cint).} = enum
    VK_SCI_SYNC_CLIENT_TYPE_SIGNALER_NV = 0
    VK_SCI_SYNC_CLIENT_TYPE_WAITER_NV = 1
    VK_SCI_SYNC_CLIENT_TYPE_SIGNALER_WAITER_NV = 2
  VkSciSyncPrimitiveTypeNV* {.size: sizeof(cint).} = enum
    VK_SCI_SYNC_PRIMITIVE_TYPE_FENCE_NV = 0
    VK_SCI_SYNC_PRIMITIVE_TYPE_SEMAPHORE_NV = 1
  VkProvokingVertexModeEXT* {.size: sizeof(cint).} = enum
    VK_PROVOKING_VERTEX_MODE_FIRST_VERTEX_EXT = 0
    VK_PROVOKING_VERTEX_MODE_LAST_VERTEX_EXT = 1
  VkPipelineCacheValidationVersion* {.size: sizeof(cint).} = enum
    VK_PIPELINE_CACHE_VALIDATION_VERSION_SAFETY_CRITICAL_ONE = 1
  VkAccelerationStructureMotionInstanceTypeNV* {.size: sizeof(cint).} = enum
    VK_ACCELERATION_STRUCTURE_MOTION_INSTANCE_TYPE_STATIC_NV = 0
    VK_ACCELERATION_STRUCTURE_MOTION_INSTANCE_TYPE_MATRIX_MOTION_NV = 1
    VK_ACCELERATION_STRUCTURE_MOTION_INSTANCE_TYPE_SRT_MOTION_NV = 2
  VkPipelineColorBlendStateCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_EXT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkPipelineColorBlendStateCreateFlagBits]): VkPipelineColorBlendStateCreateFlags =
    for flag in flags:
      result = VkPipelineColorBlendStateCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineColorBlendStateCreateFlags): seq[VkPipelineColorBlendStateCreateFlagBits] =
    for value in VkPipelineColorBlendStateCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineColorBlendStateCreateFlags): bool = cint(a) == cint(b)
type
  VkPipelineDepthStencilStateCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT = 0b00000000000000000000000000000001
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkPipelineDepthStencilStateCreateFlagBits]): VkPipelineDepthStencilStateCreateFlags =
    for flag in flags:
      result = VkPipelineDepthStencilStateCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkPipelineDepthStencilStateCreateFlags): seq[VkPipelineDepthStencilStateCreateFlagBits] =
    for value in VkPipelineDepthStencilStateCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPipelineDepthStencilStateCreateFlags): bool = cint(a) == cint(b)
type
  VkGraphicsPipelineLibraryFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_GRAPHICS_PIPELINE_LIBRARY_VERTEX_INPUT_INTERFACE_BIT_EXT = 0b00000000000000000000000000000001
    VK_GRAPHICS_PIPELINE_LIBRARY_PRE_RASTERIZATION_SHADERS_BIT_EXT = 0b00000000000000000000000000000010
    VK_GRAPHICS_PIPELINE_LIBRARY_FRAGMENT_SHADER_BIT_EXT = 0b00000000000000000000000000000100
    VK_GRAPHICS_PIPELINE_LIBRARY_FRAGMENT_OUTPUT_INTERFACE_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkGraphicsPipelineLibraryFlagBitsEXT]): VkGraphicsPipelineLibraryFlagsEXT =
    for flag in flags:
      result = VkGraphicsPipelineLibraryFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkGraphicsPipelineLibraryFlagsEXT): seq[VkGraphicsPipelineLibraryFlagBitsEXT] =
    for value in VkGraphicsPipelineLibraryFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkGraphicsPipelineLibraryFlagsEXT): bool = cint(a) == cint(b)
type
  VkDeviceAddressBindingFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_ADDRESS_BINDING_INTERNAL_OBJECT_BIT_EXT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkDeviceAddressBindingFlagBitsEXT]): VkDeviceAddressBindingFlagsEXT =
    for flag in flags:
      result = VkDeviceAddressBindingFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkDeviceAddressBindingFlagsEXT): seq[VkDeviceAddressBindingFlagBitsEXT] =
    for value in VkDeviceAddressBindingFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkDeviceAddressBindingFlagsEXT): bool = cint(a) == cint(b)
type
  VkDeviceAddressBindingTypeEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_ADDRESS_BINDING_TYPE_BIND_EXT = 0
    VK_DEVICE_ADDRESS_BINDING_TYPE_UNBIND_EXT = 1
  VkPresentScalingFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_PRESENT_SCALING_ONE_TO_ONE_BIT_EXT = 0b00000000000000000000000000000001
    VK_PRESENT_SCALING_ASPECT_RATIO_STRETCH_BIT_EXT = 0b00000000000000000000000000000010
    VK_PRESENT_SCALING_STRETCH_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkPresentScalingFlagBitsEXT]): VkPresentScalingFlagsEXT =
    for flag in flags:
      result = VkPresentScalingFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkPresentScalingFlagsEXT): seq[VkPresentScalingFlagBitsEXT] =
    for value in VkPresentScalingFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPresentScalingFlagsEXT): bool = cint(a) == cint(b)
type
  VkPresentGravityFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_PRESENT_GRAVITY_MIN_BIT_EXT = 0b00000000000000000000000000000001
    VK_PRESENT_GRAVITY_MAX_BIT_EXT = 0b00000000000000000000000000000010
    VK_PRESENT_GRAVITY_CENTERED_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkPresentGravityFlagBitsEXT]): VkPresentGravityFlagsEXT =
    for flag in flags:
      result = VkPresentGravityFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkPresentGravityFlagsEXT): seq[VkPresentGravityFlagBitsEXT] =
    for value in VkPresentGravityFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkPresentGravityFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoCodecOperationFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_CODEC_OPERATION_DECODE_H264_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_CODEC_OPERATION_DECODE_H265_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_CODEC_OPERATION_ENCODE_H264_BIT_EXT = 0b00000000000000010000000000000000
    VK_VIDEO_CODEC_OPERATION_ENCODE_H265_BIT_EXT = 0b00000000000000100000000000000000
func toBits*(flags: openArray[VkVideoCodecOperationFlagBitsKHR]): VkVideoCodecOperationFlagsKHR =
    for flag in flags:
      result = VkVideoCodecOperationFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoCodecOperationFlagsKHR): seq[VkVideoCodecOperationFlagBitsKHR] =
    for value in VkVideoCodecOperationFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoCodecOperationFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_CODEC_OPERATION_NONE_KHR* = 0
type
  VkVideoChromaSubsamplingFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_CHROMA_SUBSAMPLING_MONOCHROME_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_CHROMA_SUBSAMPLING_420_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_CHROMA_SUBSAMPLING_422_BIT_KHR = 0b00000000000000000000000000000100
    VK_VIDEO_CHROMA_SUBSAMPLING_444_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkVideoChromaSubsamplingFlagBitsKHR]): VkVideoChromaSubsamplingFlagsKHR =
    for flag in flags:
      result = VkVideoChromaSubsamplingFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoChromaSubsamplingFlagsKHR): seq[VkVideoChromaSubsamplingFlagBitsKHR] =
    for value in VkVideoChromaSubsamplingFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoChromaSubsamplingFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_CHROMA_SUBSAMPLING_INVALID_KHR* = 0
type
  VkVideoComponentBitDepthFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_COMPONENT_BIT_DEPTH_8_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_COMPONENT_BIT_DEPTH_10_BIT_KHR = 0b00000000000000000000000000000100
    VK_VIDEO_COMPONENT_BIT_DEPTH_12_BIT_KHR = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkVideoComponentBitDepthFlagBitsKHR]): VkVideoComponentBitDepthFlagsKHR =
    for flag in flags:
      result = VkVideoComponentBitDepthFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoComponentBitDepthFlagsKHR): seq[VkVideoComponentBitDepthFlagBitsKHR] =
    for value in VkVideoComponentBitDepthFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoComponentBitDepthFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_COMPONENT_BIT_DEPTH_INVALID_KHR* = 0
type
  VkVideoCapabilityFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_CAPABILITY_PROTECTED_CONTENT_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_CAPABILITY_SEPARATE_REFERENCE_IMAGES_BIT_KHR = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkVideoCapabilityFlagBitsKHR]): VkVideoCapabilityFlagsKHR =
    for flag in flags:
      result = VkVideoCapabilityFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoCapabilityFlagsKHR): seq[VkVideoCapabilityFlagBitsKHR] =
    for value in VkVideoCapabilityFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoCapabilityFlagsKHR): bool = cint(a) == cint(b)
type
  VkVideoSessionCreateFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_SESSION_CREATE_PROTECTED_CONTENT_BIT_KHR = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkVideoSessionCreateFlagBitsKHR]): VkVideoSessionCreateFlagsKHR =
    for flag in flags:
      result = VkVideoSessionCreateFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoSessionCreateFlagsKHR): seq[VkVideoSessionCreateFlagBitsKHR] =
    for value in VkVideoSessionCreateFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoSessionCreateFlagsKHR): bool = cint(a) == cint(b)
type
  VkVideoDecodeH264PictureLayoutFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_INTERLACED_INTERLEAVED_LINES_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_INTERLACED_SEPARATE_PLANES_BIT_KHR = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkVideoDecodeH264PictureLayoutFlagBitsKHR]): VkVideoDecodeH264PictureLayoutFlagsKHR =
    for flag in flags:
      result = VkVideoDecodeH264PictureLayoutFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoDecodeH264PictureLayoutFlagsKHR): seq[VkVideoDecodeH264PictureLayoutFlagBitsKHR] =
    for value in VkVideoDecodeH264PictureLayoutFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoDecodeH264PictureLayoutFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_PROGRESSIVE_KHR* = 0
type
  VkVideoCodingControlFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_CODING_CONTROL_RESET_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_CODING_CONTROL_ENCODE_RATE_CONTROL_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_CODING_CONTROL_ENCODE_RATE_CONTROL_LAYER_BIT_KHR = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoCodingControlFlagBitsKHR]): VkVideoCodingControlFlagsKHR =
    for flag in flags:
      result = VkVideoCodingControlFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoCodingControlFlagsKHR): seq[VkVideoCodingControlFlagBitsKHR] =
    for value in VkVideoCodingControlFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoCodingControlFlagsKHR): bool = cint(a) == cint(b)
type
  VkQueryResultStatusKHR* {.size: sizeof(cint).} = enum
    VK_QUERY_RESULT_STATUS_ERROR_KHR = -1
    VK_QUERY_RESULT_STATUS_NOT_READY_KHR = 0
    VK_QUERY_RESULT_STATUS_COMPLETE_KHR = 1
  VkVideoDecodeUsageFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_DECODE_USAGE_TRANSCODING_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_DECODE_USAGE_OFFLINE_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_DECODE_USAGE_STREAMING_BIT_KHR = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoDecodeUsageFlagBitsKHR]): VkVideoDecodeUsageFlagsKHR =
    for flag in flags:
      result = VkVideoDecodeUsageFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoDecodeUsageFlagsKHR): seq[VkVideoDecodeUsageFlagBitsKHR] =
    for value in VkVideoDecodeUsageFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoDecodeUsageFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_DECODE_USAGE_DEFAULT_KHR* = 0
type
  VkVideoDecodeCapabilityFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_DECODE_CAPABILITY_DPB_AND_OUTPUT_COINCIDE_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_DECODE_CAPABILITY_DPB_AND_OUTPUT_DISTINCT_BIT_KHR = 0b00000000000000000000000000000010
func toBits*(flags: openArray[VkVideoDecodeCapabilityFlagBitsKHR]): VkVideoDecodeCapabilityFlagsKHR =
    for flag in flags:
      result = VkVideoDecodeCapabilityFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoDecodeCapabilityFlagsKHR): seq[VkVideoDecodeCapabilityFlagBitsKHR] =
    for value in VkVideoDecodeCapabilityFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoDecodeCapabilityFlagsKHR): bool = cint(a) == cint(b)
type
  VkVideoEncodeUsageFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_USAGE_TRANSCODING_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_USAGE_STREAMING_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_USAGE_RECORDING_BIT_KHR = 0b00000000000000000000000000000100
    VK_VIDEO_ENCODE_USAGE_CONFERENCING_BIT_KHR = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkVideoEncodeUsageFlagBitsKHR]): VkVideoEncodeUsageFlagsKHR =
    for flag in flags:
      result = VkVideoEncodeUsageFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeUsageFlagsKHR): seq[VkVideoEncodeUsageFlagBitsKHR] =
    for value in VkVideoEncodeUsageFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeUsageFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_ENCODE_USAGE_DEFAULT_KHR* = 0
type
  VkVideoEncodeContentFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_CONTENT_CAMERA_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_CONTENT_DESKTOP_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_CONTENT_RENDERED_BIT_KHR = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeContentFlagBitsKHR]): VkVideoEncodeContentFlagsKHR =
    for flag in flags:
      result = VkVideoEncodeContentFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeContentFlagsKHR): seq[VkVideoEncodeContentFlagBitsKHR] =
    for value in VkVideoEncodeContentFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeContentFlagsKHR): bool = cint(a) == cint(b)
const
  VK_VIDEO_ENCODE_CONTENT_DEFAULT_KHR* = 0
type
  VkVideoEncodeTuningModeKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_TUNING_MODE_DEFAULT_KHR = 0
    VK_VIDEO_ENCODE_TUNING_MODE_HIGH_QUALITY_KHR = 1
    VK_VIDEO_ENCODE_TUNING_MODE_LOW_LATENCY_KHR = 2
    VK_VIDEO_ENCODE_TUNING_MODE_ULTRA_LOW_LATENCY_KHR = 3
    VK_VIDEO_ENCODE_TUNING_MODE_LOSSLESS_KHR = 4
  VkVideoEncodeCapabilityFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_CAPABILITY_PRECEDING_EXTERNALLY_ENCODED_BYTES_BIT_KHR = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkVideoEncodeCapabilityFlagBitsKHR]): VkVideoEncodeCapabilityFlagsKHR =
    for flag in flags:
      result = VkVideoEncodeCapabilityFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeCapabilityFlagsKHR): seq[VkVideoEncodeCapabilityFlagBitsKHR] =
    for value in VkVideoEncodeCapabilityFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeCapabilityFlagsKHR): bool = cint(a) == cint(b)
type
  VkVideoEncodeRateControlModeFlagBitsKHR* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_RATE_CONTROL_MODE_NONE_BIT_KHR = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_RATE_CONTROL_MODE_CBR_BIT_KHR = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_RATE_CONTROL_MODE_VBR_BIT_KHR = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeRateControlModeFlagBitsKHR]): VkVideoEncodeRateControlModeFlagsKHR =
    for flag in flags:
      result = VkVideoEncodeRateControlModeFlagsKHR(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeRateControlModeFlagsKHR): seq[VkVideoEncodeRateControlModeFlagBitsKHR] =
    for value in VkVideoEncodeRateControlModeFlagBitsKHR.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeRateControlModeFlagsKHR): bool = cint(a) == cint(b)
type
  VkVideoEncodeH264CapabilityFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H264_CAPABILITY_DIRECT_8X8_INFERENCE_ENABLED_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H264_CAPABILITY_DIRECT_8X8_INFERENCE_DISABLED_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H264_CAPABILITY_SEPARATE_COLOUR_PLANE_BIT_EXT = 0b00000000000000000000000000000100
    VK_VIDEO_ENCODE_H264_CAPABILITY_QPPRIME_Y_ZERO_TRANSFORM_BYPASS_BIT_EXT = 0b00000000000000000000000000001000
    VK_VIDEO_ENCODE_H264_CAPABILITY_SCALING_LISTS_BIT_EXT = 0b00000000000000000000000000010000
    VK_VIDEO_ENCODE_H264_CAPABILITY_HRD_COMPLIANCE_BIT_EXT = 0b00000000000000000000000000100000
    VK_VIDEO_ENCODE_H264_CAPABILITY_CHROMA_QP_OFFSET_BIT_EXT = 0b00000000000000000000000001000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_SECOND_CHROMA_QP_OFFSET_BIT_EXT = 0b00000000000000000000000010000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_PIC_INIT_QP_MINUS26_BIT_EXT = 0b00000000000000000000000100000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_WEIGHTED_PRED_BIT_EXT = 0b00000000000000000000001000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_WEIGHTED_BIPRED_EXPLICIT_BIT_EXT = 0b00000000000000000000010000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_WEIGHTED_BIPRED_IMPLICIT_BIT_EXT = 0b00000000000000000000100000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_WEIGHTED_PRED_NO_TABLE_BIT_EXT = 0b00000000000000000001000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_TRANSFORM_8X8_BIT_EXT = 0b00000000000000000010000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_CABAC_BIT_EXT = 0b00000000000000000100000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_CAVLC_BIT_EXT = 0b00000000000000001000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_DEBLOCKING_FILTER_DISABLED_BIT_EXT = 0b00000000000000010000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_DEBLOCKING_FILTER_ENABLED_BIT_EXT = 0b00000000000000100000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_DEBLOCKING_FILTER_PARTIAL_BIT_EXT = 0b00000000000001000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_DISABLE_DIRECT_SPATIAL_MV_PRED_BIT_EXT = 0b00000000000010000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_MULTIPLE_SLICE_PER_FRAME_BIT_EXT = 0b00000000000100000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_SLICE_MB_COUNT_BIT_EXT = 0b00000000001000000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_ROW_UNALIGNED_SLICE_BIT_EXT = 0b00000000010000000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_DIFFERENT_SLICE_TYPE_BIT_EXT = 0b00000000100000000000000000000000
    VK_VIDEO_ENCODE_H264_CAPABILITY_B_FRAME_IN_L1_LIST_BIT_EXT = 0b00000001000000000000000000000000
func toBits*(flags: openArray[VkVideoEncodeH264CapabilityFlagBitsEXT]): VkVideoEncodeH264CapabilityFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH264CapabilityFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH264CapabilityFlagsEXT): seq[VkVideoEncodeH264CapabilityFlagBitsEXT] =
    for value in VkVideoEncodeH264CapabilityFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH264CapabilityFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH264InputModeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H264_INPUT_MODE_FRAME_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H264_INPUT_MODE_SLICE_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H264_INPUT_MODE_NON_VCL_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeH264InputModeFlagBitsEXT]): VkVideoEncodeH264InputModeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH264InputModeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH264InputModeFlagsEXT): seq[VkVideoEncodeH264InputModeFlagBitsEXT] =
    for value in VkVideoEncodeH264InputModeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH264InputModeFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH264OutputModeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H264_OUTPUT_MODE_FRAME_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H264_OUTPUT_MODE_SLICE_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H264_OUTPUT_MODE_NON_VCL_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeH264OutputModeFlagBitsEXT]): VkVideoEncodeH264OutputModeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH264OutputModeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH264OutputModeFlagsEXT): seq[VkVideoEncodeH264OutputModeFlagBitsEXT] =
    for value in VkVideoEncodeH264OutputModeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH264OutputModeFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH264RateControlStructureEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H264_RATE_CONTROL_STRUCTURE_UNKNOWN_EXT = 0
    VK_VIDEO_ENCODE_H264_RATE_CONTROL_STRUCTURE_FLAT_EXT = 1
    VK_VIDEO_ENCODE_H264_RATE_CONTROL_STRUCTURE_DYADIC_EXT = 2
  VkImageConstraintsInfoFlagBitsFUCHSIA* {.size: sizeof(cint).} = enum
    VK_IMAGE_CONSTRAINTS_INFO_CPU_READ_RARELY_FUCHSIA = 0b00000000000000000000000000000001
    VK_IMAGE_CONSTRAINTS_INFO_CPU_READ_OFTEN_FUCHSIA = 0b00000000000000000000000000000010
    VK_IMAGE_CONSTRAINTS_INFO_CPU_WRITE_RARELY_FUCHSIA = 0b00000000000000000000000000000100
    VK_IMAGE_CONSTRAINTS_INFO_CPU_WRITE_OFTEN_FUCHSIA = 0b00000000000000000000000000001000
    VK_IMAGE_CONSTRAINTS_INFO_PROTECTED_OPTIONAL_FUCHSIA = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkImageConstraintsInfoFlagBitsFUCHSIA]): VkImageConstraintsInfoFlagsFUCHSIA =
    for flag in flags:
      result = VkImageConstraintsInfoFlagsFUCHSIA(uint(result) or uint(flag))
func toEnums*(number: VkImageConstraintsInfoFlagsFUCHSIA): seq[VkImageConstraintsInfoFlagBitsFUCHSIA] =
    for value in VkImageConstraintsInfoFlagBitsFUCHSIA.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageConstraintsInfoFlagsFUCHSIA): bool = cint(a) == cint(b)
type
  VkFormatFeatureFlagBits2* {.size: 8.} = enum
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_BIT = 0b0000000000000000000000000000000000000000000000000000000000000001
    VK_FORMAT_FEATURE_2_STORAGE_IMAGE_BIT = 0b0000000000000000000000000000000000000000000000000000000000000010
    VK_FORMAT_FEATURE_2_STORAGE_IMAGE_ATOMIC_BIT = 0b0000000000000000000000000000000000000000000000000000000000000100
    VK_FORMAT_FEATURE_2_UNIFORM_TEXEL_BUFFER_BIT = 0b0000000000000000000000000000000000000000000000000000000000001000
    VK_FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_BIT = 0b0000000000000000000000000000000000000000000000000000000000010000
    VK_FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_ATOMIC_BIT = 0b0000000000000000000000000000000000000000000000000000000000100000
    VK_FORMAT_FEATURE_2_VERTEX_BUFFER_BIT = 0b0000000000000000000000000000000000000000000000000000000001000000
    VK_FORMAT_FEATURE_2_COLOR_ATTACHMENT_BIT = 0b0000000000000000000000000000000000000000000000000000000010000000
    VK_FORMAT_FEATURE_2_COLOR_ATTACHMENT_BLEND_BIT = 0b0000000000000000000000000000000000000000000000000000000100000000
    VK_FORMAT_FEATURE_2_DEPTH_STENCIL_ATTACHMENT_BIT = 0b0000000000000000000000000000000000000000000000000000001000000000
    VK_FORMAT_FEATURE_2_BLIT_SRC_BIT = 0b0000000000000000000000000000000000000000000000000000010000000000
    VK_FORMAT_FEATURE_2_BLIT_DST_BIT = 0b0000000000000000000000000000000000000000000000000000100000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_LINEAR_BIT = 0b0000000000000000000000000000000000000000000000000001000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_CUBIC_BIT = 0b0000000000000000000000000000000000000000000000000010000000000000
    VK_FORMAT_FEATURE_2_TRANSFER_SRC_BIT = 0b0000000000000000000000000000000000000000000000000100000000000000
    VK_FORMAT_FEATURE_2_TRANSFER_DST_BIT = 0b0000000000000000000000000000000000000000000000001000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_MINMAX_BIT = 0b0000000000000000000000000000000000000000000000010000000000000000
    VK_FORMAT_FEATURE_2_MIDPOINT_CHROMA_SAMPLES_BIT = 0b0000000000000000000000000000000000000000000000100000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT = 0b0000000000000000000000000000000000000000000001000000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT = 0b0000000000000000000000000000000000000000000010000000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT = 0b0000000000000000000000000000000000000000000100000000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT = 0b0000000000000000000000000000000000000000001000000000000000000000
    VK_FORMAT_FEATURE_2_DISJOINT_BIT = 0b0000000000000000000000000000000000000000010000000000000000000000
    VK_FORMAT_FEATURE_2_COSITED_CHROMA_SAMPLES_BIT = 0b0000000000000000000000000000000000000000100000000000000000000000
    VK_FORMAT_FEATURE_2_FRAGMENT_DENSITY_MAP_BIT_EXT = 0b0000000000000000000000000000000000000001000000000000000000000000
    VK_FORMAT_FEATURE_2_VIDEO_DECODE_OUTPUT_BIT_KHR = 0b0000000000000000000000000000000000000010000000000000000000000000
    VK_FORMAT_FEATURE_2_VIDEO_DECODE_DPB_BIT_KHR = 0b0000000000000000000000000000000000000100000000000000000000000000
    VK_FORMAT_FEATURE_2_VIDEO_ENCODE_INPUT_BIT_KHR = 0b0000000000000000000000000000000000001000000000000000000000000000
    VK_FORMAT_FEATURE_2_VIDEO_ENCODE_DPB_BIT_KHR = 0b0000000000000000000000000000000000010000000000000000000000000000
    VK_FORMAT_FEATURE_2_ACCELERATION_STRUCTURE_VERTEX_BUFFER_BIT_KHR = 0b0000000000000000000000000000000000100000000000000000000000000000
    VK_FORMAT_FEATURE_2_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0b0000000000000000000000000000000001000000000000000000000000000000
    VK_FORMAT_FEATURE_2_STORAGE_READ_WITHOUT_FORMAT_BIT = 0b0000000000000000000000000000000010000000000000000000000000000000
    VK_FORMAT_FEATURE_2_STORAGE_WRITE_WITHOUT_FORMAT_BIT = 0b0000000000000000000000000000000100000000000000000000000000000000
    VK_FORMAT_FEATURE_2_SAMPLED_IMAGE_DEPTH_COMPARISON_BIT = 0b0000000000000000000000000000001000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_WEIGHT_IMAGE_BIT_QCOM = 0b0000000000000000000000000000010000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_WEIGHT_SAMPLED_IMAGE_BIT_QCOM = 0b0000000000000000000000000000100000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_BLOCK_MATCHING_BIT_QCOM = 0b0000000000000000000000000001000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_BOX_FILTER_SAMPLED_BIT_QCOM = 0b0000000000000000000000000010000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_LINEAR_COLOR_ATTACHMENT_BIT_NV = 0b0000000000000000000000000100000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_RESERVED_39_BIT_EXT = 0b0000000000000000000000001000000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_OPTICAL_FLOW_IMAGE_BIT_NV = 0b0000000000000000000000010000000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_OPTICAL_FLOW_VECTOR_BIT_NV = 0b0000000000000000000000100000000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_OPTICAL_FLOW_COST_BIT_NV = 0b0000000000000000000001000000000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_RESERVED_44_BIT_EXT = 0b0000000000000000000100000000000000000000000000000000000000000000
    VK_FORMAT_FEATURE_2_RESERVED_45_BIT_EXT = 0b0000000000000000001000000000000000000000000000000000000000000000
func toBits*(flags: openArray[VkFormatFeatureFlagBits2]): VkFormatFeatureFlags2 =
    for flag in flags:
      result = VkFormatFeatureFlags2(uint64(result) or uint64(flag))
func toEnums*(number: VkFormatFeatureFlags2): seq[VkFormatFeatureFlagBits2] =
    for value in VkFormatFeatureFlagBits2.items:
      if (cast[uint64](value) and uint64(number)) > 0:
        result.add value
proc `==`*(a, b: VkFormatFeatureFlags2): bool = uint64(a) == uint64(b)
type
  VkRenderingFlagBits* {.size: sizeof(cint).} = enum
    VK_RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT = 0b00000000000000000000000000000001
    VK_RENDERING_SUSPENDING_BIT = 0b00000000000000000000000000000010
    VK_RENDERING_RESUMING_BIT = 0b00000000000000000000000000000100
    VK_RENDERING_ENABLE_LEGACY_DITHERING_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkRenderingFlagBits]): VkRenderingFlags =
    for flag in flags:
      result = VkRenderingFlags(uint(result) or uint(flag))
func toEnums*(number: VkRenderingFlags): seq[VkRenderingFlagBits] =
    for value in VkRenderingFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkRenderingFlags): bool = cint(a) == cint(b)
type
  VkVideoEncodeH265CapabilityFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_CAPABILITY_SEPARATE_COLOUR_PLANE_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H265_CAPABILITY_SCALING_LISTS_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H265_CAPABILITY_SAMPLE_ADAPTIVE_OFFSET_ENABLED_BIT_EXT = 0b00000000000000000000000000000100
    VK_VIDEO_ENCODE_H265_CAPABILITY_PCM_ENABLE_BIT_EXT = 0b00000000000000000000000000001000
    VK_VIDEO_ENCODE_H265_CAPABILITY_SPS_TEMPORAL_MVP_ENABLED_BIT_EXT = 0b00000000000000000000000000010000
    VK_VIDEO_ENCODE_H265_CAPABILITY_HRD_COMPLIANCE_BIT_EXT = 0b00000000000000000000000000100000
    VK_VIDEO_ENCODE_H265_CAPABILITY_INIT_QP_MINUS26_BIT_EXT = 0b00000000000000000000000001000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_LOG2_PARALLEL_MERGE_LEVEL_MINUS2_BIT_EXT = 0b00000000000000000000000010000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_SIGN_DATA_HIDING_ENABLED_BIT_EXT = 0b00000000000000000000000100000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_TRANSFORM_SKIP_ENABLED_BIT_EXT = 0b00000000000000000000001000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_TRANSFORM_SKIP_DISABLED_BIT_EXT = 0b00000000000000000000010000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_PPS_SLICE_CHROMA_QP_OFFSETS_PRESENT_BIT_EXT = 0b00000000000000000000100000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_WEIGHTED_PRED_BIT_EXT = 0b00000000000000000001000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_WEIGHTED_BIPRED_BIT_EXT = 0b00000000000000000010000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_WEIGHTED_PRED_NO_TABLE_BIT_EXT = 0b00000000000000000100000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_TRANSQUANT_BYPASS_ENABLED_BIT_EXT = 0b00000000000000001000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_ENTROPY_CODING_SYNC_ENABLED_BIT_EXT = 0b00000000000000010000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_DEBLOCKING_FILTER_OVERRIDE_ENABLED_BIT_EXT = 0b00000000000000100000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_MULTIPLE_TILE_PER_FRAME_BIT_EXT = 0b00000000000001000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_MULTIPLE_SLICE_PER_TILE_BIT_EXT = 0b00000000000010000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_MULTIPLE_TILE_PER_SLICE_BIT_EXT = 0b00000000000100000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_SLICE_SEGMENT_CTB_COUNT_BIT_EXT = 0b00000000001000000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_ROW_UNALIGNED_SLICE_SEGMENT_BIT_EXT = 0b00000000010000000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_DEPENDENT_SLICE_SEGMENT_BIT_EXT = 0b00000000100000000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_DIFFERENT_SLICE_TYPE_BIT_EXT = 0b00000001000000000000000000000000
    VK_VIDEO_ENCODE_H265_CAPABILITY_B_FRAME_IN_L1_LIST_BIT_EXT = 0b00000010000000000000000000000000
func toBits*(flags: openArray[VkVideoEncodeH265CapabilityFlagBitsEXT]): VkVideoEncodeH265CapabilityFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH265CapabilityFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH265CapabilityFlagsEXT): seq[VkVideoEncodeH265CapabilityFlagBitsEXT] =
    for value in VkVideoEncodeH265CapabilityFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH265CapabilityFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH265InputModeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_INPUT_MODE_FRAME_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H265_INPUT_MODE_SLICE_SEGMENT_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H265_INPUT_MODE_NON_VCL_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeH265InputModeFlagBitsEXT]): VkVideoEncodeH265InputModeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH265InputModeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH265InputModeFlagsEXT): seq[VkVideoEncodeH265InputModeFlagBitsEXT] =
    for value in VkVideoEncodeH265InputModeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH265InputModeFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH265OutputModeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_OUTPUT_MODE_FRAME_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H265_OUTPUT_MODE_SLICE_SEGMENT_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H265_OUTPUT_MODE_NON_VCL_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeH265OutputModeFlagBitsEXT]): VkVideoEncodeH265OutputModeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH265OutputModeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH265OutputModeFlagsEXT): seq[VkVideoEncodeH265OutputModeFlagBitsEXT] =
    for value in VkVideoEncodeH265OutputModeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH265OutputModeFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH265RateControlStructureEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_RATE_CONTROL_STRUCTURE_UNKNOWN_EXT = 0
    VK_VIDEO_ENCODE_H265_RATE_CONTROL_STRUCTURE_FLAT_EXT = 1
    VK_VIDEO_ENCODE_H265_RATE_CONTROL_STRUCTURE_DYADIC_EXT = 2
  VkVideoEncodeH265CtbSizeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_CTB_SIZE_16_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H265_CTB_SIZE_32_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H265_CTB_SIZE_64_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkVideoEncodeH265CtbSizeFlagBitsEXT]): VkVideoEncodeH265CtbSizeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH265CtbSizeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH265CtbSizeFlagsEXT): seq[VkVideoEncodeH265CtbSizeFlagBitsEXT] =
    for value in VkVideoEncodeH265CtbSizeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH265CtbSizeFlagsEXT): bool = cint(a) == cint(b)
type
  VkVideoEncodeH265TransformBlockSizeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_VIDEO_ENCODE_H265_TRANSFORM_BLOCK_SIZE_4_BIT_EXT = 0b00000000000000000000000000000001
    VK_VIDEO_ENCODE_H265_TRANSFORM_BLOCK_SIZE_8_BIT_EXT = 0b00000000000000000000000000000010
    VK_VIDEO_ENCODE_H265_TRANSFORM_BLOCK_SIZE_16_BIT_EXT = 0b00000000000000000000000000000100
    VK_VIDEO_ENCODE_H265_TRANSFORM_BLOCK_SIZE_32_BIT_EXT = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkVideoEncodeH265TransformBlockSizeFlagBitsEXT]): VkVideoEncodeH265TransformBlockSizeFlagsEXT =
    for flag in flags:
      result = VkVideoEncodeH265TransformBlockSizeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkVideoEncodeH265TransformBlockSizeFlagsEXT): seq[VkVideoEncodeH265TransformBlockSizeFlagBitsEXT] =
    for value in VkVideoEncodeH265TransformBlockSizeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkVideoEncodeH265TransformBlockSizeFlagsEXT): bool = cint(a) == cint(b)
type
  VkExportMetalObjectTypeFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_DEVICE_BIT_EXT = 0b00000000000000000000000000000001
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_COMMAND_QUEUE_BIT_EXT = 0b00000000000000000000000000000010
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_BUFFER_BIT_EXT = 0b00000000000000000000000000000100
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_TEXTURE_BIT_EXT = 0b00000000000000000000000000001000
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_IOSURFACE_BIT_EXT = 0b00000000000000000000000000010000
    VK_EXPORT_METAL_OBJECT_TYPE_METAL_SHARED_EVENT_BIT_EXT = 0b00000000000000000000000000100000
func toBits*(flags: openArray[VkExportMetalObjectTypeFlagBitsEXT]): VkExportMetalObjectTypeFlagsEXT =
    for flag in flags:
      result = VkExportMetalObjectTypeFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkExportMetalObjectTypeFlagsEXT): seq[VkExportMetalObjectTypeFlagBitsEXT] =
    for value in VkExportMetalObjectTypeFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkExportMetalObjectTypeFlagsEXT): bool = cint(a) == cint(b)
type
  VkInstanceCreateFlagBits* {.size: sizeof(cint).} = enum
    VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkInstanceCreateFlagBits]): VkInstanceCreateFlags =
    for flag in flags:
      result = VkInstanceCreateFlags(uint(result) or uint(flag))
func toEnums*(number: VkInstanceCreateFlags): seq[VkInstanceCreateFlagBits] =
    for value in VkInstanceCreateFlagBits.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkInstanceCreateFlags): bool = cint(a) == cint(b)
type
  VkImageCompressionFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_IMAGE_COMPRESSION_FIXED_RATE_DEFAULT_EXT = 0b00000000000000000000000000000001
    VK_IMAGE_COMPRESSION_FIXED_RATE_EXPLICIT_EXT = 0b00000000000000000000000000000010
    VK_IMAGE_COMPRESSION_DISABLED_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkImageCompressionFlagBitsEXT]): VkImageCompressionFlagsEXT =
    for flag in flags:
      result = VkImageCompressionFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkImageCompressionFlagsEXT): seq[VkImageCompressionFlagBitsEXT] =
    for value in VkImageCompressionFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageCompressionFlagsEXT): bool = cint(a) == cint(b)
const
  VK_IMAGE_COMPRESSION_DEFAULT_EXT* = 0
type
  VkImageCompressionFixedRateFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_IMAGE_COMPRESSION_FIXED_RATE_1BPC_BIT_EXT = 0b00000000000000000000000000000001
    VK_IMAGE_COMPRESSION_FIXED_RATE_2BPC_BIT_EXT = 0b00000000000000000000000000000010
    VK_IMAGE_COMPRESSION_FIXED_RATE_3BPC_BIT_EXT = 0b00000000000000000000000000000100
    VK_IMAGE_COMPRESSION_FIXED_RATE_4BPC_BIT_EXT = 0b00000000000000000000000000001000
    VK_IMAGE_COMPRESSION_FIXED_RATE_5BPC_BIT_EXT = 0b00000000000000000000000000010000
    VK_IMAGE_COMPRESSION_FIXED_RATE_6BPC_BIT_EXT = 0b00000000000000000000000000100000
    VK_IMAGE_COMPRESSION_FIXED_RATE_7BPC_BIT_EXT = 0b00000000000000000000000001000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_8BPC_BIT_EXT = 0b00000000000000000000000010000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_9BPC_BIT_EXT = 0b00000000000000000000000100000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_10BPC_BIT_EXT = 0b00000000000000000000001000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_11BPC_BIT_EXT = 0b00000000000000000000010000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_12BPC_BIT_EXT = 0b00000000000000000000100000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_13BPC_BIT_EXT = 0b00000000000000000001000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_14BPC_BIT_EXT = 0b00000000000000000010000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_15BPC_BIT_EXT = 0b00000000000000000100000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_16BPC_BIT_EXT = 0b00000000000000001000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_17BPC_BIT_EXT = 0b00000000000000010000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_18BPC_BIT_EXT = 0b00000000000000100000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_19BPC_BIT_EXT = 0b00000000000001000000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_20BPC_BIT_EXT = 0b00000000000010000000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_21BPC_BIT_EXT = 0b00000000000100000000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_22BPC_BIT_EXT = 0b00000000001000000000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_23BPC_BIT_EXT = 0b00000000010000000000000000000000
    VK_IMAGE_COMPRESSION_FIXED_RATE_24BPC_BIT_EXT = 0b00000000100000000000000000000000
func toBits*(flags: openArray[VkImageCompressionFixedRateFlagBitsEXT]): VkImageCompressionFixedRateFlagsEXT =
    for flag in flags:
      result = VkImageCompressionFixedRateFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkImageCompressionFixedRateFlagsEXT): seq[VkImageCompressionFixedRateFlagBitsEXT] =
    for value in VkImageCompressionFixedRateFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkImageCompressionFixedRateFlagsEXT): bool = cint(a) == cint(b)
const
  VK_IMAGE_COMPRESSION_FIXED_RATE_NONE_EXT* = 0
type
  VkPipelineRobustnessBufferBehaviorEXT* {.size: sizeof(cint).} = enum
    VK_PIPELINE_ROBUSTNESS_BUFFER_BEHAVIOR_DEVICE_DEFAULT_EXT = 0
    VK_PIPELINE_ROBUSTNESS_BUFFER_BEHAVIOR_DISABLED_EXT = 1
    VK_PIPELINE_ROBUSTNESS_BUFFER_BEHAVIOR_ROBUST_BUFFER_ACCESS_EXT = 2
    VK_PIPELINE_ROBUSTNESS_BUFFER_BEHAVIOR_ROBUST_BUFFER_ACCESS_2_EXT = 3
  VkPipelineRobustnessImageBehaviorEXT* {.size: sizeof(cint).} = enum
    VK_PIPELINE_ROBUSTNESS_IMAGE_BEHAVIOR_DEVICE_DEFAULT_EXT = 0
    VK_PIPELINE_ROBUSTNESS_IMAGE_BEHAVIOR_DISABLED_EXT = 1
    VK_PIPELINE_ROBUSTNESS_IMAGE_BEHAVIOR_ROBUST_IMAGE_ACCESS_EXT = 2
    VK_PIPELINE_ROBUSTNESS_IMAGE_BEHAVIOR_ROBUST_IMAGE_ACCESS_2_EXT = 3
  VkOpticalFlowGridSizeFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_GRID_SIZE_1X1_BIT_NV = 0b00000000000000000000000000000001
    VK_OPTICAL_FLOW_GRID_SIZE_2X2_BIT_NV = 0b00000000000000000000000000000010
    VK_OPTICAL_FLOW_GRID_SIZE_4X4_BIT_NV = 0b00000000000000000000000000000100
    VK_OPTICAL_FLOW_GRID_SIZE_8X8_BIT_NV = 0b00000000000000000000000000001000
func toBits*(flags: openArray[VkOpticalFlowGridSizeFlagBitsNV]): VkOpticalFlowGridSizeFlagsNV =
    for flag in flags:
      result = VkOpticalFlowGridSizeFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkOpticalFlowGridSizeFlagsNV): seq[VkOpticalFlowGridSizeFlagBitsNV] =
    for value in VkOpticalFlowGridSizeFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkOpticalFlowGridSizeFlagsNV): bool = cint(a) == cint(b)
const
  VK_OPTICAL_FLOW_GRID_SIZE_UNKNOWN_NV* = 0
type
  VkOpticalFlowUsageFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_USAGE_INPUT_BIT_NV = 0b00000000000000000000000000000001
    VK_OPTICAL_FLOW_USAGE_OUTPUT_BIT_NV = 0b00000000000000000000000000000010
    VK_OPTICAL_FLOW_USAGE_HINT_BIT_NV = 0b00000000000000000000000000000100
    VK_OPTICAL_FLOW_USAGE_COST_BIT_NV = 0b00000000000000000000000000001000
    VK_OPTICAL_FLOW_USAGE_GLOBAL_FLOW_BIT_NV = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkOpticalFlowUsageFlagBitsNV]): VkOpticalFlowUsageFlagsNV =
    for flag in flags:
      result = VkOpticalFlowUsageFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkOpticalFlowUsageFlagsNV): seq[VkOpticalFlowUsageFlagBitsNV] =
    for value in VkOpticalFlowUsageFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkOpticalFlowUsageFlagsNV): bool = cint(a) == cint(b)
const
  VK_OPTICAL_FLOW_USAGE_UNKNOWN_NV* = 0
type
  VkOpticalFlowPerformanceLevelNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_UNKNOWN_NV = 0
    VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW_NV = 1
    VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM_NV = 2
    VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST_NV = 3
  VkOpticalFlowSessionBindingPointNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_UNKNOWN_NV = 0
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_INPUT_NV = 1
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_REFERENCE_NV = 2
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_HINT_NV = 3
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_FLOW_VECTOR_NV = 4
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_BACKWARD_FLOW_VECTOR_NV = 5
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_COST_NV = 6
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_BACKWARD_COST_NV = 7
    VK_OPTICAL_FLOW_SESSION_BINDING_POINT_GLOBAL_FLOW_NV = 8
  VkOpticalFlowSessionCreateFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_HINT_BIT_NV = 0b00000000000000000000000000000001
    VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_COST_BIT_NV = 0b00000000000000000000000000000010
    VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_GLOBAL_FLOW_BIT_NV = 0b00000000000000000000000000000100
    VK_OPTICAL_FLOW_SESSION_CREATE_ALLOW_REGIONS_BIT_NV = 0b00000000000000000000000000001000
    VK_OPTICAL_FLOW_SESSION_CREATE_BOTH_DIRECTIONS_BIT_NV = 0b00000000000000000000000000010000
func toBits*(flags: openArray[VkOpticalFlowSessionCreateFlagBitsNV]): VkOpticalFlowSessionCreateFlagsNV =
    for flag in flags:
      result = VkOpticalFlowSessionCreateFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkOpticalFlowSessionCreateFlagsNV): seq[VkOpticalFlowSessionCreateFlagBitsNV] =
    for value in VkOpticalFlowSessionCreateFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkOpticalFlowSessionCreateFlagsNV): bool = cint(a) == cint(b)
type
  VkOpticalFlowExecuteFlagBitsNV* {.size: sizeof(cint).} = enum
    VK_OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS_BIT_NV = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkOpticalFlowExecuteFlagBitsNV]): VkOpticalFlowExecuteFlagsNV =
    for flag in flags:
      result = VkOpticalFlowExecuteFlagsNV(uint(result) or uint(flag))
func toEnums*(number: VkOpticalFlowExecuteFlagsNV): seq[VkOpticalFlowExecuteFlagBitsNV] =
    for value in VkOpticalFlowExecuteFlagBitsNV.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkOpticalFlowExecuteFlagsNV): bool = cint(a) == cint(b)
type
  VkMicromapTypeEXT* {.size: sizeof(cint).} = enum
    VK_MICROMAP_TYPE_OPACITY_MICROMAP_EXT = 0
  VkBuildMicromapFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_BUILD_MICROMAP_PREFER_FAST_TRACE_BIT_EXT = 0b00000000000000000000000000000001
    VK_BUILD_MICROMAP_PREFER_FAST_BUILD_BIT_EXT = 0b00000000000000000000000000000010
    VK_BUILD_MICROMAP_ALLOW_COMPACTION_BIT_EXT = 0b00000000000000000000000000000100
func toBits*(flags: openArray[VkBuildMicromapFlagBitsEXT]): VkBuildMicromapFlagsEXT =
    for flag in flags:
      result = VkBuildMicromapFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkBuildMicromapFlagsEXT): seq[VkBuildMicromapFlagBitsEXT] =
    for value in VkBuildMicromapFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkBuildMicromapFlagsEXT): bool = cint(a) == cint(b)
type
  VkMicromapCreateFlagBitsEXT* {.size: sizeof(cint).} = enum
    VK_MICROMAP_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_EXT = 0b00000000000000000000000000000001
func toBits*(flags: openArray[VkMicromapCreateFlagBitsEXT]): VkMicromapCreateFlagsEXT =
    for flag in flags:
      result = VkMicromapCreateFlagsEXT(uint(result) or uint(flag))
func toEnums*(number: VkMicromapCreateFlagsEXT): seq[VkMicromapCreateFlagBitsEXT] =
    for value in VkMicromapCreateFlagBitsEXT.items:
      if (value.ord and cint(number)) > 0:
        result.add value
proc `==`*(a, b: VkMicromapCreateFlagsEXT): bool = cint(a) == cint(b)
type
  VkCopyMicromapModeEXT* {.size: sizeof(cint).} = enum
    VK_COPY_MICROMAP_MODE_CLONE_EXT = 0
    VK_COPY_MICROMAP_MODE_SERIALIZE_EXT = 1
    VK_COPY_MICROMAP_MODE_DESERIALIZE_EXT = 2
    VK_COPY_MICROMAP_MODE_COMPACT_EXT = 3
  VkBuildMicromapModeEXT* {.size: sizeof(cint).} = enum
    VK_BUILD_MICROMAP_MODE_BUILD_EXT = 0
  VkOpacityMicromapFormatEXT* {.size: sizeof(cint).} = enum
    VK_OPACITY_MICROMAP_FORMAT_2_STATE_EXT = 1
    VK_OPACITY_MICROMAP_FORMAT_4_STATE_EXT = 2
  VkOpacityMicromapSpecialIndexEXT* {.size: sizeof(cint).} = enum
    VK_OPACITY_MICROMAP_SPECIAL_INDEX_FULLY_UNKNOWN_OPAQUE_EXT = -4
    VK_OPACITY_MICROMAP_SPECIAL_INDEX_FULLY_UNKNOWN_TRANSPARENT_EXT = -3
    VK_OPACITY_MICROMAP_SPECIAL_INDEX_FULLY_OPAQUE_EXT = -2
    VK_OPACITY_MICROMAP_SPECIAL_INDEX_FULLY_TRANSPARENT_EXT = -1
  VkDeviceFaultAddressTypeEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_FAULT_ADDRESS_TYPE_NONE_EXT = 0
    VK_DEVICE_FAULT_ADDRESS_TYPE_READ_INVALID_EXT = 1
    VK_DEVICE_FAULT_ADDRESS_TYPE_WRITE_INVALID_EXT = 2
    VK_DEVICE_FAULT_ADDRESS_TYPE_EXECUTE_INVALID_EXT = 3
    VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_UNKNOWN_EXT = 4
    VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_INVALID_EXT = 5
    VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_FAULT_EXT = 6
  VkDeviceFaultVendorBinaryHeaderVersionEXT* {.size: sizeof(cint).} = enum
    VK_DEVICE_FAULT_VENDOR_BINARY_HEADER_VERSION_ONE_EXT_ENUM = 1
proc `$`*(bitset: VkFramebufferCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkRenderPassCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSamplerCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineCacheCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineShaderStageCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDescriptorSetLayoutCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkInstanceCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDeviceQueueCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkBufferCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkBufferUsageFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkColorComponentFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkCommandPoolCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkCommandPoolResetFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkCommandBufferResetFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkCommandBufferUsageFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkCullModeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkFenceCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkFormatFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkImageAspectFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkImageCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkImageUsageFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkImageViewCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkMemoryHeapFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkAccessFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkMemoryPropertyFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkQueryControlFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkQueryPipelineStatisticFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkQueryResultFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkQueueFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkShaderStageFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSparseMemoryBindFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkStencilFaceFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineStageFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSparseImageFormatFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSampleCountFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkAttachmentDescriptionFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDescriptorPoolCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDependencyFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkEventCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineLayoutCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkIndirectCommandsLayoutUsageFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkIndirectStateFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkPrivateDataSlotCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSubpassDescriptionFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkResolveModeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDescriptorBindingFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkConditionalRenderingFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkGeometryFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkGeometryInstanceFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkBuildAccelerationStructureFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkAccelerationStructureCreateFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkDeviceDiagnosticsConfigFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineCreationFeedbackFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPerformanceCounterDescriptionFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkSemaphoreWaitFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkToolPurposeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkAccessFlags2): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineStageFlags2): string = $toEnums(bitset)
proc `$`*(bitset: VkImageConstraintsInfoFlagsFUCHSIA): string = $toEnums(bitset)
proc `$`*(bitset: VkFormatFeatureFlags2): string = $toEnums(bitset)
proc `$`*(bitset: VkRenderingFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineDepthStencilStateCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkPipelineColorBlendStateCreateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkImageCompressionFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkImageCompressionFixedRateFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkExportMetalObjectTypeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkDeviceAddressBindingFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkBuildMicromapFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkMicromapCreateFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkMemoryDecompressionMethodFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkCompositeAlphaFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkDisplayPlaneAlphaFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkSurfaceTransformFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkDebugReportFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalMemoryHandleTypeFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalMemoryFeatureFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalMemoryHandleTypeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalMemoryFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalSemaphoreHandleTypeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalSemaphoreFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSemaphoreImportFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalFenceHandleTypeFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkExternalFenceFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkFenceImportFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkSurfaceCounterFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkPeerMemoryFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkMemoryAllocateFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDeviceGroupPresentModeFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkSwapchainCreateFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkSubgroupFeatureFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkDebugUtilsMessageSeverityFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkDebugUtilsMessageTypeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkSwapchainImageUsageFlagsANDROID): string = $toEnums(bitset)
proc `$`*(bitset: VkSubmitFlags): string = $toEnums(bitset)
proc `$`*(bitset: VkGraphicsPipelineLibraryFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkOpticalFlowGridSizeFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkOpticalFlowUsageFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkOpticalFlowSessionCreateFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkOpticalFlowExecuteFlagsNV): string = $toEnums(bitset)
proc `$`*(bitset: VkPresentScalingFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkPresentGravityFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoCodecOperationFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoChromaSubsamplingFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoComponentBitDepthFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoCapabilityFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoSessionCreateFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoCodingControlFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoDecodeUsageFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoDecodeCapabilityFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoDecodeH264PictureLayoutFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeUsageFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeContentFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeCapabilityFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeRateControlModeFlagsKHR): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH264CapabilityFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH264InputModeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH264OutputModeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH265CapabilityFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH265InputModeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH265OutputModeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH265CtbSizeFlagsEXT): string = $toEnums(bitset)
proc `$`*(bitset: VkVideoEncodeH265TransformBlockSizeFlagsEXT): string = $toEnums(bitset)
type
  VkGeometryFlagsNV* = VkGeometryFlagsKHR
  VkGeometryInstanceFlagsNV* = VkGeometryInstanceFlagsKHR
  VkBuildAccelerationStructureFlagsNV* = VkBuildAccelerationStructureFlagsKHR
  VkPrivateDataSlotCreateFlagsEXT* = VkPrivateDataSlotCreateFlags
  VkDescriptorUpdateTemplateCreateFlagsKHR* = VkDescriptorUpdateTemplateCreateFlags
  VkPipelineCreationFeedbackFlagsEXT* = VkPipelineCreationFeedbackFlags
  VkSemaphoreWaitFlagsKHR* = VkSemaphoreWaitFlags
  VkAccessFlags2KHR* = VkAccessFlags2
  VkPipelineStageFlags2KHR* = VkPipelineStageFlags2
  VkFormatFeatureFlags2KHR* = VkFormatFeatureFlags2
  VkRenderingFlagsKHR* = VkRenderingFlags
  VkPeerMemoryFeatureFlagsKHR* = VkPeerMemoryFeatureFlags
  VkMemoryAllocateFlagsKHR* = VkMemoryAllocateFlags
  VkCommandPoolTrimFlagsKHR* = VkCommandPoolTrimFlags
  VkExternalMemoryHandleTypeFlagsKHR* = VkExternalMemoryHandleTypeFlags
  VkExternalMemoryFeatureFlagsKHR* = VkExternalMemoryFeatureFlags
  VkExternalSemaphoreHandleTypeFlagsKHR* = VkExternalSemaphoreHandleTypeFlags
  VkExternalSemaphoreFeatureFlagsKHR* = VkExternalSemaphoreFeatureFlags
  VkSemaphoreImportFlagsKHR* = VkSemaphoreImportFlags
  VkExternalFenceHandleTypeFlagsKHR* = VkExternalFenceHandleTypeFlags
  VkExternalFenceFeatureFlagsKHR* = VkExternalFenceFeatureFlags
  VkFenceImportFlagsKHR* = VkFenceImportFlags
  VkDescriptorBindingFlagsEXT* = VkDescriptorBindingFlags
  VkResolveModeFlagsKHR* = VkResolveModeFlags
  VkToolPurposeFlagsEXT* = VkToolPurposeFlags
  VkSubmitFlagsKHR* = VkSubmitFlags
  VkPrivateDataSlotCreateFlagBitsEXT* = VkPrivateDataSlotCreateFlagBits
  VkDescriptorUpdateTemplateTypeKHR* = VkDescriptorUpdateTemplateType
  VkPointClippingBehaviorKHR* = VkPointClippingBehavior
  VkQueueGlobalPriorityEXT* = VkQueueGlobalPriorityKHR
  VkResolveModeFlagBitsKHR* = VkResolveModeFlagBits
  VkDescriptorBindingFlagBitsEXT* = VkDescriptorBindingFlagBits
  VkSemaphoreTypeKHR* = VkSemaphoreType
  VkGeometryFlagBitsNV* = VkGeometryFlagBitsKHR
  VkGeometryInstanceFlagBitsNV* = VkGeometryInstanceFlagBitsKHR
  VkBuildAccelerationStructureFlagBitsNV* = VkBuildAccelerationStructureFlagBitsKHR
  VkCopyAccelerationStructureModeNV* = VkCopyAccelerationStructureModeKHR
  VkAccelerationStructureTypeNV* = VkAccelerationStructureTypeKHR
  VkGeometryTypeNV* = VkGeometryTypeKHR
  VkRayTracingShaderGroupTypeNV* = VkRayTracingShaderGroupTypeKHR
  VkPipelineCreationFeedbackFlagBitsEXT* = VkPipelineCreationFeedbackFlagBits
  VkSemaphoreWaitFlagBitsKHR* = VkSemaphoreWaitFlagBits
  VkToolPurposeFlagBitsEXT* = VkToolPurposeFlagBits
  VkAccessFlagBits2KHR* = VkAccessFlagBits2
  VkPipelineStageFlagBits2KHR* = VkPipelineStageFlagBits2
  VkFormatFeatureFlagBits2KHR* = VkFormatFeatureFlagBits2
  VkRenderingFlagBitsKHR* = VkRenderingFlagBits
  VkExternalMemoryHandleTypeFlagBitsKHR* = VkExternalMemoryHandleTypeFlagBits
  VkExternalMemoryFeatureFlagBitsKHR* = VkExternalMemoryFeatureFlagBits
  VkExternalSemaphoreHandleTypeFlagBitsKHR* = VkExternalSemaphoreHandleTypeFlagBits
  VkExternalSemaphoreFeatureFlagBitsKHR* = VkExternalSemaphoreFeatureFlagBits
  VkSemaphoreImportFlagBitsKHR* = VkSemaphoreImportFlagBits
  VkExternalFenceHandleTypeFlagBitsKHR* = VkExternalFenceHandleTypeFlagBits
  VkExternalFenceFeatureFlagBitsKHR* = VkExternalFenceFeatureFlagBits
  VkFenceImportFlagBitsKHR* = VkFenceImportFlagBits
  VkPeerMemoryFeatureFlagBitsKHR* = VkPeerMemoryFeatureFlagBits
  VkMemoryAllocateFlagBitsKHR* = VkMemoryAllocateFlagBits
  VkTessellationDomainOriginKHR* = VkTessellationDomainOrigin
  VkSamplerYcbcrModelConversionKHR* = VkSamplerYcbcrModelConversion
  VkSamplerYcbcrRangeKHR* = VkSamplerYcbcrRange
  VkChromaLocationKHR* = VkChromaLocation
  VkSamplerReductionModeEXT* = VkSamplerReductionMode
  VkShaderFloatControlsIndependenceKHR* = VkShaderFloatControlsIndependence
  VkSubmitFlagBitsKHR* = VkSubmitFlagBits
  VkDriverIdKHR* = VkDriverId
type
  PFN_vkInternalAllocationNotification* = proc(pUserData: pointer, size: csize_t, allocationType: VkInternalAllocationType, allocationScope: VkSystemAllocationScope): void {.cdecl.}
  PFN_vkInternalFreeNotification* = proc(pUserData: pointer, size: csize_t, allocationType: VkInternalAllocationType, allocationScope: VkSystemAllocationScope): void {.cdecl.}
  PFN_vkReallocationFunction* = proc(pUserData: pointer, pOriginal: pointer, size: csize_t, alignment: csize_t, allocationScope: VkSystemAllocationScope): pointer {.cdecl.}
  PFN_vkAllocationFunction* = proc(pUserData: pointer, size: csize_t, alignment: csize_t, allocationScope: VkSystemAllocationScope): pointer {.cdecl.}
  PFN_vkFreeFunction* = proc(pUserData: pointer, pMemory: pointer): void {.cdecl.}
  PFN_vkVoidFunction* = proc(): void {.cdecl.}
  PFN_vkDebugReportCallbackEXT* = proc(flags: VkDebugReportFlagsEXT, objectType: VkDebugReportObjectTypeEXT, theobject: uint64, location: csize_t, messageCode: int32, pLayerPrefix: cstring, pMessage: cstring, pUserData: pointer): VkBool32 {.cdecl.}
  PFN_vkDebugUtilsMessengerCallbackEXT* = proc(messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageTypes: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT, pUserData: pointer): VkBool32 {.cdecl.}
  PFN_vkFaultCallbackFunction* = proc(unrecordedFaults: VkBool32, faultCount: uint32, pFaults: ptr VkFaultData): void {.cdecl.}
  PFN_vkDeviceMemoryReportCallbackEXT* = proc(pCallbackData: ptr VkDeviceMemoryReportCallbackDataEXT, pUserData: pointer): void {.cdecl.}
  PFN_vkGetInstanceProcAddrLUNARG* = proc(instance: VkInstance, pName: cstring): PFN_vkVoidFunction {.cdecl.}
  VkBaseOutStructure* = object
    sType*: VkStructureType
    pNext*: ptr VkBaseOutStructure
  VkBaseInStructure* = object
    sType*: VkStructureType
    pNext*: ptr VkBaseInStructure
  VkOffset2D* = object
    x*: int32
    y*: int32
  VkOffset3D* = object
    x*: int32
    y*: int32
    z*: int32
  VkExtent2D* = object
    width*: uint32
    height*: uint32
  VkExtent3D* = object
    width*: uint32
    height*: uint32
    depth*: uint32
  VkViewport* = object
    x*: float32
    y*: float32
    width*: float32
    height*: float32
    minDepth*: float32
    maxDepth*: float32
  VkRect2D* = object
    offset*: VkOffset2D
    extent*: VkExtent2D
  VkClearRect* = object
    rect*: VkRect2D
    baseArrayLayer*: uint32
    layerCount*: uint32
  VkComponentMapping* = object
    r*: VkComponentSwizzle
    g*: VkComponentSwizzle
    b*: VkComponentSwizzle
    a*: VkComponentSwizzle
  VkPhysicalDeviceProperties* = object
    apiVersion*: uint32
    driverVersion*: uint32
    vendorID*: uint32
    deviceID*: uint32
    deviceType*: VkPhysicalDeviceType
    deviceName*: array[VK_MAX_PHYSICAL_DEVICE_NAME_SIZE, char]
    pipelineCacheUUID*: array[VK_UUID_SIZE, uint8]
    limits*: VkPhysicalDeviceLimits
    sparseProperties*: VkPhysicalDeviceSparseProperties
  VkExtensionProperties* = object
    extensionName*: array[VK_MAX_EXTENSION_NAME_SIZE, char]
    specVersion*: uint32
  VkLayerProperties* = object
    layerName*: array[VK_MAX_EXTENSION_NAME_SIZE, char]
    specVersion*: uint32
    implementationVersion*: uint32
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
  VkApplicationInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    pApplicationName*: cstring
    applicationVersion*: uint32
    pEngineName*: cstring
    engineVersion*: uint32
    apiVersion*: uint32
  VkAllocationCallbacks* = object
    pUserData*: pointer
    pfnAllocation*: PFN_vkAllocationFunction
    pfnReallocation*: PFN_vkReallocationFunction
    pfnFree*: PFN_vkFreeFunction
    pfnInternalAllocation*: PFN_vkInternalAllocationNotification
    pfnInternalFree*: PFN_vkInternalFreeNotification
  VkDeviceQueueCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceQueueCreateFlags
    queueFamilyIndex*: uint32
    queueCount*: uint32
    pQueuePriorities*: ptr float32
  VkDeviceCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceCreateFlags
    queueCreateInfoCount*: uint32
    pQueueCreateInfos*: ptr VkDeviceQueueCreateInfo
    enabledLayerCount*: uint32
    ppEnabledLayerNames*: cstringArray
    enabledExtensionCount*: uint32
    ppEnabledExtensionNames*: cstringArray
    pEnabledFeatures*: ptr VkPhysicalDeviceFeatures
  VkInstanceCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkInstanceCreateFlags
    pApplicationInfo*: ptr VkApplicationInfo
    enabledLayerCount*: uint32
    ppEnabledLayerNames*: cstringArray
    enabledExtensionCount*: uint32
    ppEnabledExtensionNames*: cstringArray
  VkQueueFamilyProperties* = object
    queueFlags*: VkQueueFlags
    queueCount*: uint32
    timestampValidBits*: uint32
    minImageTransferGranularity*: VkExtent3D
  VkPhysicalDeviceMemoryProperties* = object
    memoryTypeCount*: uint32
    memoryTypes*: array[VK_MAX_MEMORY_TYPES, VkMemoryType]
    memoryHeapCount*: uint32
    memoryHeaps*: array[VK_MAX_MEMORY_HEAPS, VkMemoryHeap]
  VkMemoryAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    allocationSize*: VkDeviceSize
    memoryTypeIndex*: uint32
  VkMemoryRequirements* = object
    size*: VkDeviceSize
    alignment*: VkDeviceSize
    memoryTypeBits*: uint32
  VkSparseImageFormatProperties* = object
    aspectMask*: VkImageAspectFlags
    imageGranularity*: VkExtent3D
    flags*: VkSparseImageFormatFlags
  VkSparseImageMemoryRequirements* = object
    formatProperties*: VkSparseImageFormatProperties
    imageMipTailFirstLod*: uint32
    imageMipTailSize*: VkDeviceSize
    imageMipTailOffset*: VkDeviceSize
    imageMipTailStride*: VkDeviceSize
  VkMemoryType* = object
    propertyFlags*: VkMemoryPropertyFlags
    heapIndex*: uint32
  VkMemoryHeap* = object
    size*: VkDeviceSize
    flags*: VkMemoryHeapFlags
  VkMappedMemoryRange* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    offset*: VkDeviceSize
    size*: VkDeviceSize
  VkFormatProperties* = object
    linearTilingFeatures*: VkFormatFeatureFlags
    optimalTilingFeatures*: VkFormatFeatureFlags
    bufferFeatures*: VkFormatFeatureFlags
  VkImageFormatProperties* = object
    maxExtent*: VkExtent3D
    maxMipLevels*: uint32
    maxArrayLayers*: uint32
    sampleCounts*: VkSampleCountFlags
    maxResourceSize*: VkDeviceSize
  VkDescriptorBufferInfo* = object
    buffer*: VkBuffer
    offset*: VkDeviceSize
    range*: VkDeviceSize
  VkDescriptorImageInfo* = object
    sampler*: VkSampler
    imageView*: VkImageView
    imageLayout*: VkImageLayout
  VkWriteDescriptorSet* = object
    sType*: VkStructureType
    pNext*: pointer
    dstSet*: VkDescriptorSet
    dstBinding*: uint32
    dstArrayElement*: uint32
    descriptorCount*: uint32
    descriptorType*: VkDescriptorType
    pImageInfo*: ptr VkDescriptorImageInfo
    pBufferInfo*: ptr VkDescriptorBufferInfo
    pTexelBufferView*: ptr VkBufferView
  VkCopyDescriptorSet* = object
    sType*: VkStructureType
    pNext*: pointer
    srcSet*: VkDescriptorSet
    srcBinding*: uint32
    srcArrayElement*: uint32
    dstSet*: VkDescriptorSet
    dstBinding*: uint32
    dstArrayElement*: uint32
    descriptorCount*: uint32
  VkBufferCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkBufferCreateFlags
    size*: VkDeviceSize
    usage*: VkBufferUsageFlags
    sharingMode*: VkSharingMode
    queueFamilyIndexCount*: uint32
    pQueueFamilyIndices*: ptr uint32
  VkBufferViewCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkBufferViewCreateFlags
    buffer*: VkBuffer
    format*: VkFormat
    offset*: VkDeviceSize
    range*: VkDeviceSize
  VkImageSubresource* = object
    aspectMask*: VkImageAspectFlags
    mipLevel*: uint32
    arrayLayer*: uint32
  VkImageSubresourceLayers* = object
    aspectMask*: VkImageAspectFlags
    mipLevel*: uint32
    baseArrayLayer*: uint32
    layerCount*: uint32
  VkImageSubresourceRange* = object
    aspectMask*: VkImageAspectFlags
    baseMipLevel*: uint32
    levelCount*: uint32
    baseArrayLayer*: uint32
    layerCount*: uint32
  VkMemoryBarrier* = object
    sType*: VkStructureType
    pNext*: pointer
    srcAccessMask*: VkAccessFlags
    dstAccessMask*: VkAccessFlags
  VkBufferMemoryBarrier* = object
    sType*: VkStructureType
    pNext*: pointer
    srcAccessMask*: VkAccessFlags
    dstAccessMask*: VkAccessFlags
    srcQueueFamilyIndex*: uint32
    dstQueueFamilyIndex*: uint32
    buffer*: VkBuffer
    offset*: VkDeviceSize
    size*: VkDeviceSize
  VkImageMemoryBarrier* = object
    sType*: VkStructureType
    pNext*: pointer
    srcAccessMask*: VkAccessFlags
    dstAccessMask*: VkAccessFlags
    oldLayout*: VkImageLayout
    newLayout*: VkImageLayout
    srcQueueFamilyIndex*: uint32
    dstQueueFamilyIndex*: uint32
    image*: VkImage
    subresourceRange*: VkImageSubresourceRange
  VkImageCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkImageCreateFlags
    imageType*: VkImageType
    format*: VkFormat
    extent*: VkExtent3D
    mipLevels*: uint32
    arrayLayers*: uint32
    samples*: VkSampleCountFlagBits
    tiling*: VkImageTiling
    usage*: VkImageUsageFlags
    sharingMode*: VkSharingMode
    queueFamilyIndexCount*: uint32
    pQueueFamilyIndices*: ptr uint32
    initialLayout*: VkImageLayout
  VkSubresourceLayout* = object
    offset*: VkDeviceSize
    size*: VkDeviceSize
    rowPitch*: VkDeviceSize
    arrayPitch*: VkDeviceSize
    depthPitch*: VkDeviceSize
  VkImageViewCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkImageViewCreateFlags
    image*: VkImage
    viewType*: VkImageViewType
    format*: VkFormat
    components*: VkComponentMapping
    subresourceRange*: VkImageSubresourceRange
  VkBufferCopy* = object
    srcOffset*: VkDeviceSize
    dstOffset*: VkDeviceSize
    size*: VkDeviceSize
  VkSparseMemoryBind* = object
    resourceOffset*: VkDeviceSize
    size*: VkDeviceSize
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
    flags*: VkSparseMemoryBindFlags
  VkSparseImageMemoryBind* = object
    subresource*: VkImageSubresource
    offset*: VkOffset3D
    extent*: VkExtent3D
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
    flags*: VkSparseMemoryBindFlags
  VkSparseBufferMemoryBindInfo* = object
    buffer*: VkBuffer
    bindCount*: uint32
    pBinds*: ptr VkSparseMemoryBind
  VkSparseImageOpaqueMemoryBindInfo* = object
    image*: VkImage
    bindCount*: uint32
    pBinds*: ptr VkSparseMemoryBind
  VkSparseImageMemoryBindInfo* = object
    image*: VkImage
    bindCount*: uint32
    pBinds*: ptr VkSparseImageMemoryBind
  VkBindSparseInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreCount*: uint32
    pWaitSemaphores*: ptr VkSemaphore
    bufferBindCount*: uint32
    pBufferBinds*: ptr VkSparseBufferMemoryBindInfo
    imageOpaqueBindCount*: uint32
    pImageOpaqueBinds*: ptr VkSparseImageOpaqueMemoryBindInfo
    imageBindCount*: uint32
    pImageBinds*: ptr VkSparseImageMemoryBindInfo
    signalSemaphoreCount*: uint32
    pSignalSemaphores*: ptr VkSemaphore
  VkImageCopy* = object
    srcSubresource*: VkImageSubresourceLayers
    srcOffset*: VkOffset3D
    dstSubresource*: VkImageSubresourceLayers
    dstOffset*: VkOffset3D
    extent*: VkExtent3D
  VkImageBlit* = object
    srcSubresource*: VkImageSubresourceLayers
    srcOffsets*: array[2, VkOffset3D]
    dstSubresource*: VkImageSubresourceLayers
    dstOffsets*: array[2, VkOffset3D]
  VkBufferImageCopy* = object
    bufferOffset*: VkDeviceSize
    bufferRowLength*: uint32
    bufferImageHeight*: uint32
    imageSubresource*: VkImageSubresourceLayers
    imageOffset*: VkOffset3D
    imageExtent*: VkExtent3D
  VkCopyMemoryIndirectCommandNV* = object
    srcAddress*: VkDeviceAddress
    dstAddress*: VkDeviceAddress
    size*: VkDeviceSize
  VkCopyMemoryToImageIndirectCommandNV* = object
    srcAddress*: VkDeviceAddress
    bufferRowLength*: uint32
    bufferImageHeight*: uint32
    imageSubresource*: VkImageSubresourceLayers
    imageOffset*: VkOffset3D
    imageExtent*: VkExtent3D
  VkImageResolve* = object
    srcSubresource*: VkImageSubresourceLayers
    srcOffset*: VkOffset3D
    dstSubresource*: VkImageSubresourceLayers
    dstOffset*: VkOffset3D
    extent*: VkExtent3D
  VkShaderModuleCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkShaderModuleCreateFlags
    codeSize*: csize_t
    pCode*: ptr uint32
  VkDescriptorSetLayoutBinding* = object
    binding*: uint32
    descriptorType*: VkDescriptorType
    descriptorCount*: uint32
    stageFlags*: VkShaderStageFlags
    pImmutableSamplers*: ptr VkSampler
  VkDescriptorSetLayoutCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDescriptorSetLayoutCreateFlags
    bindingCount*: uint32
    pBindings*: ptr VkDescriptorSetLayoutBinding
  VkDescriptorPoolSize* = object
    thetype*: VkDescriptorType
    descriptorCount*: uint32
  VkDescriptorPoolCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDescriptorPoolCreateFlags
    maxSets*: uint32
    poolSizeCount*: uint32
    pPoolSizes*: ptr VkDescriptorPoolSize
  VkDescriptorSetAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorPool*: VkDescriptorPool
    descriptorSetCount*: uint32
    pSetLayouts*: ptr VkDescriptorSetLayout
  VkSpecializationMapEntry* = object
    constantID*: uint32
    offset*: uint32
    size*: csize_t
  VkSpecializationInfo* = object
    mapEntryCount*: uint32
    pMapEntries*: ptr VkSpecializationMapEntry
    dataSize*: csize_t
    pData*: pointer
  VkPipelineShaderStageCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineShaderStageCreateFlags
    stage*: VkShaderStageFlagBits
    module*: VkShaderModule
    pName*: cstring
    pSpecializationInfo*: ptr VkSpecializationInfo
  VkComputePipelineCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCreateFlags
    stage*: VkPipelineShaderStageCreateInfo
    layout*: VkPipelineLayout
    basePipelineHandle*: VkPipeline
    basePipelineIndex*: int32
  VkVertexInputBindingDescription* = object
    binding*: uint32
    stride*: uint32
    inputRate*: VkVertexInputRate
  VkVertexInputAttributeDescription* = object
    location*: uint32
    binding*: uint32
    format*: VkFormat
    offset*: uint32
  VkPipelineVertexInputStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineVertexInputStateCreateFlags
    vertexBindingDescriptionCount*: uint32
    pVertexBindingDescriptions*: ptr VkVertexInputBindingDescription
    vertexAttributeDescriptionCount*: uint32
    pVertexAttributeDescriptions*: ptr VkVertexInputAttributeDescription
  VkPipelineInputAssemblyStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineInputAssemblyStateCreateFlags
    topology*: VkPrimitiveTopology
    primitiveRestartEnable*: VkBool32
  VkPipelineTessellationStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineTessellationStateCreateFlags
    patchControlPoints*: uint32
  VkPipelineViewportStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineViewportStateCreateFlags
    viewportCount*: uint32
    pViewports*: ptr VkViewport
    scissorCount*: uint32
    pScissors*: ptr VkRect2D
  VkPipelineRasterizationStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineRasterizationStateCreateFlags
    depthClampEnable*: VkBool32
    rasterizerDiscardEnable*: VkBool32
    polygonMode*: VkPolygonMode
    cullMode*: VkCullModeFlags
    frontFace*: VkFrontFace
    depthBiasEnable*: VkBool32
    depthBiasConstantFactor*: float32
    depthBiasClamp*: float32
    depthBiasSlopeFactor*: float32
    lineWidth*: float32
  VkPipelineMultisampleStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineMultisampleStateCreateFlags
    rasterizationSamples*: VkSampleCountFlagBits
    sampleShadingEnable*: VkBool32
    minSampleShading*: float32
    pSampleMask*: ptr VkSampleMask
    alphaToCoverageEnable*: VkBool32
    alphaToOneEnable*: VkBool32
  VkPipelineColorBlendAttachmentState* = object
    blendEnable*: VkBool32
    srcColorBlendFactor*: VkBlendFactor
    dstColorBlendFactor*: VkBlendFactor
    colorBlendOp*: VkBlendOp
    srcAlphaBlendFactor*: VkBlendFactor
    dstAlphaBlendFactor*: VkBlendFactor
    alphaBlendOp*: VkBlendOp
    colorWriteMask*: VkColorComponentFlags
  VkPipelineColorBlendStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineColorBlendStateCreateFlags
    logicOpEnable*: VkBool32
    logicOp*: VkLogicOp
    attachmentCount*: uint32
    pAttachments*: ptr VkPipelineColorBlendAttachmentState
    blendConstants*: array[4, float32]
  VkPipelineDynamicStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineDynamicStateCreateFlags
    dynamicStateCount*: uint32
    pDynamicStates*: ptr VkDynamicState
  VkStencilOpState* = object
    failOp*: VkStencilOp
    passOp*: VkStencilOp
    depthFailOp*: VkStencilOp
    compareOp*: VkCompareOp
    compareMask*: uint32
    writeMask*: uint32
    reference*: uint32
  VkPipelineDepthStencilStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineDepthStencilStateCreateFlags
    depthTestEnable*: VkBool32
    depthWriteEnable*: VkBool32
    depthCompareOp*: VkCompareOp
    depthBoundsTestEnable*: VkBool32
    stencilTestEnable*: VkBool32
    front*: VkStencilOpState
    back*: VkStencilOpState
    minDepthBounds*: float32
    maxDepthBounds*: float32
  VkGraphicsPipelineCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCreateFlags
    stageCount*: uint32
    pStages*: ptr VkPipelineShaderStageCreateInfo
    pVertexInputState*: ptr VkPipelineVertexInputStateCreateInfo
    pInputAssemblyState*: ptr VkPipelineInputAssemblyStateCreateInfo
    pTessellationState*: ptr VkPipelineTessellationStateCreateInfo
    pViewportState*: ptr VkPipelineViewportStateCreateInfo
    pRasterizationState*: ptr VkPipelineRasterizationStateCreateInfo
    pMultisampleState*: ptr VkPipelineMultisampleStateCreateInfo
    pDepthStencilState*: ptr VkPipelineDepthStencilStateCreateInfo
    pColorBlendState*: ptr VkPipelineColorBlendStateCreateInfo
    pDynamicState*: ptr VkPipelineDynamicStateCreateInfo
    layout*: VkPipelineLayout
    renderPass*: VkRenderPass
    subpass*: uint32
    basePipelineHandle*: VkPipeline
    basePipelineIndex*: int32
  VkPipelineCacheCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCacheCreateFlags
    initialDataSize*: csize_t
    pInitialData*: pointer
  VkPipelineCacheHeaderVersionOne* = object
    headerSize*: uint32
    headerVersion*: VkPipelineCacheHeaderVersion
    vendorID*: uint32
    deviceID*: uint32
    pipelineCacheUUID*: array[VK_UUID_SIZE, uint8]
  VkPipelineCacheStageValidationIndexEntry* = object
    codeSize*: uint64
    codeOffset*: uint64
  VkPipelineCacheSafetyCriticalIndexEntry* = object
    pipelineIdentifier*: array[VK_UUID_SIZE, uint8]
    pipelineMemorySize*: uint64
    jsonSize*: uint64
    jsonOffset*: uint64
    stageIndexCount*: uint32
    stageIndexStride*: uint32
    stageIndexOffset*: uint64
  VkPipelineCacheHeaderVersionSafetyCriticalOne* = object
    headerVersionOne*: VkPipelineCacheHeaderVersionOne
    validationVersion*: VkPipelineCacheValidationVersion
    implementationData*: uint32
    pipelineIndexCount*: uint32
    pipelineIndexStride*: uint32
    pipelineIndexOffset*: uint64
  VkPushConstantRange* = object
    stageFlags*: VkShaderStageFlags
    offset*: uint32
    size*: uint32
  VkPipelineLayoutCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineLayoutCreateFlags
    setLayoutCount*: uint32
    pSetLayouts*: ptr VkDescriptorSetLayout
    pushConstantRangeCount*: uint32
    pPushConstantRanges*: ptr VkPushConstantRange
  VkSamplerCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSamplerCreateFlags
    magFilter*: VkFilter
    minFilter*: VkFilter
    mipmapMode*: VkSamplerMipmapMode
    addressModeU*: VkSamplerAddressMode
    addressModeV*: VkSamplerAddressMode
    addressModeW*: VkSamplerAddressMode
    mipLodBias*: float32
    anisotropyEnable*: VkBool32
    maxAnisotropy*: float32
    compareEnable*: VkBool32
    compareOp*: VkCompareOp
    minLod*: float32
    maxLod*: float32
    borderColor*: VkBorderColor
    unnormalizedCoordinates*: VkBool32
  VkCommandPoolCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkCommandPoolCreateFlags
    queueFamilyIndex*: uint32
  VkCommandBufferAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    commandPool*: VkCommandPool
    level*: VkCommandBufferLevel
    commandBufferCount*: uint32
  VkCommandBufferInheritanceInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    renderPass*: VkRenderPass
    subpass*: uint32
    framebuffer*: VkFramebuffer
    occlusionQueryEnable*: VkBool32
    queryFlags*: VkQueryControlFlags
    pipelineStatistics*: VkQueryPipelineStatisticFlags
  VkCommandBufferBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkCommandBufferUsageFlags
    pInheritanceInfo*: ptr VkCommandBufferInheritanceInfo
  VkRenderPassBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    renderPass*: VkRenderPass
    framebuffer*: VkFramebuffer
    renderArea*: VkRect2D
    clearValueCount*: uint32
    pClearValues*: ptr VkClearValue
  VkClearColorValue* {.union.} = object
    float32*: array[4, float32]
    int32*: array[4, int32]
    uint32*: array[4, uint32]
  VkClearDepthStencilValue* = object
    depth*: float32
    stencil*: uint32
  VkClearValue* {.union.} = object
    color*: VkClearColorValue
    depthStencil*: VkClearDepthStencilValue
  VkClearAttachment* = object
    aspectMask*: VkImageAspectFlags
    colorAttachment*: uint32
    clearValue*: VkClearValue
  VkAttachmentDescription* = object
    flags*: VkAttachmentDescriptionFlags
    format*: VkFormat
    samples*: VkSampleCountFlagBits
    loadOp*: VkAttachmentLoadOp
    storeOp*: VkAttachmentStoreOp
    stencilLoadOp*: VkAttachmentLoadOp
    stencilStoreOp*: VkAttachmentStoreOp
    initialLayout*: VkImageLayout
    finalLayout*: VkImageLayout
  VkAttachmentReference* = object
    attachment*: uint32
    layout*: VkImageLayout
  VkSubpassDescription* = object
    flags*: VkSubpassDescriptionFlags
    pipelineBindPoint*: VkPipelineBindPoint
    inputAttachmentCount*: uint32
    pInputAttachments*: ptr VkAttachmentReference
    colorAttachmentCount*: uint32
    pColorAttachments*: ptr VkAttachmentReference
    pResolveAttachments*: ptr VkAttachmentReference
    pDepthStencilAttachment*: ptr VkAttachmentReference
    preserveAttachmentCount*: uint32
    pPreserveAttachments*: ptr uint32
  VkSubpassDependency* = object
    srcSubpass*: uint32
    dstSubpass*: uint32
    srcStageMask*: VkPipelineStageFlags
    dstStageMask*: VkPipelineStageFlags
    srcAccessMask*: VkAccessFlags
    dstAccessMask*: VkAccessFlags
    dependencyFlags*: VkDependencyFlags
  VkRenderPassCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkRenderPassCreateFlags
    attachmentCount*: uint32
    pAttachments*: ptr VkAttachmentDescription
    subpassCount*: uint32
    pSubpasses*: ptr VkSubpassDescription
    dependencyCount*: uint32
    pDependencies*: ptr VkSubpassDependency
  VkEventCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkEventCreateFlags
  VkFenceCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkFenceCreateFlags
  VkPhysicalDeviceFeatures* = object
    robustBufferAccess*: VkBool32
    fullDrawIndexUint32*: VkBool32
    imageCubeArray*: VkBool32
    independentBlend*: VkBool32
    geometryShader*: VkBool32
    tessellationShader*: VkBool32
    sampleRateShading*: VkBool32
    dualSrcBlend*: VkBool32
    logicOp*: VkBool32
    multiDrawIndirect*: VkBool32
    drawIndirectFirstInstance*: VkBool32
    depthClamp*: VkBool32
    depthBiasClamp*: VkBool32
    fillModeNonSolid*: VkBool32
    depthBounds*: VkBool32
    wideLines*: VkBool32
    largePoints*: VkBool32
    alphaToOne*: VkBool32
    multiViewport*: VkBool32
    samplerAnisotropy*: VkBool32
    textureCompressionETC2*: VkBool32
    textureCompressionASTC_LDR*: VkBool32
    textureCompressionBC*: VkBool32
    occlusionQueryPrecise*: VkBool32
    pipelineStatisticsQuery*: VkBool32
    vertexPipelineStoresAndAtomics*: VkBool32
    fragmentStoresAndAtomics*: VkBool32
    shaderTessellationAndGeometryPointSize*: VkBool32
    shaderImageGatherExtended*: VkBool32
    shaderStorageImageExtendedFormats*: VkBool32
    shaderStorageImageMultisample*: VkBool32
    shaderStorageImageReadWithoutFormat*: VkBool32
    shaderStorageImageWriteWithoutFormat*: VkBool32
    shaderUniformBufferArrayDynamicIndexing*: VkBool32
    shaderSampledImageArrayDynamicIndexing*: VkBool32
    shaderStorageBufferArrayDynamicIndexing*: VkBool32
    shaderStorageImageArrayDynamicIndexing*: VkBool32
    shaderClipDistance*: VkBool32
    shaderCullDistance*: VkBool32
    shaderFloat64*: VkBool32
    shaderInt64*: VkBool32
    shaderInt16*: VkBool32
    shaderResourceResidency*: VkBool32
    shaderResourceMinLod*: VkBool32
    sparseBinding*: VkBool32
    sparseResidencyBuffer*: VkBool32
    sparseResidencyImage2D*: VkBool32
    sparseResidencyImage3D*: VkBool32
    sparseResidency2Samples*: VkBool32
    sparseResidency4Samples*: VkBool32
    sparseResidency8Samples*: VkBool32
    sparseResidency16Samples*: VkBool32
    sparseResidencyAliased*: VkBool32
    variableMultisampleRate*: VkBool32
    inheritedQueries*: VkBool32
  VkPhysicalDeviceSparseProperties* = object
    residencyStandard2DBlockShape*: VkBool32
    residencyStandard2DMultisampleBlockShape*: VkBool32
    residencyStandard3DBlockShape*: VkBool32
    residencyAlignedMipSize*: VkBool32
    residencyNonResidentStrict*: VkBool32
  VkPhysicalDeviceLimits* = object
    maxImageDimension1D*: uint32
    maxImageDimension2D*: uint32
    maxImageDimension3D*: uint32
    maxImageDimensionCube*: uint32
    maxImageArrayLayers*: uint32
    maxTexelBufferElements*: uint32
    maxUniformBufferRange*: uint32
    maxStorageBufferRange*: uint32
    maxPushConstantsSize*: uint32
    maxMemoryAllocationCount*: uint32
    maxSamplerAllocationCount*: uint32
    bufferImageGranularity*: VkDeviceSize
    sparseAddressSpaceSize*: VkDeviceSize
    maxBoundDescriptorSets*: uint32
    maxPerStageDescriptorSamplers*: uint32
    maxPerStageDescriptorUniformBuffers*: uint32
    maxPerStageDescriptorStorageBuffers*: uint32
    maxPerStageDescriptorSampledImages*: uint32
    maxPerStageDescriptorStorageImages*: uint32
    maxPerStageDescriptorInputAttachments*: uint32
    maxPerStageResources*: uint32
    maxDescriptorSetSamplers*: uint32
    maxDescriptorSetUniformBuffers*: uint32
    maxDescriptorSetUniformBuffersDynamic*: uint32
    maxDescriptorSetStorageBuffers*: uint32
    maxDescriptorSetStorageBuffersDynamic*: uint32
    maxDescriptorSetSampledImages*: uint32
    maxDescriptorSetStorageImages*: uint32
    maxDescriptorSetInputAttachments*: uint32
    maxVertexInputAttributes*: uint32
    maxVertexInputBindings*: uint32
    maxVertexInputAttributeOffset*: uint32
    maxVertexInputBindingStride*: uint32
    maxVertexOutputComponents*: uint32
    maxTessellationGenerationLevel*: uint32
    maxTessellationPatchSize*: uint32
    maxTessellationControlPerVertexInputComponents*: uint32
    maxTessellationControlPerVertexOutputComponents*: uint32
    maxTessellationControlPerPatchOutputComponents*: uint32
    maxTessellationControlTotalOutputComponents*: uint32
    maxTessellationEvaluationInputComponents*: uint32
    maxTessellationEvaluationOutputComponents*: uint32
    maxGeometryShaderInvocations*: uint32
    maxGeometryInputComponents*: uint32
    maxGeometryOutputComponents*: uint32
    maxGeometryOutputVertices*: uint32
    maxGeometryTotalOutputComponents*: uint32
    maxFragmentInputComponents*: uint32
    maxFragmentOutputAttachments*: uint32
    maxFragmentDualSrcAttachments*: uint32
    maxFragmentCombinedOutputResources*: uint32
    maxComputeSharedMemorySize*: uint32
    maxComputeWorkGroupCount*: array[3, uint32]
    maxComputeWorkGroupInvocations*: uint32
    maxComputeWorkGroupSize*: array[3, uint32]
    subPixelPrecisionBits*: uint32
    subTexelPrecisionBits*: uint32
    mipmapPrecisionBits*: uint32
    maxDrawIndexedIndexValue*: uint32
    maxDrawIndirectCount*: uint32
    maxSamplerLodBias*: float32
    maxSamplerAnisotropy*: float32
    maxViewports*: uint32
    maxViewportDimensions*: array[2, uint32]
    viewportBoundsRange*: array[2, float32]
    viewportSubPixelBits*: uint32
    minMemoryMapAlignment*: csize_t
    minTexelBufferOffsetAlignment*: VkDeviceSize
    minUniformBufferOffsetAlignment*: VkDeviceSize
    minStorageBufferOffsetAlignment*: VkDeviceSize
    minTexelOffset*: int32
    maxTexelOffset*: uint32
    minTexelGatherOffset*: int32
    maxTexelGatherOffset*: uint32
    minInterpolationOffset*: float32
    maxInterpolationOffset*: float32
    subPixelInterpolationOffsetBits*: uint32
    maxFramebufferWidth*: uint32
    maxFramebufferHeight*: uint32
    maxFramebufferLayers*: uint32
    framebufferColorSampleCounts*: VkSampleCountFlags
    framebufferDepthSampleCounts*: VkSampleCountFlags
    framebufferStencilSampleCounts*: VkSampleCountFlags
    framebufferNoAttachmentsSampleCounts*: VkSampleCountFlags
    maxColorAttachments*: uint32
    sampledImageColorSampleCounts*: VkSampleCountFlags
    sampledImageIntegerSampleCounts*: VkSampleCountFlags
    sampledImageDepthSampleCounts*: VkSampleCountFlags
    sampledImageStencilSampleCounts*: VkSampleCountFlags
    storageImageSampleCounts*: VkSampleCountFlags
    maxSampleMaskWords*: uint32
    timestampComputeAndGraphics*: VkBool32
    timestampPeriod*: float32
    maxClipDistances*: uint32
    maxCullDistances*: uint32
    maxCombinedClipAndCullDistances*: uint32
    discreteQueuePriorities*: uint32
    pointSizeRange*: array[2, float32]
    lineWidthRange*: array[2, float32]
    pointSizeGranularity*: float32
    lineWidthGranularity*: float32
    strictLines*: VkBool32
    standardSampleLocations*: VkBool32
    optimalBufferCopyOffsetAlignment*: VkDeviceSize
    optimalBufferCopyRowPitchAlignment*: VkDeviceSize
    nonCoherentAtomSize*: VkDeviceSize
  VkSemaphoreCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSemaphoreCreateFlags
  VkQueryPoolCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkQueryPoolCreateFlags
    queryType*: VkQueryType
    queryCount*: uint32
    pipelineStatistics*: VkQueryPipelineStatisticFlags
  VkFramebufferCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkFramebufferCreateFlags
    renderPass*: VkRenderPass
    attachmentCount*: uint32
    pAttachments*: ptr VkImageView
    width*: uint32
    height*: uint32
    layers*: uint32
  VkDrawIndirectCommand* = object
    vertexCount*: uint32
    instanceCount*: uint32
    firstVertex*: uint32
    firstInstance*: uint32
  VkDrawIndexedIndirectCommand* = object
    indexCount*: uint32
    instanceCount*: uint32
    firstIndex*: uint32
    vertexOffset*: int32
    firstInstance*: uint32
  VkDispatchIndirectCommand* = object
    x*: uint32
    y*: uint32
    z*: uint32
  VkMultiDrawInfoEXT* = object
    firstVertex*: uint32
    vertexCount*: uint32
  VkMultiDrawIndexedInfoEXT* = object
    firstIndex*: uint32
    indexCount*: uint32
    vertexOffset*: int32
  VkSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreCount*: uint32
    pWaitSemaphores*: ptr VkSemaphore
    pWaitDstStageMask*: ptr VkPipelineStageFlags
    commandBufferCount*: uint32
    pCommandBuffers*: ptr VkCommandBuffer
    signalSemaphoreCount*: uint32
    pSignalSemaphores*: ptr VkSemaphore
  VkDisplayPropertiesKHR* = object
    display*: VkDisplayKHR
    displayName*: cstring
    physicalDimensions*: VkExtent2D
    physicalResolution*: VkExtent2D
    supportedTransforms*: VkSurfaceTransformFlagsKHR
    planeReorderPossible*: VkBool32
    persistentContent*: VkBool32
  VkDisplayPlanePropertiesKHR* = object
    currentDisplay*: VkDisplayKHR
    currentStackIndex*: uint32
  VkDisplayModeParametersKHR* = object
    visibleRegion*: VkExtent2D
    refreshRate*: uint32
  VkDisplayModePropertiesKHR* = object
    displayMode*: VkDisplayModeKHR
    parameters*: VkDisplayModeParametersKHR
  VkDisplayModeCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDisplayModeCreateFlagsKHR
    parameters*: VkDisplayModeParametersKHR
  VkDisplayPlaneCapabilitiesKHR* = object
    supportedAlpha*: VkDisplayPlaneAlphaFlagsKHR
    minSrcPosition*: VkOffset2D
    maxSrcPosition*: VkOffset2D
    minSrcExtent*: VkExtent2D
    maxSrcExtent*: VkExtent2D
    minDstPosition*: VkOffset2D
    maxDstPosition*: VkOffset2D
    minDstExtent*: VkExtent2D
    maxDstExtent*: VkExtent2D
  VkDisplaySurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDisplaySurfaceCreateFlagsKHR
    displayMode*: VkDisplayModeKHR
    planeIndex*: uint32
    planeStackIndex*: uint32
    transform*: VkSurfaceTransformFlagBitsKHR
    globalAlpha*: float32
    alphaMode*: VkDisplayPlaneAlphaFlagBitsKHR
    imageExtent*: VkExtent2D
  VkDisplayPresentInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    srcRect*: VkRect2D
    dstRect*: VkRect2D
    persistent*: VkBool32
  VkSurfaceCapabilitiesKHR* = object
    minImageCount*: uint32
    maxImageCount*: uint32
    currentExtent*: VkExtent2D
    minImageExtent*: VkExtent2D
    maxImageExtent*: VkExtent2D
    maxImageArrayLayers*: uint32
    supportedTransforms*: VkSurfaceTransformFlagsKHR
    currentTransform*: VkSurfaceTransformFlagBitsKHR
    supportedCompositeAlpha*: VkCompositeAlphaFlagsKHR
    supportedUsageFlags*: VkImageUsageFlags
  VkSurfaceFormatKHR* = object
    format*: VkFormat
    colorSpace*: VkColorSpaceKHR
  VkSwapchainCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSwapchainCreateFlagsKHR
    surface*: VkSurfaceKHR
    minImageCount*: uint32
    imageFormat*: VkFormat
    imageColorSpace*: VkColorSpaceKHR
    imageExtent*: VkExtent2D
    imageArrayLayers*: uint32
    imageUsage*: VkImageUsageFlags
    imageSharingMode*: VkSharingMode
    queueFamilyIndexCount*: uint32
    pQueueFamilyIndices*: ptr uint32
    preTransform*: VkSurfaceTransformFlagBitsKHR
    compositeAlpha*: VkCompositeAlphaFlagBitsKHR
    presentMode*: VkPresentModeKHR
    clipped*: VkBool32
    oldSwapchain*: VkSwapchainKHR
  VkPresentInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreCount*: uint32
    pWaitSemaphores*: ptr VkSemaphore
    swapchainCount*: uint32
    pSwapchains*: ptr VkSwapchainKHR
    pImageIndices*: ptr uint32
    pResults*: ptr VkResult
  VkDebugReportCallbackCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDebugReportFlagsEXT
    pfnCallback*: PFN_vkDebugReportCallbackEXT
    pUserData*: pointer
  VkValidationFlagsEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    disabledValidationCheckCount*: uint32
    pDisabledValidationChecks*: ptr VkValidationCheckEXT
  VkValidationFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    enabledValidationFeatureCount*: uint32
    pEnabledValidationFeatures*: ptr VkValidationFeatureEnableEXT
    disabledValidationFeatureCount*: uint32
    pDisabledValidationFeatures*: ptr VkValidationFeatureDisableEXT
  VkApplicationParametersEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    vendorID*: uint32
    deviceID*: uint32
    key*: uint32
    value*: uint64
  VkPipelineRasterizationStateRasterizationOrderAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    rasterizationOrder*: VkRasterizationOrderAMD
  VkDebugMarkerObjectNameInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    objectType*: VkDebugReportObjectTypeEXT
    theobject*: uint64
    pObjectName*: cstring
  VkDebugMarkerObjectTagInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    objectType*: VkDebugReportObjectTypeEXT
    theobject*: uint64
    tagName*: uint64
    tagSize*: csize_t
    pTag*: pointer
  VkDebugMarkerMarkerInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pMarkerName*: cstring
    color*: array[4, float32]
  VkDedicatedAllocationImageCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    dedicatedAllocation*: VkBool32
  VkDedicatedAllocationBufferCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    dedicatedAllocation*: VkBool32
  VkDedicatedAllocationMemoryAllocateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
    buffer*: VkBuffer
  VkExternalImageFormatPropertiesNV* = object
    imageFormatProperties*: VkImageFormatProperties
    externalMemoryFeatures*: VkExternalMemoryFeatureFlagsNV
    exportFromImportedHandleTypes*: VkExternalMemoryHandleTypeFlagsNV
    compatibleHandleTypes*: VkExternalMemoryHandleTypeFlagsNV
  VkExternalMemoryImageCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalMemoryHandleTypeFlagsNV
  VkExportMemoryAllocateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalMemoryHandleTypeFlagsNV
  VkPhysicalDeviceDeviceGeneratedCommandsFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceGeneratedCommands*: VkBool32
  VkDevicePrivateDataCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    privateDataSlotRequestCount*: uint32
  VkDevicePrivateDataCreateInfoEXT* = object
  VkPrivateDataSlotCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPrivateDataSlotCreateFlags
  VkPrivateDataSlotCreateInfoEXT* = object
  VkPhysicalDevicePrivateDataFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    privateData*: VkBool32
  VkPhysicalDevicePrivateDataFeaturesEXT* = object
  VkPhysicalDeviceDeviceGeneratedCommandsPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    maxGraphicsShaderGroupCount*: uint32
    maxIndirectSequenceCount*: uint32
    maxIndirectCommandsTokenCount*: uint32
    maxIndirectCommandsStreamCount*: uint32
    maxIndirectCommandsTokenOffset*: uint32
    maxIndirectCommandsStreamStride*: uint32
    minSequencesCountBufferOffsetAlignment*: uint32
    minSequencesIndexBufferOffsetAlignment*: uint32
    minIndirectCommandsBufferOffsetAlignment*: uint32
  VkPhysicalDeviceMultiDrawPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxMultiDrawCount*: uint32
  VkGraphicsShaderGroupCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    stageCount*: uint32
    pStages*: ptr VkPipelineShaderStageCreateInfo
    pVertexInputState*: ptr VkPipelineVertexInputStateCreateInfo
    pTessellationState*: ptr VkPipelineTessellationStateCreateInfo
  VkGraphicsPipelineShaderGroupsCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    groupCount*: uint32
    pGroups*: ptr VkGraphicsShaderGroupCreateInfoNV
    pipelineCount*: uint32
    pPipelines*: ptr VkPipeline
  VkBindShaderGroupIndirectCommandNV* = object
    groupIndex*: uint32
  VkBindIndexBufferIndirectCommandNV* = object
    bufferAddress*: VkDeviceAddress
    size*: uint32
    indexType*: VkIndexType
  VkBindVertexBufferIndirectCommandNV* = object
    bufferAddress*: VkDeviceAddress
    size*: uint32
    stride*: uint32
  VkSetStateFlagsIndirectCommandNV* = object
    data*: uint32
  VkIndirectCommandsStreamNV* = object
    buffer*: VkBuffer
    offset*: VkDeviceSize
  VkIndirectCommandsLayoutTokenNV* = object
    sType*: VkStructureType
    pNext*: pointer
    tokenType*: VkIndirectCommandsTokenTypeNV
    stream*: uint32
    offset*: uint32
    vertexBindingUnit*: uint32
    vertexDynamicStride*: VkBool32
    pushconstantPipelineLayout*: VkPipelineLayout
    pushconstantShaderStageFlags*: VkShaderStageFlags
    pushconstantOffset*: uint32
    pushconstantSize*: uint32
    indirectStateFlags*: VkIndirectStateFlagsNV
    indexTypeCount*: uint32
    pIndexTypes*: ptr VkIndexType
    pIndexTypeValues*: ptr uint32
  VkIndirectCommandsLayoutCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkIndirectCommandsLayoutUsageFlagsNV
    pipelineBindPoint*: VkPipelineBindPoint
    tokenCount*: uint32
    pTokens*: ptr VkIndirectCommandsLayoutTokenNV
    streamCount*: uint32
    pStreamStrides*: ptr uint32
  VkGeneratedCommandsInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineBindPoint*: VkPipelineBindPoint
    pipeline*: VkPipeline
    indirectCommandsLayout*: VkIndirectCommandsLayoutNV
    streamCount*: uint32
    pStreams*: ptr VkIndirectCommandsStreamNV
    sequencesCount*: uint32
    preprocessBuffer*: VkBuffer
    preprocessOffset*: VkDeviceSize
    preprocessSize*: VkDeviceSize
    sequencesCountBuffer*: VkBuffer
    sequencesCountOffset*: VkDeviceSize
    sequencesIndexBuffer*: VkBuffer
    sequencesIndexOffset*: VkDeviceSize
  VkGeneratedCommandsMemoryRequirementsInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineBindPoint*: VkPipelineBindPoint
    pipeline*: VkPipeline
    indirectCommandsLayout*: VkIndirectCommandsLayoutNV
    maxSequencesCount*: uint32
  VkPhysicalDeviceFeatures2* = object
    sType*: VkStructureType
    pNext*: pointer
    features*: VkPhysicalDeviceFeatures
  VkPhysicalDeviceFeatures2KHR* = object
  VkPhysicalDeviceProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    properties*: VkPhysicalDeviceProperties
  VkPhysicalDeviceProperties2KHR* = object
  VkFormatProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    formatProperties*: VkFormatProperties
  VkFormatProperties2KHR* = object
  VkImageFormatProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    imageFormatProperties*: VkImageFormatProperties
  VkImageFormatProperties2KHR* = object
  VkPhysicalDeviceImageFormatInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    thetype*: VkImageType
    tiling*: VkImageTiling
    usage*: VkImageUsageFlags
    flags*: VkImageCreateFlags
  VkPhysicalDeviceImageFormatInfo2KHR* = object
  VkQueueFamilyProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    queueFamilyProperties*: VkQueueFamilyProperties
  VkQueueFamilyProperties2KHR* = object
  VkPhysicalDeviceMemoryProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryProperties*: VkPhysicalDeviceMemoryProperties
  VkPhysicalDeviceMemoryProperties2KHR* = object
  VkSparseImageFormatProperties2* = object
    sType*: VkStructureType
    pNext*: pointer
    properties*: VkSparseImageFormatProperties
  VkSparseImageFormatProperties2KHR* = object
  VkPhysicalDeviceSparseImageFormatInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    thetype*: VkImageType
    samples*: VkSampleCountFlagBits
    usage*: VkImageUsageFlags
    tiling*: VkImageTiling
  VkPhysicalDeviceSparseImageFormatInfo2KHR* = object
  VkPhysicalDevicePushDescriptorPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxPushDescriptors*: uint32
  VkConformanceVersion* = object
    major*: uint8
    minor*: uint8
    subminor*: uint8
    patch*: uint8
  VkConformanceVersionKHR* = object
  VkPhysicalDeviceDriverProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    driverID*: VkDriverId
    driverName*: array[VK_MAX_DRIVER_NAME_SIZE, char]
    driverInfo*: array[VK_MAX_DRIVER_INFO_SIZE, char]
    conformanceVersion*: VkConformanceVersion
  VkPhysicalDeviceDriverPropertiesKHR* = object
  VkPresentRegionsKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pRegions*: ptr VkPresentRegionKHR
  VkPresentRegionKHR* = object
    rectangleCount*: uint32
    pRectangles*: ptr VkRectLayerKHR
  VkRectLayerKHR* = object
    offset*: VkOffset2D
    extent*: VkExtent2D
    layer*: uint32
  VkPhysicalDeviceVariablePointersFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    variablePointersStorageBuffer*: VkBool32
    variablePointers*: VkBool32
  VkPhysicalDeviceVariablePointersFeaturesKHR* = object
  VkPhysicalDeviceVariablePointerFeaturesKHR* = object
  VkPhysicalDeviceVariablePointerFeatures* = object
  VkExternalMemoryProperties* = object
    externalMemoryFeatures*: VkExternalMemoryFeatureFlags
    exportFromImportedHandleTypes*: VkExternalMemoryHandleTypeFlags
    compatibleHandleTypes*: VkExternalMemoryHandleTypeFlags
  VkExternalMemoryPropertiesKHR* = object
  VkPhysicalDeviceExternalImageFormatInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkPhysicalDeviceExternalImageFormatInfoKHR* = object
  VkExternalImageFormatProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    externalMemoryProperties*: VkExternalMemoryProperties
  VkExternalImageFormatPropertiesKHR* = object
  VkPhysicalDeviceExternalBufferInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkBufferCreateFlags
    usage*: VkBufferUsageFlags
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkPhysicalDeviceExternalBufferInfoKHR* = object
  VkExternalBufferProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    externalMemoryProperties*: VkExternalMemoryProperties
  VkExternalBufferPropertiesKHR* = object
  VkPhysicalDeviceIDProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceUUID*: array[VK_UUID_SIZE, uint8]
    driverUUID*: array[VK_UUID_SIZE, uint8]
    deviceLUID*: array[VK_LUID_SIZE, uint8]
    deviceNodeMask*: uint32
    deviceLUIDValid*: VkBool32
  VkPhysicalDeviceIDPropertiesKHR* = object
  VkExternalMemoryImageCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalMemoryHandleTypeFlags
  VkExternalMemoryImageCreateInfoKHR* = object
  VkExternalMemoryBufferCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalMemoryHandleTypeFlags
  VkExternalMemoryBufferCreateInfoKHR* = object
  VkExportMemoryAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalMemoryHandleTypeFlags
  VkExportMemoryAllocateInfoKHR* = object
  VkImportMemoryFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
    fd*: cint
  VkMemoryFdPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
  VkMemoryGetFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkPhysicalDeviceExternalSemaphoreInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
  VkPhysicalDeviceExternalSemaphoreInfoKHR* = object
  VkExternalSemaphoreProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    exportFromImportedHandleTypes*: VkExternalSemaphoreHandleTypeFlags
    compatibleHandleTypes*: VkExternalSemaphoreHandleTypeFlags
    externalSemaphoreFeatures*: VkExternalSemaphoreFeatureFlags
  VkExternalSemaphorePropertiesKHR* = object
  VkExportSemaphoreCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalSemaphoreHandleTypeFlags
  VkExportSemaphoreCreateInfoKHR* = object
  VkImportSemaphoreFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    flags*: VkSemaphoreImportFlags
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
    fd*: cint
  VkSemaphoreGetFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
  VkPhysicalDeviceExternalFenceInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalFenceHandleTypeFlagBits
  VkPhysicalDeviceExternalFenceInfoKHR* = object
  VkExternalFenceProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    exportFromImportedHandleTypes*: VkExternalFenceHandleTypeFlags
    compatibleHandleTypes*: VkExternalFenceHandleTypeFlags
    externalFenceFeatures*: VkExternalFenceFeatureFlags
  VkExternalFencePropertiesKHR* = object
  VkExportFenceCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    handleTypes*: VkExternalFenceHandleTypeFlags
  VkExportFenceCreateInfoKHR* = object
  VkImportFenceFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    flags*: VkFenceImportFlags
    handleType*: VkExternalFenceHandleTypeFlagBits
    fd*: cint
  VkFenceGetFdInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    handleType*: VkExternalFenceHandleTypeFlagBits
  VkPhysicalDeviceMultiviewFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    multiview*: VkBool32
    multiviewGeometryShader*: VkBool32
    multiviewTessellationShader*: VkBool32
  VkPhysicalDeviceMultiviewFeaturesKHR* = object
  VkPhysicalDeviceMultiviewProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxMultiviewViewCount*: uint32
    maxMultiviewInstanceIndex*: uint32
  VkPhysicalDeviceMultiviewPropertiesKHR* = object
  VkRenderPassMultiviewCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    subpassCount*: uint32
    pViewMasks*: ptr uint32
    dependencyCount*: uint32
    pViewOffsets*: ptr int32
    correlationMaskCount*: uint32
    pCorrelationMasks*: ptr uint32
  VkRenderPassMultiviewCreateInfoKHR* = object
  VkSurfaceCapabilities2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    minImageCount*: uint32
    maxImageCount*: uint32
    currentExtent*: VkExtent2D
    minImageExtent*: VkExtent2D
    maxImageExtent*: VkExtent2D
    maxImageArrayLayers*: uint32
    supportedTransforms*: VkSurfaceTransformFlagsKHR
    currentTransform*: VkSurfaceTransformFlagBitsKHR
    supportedCompositeAlpha*: VkCompositeAlphaFlagsKHR
    supportedUsageFlags*: VkImageUsageFlags
    supportedSurfaceCounters*: VkSurfaceCounterFlagsEXT
  VkDisplayPowerInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    powerState*: VkDisplayPowerStateEXT
  VkDeviceEventInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceEvent*: VkDeviceEventTypeEXT
  VkDisplayEventInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    displayEvent*: VkDisplayEventTypeEXT
  VkSwapchainCounterCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    surfaceCounters*: VkSurfaceCounterFlagsEXT
  VkPhysicalDeviceGroupProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    physicalDeviceCount*: uint32
    physicalDevices*: array[VK_MAX_DEVICE_GROUP_SIZE, VkPhysicalDevice]
    subsetAllocation*: VkBool32
  VkPhysicalDeviceGroupPropertiesKHR* = object
  VkMemoryAllocateFlagsInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkMemoryAllocateFlags
    deviceMask*: uint32
  VkMemoryAllocateFlagsInfoKHR* = object
  VkBindBufferMemoryInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
  VkBindBufferMemoryInfoKHR* = object
  VkBindBufferMemoryDeviceGroupInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceIndexCount*: uint32
    pDeviceIndices*: ptr uint32
  VkBindBufferMemoryDeviceGroupInfoKHR* = object
  VkBindImageMemoryInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
  VkBindImageMemoryInfoKHR* = object
  VkBindImageMemoryDeviceGroupInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceIndexCount*: uint32
    pDeviceIndices*: ptr uint32
    splitInstanceBindRegionCount*: uint32
    pSplitInstanceBindRegions*: ptr VkRect2D
  VkBindImageMemoryDeviceGroupInfoKHR* = object
  VkDeviceGroupRenderPassBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceMask*: uint32
    deviceRenderAreaCount*: uint32
    pDeviceRenderAreas*: ptr VkRect2D
  VkDeviceGroupRenderPassBeginInfoKHR* = object
  VkDeviceGroupCommandBufferBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceMask*: uint32
  VkDeviceGroupCommandBufferBeginInfoKHR* = object
  VkDeviceGroupSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreCount*: uint32
    pWaitSemaphoreDeviceIndices*: ptr uint32
    commandBufferCount*: uint32
    pCommandBufferDeviceMasks*: ptr uint32
    signalSemaphoreCount*: uint32
    pSignalSemaphoreDeviceIndices*: ptr uint32
  VkDeviceGroupSubmitInfoKHR* = object
  VkDeviceGroupBindSparseInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    resourceDeviceIndex*: uint32
    memoryDeviceIndex*: uint32
  VkDeviceGroupBindSparseInfoKHR* = object
  VkDeviceGroupPresentCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    presentMask*: array[VK_MAX_DEVICE_GROUP_SIZE, uint32]
    modes*: VkDeviceGroupPresentModeFlagsKHR
  VkImageSwapchainCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchain*: VkSwapchainKHR
  VkBindImageMemorySwapchainInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchain*: VkSwapchainKHR
    imageIndex*: uint32
  VkAcquireNextImageInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchain*: VkSwapchainKHR
    timeout*: uint64
    semaphore*: VkSemaphore
    fence*: VkFence
    deviceMask*: uint32
  VkDeviceGroupPresentInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pDeviceMasks*: ptr uint32
    mode*: VkDeviceGroupPresentModeFlagBitsKHR
  VkDeviceGroupDeviceCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    physicalDeviceCount*: uint32
    pPhysicalDevices*: ptr VkPhysicalDevice
  VkDeviceGroupDeviceCreateInfoKHR* = object
  VkDeviceGroupSwapchainCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    modes*: VkDeviceGroupPresentModeFlagsKHR
  VkDescriptorUpdateTemplateEntry* = object
    dstBinding*: uint32
    dstArrayElement*: uint32
    descriptorCount*: uint32
    descriptorType*: VkDescriptorType
    offset*: csize_t
    stride*: csize_t
  VkDescriptorUpdateTemplateEntryKHR* = object
  VkDescriptorUpdateTemplateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDescriptorUpdateTemplateCreateFlags
    descriptorUpdateEntryCount*: uint32
    pDescriptorUpdateEntries*: ptr VkDescriptorUpdateTemplateEntry
    templateType*: VkDescriptorUpdateTemplateType
    descriptorSetLayout*: VkDescriptorSetLayout
    pipelineBindPoint*: VkPipelineBindPoint
    pipelineLayout*: VkPipelineLayout
    set*: uint32
  VkDescriptorUpdateTemplateCreateInfoKHR* = object
  VkXYColorEXT* = object
    x*: float32
    y*: float32
  VkPhysicalDevicePresentIdFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    presentId*: VkBool32
  VkPresentIdKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pPresentIds*: ptr uint64
  VkPhysicalDevicePresentWaitFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    presentWait*: VkBool32
  VkHdrMetadataEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    displayPrimaryRed*: VkXYColorEXT
    displayPrimaryGreen*: VkXYColorEXT
    displayPrimaryBlue*: VkXYColorEXT
    whitePoint*: VkXYColorEXT
    maxLuminance*: float32
    minLuminance*: float32
    maxContentLightLevel*: float32
    maxFrameAverageLightLevel*: float32
  VkDisplayNativeHdrSurfaceCapabilitiesAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    localDimmingSupport*: VkBool32
  VkSwapchainDisplayNativeHdrCreateInfoAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    localDimmingEnable*: VkBool32
  VkRefreshCycleDurationGOOGLE* = object
    refreshDuration*: uint64
  VkPastPresentationTimingGOOGLE* = object
    presentID*: uint32
    desiredPresentTime*: uint64
    actualPresentTime*: uint64
    earliestPresentTime*: uint64
    presentMargin*: uint64
  VkPresentTimesInfoGOOGLE* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pTimes*: ptr VkPresentTimeGOOGLE
  VkPresentTimeGOOGLE* = object
    presentID*: uint32
    desiredPresentTime*: uint64
  VkViewportWScalingNV* = object
    xcoeff*: float32
    ycoeff*: float32
  VkPipelineViewportWScalingStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    viewportWScalingEnable*: VkBool32
    viewportCount*: uint32
    pViewportWScalings*: ptr VkViewportWScalingNV
  VkViewportSwizzleNV* = object
    x*: VkViewportCoordinateSwizzleNV
    y*: VkViewportCoordinateSwizzleNV
    z*: VkViewportCoordinateSwizzleNV
    w*: VkViewportCoordinateSwizzleNV
  VkPipelineViewportSwizzleStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineViewportSwizzleStateCreateFlagsNV
    viewportCount*: uint32
    pViewportSwizzles*: ptr VkViewportSwizzleNV
  VkPhysicalDeviceDiscardRectanglePropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxDiscardRectangles*: uint32
  VkPipelineDiscardRectangleStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineDiscardRectangleStateCreateFlagsEXT
    discardRectangleMode*: VkDiscardRectangleModeEXT
    discardRectangleCount*: uint32
    pDiscardRectangles*: ptr VkRect2D
  VkPhysicalDeviceMultiviewPerViewAttributesPropertiesNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    perViewPositionAllComponents*: VkBool32
  VkInputAttachmentAspectReference* = object
    subpass*: uint32
    inputAttachmentIndex*: uint32
    aspectMask*: VkImageAspectFlags
  VkInputAttachmentAspectReferenceKHR* = object
  VkRenderPassInputAttachmentAspectCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    aspectReferenceCount*: uint32
    pAspectReferences*: ptr VkInputAttachmentAspectReference
  VkRenderPassInputAttachmentAspectCreateInfoKHR* = object
  VkPhysicalDeviceSurfaceInfo2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    surface*: VkSurfaceKHR
  VkSurfaceCapabilities2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    surfaceCapabilities*: VkSurfaceCapabilitiesKHR
  VkSurfaceFormat2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    surfaceFormat*: VkSurfaceFormatKHR
  VkDisplayProperties2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    displayProperties*: VkDisplayPropertiesKHR
  VkDisplayPlaneProperties2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    displayPlaneProperties*: VkDisplayPlanePropertiesKHR
  VkDisplayModeProperties2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    displayModeProperties*: VkDisplayModePropertiesKHR
  VkDisplayPlaneInfo2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    mode*: VkDisplayModeKHR
    planeIndex*: uint32
  VkDisplayPlaneCapabilities2KHR* = object
    sType*: VkStructureType
    pNext*: pointer
    capabilities*: VkDisplayPlaneCapabilitiesKHR
  VkSharedPresentSurfaceCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    sharedPresentSupportedUsageFlags*: VkImageUsageFlags
  VkPhysicalDevice16BitStorageFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    storageBuffer16BitAccess*: VkBool32
    uniformAndStorageBuffer16BitAccess*: VkBool32
    storagePushConstant16*: VkBool32
    storageInputOutput16*: VkBool32
  VkPhysicalDevice16BitStorageFeaturesKHR* = object
  VkPhysicalDeviceSubgroupProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    subgroupSize*: uint32
    supportedStages*: VkShaderStageFlags
    supportedOperations*: VkSubgroupFeatureFlags
    quadOperationsInAllStages*: VkBool32
  VkPhysicalDeviceShaderSubgroupExtendedTypesFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderSubgroupExtendedTypes*: VkBool32
  VkPhysicalDeviceShaderSubgroupExtendedTypesFeaturesKHR* = object
  VkBufferMemoryRequirementsInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
  VkBufferMemoryRequirementsInfo2KHR* = object
  VkDeviceBufferMemoryRequirements* = object
    sType*: VkStructureType
    pNext*: pointer
    pCreateInfo*: ptr VkBufferCreateInfo
  VkDeviceBufferMemoryRequirementsKHR* = object
  VkImageMemoryRequirementsInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
  VkImageMemoryRequirementsInfo2KHR* = object
  VkImageSparseMemoryRequirementsInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
  VkImageSparseMemoryRequirementsInfo2KHR* = object
  VkDeviceImageMemoryRequirements* = object
    sType*: VkStructureType
    pNext*: pointer
    pCreateInfo*: ptr VkImageCreateInfo
    planeAspect*: VkImageAspectFlagBits
  VkDeviceImageMemoryRequirementsKHR* = object
  VkMemoryRequirements2* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryRequirements*: VkMemoryRequirements
  VkMemoryRequirements2KHR* = object
  VkSparseImageMemoryRequirements2* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryRequirements*: VkSparseImageMemoryRequirements
  VkSparseImageMemoryRequirements2KHR* = object
  VkPhysicalDevicePointClippingProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    pointClippingBehavior*: VkPointClippingBehavior
  VkPhysicalDevicePointClippingPropertiesKHR* = object
  VkMemoryDedicatedRequirements* = object
    sType*: VkStructureType
    pNext*: pointer
    prefersDedicatedAllocation*: VkBool32
    requiresDedicatedAllocation*: VkBool32
  VkMemoryDedicatedRequirementsKHR* = object
  VkMemoryDedicatedAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
    buffer*: VkBuffer
  VkMemoryDedicatedAllocateInfoKHR* = object
  VkImageViewUsageCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    usage*: VkImageUsageFlags
  VkImageViewSlicedCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    sliceOffset*: uint32
    sliceCount*: uint32
  VkImageViewUsageCreateInfoKHR* = object
  VkPipelineTessellationDomainOriginStateCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    domainOrigin*: VkTessellationDomainOrigin
  VkPipelineTessellationDomainOriginStateCreateInfoKHR* = object
  VkSamplerYcbcrConversionInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    conversion*: VkSamplerYcbcrConversion
  VkSamplerYcbcrConversionInfoKHR* = object
  VkSamplerYcbcrConversionCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    ycbcrModel*: VkSamplerYcbcrModelConversion
    ycbcrRange*: VkSamplerYcbcrRange
    components*: VkComponentMapping
    xChromaOffset*: VkChromaLocation
    yChromaOffset*: VkChromaLocation
    chromaFilter*: VkFilter
    forceExplicitReconstruction*: VkBool32
  VkSamplerYcbcrConversionCreateInfoKHR* = object
  VkBindImagePlaneMemoryInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    planeAspect*: VkImageAspectFlagBits
  VkBindImagePlaneMemoryInfoKHR* = object
  VkImagePlaneMemoryRequirementsInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    planeAspect*: VkImageAspectFlagBits
  VkImagePlaneMemoryRequirementsInfoKHR* = object
  VkPhysicalDeviceSamplerYcbcrConversionFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    samplerYcbcrConversion*: VkBool32
  VkPhysicalDeviceSamplerYcbcrConversionFeaturesKHR* = object
  VkSamplerYcbcrConversionImageFormatProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    combinedImageSamplerDescriptorCount*: uint32
  VkSamplerYcbcrConversionImageFormatPropertiesKHR* = object
  VkTextureLODGatherFormatPropertiesAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    supportsTextureGatherLODBiasAMD*: VkBool32
  VkConditionalRenderingBeginInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
    offset*: VkDeviceSize
    flags*: VkConditionalRenderingFlagsEXT
  VkProtectedSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    protectedSubmit*: VkBool32
  VkPhysicalDeviceProtectedMemoryFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    protectedMemory*: VkBool32
  VkPhysicalDeviceProtectedMemoryProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    protectedNoFault*: VkBool32
  VkDeviceQueueInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceQueueCreateFlags
    queueFamilyIndex*: uint32
    queueIndex*: uint32
  VkPipelineCoverageToColorStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCoverageToColorStateCreateFlagsNV
    coverageToColorEnable*: VkBool32
    coverageToColorLocation*: uint32
  VkPhysicalDeviceSamplerFilterMinmaxProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    filterMinmaxSingleComponentFormats*: VkBool32
    filterMinmaxImageComponentMapping*: VkBool32
  VkPhysicalDeviceSamplerFilterMinmaxPropertiesEXT* = object
  VkSampleLocationEXT* = object
    x*: float32
    y*: float32
  VkSampleLocationsInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    sampleLocationsPerPixel*: VkSampleCountFlagBits
    sampleLocationGridSize*: VkExtent2D
    sampleLocationsCount*: uint32
    pSampleLocations*: ptr VkSampleLocationEXT
  VkAttachmentSampleLocationsEXT* = object
    attachmentIndex*: uint32
    sampleLocationsInfo*: VkSampleLocationsInfoEXT
  VkSubpassSampleLocationsEXT* = object
    subpassIndex*: uint32
    sampleLocationsInfo*: VkSampleLocationsInfoEXT
  VkRenderPassSampleLocationsBeginInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    attachmentInitialSampleLocationsCount*: uint32
    pAttachmentInitialSampleLocations*: ptr VkAttachmentSampleLocationsEXT
    postSubpassSampleLocationsCount*: uint32
    pPostSubpassSampleLocations*: ptr VkSubpassSampleLocationsEXT
  VkPipelineSampleLocationsStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    sampleLocationsEnable*: VkBool32
    sampleLocationsInfo*: VkSampleLocationsInfoEXT
  VkPhysicalDeviceSampleLocationsPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    sampleLocationSampleCounts*: VkSampleCountFlags
    maxSampleLocationGridSize*: VkExtent2D
    sampleLocationCoordinateRange*: array[2, float32]
    sampleLocationSubPixelBits*: uint32
    variableSampleLocations*: VkBool32
  VkMultisamplePropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxSampleLocationGridSize*: VkExtent2D
  VkSamplerReductionModeCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    reductionMode*: VkSamplerReductionMode
  VkSamplerReductionModeCreateInfoEXT* = object
  VkPhysicalDeviceBlendOperationAdvancedFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    advancedBlendCoherentOperations*: VkBool32
  VkPhysicalDeviceMultiDrawFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    multiDraw*: VkBool32
  VkPhysicalDeviceBlendOperationAdvancedPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    advancedBlendMaxColorAttachments*: uint32
    advancedBlendIndependentBlend*: VkBool32
    advancedBlendNonPremultipliedSrcColor*: VkBool32
    advancedBlendNonPremultipliedDstColor*: VkBool32
    advancedBlendCorrelatedOverlap*: VkBool32
    advancedBlendAllOperations*: VkBool32
  VkPipelineColorBlendAdvancedStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    srcPremultiplied*: VkBool32
    dstPremultiplied*: VkBool32
    blendOverlap*: VkBlendOverlapEXT
  VkPhysicalDeviceInlineUniformBlockFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    inlineUniformBlock*: VkBool32
    descriptorBindingInlineUniformBlockUpdateAfterBind*: VkBool32
  VkPhysicalDeviceInlineUniformBlockFeaturesEXT* = object
  VkPhysicalDeviceInlineUniformBlockProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxInlineUniformBlockSize*: uint32
    maxPerStageDescriptorInlineUniformBlocks*: uint32
    maxPerStageDescriptorUpdateAfterBindInlineUniformBlocks*: uint32
    maxDescriptorSetInlineUniformBlocks*: uint32
    maxDescriptorSetUpdateAfterBindInlineUniformBlocks*: uint32
  VkPhysicalDeviceInlineUniformBlockPropertiesEXT* = object
  VkWriteDescriptorSetInlineUniformBlock* = object
    sType*: VkStructureType
    pNext*: pointer
    dataSize*: uint32
    pData*: pointer
  VkWriteDescriptorSetInlineUniformBlockEXT* = object
  VkDescriptorPoolInlineUniformBlockCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    maxInlineUniformBlockBindings*: uint32
  VkDescriptorPoolInlineUniformBlockCreateInfoEXT* = object
  VkPipelineCoverageModulationStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCoverageModulationStateCreateFlagsNV
    coverageModulationMode*: VkCoverageModulationModeNV
    coverageModulationTableEnable*: VkBool32
    coverageModulationTableCount*: uint32
    pCoverageModulationTable*: ptr float32
  VkImageFormatListCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    viewFormatCount*: uint32
    pViewFormats*: ptr VkFormat
  VkImageFormatListCreateInfoKHR* = object
  VkValidationCacheCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkValidationCacheCreateFlagsEXT
    initialDataSize*: csize_t
    pInitialData*: pointer
  VkShaderModuleValidationCacheCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    validationCache*: VkValidationCacheEXT
  VkPhysicalDeviceMaintenance3Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxPerSetDescriptors*: uint32
    maxMemoryAllocationSize*: VkDeviceSize
  VkPhysicalDeviceMaintenance3PropertiesKHR* = object
  VkPhysicalDeviceMaintenance4Features* = object
    sType*: VkStructureType
    pNext*: pointer
    maintenance4*: VkBool32
  VkPhysicalDeviceMaintenance4FeaturesKHR* = object
  VkPhysicalDeviceMaintenance4Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxBufferSize*: VkDeviceSize
  VkPhysicalDeviceMaintenance4PropertiesKHR* = object
  VkDescriptorSetLayoutSupport* = object
    sType*: VkStructureType
    pNext*: pointer
    supported*: VkBool32
  VkDescriptorSetLayoutSupportKHR* = object
  VkPhysicalDeviceShaderDrawParametersFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderDrawParameters*: VkBool32
  VkPhysicalDeviceShaderDrawParameterFeatures* = object
  VkPhysicalDeviceShaderFloat16Int8Features* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderFloat16*: VkBool32
    shaderInt8*: VkBool32
  VkPhysicalDeviceShaderFloat16Int8FeaturesKHR* = object
  VkPhysicalDeviceFloat16Int8FeaturesKHR* = object
  VkPhysicalDeviceFloatControlsProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    denormBehaviorIndependence*: VkShaderFloatControlsIndependence
    roundingModeIndependence*: VkShaderFloatControlsIndependence
    shaderSignedZeroInfNanPreserveFloat16*: VkBool32
    shaderSignedZeroInfNanPreserveFloat32*: VkBool32
    shaderSignedZeroInfNanPreserveFloat64*: VkBool32
    shaderDenormPreserveFloat16*: VkBool32
    shaderDenormPreserveFloat32*: VkBool32
    shaderDenormPreserveFloat64*: VkBool32
    shaderDenormFlushToZeroFloat16*: VkBool32
    shaderDenormFlushToZeroFloat32*: VkBool32
    shaderDenormFlushToZeroFloat64*: VkBool32
    shaderRoundingModeRTEFloat16*: VkBool32
    shaderRoundingModeRTEFloat32*: VkBool32
    shaderRoundingModeRTEFloat64*: VkBool32
    shaderRoundingModeRTZFloat16*: VkBool32
    shaderRoundingModeRTZFloat32*: VkBool32
    shaderRoundingModeRTZFloat64*: VkBool32
  VkPhysicalDeviceFloatControlsPropertiesKHR* = object
  VkPhysicalDeviceHostQueryResetFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    hostQueryReset*: VkBool32
  VkPhysicalDeviceHostQueryResetFeaturesEXT* = object
  VkShaderResourceUsageAMD* = object
    numUsedVgprs*: uint32
    numUsedSgprs*: uint32
    ldsSizePerLocalWorkGroup*: uint32
    ldsUsageSizeInBytes*: csize_t
    scratchMemUsageInBytes*: csize_t
  VkShaderStatisticsInfoAMD* = object
    shaderStageMask*: VkShaderStageFlags
    resourceUsage*: VkShaderResourceUsageAMD
    numPhysicalVgprs*: uint32
    numPhysicalSgprs*: uint32
    numAvailableVgprs*: uint32
    numAvailableSgprs*: uint32
    computeWorkGroupSize*: array[3, uint32]
  VkDeviceQueueGlobalPriorityCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    globalPriority*: VkQueueGlobalPriorityKHR
  VkDeviceQueueGlobalPriorityCreateInfoEXT* = object
  VkPhysicalDeviceGlobalPriorityQueryFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    globalPriorityQuery*: VkBool32
  VkPhysicalDeviceGlobalPriorityQueryFeaturesEXT* = object
  VkQueueFamilyGlobalPriorityPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    priorityCount*: uint32
    priorities*: array[VK_MAX_GLOBAL_PRIORITY_SIZE_KHR, VkQueueGlobalPriorityKHR]
  VkQueueFamilyGlobalPriorityPropertiesEXT* = object
  VkDebugUtilsObjectNameInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    objectType*: VkObjectType
    objectHandle*: uint64
    pObjectName*: cstring
  VkDebugUtilsObjectTagInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    objectType*: VkObjectType
    objectHandle*: uint64
    tagName*: uint64
    tagSize*: csize_t
    pTag*: pointer
  VkDebugUtilsLabelEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pLabelName*: cstring
    color*: array[4, float32]
  VkDebugUtilsMessengerCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDebugUtilsMessengerCreateFlagsEXT
    messageSeverity*: VkDebugUtilsMessageSeverityFlagsEXT
    messageType*: VkDebugUtilsMessageTypeFlagsEXT
    pfnUserCallback*: PFN_vkDebugUtilsMessengerCallbackEXT
    pUserData*: pointer
  VkDebugUtilsMessengerCallbackDataEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDebugUtilsMessengerCallbackDataFlagsEXT
    pMessageIdName*: cstring
    messageIdNumber*: int32
    pMessage*: cstring
    queueLabelCount*: uint32
    pQueueLabels*: ptr VkDebugUtilsLabelEXT
    cmdBufLabelCount*: uint32
    pCmdBufLabels*: ptr VkDebugUtilsLabelEXT
    objectCount*: uint32
    pObjects*: ptr VkDebugUtilsObjectNameInfoEXT
  VkPhysicalDeviceDeviceMemoryReportFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceMemoryReport*: VkBool32
  VkDeviceDeviceMemoryReportCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceMemoryReportFlagsEXT
    pfnUserCallback*: PFN_vkDeviceMemoryReportCallbackEXT
    pUserData*: pointer
  VkDeviceMemoryReportCallbackDataEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceMemoryReportFlagsEXT
    thetype*: VkDeviceMemoryReportEventTypeEXT
    memoryObjectId*: uint64
    size*: VkDeviceSize
    objectType*: VkObjectType
    objectHandle*: uint64
    heapIndex*: uint32
  VkImportMemoryHostPointerInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
    pHostPointer*: pointer
  VkMemoryHostPointerPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
  VkPhysicalDeviceExternalMemoryHostPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    minImportedHostPointerAlignment*: VkDeviceSize
  VkPhysicalDeviceConservativeRasterizationPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    primitiveOverestimationSize*: float32
    maxExtraPrimitiveOverestimationSize*: float32
    extraPrimitiveOverestimationSizeGranularity*: float32
    primitiveUnderestimation*: VkBool32
    conservativePointAndLineRasterization*: VkBool32
    degenerateTrianglesRasterized*: VkBool32
    degenerateLinesRasterized*: VkBool32
    fullyCoveredFragmentShaderInputVariable*: VkBool32
    conservativeRasterizationPostDepthCoverage*: VkBool32
  VkCalibratedTimestampInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    timeDomain*: VkTimeDomainEXT
  VkPhysicalDeviceShaderCorePropertiesAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderEngineCount*: uint32
    shaderArraysPerEngineCount*: uint32
    computeUnitsPerShaderArray*: uint32
    simdPerComputeUnit*: uint32
    wavefrontsPerSimd*: uint32
    wavefrontSize*: uint32
    sgprsPerSimd*: uint32
    minSgprAllocation*: uint32
    maxSgprAllocation*: uint32
    sgprAllocationGranularity*: uint32
    vgprsPerSimd*: uint32
    minVgprAllocation*: uint32
    maxVgprAllocation*: uint32
    vgprAllocationGranularity*: uint32
  VkPhysicalDeviceShaderCoreProperties2AMD* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderCoreFeatures*: VkShaderCorePropertiesFlagsAMD
    activeComputeUnitCount*: uint32
  VkPipelineRasterizationConservativeStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineRasterizationConservativeStateCreateFlagsEXT
    conservativeRasterizationMode*: VkConservativeRasterizationModeEXT
    extraPrimitiveOverestimationSize*: float32
  VkPhysicalDeviceDescriptorIndexingFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderInputAttachmentArrayDynamicIndexing*: VkBool32
    shaderUniformTexelBufferArrayDynamicIndexing*: VkBool32
    shaderStorageTexelBufferArrayDynamicIndexing*: VkBool32
    shaderUniformBufferArrayNonUniformIndexing*: VkBool32
    shaderSampledImageArrayNonUniformIndexing*: VkBool32
    shaderStorageBufferArrayNonUniformIndexing*: VkBool32
    shaderStorageImageArrayNonUniformIndexing*: VkBool32
    shaderInputAttachmentArrayNonUniformIndexing*: VkBool32
    shaderUniformTexelBufferArrayNonUniformIndexing*: VkBool32
    shaderStorageTexelBufferArrayNonUniformIndexing*: VkBool32
    descriptorBindingUniformBufferUpdateAfterBind*: VkBool32
    descriptorBindingSampledImageUpdateAfterBind*: VkBool32
    descriptorBindingStorageImageUpdateAfterBind*: VkBool32
    descriptorBindingStorageBufferUpdateAfterBind*: VkBool32
    descriptorBindingUniformTexelBufferUpdateAfterBind*: VkBool32
    descriptorBindingStorageTexelBufferUpdateAfterBind*: VkBool32
    descriptorBindingUpdateUnusedWhilePending*: VkBool32
    descriptorBindingPartiallyBound*: VkBool32
    descriptorBindingVariableDescriptorCount*: VkBool32
    runtimeDescriptorArray*: VkBool32
  VkPhysicalDeviceDescriptorIndexingFeaturesEXT* = object
  VkPhysicalDeviceDescriptorIndexingProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxUpdateAfterBindDescriptorsInAllPools*: uint32
    shaderUniformBufferArrayNonUniformIndexingNative*: VkBool32
    shaderSampledImageArrayNonUniformIndexingNative*: VkBool32
    shaderStorageBufferArrayNonUniformIndexingNative*: VkBool32
    shaderStorageImageArrayNonUniformIndexingNative*: VkBool32
    shaderInputAttachmentArrayNonUniformIndexingNative*: VkBool32
    robustBufferAccessUpdateAfterBind*: VkBool32
    quadDivergentImplicitLod*: VkBool32
    maxPerStageDescriptorUpdateAfterBindSamplers*: uint32
    maxPerStageDescriptorUpdateAfterBindUniformBuffers*: uint32
    maxPerStageDescriptorUpdateAfterBindStorageBuffers*: uint32
    maxPerStageDescriptorUpdateAfterBindSampledImages*: uint32
    maxPerStageDescriptorUpdateAfterBindStorageImages*: uint32
    maxPerStageDescriptorUpdateAfterBindInputAttachments*: uint32
    maxPerStageUpdateAfterBindResources*: uint32
    maxDescriptorSetUpdateAfterBindSamplers*: uint32
    maxDescriptorSetUpdateAfterBindUniformBuffers*: uint32
    maxDescriptorSetUpdateAfterBindUniformBuffersDynamic*: uint32
    maxDescriptorSetUpdateAfterBindStorageBuffers*: uint32
    maxDescriptorSetUpdateAfterBindStorageBuffersDynamic*: uint32
    maxDescriptorSetUpdateAfterBindSampledImages*: uint32
    maxDescriptorSetUpdateAfterBindStorageImages*: uint32
    maxDescriptorSetUpdateAfterBindInputAttachments*: uint32
  VkPhysicalDeviceDescriptorIndexingPropertiesEXT* = object
  VkDescriptorSetLayoutBindingFlagsCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    bindingCount*: uint32
    pBindingFlags*: ptr VkDescriptorBindingFlags
  VkDescriptorSetLayoutBindingFlagsCreateInfoEXT* = object
  VkDescriptorSetVariableDescriptorCountAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorSetCount*: uint32
    pDescriptorCounts*: ptr uint32
  VkDescriptorSetVariableDescriptorCountAllocateInfoEXT* = object
  VkDescriptorSetVariableDescriptorCountLayoutSupport* = object
    sType*: VkStructureType
    pNext*: pointer
    maxVariableDescriptorCount*: uint32
  VkDescriptorSetVariableDescriptorCountLayoutSupportEXT* = object
  VkAttachmentDescription2* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkAttachmentDescriptionFlags
    format*: VkFormat
    samples*: VkSampleCountFlagBits
    loadOp*: VkAttachmentLoadOp
    storeOp*: VkAttachmentStoreOp
    stencilLoadOp*: VkAttachmentLoadOp
    stencilStoreOp*: VkAttachmentStoreOp
    initialLayout*: VkImageLayout
    finalLayout*: VkImageLayout
  VkAttachmentDescription2KHR* = object
  VkAttachmentReference2* = object
    sType*: VkStructureType
    pNext*: pointer
    attachment*: uint32
    layout*: VkImageLayout
    aspectMask*: VkImageAspectFlags
  VkAttachmentReference2KHR* = object
  VkSubpassDescription2* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSubpassDescriptionFlags
    pipelineBindPoint*: VkPipelineBindPoint
    viewMask*: uint32
    inputAttachmentCount*: uint32
    pInputAttachments*: ptr VkAttachmentReference2
    colorAttachmentCount*: uint32
    pColorAttachments*: ptr VkAttachmentReference2
    pResolveAttachments*: ptr VkAttachmentReference2
    pDepthStencilAttachment*: ptr VkAttachmentReference2
    preserveAttachmentCount*: uint32
    pPreserveAttachments*: ptr uint32
  VkSubpassDescription2KHR* = object
  VkSubpassDependency2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcSubpass*: uint32
    dstSubpass*: uint32
    srcStageMask*: VkPipelineStageFlags
    dstStageMask*: VkPipelineStageFlags
    srcAccessMask*: VkAccessFlags
    dstAccessMask*: VkAccessFlags
    dependencyFlags*: VkDependencyFlags
    viewOffset*: int32
  VkSubpassDependency2KHR* = object
  VkRenderPassCreateInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkRenderPassCreateFlags
    attachmentCount*: uint32
    pAttachments*: ptr VkAttachmentDescription2
    subpassCount*: uint32
    pSubpasses*: ptr VkSubpassDescription2
    dependencyCount*: uint32
    pDependencies*: ptr VkSubpassDependency2
    correlatedViewMaskCount*: uint32
    pCorrelatedViewMasks*: ptr uint32
  VkRenderPassCreateInfo2KHR* = object
  VkSubpassBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    contents*: VkSubpassContents
  VkSubpassBeginInfoKHR* = object
  VkSubpassEndInfo* = object
    sType*: VkStructureType
    pNext*: pointer
  VkSubpassEndInfoKHR* = object
  VkPhysicalDeviceTimelineSemaphoreFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    timelineSemaphore*: VkBool32
  VkPhysicalDeviceTimelineSemaphoreFeaturesKHR* = object
  VkPhysicalDeviceTimelineSemaphoreProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    maxTimelineSemaphoreValueDifference*: uint64
  VkPhysicalDeviceTimelineSemaphorePropertiesKHR* = object
  VkSemaphoreTypeCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphoreType*: VkSemaphoreType
    initialValue*: uint64
  VkSemaphoreTypeCreateInfoKHR* = object
  VkTimelineSemaphoreSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreValueCount*: uint32
    pWaitSemaphoreValues*: ptr uint64
    signalSemaphoreValueCount*: uint32
    pSignalSemaphoreValues*: ptr uint64
  VkTimelineSemaphoreSubmitInfoKHR* = object
  VkSemaphoreWaitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSemaphoreWaitFlags
    semaphoreCount*: uint32
    pSemaphores*: ptr VkSemaphore
    pValues*: ptr uint64
  VkSemaphoreWaitInfoKHR* = object
  VkSemaphoreSignalInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    value*: uint64
  VkSemaphoreSignalInfoKHR* = object
  VkVertexInputBindingDivisorDescriptionEXT* = object
    binding*: uint32
    divisor*: uint32
  VkPipelineVertexInputDivisorStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexBindingDivisorCount*: uint32
    pVertexBindingDivisors*: ptr VkVertexInputBindingDivisorDescriptionEXT
  VkPhysicalDeviceVertexAttributeDivisorPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxVertexAttribDivisor*: uint32
  VkPhysicalDevicePCIBusInfoPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pciDomain*: uint32
    pciBus*: uint32
    pciDevice*: uint32
    pciFunction*: uint32
  VkCommandBufferInheritanceConditionalRenderingInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    conditionalRenderingEnable*: VkBool32
  VkPhysicalDevice8BitStorageFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    storageBuffer8BitAccess*: VkBool32
    uniformAndStorageBuffer8BitAccess*: VkBool32
    storagePushConstant8*: VkBool32
  VkPhysicalDevice8BitStorageFeaturesKHR* = object
  VkPhysicalDeviceConditionalRenderingFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    conditionalRendering*: VkBool32
    inheritedConditionalRendering*: VkBool32
  VkPhysicalDeviceVulkanMemoryModelFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    vulkanMemoryModel*: VkBool32
    vulkanMemoryModelDeviceScope*: VkBool32
    vulkanMemoryModelAvailabilityVisibilityChains*: VkBool32
  VkPhysicalDeviceVulkanMemoryModelFeaturesKHR* = object
  VkPhysicalDeviceShaderAtomicInt64Features* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderBufferInt64Atomics*: VkBool32
    shaderSharedInt64Atomics*: VkBool32
  VkPhysicalDeviceShaderAtomicInt64FeaturesKHR* = object
  VkPhysicalDeviceShaderAtomicFloatFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderBufferFloat32Atomics*: VkBool32
    shaderBufferFloat32AtomicAdd*: VkBool32
    shaderBufferFloat64Atomics*: VkBool32
    shaderBufferFloat64AtomicAdd*: VkBool32
    shaderSharedFloat32Atomics*: VkBool32
    shaderSharedFloat32AtomicAdd*: VkBool32
    shaderSharedFloat64Atomics*: VkBool32
    shaderSharedFloat64AtomicAdd*: VkBool32
    shaderImageFloat32Atomics*: VkBool32
    shaderImageFloat32AtomicAdd*: VkBool32
    sparseImageFloat32Atomics*: VkBool32
    sparseImageFloat32AtomicAdd*: VkBool32
  VkPhysicalDeviceShaderAtomicFloat2FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderBufferFloat16Atomics*: VkBool32
    shaderBufferFloat16AtomicAdd*: VkBool32
    shaderBufferFloat16AtomicMinMax*: VkBool32
    shaderBufferFloat32AtomicMinMax*: VkBool32
    shaderBufferFloat64AtomicMinMax*: VkBool32
    shaderSharedFloat16Atomics*: VkBool32
    shaderSharedFloat16AtomicAdd*: VkBool32
    shaderSharedFloat16AtomicMinMax*: VkBool32
    shaderSharedFloat32AtomicMinMax*: VkBool32
    shaderSharedFloat64AtomicMinMax*: VkBool32
    shaderImageFloat32AtomicMinMax*: VkBool32
    sparseImageFloat32AtomicMinMax*: VkBool32
  VkPhysicalDeviceVertexAttributeDivisorFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexAttributeInstanceRateDivisor*: VkBool32
    vertexAttributeInstanceRateZeroDivisor*: VkBool32
  VkQueueFamilyCheckpointPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    checkpointExecutionStageMask*: VkPipelineStageFlags
  VkCheckpointDataNV* = object
    sType*: VkStructureType
    pNext*: pointer
    stage*: VkPipelineStageFlagBits
    pCheckpointMarker*: pointer
  VkPhysicalDeviceDepthStencilResolveProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    supportedDepthResolveModes*: VkResolveModeFlags
    supportedStencilResolveModes*: VkResolveModeFlags
    independentResolveNone*: VkBool32
    independentResolve*: VkBool32
  VkPhysicalDeviceDepthStencilResolvePropertiesKHR* = object
  VkSubpassDescriptionDepthStencilResolve* = object
    sType*: VkStructureType
    pNext*: pointer
    depthResolveMode*: VkResolveModeFlagBits
    stencilResolveMode*: VkResolveModeFlagBits
    pDepthStencilResolveAttachment*: ptr VkAttachmentReference2
  VkSubpassDescriptionDepthStencilResolveKHR* = object
  VkImageViewASTCDecodeModeEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    decodeMode*: VkFormat
  VkPhysicalDeviceASTCDecodeFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    decodeModeSharedExponent*: VkBool32
  VkPhysicalDeviceTransformFeedbackFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    transformFeedback*: VkBool32
    geometryStreams*: VkBool32
  VkPhysicalDeviceTransformFeedbackPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxTransformFeedbackStreams*: uint32
    maxTransformFeedbackBuffers*: uint32
    maxTransformFeedbackBufferSize*: VkDeviceSize
    maxTransformFeedbackStreamDataSize*: uint32
    maxTransformFeedbackBufferDataSize*: uint32
    maxTransformFeedbackBufferDataStride*: uint32
    transformFeedbackQueries*: VkBool32
    transformFeedbackStreamsLinesTriangles*: VkBool32
    transformFeedbackRasterizationStreamSelect*: VkBool32
    transformFeedbackDraw*: VkBool32
  VkPipelineRasterizationStateStreamCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineRasterizationStateStreamCreateFlagsEXT
    rasterizationStream*: uint32
  VkPhysicalDeviceRepresentativeFragmentTestFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    representativeFragmentTest*: VkBool32
  VkPipelineRepresentativeFragmentTestStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    representativeFragmentTestEnable*: VkBool32
  VkPhysicalDeviceExclusiveScissorFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    exclusiveScissor*: VkBool32
  VkPipelineViewportExclusiveScissorStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    exclusiveScissorCount*: uint32
    pExclusiveScissors*: ptr VkRect2D
  VkPhysicalDeviceCornerSampledImageFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    cornerSampledImage*: VkBool32
  VkPhysicalDeviceComputeShaderDerivativesFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    computeDerivativeGroupQuads*: VkBool32
    computeDerivativeGroupLinear*: VkBool32
  VkPhysicalDeviceFragmentShaderBarycentricFeaturesNV* = object
  VkPhysicalDeviceShaderImageFootprintFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    imageFootprint*: VkBool32
  VkPhysicalDeviceDedicatedAllocationImageAliasingFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    dedicatedAllocationImageAliasing*: VkBool32
  VkPhysicalDeviceCopyMemoryIndirectFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    indirectCopy*: VkBool32
  VkPhysicalDeviceCopyMemoryIndirectPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    supportedQueues*: VkQueueFlags
  VkPhysicalDeviceMemoryDecompressionFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryDecompression*: VkBool32
  VkPhysicalDeviceMemoryDecompressionPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    decompressionMethods*: VkMemoryDecompressionMethodFlagsNV
    maxDecompressionIndirectCount*: uint64
  VkShadingRatePaletteNV* = object
    shadingRatePaletteEntryCount*: uint32
    pShadingRatePaletteEntries*: ptr VkShadingRatePaletteEntryNV
  VkPipelineViewportShadingRateImageStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shadingRateImageEnable*: VkBool32
    viewportCount*: uint32
    pShadingRatePalettes*: ptr VkShadingRatePaletteNV
  VkPhysicalDeviceShadingRateImageFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shadingRateImage*: VkBool32
    shadingRateCoarseSampleOrder*: VkBool32
  VkPhysicalDeviceShadingRateImagePropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shadingRateTexelSize*: VkExtent2D
    shadingRatePaletteSize*: uint32
    shadingRateMaxCoarseSamples*: uint32
  VkPhysicalDeviceInvocationMaskFeaturesHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    invocationMask*: VkBool32
  VkCoarseSampleLocationNV* = object
    pixelX*: uint32
    pixelY*: uint32
    sample*: uint32
  VkCoarseSampleOrderCustomNV* = object
    shadingRate*: VkShadingRatePaletteEntryNV
    sampleCount*: uint32
    sampleLocationCount*: uint32
    pSampleLocations*: ptr VkCoarseSampleLocationNV
  VkPipelineViewportCoarseSampleOrderStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    sampleOrderType*: VkCoarseSampleOrderTypeNV
    customSampleOrderCount*: uint32
    pCustomSampleOrders*: ptr VkCoarseSampleOrderCustomNV
  VkPhysicalDeviceMeshShaderFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    taskShader*: VkBool32
    meshShader*: VkBool32
  VkPhysicalDeviceMeshShaderPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    maxDrawMeshTasksCount*: uint32
    maxTaskWorkGroupInvocations*: uint32
    maxTaskWorkGroupSize*: array[3, uint32]
    maxTaskTotalMemorySize*: uint32
    maxTaskOutputCount*: uint32
    maxMeshWorkGroupInvocations*: uint32
    maxMeshWorkGroupSize*: array[3, uint32]
    maxMeshTotalMemorySize*: uint32
    maxMeshOutputVertices*: uint32
    maxMeshOutputPrimitives*: uint32
    maxMeshMultiviewViewCount*: uint32
    meshOutputPerVertexGranularity*: uint32
    meshOutputPerPrimitiveGranularity*: uint32
  VkDrawMeshTasksIndirectCommandNV* = object
    taskCount*: uint32
    firstTask*: uint32
  VkPhysicalDeviceMeshShaderFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    taskShader*: VkBool32
    meshShader*: VkBool32
    multiviewMeshShader*: VkBool32
    primitiveFragmentShadingRateMeshShader*: VkBool32
    meshShaderQueries*: VkBool32
  VkPhysicalDeviceMeshShaderPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxTaskWorkGroupTotalCount*: uint32
    maxTaskWorkGroupCount*: array[3, uint32]
    maxTaskWorkGroupInvocations*: uint32
    maxTaskWorkGroupSize*: array[3, uint32]
    maxTaskPayloadSize*: uint32
    maxTaskSharedMemorySize*: uint32
    maxTaskPayloadAndSharedMemorySize*: uint32
    maxMeshWorkGroupTotalCount*: uint32
    maxMeshWorkGroupCount*: array[3, uint32]
    maxMeshWorkGroupInvocations*: uint32
    maxMeshWorkGroupSize*: array[3, uint32]
    maxMeshSharedMemorySize*: uint32
    maxMeshPayloadAndSharedMemorySize*: uint32
    maxMeshOutputMemorySize*: uint32
    maxMeshPayloadAndOutputMemorySize*: uint32
    maxMeshOutputComponents*: uint32
    maxMeshOutputVertices*: uint32
    maxMeshOutputPrimitives*: uint32
    maxMeshOutputLayers*: uint32
    maxMeshMultiviewViewCount*: uint32
    meshOutputPerVertexGranularity*: uint32
    meshOutputPerPrimitiveGranularity*: uint32
    maxPreferredTaskWorkGroupInvocations*: uint32
    maxPreferredMeshWorkGroupInvocations*: uint32
    prefersLocalInvocationVertexOutput*: VkBool32
    prefersLocalInvocationPrimitiveOutput*: VkBool32
    prefersCompactVertexOutput*: VkBool32
    prefersCompactPrimitiveOutput*: VkBool32
  VkDrawMeshTasksIndirectCommandEXT* = object
    groupCountX*: uint32
    groupCountY*: uint32
    groupCountZ*: uint32
  VkRayTracingShaderGroupCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkRayTracingShaderGroupTypeKHR
    generalShader*: uint32
    closestHitShader*: uint32
    anyHitShader*: uint32
    intersectionShader*: uint32
  VkRayTracingShaderGroupCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkRayTracingShaderGroupTypeKHR
    generalShader*: uint32
    closestHitShader*: uint32
    anyHitShader*: uint32
    intersectionShader*: uint32
    pShaderGroupCaptureReplayHandle*: pointer
  VkRayTracingPipelineCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCreateFlags
    stageCount*: uint32
    pStages*: ptr VkPipelineShaderStageCreateInfo
    groupCount*: uint32
    pGroups*: ptr VkRayTracingShaderGroupCreateInfoNV
    maxRecursionDepth*: uint32
    layout*: VkPipelineLayout
    basePipelineHandle*: VkPipeline
    basePipelineIndex*: int32
  VkRayTracingPipelineCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCreateFlags
    stageCount*: uint32
    pStages*: ptr VkPipelineShaderStageCreateInfo
    groupCount*: uint32
    pGroups*: ptr VkRayTracingShaderGroupCreateInfoKHR
    maxPipelineRayRecursionDepth*: uint32
    pLibraryInfo*: ptr VkPipelineLibraryCreateInfoKHR
    pLibraryInterface*: ptr VkRayTracingPipelineInterfaceCreateInfoKHR
    pDynamicState*: ptr VkPipelineDynamicStateCreateInfo
    layout*: VkPipelineLayout
    basePipelineHandle*: VkPipeline
    basePipelineIndex*: int32
  VkGeometryTrianglesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexData*: VkBuffer
    vertexOffset*: VkDeviceSize
    vertexCount*: uint32
    vertexStride*: VkDeviceSize
    vertexFormat*: VkFormat
    indexData*: VkBuffer
    indexOffset*: VkDeviceSize
    indexCount*: uint32
    indexType*: VkIndexType
    transformData*: VkBuffer
    transformOffset*: VkDeviceSize
  VkGeometryAABBNV* = object
    sType*: VkStructureType
    pNext*: pointer
    aabbData*: VkBuffer
    numAABBs*: uint32
    stride*: uint32
    offset*: VkDeviceSize
  VkGeometryDataNV* = object
    triangles*: VkGeometryTrianglesNV
    aabbs*: VkGeometryAABBNV
  VkGeometryNV* = object
    sType*: VkStructureType
    pNext*: pointer
    geometryType*: VkGeometryTypeKHR
    geometry*: VkGeometryDataNV
    flags*: VkGeometryFlagsKHR
  VkAccelerationStructureInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkAccelerationStructureTypeNV
    flags*: VkBuildAccelerationStructureFlagsNV
    instanceCount*: uint32
    geometryCount*: uint32
    pGeometries*: ptr VkGeometryNV
  VkAccelerationStructureCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    compactedSize*: VkDeviceSize
    info*: VkAccelerationStructureInfoNV
  VkBindAccelerationStructureMemoryInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructure*: VkAccelerationStructureNV
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
    deviceIndexCount*: uint32
    pDeviceIndices*: ptr uint32
  VkWriteDescriptorSetAccelerationStructureKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructureCount*: uint32
    pAccelerationStructures*: ptr VkAccelerationStructureKHR
  VkWriteDescriptorSetAccelerationStructureNV* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructureCount*: uint32
    pAccelerationStructures*: ptr VkAccelerationStructureNV
  VkAccelerationStructureMemoryRequirementsInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkAccelerationStructureMemoryRequirementsTypeNV
    accelerationStructure*: VkAccelerationStructureNV
  VkPhysicalDeviceAccelerationStructureFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructure*: VkBool32
    accelerationStructureCaptureReplay*: VkBool32
    accelerationStructureIndirectBuild*: VkBool32
    accelerationStructureHostCommands*: VkBool32
    descriptorBindingAccelerationStructureUpdateAfterBind*: VkBool32
  VkPhysicalDeviceRayTracingPipelineFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    rayTracingPipeline*: VkBool32
    rayTracingPipelineShaderGroupHandleCaptureReplay*: VkBool32
    rayTracingPipelineShaderGroupHandleCaptureReplayMixed*: VkBool32
    rayTracingPipelineTraceRaysIndirect*: VkBool32
    rayTraversalPrimitiveCulling*: VkBool32
  VkPhysicalDeviceRayQueryFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    rayQuery*: VkBool32
  VkPhysicalDeviceAccelerationStructurePropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxGeometryCount*: uint64
    maxInstanceCount*: uint64
    maxPrimitiveCount*: uint64
    maxPerStageDescriptorAccelerationStructures*: uint32
    maxPerStageDescriptorUpdateAfterBindAccelerationStructures*: uint32
    maxDescriptorSetAccelerationStructures*: uint32
    maxDescriptorSetUpdateAfterBindAccelerationStructures*: uint32
    minAccelerationStructureScratchOffsetAlignment*: uint32
  VkPhysicalDeviceRayTracingPipelinePropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderGroupHandleSize*: uint32
    maxRayRecursionDepth*: uint32
    maxShaderGroupStride*: uint32
    shaderGroupBaseAlignment*: uint32
    shaderGroupHandleCaptureReplaySize*: uint32
    maxRayDispatchInvocationCount*: uint32
    shaderGroupHandleAlignment*: uint32
    maxRayHitAttributeSize*: uint32
  VkPhysicalDeviceRayTracingPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderGroupHandleSize*: uint32
    maxRecursionDepth*: uint32
    maxShaderGroupStride*: uint32
    shaderGroupBaseAlignment*: uint32
    maxGeometryCount*: uint64
    maxInstanceCount*: uint64
    maxTriangleCount*: uint64
    maxDescriptorSetAccelerationStructures*: uint32
  VkStridedDeviceAddressRegionKHR* = object
    deviceAddress*: VkDeviceAddress
    stride*: VkDeviceSize
    size*: VkDeviceSize
  VkTraceRaysIndirectCommandKHR* = object
    width*: uint32
    height*: uint32
    depth*: uint32
  VkTraceRaysIndirectCommand2KHR* = object
    raygenShaderRecordAddress*: VkDeviceAddress
    raygenShaderRecordSize*: VkDeviceSize
    missShaderBindingTableAddress*: VkDeviceAddress
    missShaderBindingTableSize*: VkDeviceSize
    missShaderBindingTableStride*: VkDeviceSize
    hitShaderBindingTableAddress*: VkDeviceAddress
    hitShaderBindingTableSize*: VkDeviceSize
    hitShaderBindingTableStride*: VkDeviceSize
    callableShaderBindingTableAddress*: VkDeviceAddress
    callableShaderBindingTableSize*: VkDeviceSize
    callableShaderBindingTableStride*: VkDeviceSize
    width*: uint32
    height*: uint32
    depth*: uint32
  VkPhysicalDeviceRayTracingMaintenance1FeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    rayTracingMaintenance1*: VkBool32
    rayTracingPipelineTraceRaysIndirect2*: VkBool32
  VkDrmFormatModifierPropertiesListEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifierCount*: uint32
    pDrmFormatModifierProperties*: ptr VkDrmFormatModifierPropertiesEXT
  VkDrmFormatModifierPropertiesEXT* = object
    drmFormatModifier*: uint64
    drmFormatModifierPlaneCount*: uint32
    drmFormatModifierTilingFeatures*: VkFormatFeatureFlags
  VkPhysicalDeviceImageDrmFormatModifierInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifier*: uint64
    sharingMode*: VkSharingMode
    queueFamilyIndexCount*: uint32
    pQueueFamilyIndices*: ptr uint32
  VkImageDrmFormatModifierListCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifierCount*: uint32
    pDrmFormatModifiers*: ptr uint64
  VkImageDrmFormatModifierExplicitCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifier*: uint64
    drmFormatModifierPlaneCount*: uint32
    pPlaneLayouts*: ptr VkSubresourceLayout
  VkImageDrmFormatModifierPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifier*: uint64
  VkImageStencilUsageCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    stencilUsage*: VkImageUsageFlags
  VkImageStencilUsageCreateInfoEXT* = object
  VkDeviceMemoryOverallocationCreateInfoAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    overallocationBehavior*: VkMemoryOverallocationBehaviorAMD
  VkPhysicalDeviceFragmentDensityMapFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityMap*: VkBool32
    fragmentDensityMapDynamic*: VkBool32
    fragmentDensityMapNonSubsampledImages*: VkBool32
  VkPhysicalDeviceFragmentDensityMap2FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityMapDeferred*: VkBool32
  VkPhysicalDeviceFragmentDensityMapOffsetFeaturesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityMapOffset*: VkBool32
  VkPhysicalDeviceFragmentDensityMapPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    minFragmentDensityTexelSize*: VkExtent2D
    maxFragmentDensityTexelSize*: VkExtent2D
    fragmentDensityInvocations*: VkBool32
  VkPhysicalDeviceFragmentDensityMap2PropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    subsampledLoads*: VkBool32
    subsampledCoarseReconstructionEarlyAccess*: VkBool32
    maxSubsampledArrayLayers*: uint32
    maxDescriptorSetSubsampledSamplers*: uint32
  VkPhysicalDeviceFragmentDensityMapOffsetPropertiesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityOffsetGranularity*: VkExtent2D
  VkRenderPassFragmentDensityMapCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityMapAttachment*: VkAttachmentReference
  VkSubpassFragmentDensityMapOffsetEndInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentDensityOffsetCount*: uint32
    pFragmentDensityOffsets*: ptr VkOffset2D
  VkPhysicalDeviceScalarBlockLayoutFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    scalarBlockLayout*: VkBool32
  VkPhysicalDeviceScalarBlockLayoutFeaturesEXT* = object
  VkSurfaceProtectedCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    supportsProtected*: VkBool32
  VkPhysicalDeviceUniformBufferStandardLayoutFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    uniformBufferStandardLayout*: VkBool32
  VkPhysicalDeviceUniformBufferStandardLayoutFeaturesKHR* = object
  VkPhysicalDeviceDepthClipEnableFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    depthClipEnable*: VkBool32
  VkPipelineRasterizationDepthClipStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineRasterizationDepthClipStateCreateFlagsEXT
    depthClipEnable*: VkBool32
  VkPhysicalDeviceMemoryBudgetPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    heapBudget*: array[VK_MAX_MEMORY_HEAPS, VkDeviceSize]
    heapUsage*: array[VK_MAX_MEMORY_HEAPS, VkDeviceSize]
  VkPhysicalDeviceMemoryPriorityFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryPriority*: VkBool32
  VkMemoryPriorityAllocateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    priority*: float32
  VkPhysicalDevicePageableDeviceLocalMemoryFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pageableDeviceLocalMemory*: VkBool32
  VkPhysicalDeviceBufferDeviceAddressFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    bufferDeviceAddress*: VkBool32
    bufferDeviceAddressCaptureReplay*: VkBool32
    bufferDeviceAddressMultiDevice*: VkBool32
  VkPhysicalDeviceBufferDeviceAddressFeaturesKHR* = object
  VkPhysicalDeviceBufferDeviceAddressFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    bufferDeviceAddress*: VkBool32
    bufferDeviceAddressCaptureReplay*: VkBool32
    bufferDeviceAddressMultiDevice*: VkBool32
  VkPhysicalDeviceBufferAddressFeaturesEXT* = object
  VkBufferDeviceAddressInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
  VkBufferDeviceAddressInfoKHR* = object
  VkBufferDeviceAddressInfoEXT* = object
  VkBufferOpaqueCaptureAddressCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    opaqueCaptureAddress*: uint64
  VkBufferOpaqueCaptureAddressCreateInfoKHR* = object
  VkBufferDeviceAddressCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceAddress*: VkDeviceAddress
  VkPhysicalDeviceImageViewImageFormatInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageViewType*: VkImageViewType
  VkFilterCubicImageViewImageFormatPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    filterCubic*: VkBool32
    filterCubicMinmax*: VkBool32
  VkPhysicalDeviceImagelessFramebufferFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    imagelessFramebuffer*: VkBool32
  VkPhysicalDeviceImagelessFramebufferFeaturesKHR* = object
  VkFramebufferAttachmentsCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    attachmentImageInfoCount*: uint32
    pAttachmentImageInfos*: ptr VkFramebufferAttachmentImageInfo
  VkFramebufferAttachmentsCreateInfoKHR* = object
  VkFramebufferAttachmentImageInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkImageCreateFlags
    usage*: VkImageUsageFlags
    width*: uint32
    height*: uint32
    layerCount*: uint32
    viewFormatCount*: uint32
    pViewFormats*: ptr VkFormat
  VkFramebufferAttachmentImageInfoKHR* = object
  VkRenderPassAttachmentBeginInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    attachmentCount*: uint32
    pAttachments*: ptr VkImageView
  VkRenderPassAttachmentBeginInfoKHR* = object
  VkPhysicalDeviceTextureCompressionASTCHDRFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    textureCompressionASTC_HDR*: VkBool32
  VkPhysicalDeviceTextureCompressionASTCHDRFeaturesEXT* = object
  VkPhysicalDeviceCooperativeMatrixFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    cooperativeMatrix*: VkBool32
    cooperativeMatrixRobustBufferAccess*: VkBool32
  VkPhysicalDeviceCooperativeMatrixPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    cooperativeMatrixSupportedStages*: VkShaderStageFlags
  VkCooperativeMatrixPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    MSize*: uint32
    NSize*: uint32
    KSize*: uint32
    AType*: VkComponentTypeNV
    BType*: VkComponentTypeNV
    CType*: VkComponentTypeNV
    DType*: VkComponentTypeNV
    scope*: VkScopeNV
  VkPhysicalDeviceYcbcrImageArraysFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    ycbcrImageArrays*: VkBool32
  VkImageViewHandleInfoNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    imageView*: VkImageView
    descriptorType*: VkDescriptorType
    sampler*: VkSampler
  VkImageViewAddressPropertiesNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceAddress*: VkDeviceAddress
    size*: VkDeviceSize
  VkPipelineCreationFeedback* = object
    flags*: VkPipelineCreationFeedbackFlags
    duration*: uint64
  VkPipelineCreationFeedbackEXT* = object
  VkPipelineCreationFeedbackCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    pPipelineCreationFeedback*: ptr VkPipelineCreationFeedback
    pipelineStageCreationFeedbackCount*: uint32
    pPipelineStageCreationFeedbacks*: ptr VkPipelineCreationFeedback
  VkPipelineCreationFeedbackCreateInfoEXT* = object
  VkPhysicalDevicePresentBarrierFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    presentBarrier*: VkBool32
  VkSurfaceCapabilitiesPresentBarrierNV* = object
    sType*: VkStructureType
    pNext*: pointer
    presentBarrierSupported*: VkBool32
  VkSwapchainPresentBarrierCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    presentBarrierEnable*: VkBool32
  VkPhysicalDevicePerformanceQueryFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    performanceCounterQueryPools*: VkBool32
    performanceCounterMultipleQueryPools*: VkBool32
  VkPhysicalDevicePerformanceQueryPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    allowCommandBufferQueryCopies*: VkBool32
  VkPerformanceCounterKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    unit*: VkPerformanceCounterUnitKHR
    scope*: VkPerformanceCounterScopeKHR
    storage*: VkPerformanceCounterStorageKHR
    uuid*: array[VK_UUID_SIZE, uint8]
  VkPerformanceCounterDescriptionKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPerformanceCounterDescriptionFlagsKHR
    name*: array[VK_MAX_DESCRIPTION_SIZE, char]
    category*: array[VK_MAX_DESCRIPTION_SIZE, char]
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
  VkQueryPoolPerformanceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    queueFamilyIndex*: uint32
    counterIndexCount*: uint32
    pCounterIndices*: ptr uint32
  VkPerformanceCounterResultKHR* {.union.} = object
    int32*: int32
    int64*: int64
    uint32*: uint32
    uint64*: uint64
    float32*: float32
    float64*: float64
  VkAcquireProfilingLockInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkAcquireProfilingLockFlagsKHR
    timeout*: uint64
  VkPerformanceQuerySubmitInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    counterPassIndex*: uint32
  VkPerformanceQueryReservationInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxPerformanceQueriesPerPool*: uint32
  VkHeadlessSurfaceCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkHeadlessSurfaceCreateFlagsEXT
  VkPhysicalDeviceCoverageReductionModeFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    coverageReductionMode*: VkBool32
  VkPipelineCoverageReductionStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkPipelineCoverageReductionStateCreateFlagsNV
    coverageReductionMode*: VkCoverageReductionModeNV
  VkFramebufferMixedSamplesCombinationNV* = object
    sType*: VkStructureType
    pNext*: pointer
    coverageReductionMode*: VkCoverageReductionModeNV
    rasterizationSamples*: VkSampleCountFlagBits
    depthStencilSamples*: VkSampleCountFlags
    colorSamples*: VkSampleCountFlags
  VkPhysicalDeviceShaderIntegerFunctions2FeaturesINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderIntegerFunctions2*: VkBool32
  VkPerformanceValueDataINTEL* {.union.} = object
    value32*: uint32
    value64*: uint64
    valueFloat*: float32
    valueBool*: VkBool32
    valueString*: cstring
  VkPerformanceValueINTEL* = object
    thetype*: VkPerformanceValueTypeINTEL
    data*: VkPerformanceValueDataINTEL
  VkInitializePerformanceApiInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    pUserData*: pointer
  VkQueryPoolPerformanceQueryCreateInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    performanceCountersSampling*: VkQueryPoolSamplingModeINTEL
  VkQueryPoolCreateInfoINTEL* = object
  VkPerformanceMarkerInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    marker*: uint64
  VkPerformanceStreamMarkerInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    marker*: uint32
  VkPerformanceOverrideInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkPerformanceOverrideTypeINTEL
    enable*: VkBool32
    parameter*: uint64
  VkPerformanceConfigurationAcquireInfoINTEL* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkPerformanceConfigurationTypeINTEL
  VkPhysicalDeviceShaderClockFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderSubgroupClock*: VkBool32
    shaderDeviceClock*: VkBool32
  VkPhysicalDeviceIndexTypeUint8FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    indexTypeUint8*: VkBool32
  VkPhysicalDeviceShaderSMBuiltinsPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderSMCount*: uint32
    shaderWarpsPerSM*: uint32
  VkPhysicalDeviceShaderSMBuiltinsFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderSMBuiltins*: VkBool32
  VkPhysicalDeviceFragmentShaderInterlockFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentShaderSampleInterlock*: VkBool32
    fragmentShaderPixelInterlock*: VkBool32
    fragmentShaderShadingRateInterlock*: VkBool32
  VkPhysicalDeviceSeparateDepthStencilLayoutsFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    separateDepthStencilLayouts*: VkBool32
  VkPhysicalDeviceSeparateDepthStencilLayoutsFeaturesKHR* = object
  VkAttachmentReferenceStencilLayout* = object
    sType*: VkStructureType
    pNext*: pointer
    stencilLayout*: VkImageLayout
  VkPhysicalDevicePrimitiveTopologyListRestartFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    primitiveTopologyListRestart*: VkBool32
    primitiveTopologyPatchListRestart*: VkBool32
  VkAttachmentReferenceStencilLayoutKHR* = object
  VkAttachmentDescriptionStencilLayout* = object
    sType*: VkStructureType
    pNext*: pointer
    stencilInitialLayout*: VkImageLayout
    stencilFinalLayout*: VkImageLayout
  VkAttachmentDescriptionStencilLayoutKHR* = object
  VkPhysicalDevicePipelineExecutablePropertiesFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineExecutableInfo*: VkBool32
  VkPipelineInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pipeline*: VkPipeline
  VkPipelineInfoEXT* = object
  VkPipelineExecutablePropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    stages*: VkShaderStageFlags
    name*: array[VK_MAX_DESCRIPTION_SIZE, char]
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    subgroupSize*: uint32
  VkPipelineExecutableInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pipeline*: VkPipeline
    executableIndex*: uint32
  VkPipelineExecutableStatisticValueKHR* {.union.} = object
    b32*: VkBool32
    i64*: int64
    u64*: uint64
    f64*: float64
  VkPipelineExecutableStatisticKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    name*: array[VK_MAX_DESCRIPTION_SIZE, char]
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    format*: VkPipelineExecutableStatisticFormatKHR
    value*: VkPipelineExecutableStatisticValueKHR
  VkPipelineExecutableInternalRepresentationKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    name*: array[VK_MAX_DESCRIPTION_SIZE, char]
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    isText*: VkBool32
    dataSize*: csize_t
    pData*: pointer
  VkPhysicalDeviceShaderDemoteToHelperInvocationFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderDemoteToHelperInvocation*: VkBool32
  VkPhysicalDeviceShaderDemoteToHelperInvocationFeaturesEXT* = object
  VkPhysicalDeviceTexelBufferAlignmentFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    texelBufferAlignment*: VkBool32
  VkPhysicalDeviceTexelBufferAlignmentProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    storageTexelBufferOffsetAlignmentBytes*: VkDeviceSize
    storageTexelBufferOffsetSingleTexelAlignment*: VkBool32
    uniformTexelBufferOffsetAlignmentBytes*: VkDeviceSize
    uniformTexelBufferOffsetSingleTexelAlignment*: VkBool32
  VkPhysicalDeviceTexelBufferAlignmentPropertiesEXT* = object
  VkPhysicalDeviceSubgroupSizeControlFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    subgroupSizeControl*: VkBool32
    computeFullSubgroups*: VkBool32
  VkPhysicalDeviceSubgroupSizeControlFeaturesEXT* = object
  VkPhysicalDeviceSubgroupSizeControlProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    minSubgroupSize*: uint32
    maxSubgroupSize*: uint32
    maxComputeWorkgroupSubgroups*: uint32
    requiredSubgroupSizeStages*: VkShaderStageFlags
  VkPhysicalDeviceSubgroupSizeControlPropertiesEXT* = object
  VkPipelineShaderStageRequiredSubgroupSizeCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    requiredSubgroupSize*: uint32
  VkPipelineShaderStageRequiredSubgroupSizeCreateInfoEXT* = object
  VkSubpassShadingPipelineCreateInfoHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    renderPass*: VkRenderPass
    subpass*: uint32
  VkPhysicalDeviceSubpassShadingPropertiesHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    maxSubpassShadingWorkgroupSizeAspectRatio*: uint32
  VkPhysicalDeviceClusterCullingShaderPropertiesHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    maxWorkGroupCount*: array[3, uint32]
    maxWorkGroupSize*: array[3, uint32]
    maxOutputClusterCount*: uint32
  VkMemoryOpaqueCaptureAddressAllocateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    opaqueCaptureAddress*: uint64
  VkMemoryOpaqueCaptureAddressAllocateInfoKHR* = object
  VkDeviceMemoryOpaqueCaptureAddressInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
  VkDeviceMemoryOpaqueCaptureAddressInfoKHR* = object
  VkPhysicalDeviceLineRasterizationFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    rectangularLines*: VkBool32
    bresenhamLines*: VkBool32
    smoothLines*: VkBool32
    stippledRectangularLines*: VkBool32
    stippledBresenhamLines*: VkBool32
    stippledSmoothLines*: VkBool32
  VkPhysicalDeviceLineRasterizationPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    lineSubPixelPrecisionBits*: uint32
  VkPipelineRasterizationLineStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    lineRasterizationMode*: VkLineRasterizationModeEXT
    stippledLineEnable*: VkBool32
    lineStippleFactor*: uint32
    lineStipplePattern*: uint16
  VkPhysicalDevicePipelineCreationCacheControlFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineCreationCacheControl*: VkBool32
  VkPhysicalDevicePipelineCreationCacheControlFeaturesEXT* = object
  VkPhysicalDeviceVulkan11Features* = object
    sType*: VkStructureType
    pNext*: pointer
    storageBuffer16BitAccess*: VkBool32
    uniformAndStorageBuffer16BitAccess*: VkBool32
    storagePushConstant16*: VkBool32
    storageInputOutput16*: VkBool32
    multiview*: VkBool32
    multiviewGeometryShader*: VkBool32
    multiviewTessellationShader*: VkBool32
    variablePointersStorageBuffer*: VkBool32
    variablePointers*: VkBool32
    protectedMemory*: VkBool32
    samplerYcbcrConversion*: VkBool32
    shaderDrawParameters*: VkBool32
  VkPhysicalDeviceVulkan11Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceUUID*: array[VK_UUID_SIZE, uint8]
    driverUUID*: array[VK_UUID_SIZE, uint8]
    deviceLUID*: array[VK_LUID_SIZE, uint8]
    deviceNodeMask*: uint32
    deviceLUIDValid*: VkBool32
    subgroupSize*: uint32
    subgroupSupportedStages*: VkShaderStageFlags
    subgroupSupportedOperations*: VkSubgroupFeatureFlags
    subgroupQuadOperationsInAllStages*: VkBool32
    pointClippingBehavior*: VkPointClippingBehavior
    maxMultiviewViewCount*: uint32
    maxMultiviewInstanceIndex*: uint32
    protectedNoFault*: VkBool32
    maxPerSetDescriptors*: uint32
    maxMemoryAllocationSize*: VkDeviceSize
  VkPhysicalDeviceVulkan12Features* = object
    sType*: VkStructureType
    pNext*: pointer
    samplerMirrorClampToEdge*: VkBool32
    drawIndirectCount*: VkBool32
    storageBuffer8BitAccess*: VkBool32
    uniformAndStorageBuffer8BitAccess*: VkBool32
    storagePushConstant8*: VkBool32
    shaderBufferInt64Atomics*: VkBool32
    shaderSharedInt64Atomics*: VkBool32
    shaderFloat16*: VkBool32
    shaderInt8*: VkBool32
    descriptorIndexing*: VkBool32
    shaderInputAttachmentArrayDynamicIndexing*: VkBool32
    shaderUniformTexelBufferArrayDynamicIndexing*: VkBool32
    shaderStorageTexelBufferArrayDynamicIndexing*: VkBool32
    shaderUniformBufferArrayNonUniformIndexing*: VkBool32
    shaderSampledImageArrayNonUniformIndexing*: VkBool32
    shaderStorageBufferArrayNonUniformIndexing*: VkBool32
    shaderStorageImageArrayNonUniformIndexing*: VkBool32
    shaderInputAttachmentArrayNonUniformIndexing*: VkBool32
    shaderUniformTexelBufferArrayNonUniformIndexing*: VkBool32
    shaderStorageTexelBufferArrayNonUniformIndexing*: VkBool32
    descriptorBindingUniformBufferUpdateAfterBind*: VkBool32
    descriptorBindingSampledImageUpdateAfterBind*: VkBool32
    descriptorBindingStorageImageUpdateAfterBind*: VkBool32
    descriptorBindingStorageBufferUpdateAfterBind*: VkBool32
    descriptorBindingUniformTexelBufferUpdateAfterBind*: VkBool32
    descriptorBindingStorageTexelBufferUpdateAfterBind*: VkBool32
    descriptorBindingUpdateUnusedWhilePending*: VkBool32
    descriptorBindingPartiallyBound*: VkBool32
    descriptorBindingVariableDescriptorCount*: VkBool32
    runtimeDescriptorArray*: VkBool32
    samplerFilterMinmax*: VkBool32
    scalarBlockLayout*: VkBool32
    imagelessFramebuffer*: VkBool32
    uniformBufferStandardLayout*: VkBool32
    shaderSubgroupExtendedTypes*: VkBool32
    separateDepthStencilLayouts*: VkBool32
    hostQueryReset*: VkBool32
    timelineSemaphore*: VkBool32
    bufferDeviceAddress*: VkBool32
    bufferDeviceAddressCaptureReplay*: VkBool32
    bufferDeviceAddressMultiDevice*: VkBool32
    vulkanMemoryModel*: VkBool32
    vulkanMemoryModelDeviceScope*: VkBool32
    vulkanMemoryModelAvailabilityVisibilityChains*: VkBool32
    shaderOutputViewportIndex*: VkBool32
    shaderOutputLayer*: VkBool32
    subgroupBroadcastDynamicId*: VkBool32
  VkPhysicalDeviceVulkan12Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    driverID*: VkDriverId
    driverName*: array[VK_MAX_DRIVER_NAME_SIZE, char]
    driverInfo*: array[VK_MAX_DRIVER_INFO_SIZE, char]
    conformanceVersion*: VkConformanceVersion
    denormBehaviorIndependence*: VkShaderFloatControlsIndependence
    roundingModeIndependence*: VkShaderFloatControlsIndependence
    shaderSignedZeroInfNanPreserveFloat16*: VkBool32
    shaderSignedZeroInfNanPreserveFloat32*: VkBool32
    shaderSignedZeroInfNanPreserveFloat64*: VkBool32
    shaderDenormPreserveFloat16*: VkBool32
    shaderDenormPreserveFloat32*: VkBool32
    shaderDenormPreserveFloat64*: VkBool32
    shaderDenormFlushToZeroFloat16*: VkBool32
    shaderDenormFlushToZeroFloat32*: VkBool32
    shaderDenormFlushToZeroFloat64*: VkBool32
    shaderRoundingModeRTEFloat16*: VkBool32
    shaderRoundingModeRTEFloat32*: VkBool32
    shaderRoundingModeRTEFloat64*: VkBool32
    shaderRoundingModeRTZFloat16*: VkBool32
    shaderRoundingModeRTZFloat32*: VkBool32
    shaderRoundingModeRTZFloat64*: VkBool32
    maxUpdateAfterBindDescriptorsInAllPools*: uint32
    shaderUniformBufferArrayNonUniformIndexingNative*: VkBool32
    shaderSampledImageArrayNonUniformIndexingNative*: VkBool32
    shaderStorageBufferArrayNonUniformIndexingNative*: VkBool32
    shaderStorageImageArrayNonUniformIndexingNative*: VkBool32
    shaderInputAttachmentArrayNonUniformIndexingNative*: VkBool32
    robustBufferAccessUpdateAfterBind*: VkBool32
    quadDivergentImplicitLod*: VkBool32
    maxPerStageDescriptorUpdateAfterBindSamplers*: uint32
    maxPerStageDescriptorUpdateAfterBindUniformBuffers*: uint32
    maxPerStageDescriptorUpdateAfterBindStorageBuffers*: uint32
    maxPerStageDescriptorUpdateAfterBindSampledImages*: uint32
    maxPerStageDescriptorUpdateAfterBindStorageImages*: uint32
    maxPerStageDescriptorUpdateAfterBindInputAttachments*: uint32
    maxPerStageUpdateAfterBindResources*: uint32
    maxDescriptorSetUpdateAfterBindSamplers*: uint32
    maxDescriptorSetUpdateAfterBindUniformBuffers*: uint32
    maxDescriptorSetUpdateAfterBindUniformBuffersDynamic*: uint32
    maxDescriptorSetUpdateAfterBindStorageBuffers*: uint32
    maxDescriptorSetUpdateAfterBindStorageBuffersDynamic*: uint32
    maxDescriptorSetUpdateAfterBindSampledImages*: uint32
    maxDescriptorSetUpdateAfterBindStorageImages*: uint32
    maxDescriptorSetUpdateAfterBindInputAttachments*: uint32
    supportedDepthResolveModes*: VkResolveModeFlags
    supportedStencilResolveModes*: VkResolveModeFlags
    independentResolveNone*: VkBool32
    independentResolve*: VkBool32
    filterMinmaxSingleComponentFormats*: VkBool32
    filterMinmaxImageComponentMapping*: VkBool32
    maxTimelineSemaphoreValueDifference*: uint64
    framebufferIntegerColorSampleCounts*: VkSampleCountFlags
  VkPhysicalDeviceVulkan13Features* = object
    sType*: VkStructureType
    pNext*: pointer
    robustImageAccess*: VkBool32
    inlineUniformBlock*: VkBool32
    descriptorBindingInlineUniformBlockUpdateAfterBind*: VkBool32
    pipelineCreationCacheControl*: VkBool32
    privateData*: VkBool32
    shaderDemoteToHelperInvocation*: VkBool32
    shaderTerminateInvocation*: VkBool32
    subgroupSizeControl*: VkBool32
    computeFullSubgroups*: VkBool32
    synchronization2*: VkBool32
    textureCompressionASTC_HDR*: VkBool32
    shaderZeroInitializeWorkgroupMemory*: VkBool32
    dynamicRendering*: VkBool32
    shaderIntegerDotProduct*: VkBool32
    maintenance4*: VkBool32
  VkPhysicalDeviceVulkan13Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    minSubgroupSize*: uint32
    maxSubgroupSize*: uint32
    maxComputeWorkgroupSubgroups*: uint32
    requiredSubgroupSizeStages*: VkShaderStageFlags
    maxInlineUniformBlockSize*: uint32
    maxPerStageDescriptorInlineUniformBlocks*: uint32
    maxPerStageDescriptorUpdateAfterBindInlineUniformBlocks*: uint32
    maxDescriptorSetInlineUniformBlocks*: uint32
    maxDescriptorSetUpdateAfterBindInlineUniformBlocks*: uint32
    maxInlineUniformTotalSize*: uint32
    integerDotProduct8BitUnsignedAccelerated*: VkBool32
    integerDotProduct8BitSignedAccelerated*: VkBool32
    integerDotProduct8BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct4x8BitPackedUnsignedAccelerated*: VkBool32
    integerDotProduct4x8BitPackedSignedAccelerated*: VkBool32
    integerDotProduct4x8BitPackedMixedSignednessAccelerated*: VkBool32
    integerDotProduct16BitUnsignedAccelerated*: VkBool32
    integerDotProduct16BitSignedAccelerated*: VkBool32
    integerDotProduct16BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct32BitUnsignedAccelerated*: VkBool32
    integerDotProduct32BitSignedAccelerated*: VkBool32
    integerDotProduct32BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct64BitUnsignedAccelerated*: VkBool32
    integerDotProduct64BitSignedAccelerated*: VkBool32
    integerDotProduct64BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitMixedSignednessAccelerated*: VkBool32
    storageTexelBufferOffsetAlignmentBytes*: VkDeviceSize
    storageTexelBufferOffsetSingleTexelAlignment*: VkBool32
    uniformTexelBufferOffsetAlignmentBytes*: VkDeviceSize
    uniformTexelBufferOffsetSingleTexelAlignment*: VkBool32
    maxBufferSize*: VkDeviceSize
  VkPipelineCompilerControlCreateInfoAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    compilerControlFlags*: VkPipelineCompilerControlFlagsAMD
  VkPhysicalDeviceCoherentMemoryFeaturesAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceCoherentMemory*: VkBool32
  VkFaultData* = object
    sType*: VkStructureType
    pNext*: pointer
    faultLevel*: VkFaultLevel
    faultType*: VkFaultType
  VkFaultCallbackInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    faultCount*: uint32
    pFaults*: ptr VkFaultData
    pfnFaultCallback*: PFN_vkFaultCallbackFunction
  VkPhysicalDeviceToolProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    name*: array[VK_MAX_EXTENSION_NAME_SIZE, char]
    version*: array[VK_MAX_EXTENSION_NAME_SIZE, char]
    purposes*: VkToolPurposeFlags
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    layer*: array[VK_MAX_EXTENSION_NAME_SIZE, char]
  VkPhysicalDeviceToolPropertiesEXT* = object
  VkSamplerCustomBorderColorCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    customBorderColor*: VkClearColorValue
    format*: VkFormat
  VkPhysicalDeviceCustomBorderColorPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxCustomBorderColorSamplers*: uint32
  VkPhysicalDeviceCustomBorderColorFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    customBorderColors*: VkBool32
    customBorderColorWithoutFormat*: VkBool32
  VkSamplerBorderColorComponentMappingCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    components*: VkComponentMapping
    srgb*: VkBool32
  VkPhysicalDeviceBorderColorSwizzleFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    borderColorSwizzle*: VkBool32
    borderColorSwizzleFromImage*: VkBool32
  VkDeviceOrHostAddressKHR* {.union.} = object
    deviceAddress*: VkDeviceAddress
    hostAddress*: pointer
  VkDeviceOrHostAddressConstKHR* {.union.} = object
    deviceAddress*: VkDeviceAddress
    hostAddress*: pointer
  VkAccelerationStructureGeometryTrianglesDataKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexFormat*: VkFormat
    vertexData*: VkDeviceOrHostAddressConstKHR
    vertexStride*: VkDeviceSize
    maxVertex*: uint32
    indexType*: VkIndexType
    indexData*: VkDeviceOrHostAddressConstKHR
    transformData*: VkDeviceOrHostAddressConstKHR
  VkAccelerationStructureGeometryAabbsDataKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    data*: VkDeviceOrHostAddressConstKHR
    stride*: VkDeviceSize
  VkAccelerationStructureGeometryInstancesDataKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    arrayOfPointers*: VkBool32
    data*: VkDeviceOrHostAddressConstKHR
  VkAccelerationStructureGeometryDataKHR* {.union.} = object
    triangles*: VkAccelerationStructureGeometryTrianglesDataKHR
    aabbs*: VkAccelerationStructureGeometryAabbsDataKHR
    instances*: VkAccelerationStructureGeometryInstancesDataKHR
  VkAccelerationStructureGeometryKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    geometryType*: VkGeometryTypeKHR
    geometry*: VkAccelerationStructureGeometryDataKHR
    flags*: VkGeometryFlagsKHR
  VkAccelerationStructureBuildGeometryInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkAccelerationStructureTypeKHR
    flags*: VkBuildAccelerationStructureFlagsKHR
    mode*: VkBuildAccelerationStructureModeKHR
    srcAccelerationStructure*: VkAccelerationStructureKHR
    dstAccelerationStructure*: VkAccelerationStructureKHR
    geometryCount*: uint32
    pGeometries*: ptr VkAccelerationStructureGeometryKHR
    ppGeometries*: ptr ptr VkAccelerationStructureGeometryKHR
    scratchData*: VkDeviceOrHostAddressKHR
  VkAccelerationStructureBuildRangeInfoKHR* = object
    primitiveCount*: uint32
    primitiveOffset*: uint32
    firstVertex*: uint32
    transformOffset*: uint32
  VkAccelerationStructureCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    createFlags*: VkAccelerationStructureCreateFlagsKHR
    buffer*: VkBuffer
    offset*: VkDeviceSize
    size*: VkDeviceSize
    thetype*: VkAccelerationStructureTypeKHR
    deviceAddress*: VkDeviceAddress
  VkAabbPositionsKHR* = object
    minX*: float32
    minY*: float32
    minZ*: float32
    maxX*: float32
    maxY*: float32
    maxZ*: float32
  VkAabbPositionsNV* = object
  VkTransformMatrixKHR* = object
    matrix*: array[3*4, float32]
  VkTransformMatrixNV* = object
  VkAccelerationStructureInstanceKHR* = object
    transform*: VkTransformMatrixKHR
    instanceCustomIndex*: uint32
    mask*: uint32
    instanceShaderBindingTableRecordOffset*: uint32
    flags*: VkGeometryInstanceFlagsKHR
    accelerationStructureReference*: uint64
  VkAccelerationStructureInstanceNV* = object
  VkAccelerationStructureDeviceAddressInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructure*: VkAccelerationStructureKHR
  VkAccelerationStructureVersionInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pVersionData*: ptr uint8
  VkCopyAccelerationStructureInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkAccelerationStructureKHR
    dst*: VkAccelerationStructureKHR
    mode*: VkCopyAccelerationStructureModeKHR
  VkCopyAccelerationStructureToMemoryInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkAccelerationStructureKHR
    dst*: VkDeviceOrHostAddressKHR
    mode*: VkCopyAccelerationStructureModeKHR
  VkCopyMemoryToAccelerationStructureInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkDeviceOrHostAddressConstKHR
    dst*: VkAccelerationStructureKHR
    mode*: VkCopyAccelerationStructureModeKHR
  VkRayTracingPipelineInterfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxPipelineRayPayloadSize*: uint32
    maxPipelineRayHitAttributeSize*: uint32
  VkPipelineLibraryCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    libraryCount*: uint32
    pLibraries*: ptr VkPipeline
  VkRefreshObjectKHR* = object
    objectType*: VkObjectType
    objectHandle*: uint64
    flags*: VkRefreshObjectFlagsKHR
  VkRefreshObjectListKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    objectCount*: uint32
    pObjects*: ptr VkRefreshObjectKHR
  VkPhysicalDeviceExtendedDynamicStateFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    extendedDynamicState*: VkBool32
  VkPhysicalDeviceExtendedDynamicState2FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    extendedDynamicState2*: VkBool32
    extendedDynamicState2LogicOp*: VkBool32
    extendedDynamicState2PatchControlPoints*: VkBool32
  VkPhysicalDeviceExtendedDynamicState3FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    extendedDynamicState3TessellationDomainOrigin*: VkBool32
    extendedDynamicState3DepthClampEnable*: VkBool32
    extendedDynamicState3PolygonMode*: VkBool32
    extendedDynamicState3RasterizationSamples*: VkBool32
    extendedDynamicState3SampleMask*: VkBool32
    extendedDynamicState3AlphaToCoverageEnable*: VkBool32
    extendedDynamicState3AlphaToOneEnable*: VkBool32
    extendedDynamicState3LogicOpEnable*: VkBool32
    extendedDynamicState3ColorBlendEnable*: VkBool32
    extendedDynamicState3ColorBlendEquation*: VkBool32
    extendedDynamicState3ColorWriteMask*: VkBool32
    extendedDynamicState3RasterizationStream*: VkBool32
    extendedDynamicState3ConservativeRasterizationMode*: VkBool32
    extendedDynamicState3ExtraPrimitiveOverestimationSize*: VkBool32
    extendedDynamicState3DepthClipEnable*: VkBool32
    extendedDynamicState3SampleLocationsEnable*: VkBool32
    extendedDynamicState3ColorBlendAdvanced*: VkBool32
    extendedDynamicState3ProvokingVertexMode*: VkBool32
    extendedDynamicState3LineRasterizationMode*: VkBool32
    extendedDynamicState3LineStippleEnable*: VkBool32
    extendedDynamicState3DepthClipNegativeOneToOne*: VkBool32
    extendedDynamicState3ViewportWScalingEnable*: VkBool32
    extendedDynamicState3ViewportSwizzle*: VkBool32
    extendedDynamicState3CoverageToColorEnable*: VkBool32
    extendedDynamicState3CoverageToColorLocation*: VkBool32
    extendedDynamicState3CoverageModulationMode*: VkBool32
    extendedDynamicState3CoverageModulationTableEnable*: VkBool32
    extendedDynamicState3CoverageModulationTable*: VkBool32
    extendedDynamicState3CoverageReductionMode*: VkBool32
    extendedDynamicState3RepresentativeFragmentTestEnable*: VkBool32
    extendedDynamicState3ShadingRateImageEnable*: VkBool32
  VkPhysicalDeviceExtendedDynamicState3PropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    dynamicPrimitiveTopologyUnrestricted*: VkBool32
  VkColorBlendEquationEXT* = object
    srcColorBlendFactor*: VkBlendFactor
    dstColorBlendFactor*: VkBlendFactor
    colorBlendOp*: VkBlendOp
    srcAlphaBlendFactor*: VkBlendFactor
    dstAlphaBlendFactor*: VkBlendFactor
    alphaBlendOp*: VkBlendOp
  VkColorBlendAdvancedEXT* = object
    advancedBlendOp*: VkBlendOp
    srcPremultiplied*: VkBool32
    dstPremultiplied*: VkBool32
    blendOverlap*: VkBlendOverlapEXT
    clampResults*: VkBool32
  VkRenderPassTransformBeginInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    transform*: VkSurfaceTransformFlagBitsKHR
  VkCopyCommandTransformInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    transform*: VkSurfaceTransformFlagBitsKHR
  VkCommandBufferInheritanceRenderPassTransformInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    transform*: VkSurfaceTransformFlagBitsKHR
    renderArea*: VkRect2D
  VkPhysicalDeviceDiagnosticsConfigFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    diagnosticsConfig*: VkBool32
  VkDeviceDiagnosticsConfigCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceDiagnosticsConfigFlagsNV
  VkPipelineOfflineCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineIdentifier*: array[VK_UUID_SIZE, uint8]
    matchControl*: VkPipelineMatchControl
    poolEntrySize*: VkDeviceSize
  VkPhysicalDeviceZeroInitializeWorkgroupMemoryFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderZeroInitializeWorkgroupMemory*: VkBool32
  VkPhysicalDeviceZeroInitializeWorkgroupMemoryFeaturesKHR* = object
  VkPhysicalDeviceShaderSubgroupUniformControlFlowFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderSubgroupUniformControlFlow*: VkBool32
  VkPhysicalDeviceRobustness2FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    robustBufferAccess2*: VkBool32
    robustImageAccess2*: VkBool32
    nullDescriptor*: VkBool32
  VkPhysicalDeviceRobustness2PropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    robustStorageBufferAccessSizeAlignment*: VkDeviceSize
    robustUniformBufferAccessSizeAlignment*: VkDeviceSize
  VkPhysicalDeviceImageRobustnessFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    robustImageAccess*: VkBool32
  VkPhysicalDeviceImageRobustnessFeaturesEXT* = object
  VkPhysicalDeviceWorkgroupMemoryExplicitLayoutFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    workgroupMemoryExplicitLayout*: VkBool32
    workgroupMemoryExplicitLayoutScalarBlockLayout*: VkBool32
    workgroupMemoryExplicitLayout8BitAccess*: VkBool32
    workgroupMemoryExplicitLayout16BitAccess*: VkBool32
  VkPhysicalDevice4444FormatsFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    formatA4R4G4B4*: VkBool32
    formatA4B4G4R4*: VkBool32
  VkPhysicalDeviceSubpassShadingFeaturesHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    subpassShading*: VkBool32
  VkPhysicalDeviceClusterCullingShaderFeaturesHUAWEI* = object
    sType*: VkStructureType
    pNext*: pointer
    clustercullingShader*: VkBool32
    multiviewClusterCullingShader*: VkBool32
  VkBufferCopy2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcOffset*: VkDeviceSize
    dstOffset*: VkDeviceSize
    size*: VkDeviceSize
  VkBufferCopy2KHR* = object
  VkImageCopy2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcSubresource*: VkImageSubresourceLayers
    srcOffset*: VkOffset3D
    dstSubresource*: VkImageSubresourceLayers
    dstOffset*: VkOffset3D
    extent*: VkExtent3D
  VkImageCopy2KHR* = object
  VkImageBlit2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcSubresource*: VkImageSubresourceLayers
    srcOffsets*: array[2, VkOffset3D]
    dstSubresource*: VkImageSubresourceLayers
    dstOffsets*: array[2, VkOffset3D]
  VkImageBlit2KHR* = object
  VkBufferImageCopy2* = object
    sType*: VkStructureType
    pNext*: pointer
    bufferOffset*: VkDeviceSize
    bufferRowLength*: uint32
    bufferImageHeight*: uint32
    imageSubresource*: VkImageSubresourceLayers
    imageOffset*: VkOffset3D
    imageExtent*: VkExtent3D
  VkBufferImageCopy2KHR* = object
  VkImageResolve2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcSubresource*: VkImageSubresourceLayers
    srcOffset*: VkOffset3D
    dstSubresource*: VkImageSubresourceLayers
    dstOffset*: VkOffset3D
    extent*: VkExtent3D
  VkImageResolve2KHR* = object
  VkCopyBufferInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcBuffer*: VkBuffer
    dstBuffer*: VkBuffer
    regionCount*: uint32
    pRegions*: ptr VkBufferCopy2
  VkCopyBufferInfo2KHR* = object
  VkCopyImageInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcImage*: VkImage
    srcImageLayout*: VkImageLayout
    dstImage*: VkImage
    dstImageLayout*: VkImageLayout
    regionCount*: uint32
    pRegions*: ptr VkImageCopy2
  VkCopyImageInfo2KHR* = object
  VkBlitImageInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcImage*: VkImage
    srcImageLayout*: VkImageLayout
    dstImage*: VkImage
    dstImageLayout*: VkImageLayout
    regionCount*: uint32
    pRegions*: ptr VkImageBlit2
    filter*: VkFilter
  VkBlitImageInfo2KHR* = object
  VkCopyBufferToImageInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcBuffer*: VkBuffer
    dstImage*: VkImage
    dstImageLayout*: VkImageLayout
    regionCount*: uint32
    pRegions*: ptr VkBufferImageCopy2
  VkCopyBufferToImageInfo2KHR* = object
  VkCopyImageToBufferInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcImage*: VkImage
    srcImageLayout*: VkImageLayout
    dstBuffer*: VkBuffer
    regionCount*: uint32
    pRegions*: ptr VkBufferImageCopy2
  VkCopyImageToBufferInfo2KHR* = object
  VkResolveImageInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcImage*: VkImage
    srcImageLayout*: VkImageLayout
    dstImage*: VkImage
    dstImageLayout*: VkImageLayout
    regionCount*: uint32
    pRegions*: ptr VkImageResolve2
  VkResolveImageInfo2KHR* = object
  VkPhysicalDeviceShaderImageAtomicInt64FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderImageInt64Atomics*: VkBool32
    sparseImageInt64Atomics*: VkBool32
  VkFragmentShadingRateAttachmentInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pFragmentShadingRateAttachment*: ptr VkAttachmentReference2
    shadingRateAttachmentTexelSize*: VkExtent2D
  VkPipelineFragmentShadingRateStateCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentSize*: VkExtent2D
    combinerOps*: array[2, VkFragmentShadingRateCombinerOpKHR]
  VkPhysicalDeviceFragmentShadingRateFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineFragmentShadingRate*: VkBool32
    primitiveFragmentShadingRate*: VkBool32
    attachmentFragmentShadingRate*: VkBool32
  VkPhysicalDeviceFragmentShadingRatePropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    minFragmentShadingRateAttachmentTexelSize*: VkExtent2D
    maxFragmentShadingRateAttachmentTexelSize*: VkExtent2D
    maxFragmentShadingRateAttachmentTexelSizeAspectRatio*: uint32
    primitiveFragmentShadingRateWithMultipleViewports*: VkBool32
    layeredShadingRateAttachments*: VkBool32
    fragmentShadingRateNonTrivialCombinerOps*: VkBool32
    maxFragmentSize*: VkExtent2D
    maxFragmentSizeAspectRatio*: uint32
    maxFragmentShadingRateCoverageSamples*: uint32
    maxFragmentShadingRateRasterizationSamples*: VkSampleCountFlagBits
    fragmentShadingRateWithShaderDepthStencilWrites*: VkBool32
    fragmentShadingRateWithSampleMask*: VkBool32
    fragmentShadingRateWithShaderSampleMask*: VkBool32
    fragmentShadingRateWithConservativeRasterization*: VkBool32
    fragmentShadingRateWithFragmentShaderInterlock*: VkBool32
    fragmentShadingRateWithCustomSampleLocations*: VkBool32
    fragmentShadingRateStrictMultiplyCombiner*: VkBool32
  VkPhysicalDeviceFragmentShadingRateKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    sampleCounts*: VkSampleCountFlags
    fragmentSize*: VkExtent2D
  VkPhysicalDeviceShaderTerminateInvocationFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderTerminateInvocation*: VkBool32
  VkPhysicalDeviceShaderTerminateInvocationFeaturesKHR* = object
  VkPhysicalDeviceFragmentShadingRateEnumsFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentShadingRateEnums*: VkBool32
    supersampleFragmentShadingRates*: VkBool32
    noInvocationFragmentShadingRates*: VkBool32
  VkPhysicalDeviceFragmentShadingRateEnumsPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    maxFragmentShadingRateInvocationCount*: VkSampleCountFlagBits
  VkPipelineFragmentShadingRateEnumStateCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    shadingRateType*: VkFragmentShadingRateTypeNV
    shadingRate*: VkFragmentShadingRateNV
    combinerOps*: array[2, VkFragmentShadingRateCombinerOpKHR]
  VkAccelerationStructureBuildSizesInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructureSize*: VkDeviceSize
    updateScratchSize*: VkDeviceSize
    buildScratchSize*: VkDeviceSize
  VkPhysicalDeviceImage2DViewOf3DFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    image2DViewOf3D*: VkBool32
    sampler2DViewOf3D*: VkBool32
  VkPhysicalDeviceImageSlicedViewOf3DFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageSlicedViewOf3D*: VkBool32
  VkPhysicalDeviceMutableDescriptorTypeFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mutableDescriptorType*: VkBool32
  VkPhysicalDeviceMutableDescriptorTypeFeaturesVALVE* = object
  VkMutableDescriptorTypeListEXT* = object
    descriptorTypeCount*: uint32
    pDescriptorTypes*: ptr VkDescriptorType
  VkMutableDescriptorTypeListVALVE* = object
  VkMutableDescriptorTypeCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mutableDescriptorTypeListCount*: uint32
    pMutableDescriptorTypeLists*: ptr VkMutableDescriptorTypeListEXT
  VkMutableDescriptorTypeCreateInfoVALVE* = object
  VkPhysicalDeviceDepthClipControlFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    depthClipControl*: VkBool32
  VkPipelineViewportDepthClipControlCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    negativeOneToOne*: VkBool32
  VkPhysicalDeviceVertexInputDynamicStateFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexInputDynamicState*: VkBool32
  VkPhysicalDeviceExternalMemoryRDMAFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    externalMemoryRDMA*: VkBool32
  VkVertexInputBindingDescription2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    binding*: uint32
    stride*: uint32
    inputRate*: VkVertexInputRate
    divisor*: uint32
  VkVertexInputAttributeDescription2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    location*: uint32
    binding*: uint32
    format*: VkFormat
    offset*: uint32
  VkPhysicalDeviceColorWriteEnableFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    colorWriteEnable*: VkBool32
  VkPipelineColorWriteCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    attachmentCount*: uint32
    pColorWriteEnables*: ptr VkBool32
  VkMemoryBarrier2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcStageMask*: VkPipelineStageFlags2
    srcAccessMask*: VkAccessFlags2
    dstStageMask*: VkPipelineStageFlags2
    dstAccessMask*: VkAccessFlags2
  VkMemoryBarrier2KHR* = object
  VkImageMemoryBarrier2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcStageMask*: VkPipelineStageFlags2
    srcAccessMask*: VkAccessFlags2
    dstStageMask*: VkPipelineStageFlags2
    dstAccessMask*: VkAccessFlags2
    oldLayout*: VkImageLayout
    newLayout*: VkImageLayout
    srcQueueFamilyIndex*: uint32
    dstQueueFamilyIndex*: uint32
    image*: VkImage
    subresourceRange*: VkImageSubresourceRange
  VkImageMemoryBarrier2KHR* = object
  VkBufferMemoryBarrier2* = object
    sType*: VkStructureType
    pNext*: pointer
    srcStageMask*: VkPipelineStageFlags2
    srcAccessMask*: VkAccessFlags2
    dstStageMask*: VkPipelineStageFlags2
    dstAccessMask*: VkAccessFlags2
    srcQueueFamilyIndex*: uint32
    dstQueueFamilyIndex*: uint32
    buffer*: VkBuffer
    offset*: VkDeviceSize
    size*: VkDeviceSize
  VkBufferMemoryBarrier2KHR* = object
  VkDependencyInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    dependencyFlags*: VkDependencyFlags
    memoryBarrierCount*: uint32
    pMemoryBarriers*: ptr VkMemoryBarrier2
    bufferMemoryBarrierCount*: uint32
    pBufferMemoryBarriers*: ptr VkBufferMemoryBarrier2
    imageMemoryBarrierCount*: uint32
    pImageMemoryBarriers*: ptr VkImageMemoryBarrier2
  VkDependencyInfoKHR* = object
  VkSemaphoreSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    value*: uint64
    stageMask*: VkPipelineStageFlags2
    deviceIndex*: uint32
  VkSemaphoreSubmitInfoKHR* = object
  VkCommandBufferSubmitInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    commandBuffer*: VkCommandBuffer
    deviceMask*: uint32
  VkCommandBufferSubmitInfoKHR* = object
  VkSubmitInfo2* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkSubmitFlags
    waitSemaphoreInfoCount*: uint32
    pWaitSemaphoreInfos*: ptr VkSemaphoreSubmitInfo
    commandBufferInfoCount*: uint32
    pCommandBufferInfos*: ptr VkCommandBufferSubmitInfo
    signalSemaphoreInfoCount*: uint32
    pSignalSemaphoreInfos*: ptr VkSemaphoreSubmitInfo
  VkSubmitInfo2KHR* = object
  VkQueueFamilyCheckpointProperties2NV* = object
    sType*: VkStructureType
    pNext*: pointer
    checkpointExecutionStageMask*: VkPipelineStageFlags2
  VkCheckpointData2NV* = object
    sType*: VkStructureType
    pNext*: pointer
    stage*: VkPipelineStageFlags2
    pCheckpointMarker*: pointer
  VkPhysicalDeviceSynchronization2Features* = object
    sType*: VkStructureType
    pNext*: pointer
    synchronization2*: VkBool32
  VkPhysicalDeviceSynchronization2FeaturesKHR* = object
  VkPhysicalDeviceVulkanSC10Properties* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceNoDynamicHostAllocations*: VkBool32
    deviceDestroyFreesMemory*: VkBool32
    commandPoolMultipleCommandBuffersRecording*: VkBool32
    commandPoolResetCommandBuffer*: VkBool32
    commandBufferSimultaneousUse*: VkBool32
    secondaryCommandBufferNullOrImagelessFramebuffer*: VkBool32
    recycleDescriptorSetMemory*: VkBool32
    recyclePipelineMemory*: VkBool32
    maxRenderPassSubpasses*: uint32
    maxRenderPassDependencies*: uint32
    maxSubpassInputAttachments*: uint32
    maxSubpassPreserveAttachments*: uint32
    maxFramebufferAttachments*: uint32
    maxDescriptorSetLayoutBindings*: uint32
    maxQueryFaultCount*: uint32
    maxCallbackFaultCount*: uint32
    maxCommandPoolCommandBuffers*: uint32
    maxCommandBufferSize*: VkDeviceSize
  VkPipelinePoolSize* = object
    sType*: VkStructureType
    pNext*: pointer
    poolEntrySize*: VkDeviceSize
    poolEntryCount*: uint32
  VkDeviceObjectReservationCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineCacheCreateInfoCount*: uint32
    pPipelineCacheCreateInfos*: ptr VkPipelineCacheCreateInfo
    pipelinePoolSizeCount*: uint32
    pPipelinePoolSizes*: ptr VkPipelinePoolSize
    semaphoreRequestCount*: uint32
    commandBufferRequestCount*: uint32
    fenceRequestCount*: uint32
    deviceMemoryRequestCount*: uint32
    bufferRequestCount*: uint32
    imageRequestCount*: uint32
    eventRequestCount*: uint32
    queryPoolRequestCount*: uint32
    bufferViewRequestCount*: uint32
    imageViewRequestCount*: uint32
    layeredImageViewRequestCount*: uint32
    pipelineCacheRequestCount*: uint32
    pipelineLayoutRequestCount*: uint32
    renderPassRequestCount*: uint32
    graphicsPipelineRequestCount*: uint32
    computePipelineRequestCount*: uint32
    descriptorSetLayoutRequestCount*: uint32
    samplerRequestCount*: uint32
    descriptorPoolRequestCount*: uint32
    descriptorSetRequestCount*: uint32
    framebufferRequestCount*: uint32
    commandPoolRequestCount*: uint32
    samplerYcbcrConversionRequestCount*: uint32
    surfaceRequestCount*: uint32
    swapchainRequestCount*: uint32
    displayModeRequestCount*: uint32
    subpassDescriptionRequestCount*: uint32
    attachmentDescriptionRequestCount*: uint32
    descriptorSetLayoutBindingRequestCount*: uint32
    descriptorSetLayoutBindingLimit*: uint32
    maxImageViewMipLevels*: uint32
    maxImageViewArrayLayers*: uint32
    maxLayeredImageViewMipLevels*: uint32
    maxOcclusionQueriesPerPool*: uint32
    maxPipelineStatisticsQueriesPerPool*: uint32
    maxTimestampQueriesPerPool*: uint32
    maxImmutableSamplersPerDescriptorSetLayout*: uint32
  VkCommandPoolMemoryReservationCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    commandPoolReservedSize*: VkDeviceSize
    commandPoolMaxCommandBuffers*: uint32
  VkCommandPoolMemoryConsumption* = object
    sType*: VkStructureType
    pNext*: pointer
    commandPoolAllocated*: VkDeviceSize
    commandPoolReservedSize*: VkDeviceSize
    commandBufferAllocated*: VkDeviceSize
  VkPhysicalDeviceVulkanSC10Features* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderAtomicInstructions*: VkBool32
  VkPhysicalDevicePrimitivesGeneratedQueryFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    primitivesGeneratedQuery*: VkBool32
    primitivesGeneratedQueryWithRasterizerDiscard*: VkBool32
    primitivesGeneratedQueryWithNonZeroStreams*: VkBool32
  VkPhysicalDeviceLegacyDitheringFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    legacyDithering*: VkBool32
  VkPhysicalDeviceMultisampledRenderToSingleSampledFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    multisampledRenderToSingleSampled*: VkBool32
  VkSubpassResolvePerformanceQueryEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    optimal*: VkBool32
  VkMultisampledRenderToSingleSampledInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    multisampledRenderToSingleSampledEnable*: VkBool32
    rasterizationSamples*: VkSampleCountFlagBits
  VkPhysicalDevicePipelineProtectedAccessFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineProtectedAccess*: VkBool32
  VkPhysicalDeviceInheritedViewportScissorFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    inheritedViewportScissor2D*: VkBool32
  VkCommandBufferInheritanceViewportScissorInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    viewportScissor2D*: VkBool32
    viewportDepthCount*: uint32
    pViewportDepths*: ptr VkViewport
  VkPhysicalDeviceYcbcr2Plane444FormatsFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    ycbcr2plane444Formats*: VkBool32
  VkPhysicalDeviceProvokingVertexFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    provokingVertexLast*: VkBool32
    transformFeedbackPreservesProvokingVertex*: VkBool32
  VkPhysicalDeviceProvokingVertexPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    provokingVertexModePerPipeline*: VkBool32
    transformFeedbackPreservesTriangleFanProvokingVertex*: VkBool32
  VkPipelineRasterizationProvokingVertexStateCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    provokingVertexMode*: VkProvokingVertexModeEXT
  VkCuModuleCreateInfoNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    dataSize*: csize_t
    pData*: pointer
  VkCuFunctionCreateInfoNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    module*: VkCuModuleNVX
    pName*: cstring
  VkCuLaunchInfoNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    function*: VkCuFunctionNVX
    gridDimX*: uint32
    gridDimY*: uint32
    gridDimZ*: uint32
    blockDimX*: uint32
    blockDimY*: uint32
    blockDimZ*: uint32
    sharedMemBytes*: uint32
    paramCount*: csize_t
    pParams*: ptr pointer
    extraCount*: csize_t
    pExtras*: ptr pointer
  VkPhysicalDeviceDescriptorBufferFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorBuffer*: VkBool32
    descriptorBufferCaptureReplay*: VkBool32
    descriptorBufferImageLayoutIgnored*: VkBool32
    descriptorBufferPushDescriptors*: VkBool32
  VkPhysicalDeviceDescriptorBufferPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    combinedImageSamplerDescriptorSingleArray*: VkBool32
    bufferlessPushDescriptors*: VkBool32
    allowSamplerImageViewPostSubmitCreation*: VkBool32
    descriptorBufferOffsetAlignment*: VkDeviceSize
    maxDescriptorBufferBindings*: uint32
    maxResourceDescriptorBufferBindings*: uint32
    maxSamplerDescriptorBufferBindings*: uint32
    maxEmbeddedImmutableSamplerBindings*: uint32
    maxEmbeddedImmutableSamplers*: uint32
    bufferCaptureReplayDescriptorDataSize*: csize_t
    imageCaptureReplayDescriptorDataSize*: csize_t
    imageViewCaptureReplayDescriptorDataSize*: csize_t
    samplerCaptureReplayDescriptorDataSize*: csize_t
    accelerationStructureCaptureReplayDescriptorDataSize*: csize_t
    samplerDescriptorSize*: csize_t
    combinedImageSamplerDescriptorSize*: csize_t
    sampledImageDescriptorSize*: csize_t
    storageImageDescriptorSize*: csize_t
    uniformTexelBufferDescriptorSize*: csize_t
    robustUniformTexelBufferDescriptorSize*: csize_t
    storageTexelBufferDescriptorSize*: csize_t
    robustStorageTexelBufferDescriptorSize*: csize_t
    uniformBufferDescriptorSize*: csize_t
    robustUniformBufferDescriptorSize*: csize_t
    storageBufferDescriptorSize*: csize_t
    robustStorageBufferDescriptorSize*: csize_t
    inputAttachmentDescriptorSize*: csize_t
    accelerationStructureDescriptorSize*: csize_t
    maxSamplerDescriptorBufferRange*: VkDeviceSize
    maxResourceDescriptorBufferRange*: VkDeviceSize
    samplerDescriptorBufferAddressSpaceSize*: VkDeviceSize
    resourceDescriptorBufferAddressSpaceSize*: VkDeviceSize
    descriptorBufferAddressSpaceSize*: VkDeviceSize
  VkPhysicalDeviceDescriptorBufferDensityMapPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    combinedImageSamplerDensityMapDescriptorSize*: csize_t
  VkDescriptorAddressInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    address*: VkDeviceAddress
    range*: VkDeviceSize
    format*: VkFormat
  VkDescriptorBufferBindingInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    address*: VkDeviceAddress
    usage*: VkBufferUsageFlags
  VkDescriptorBufferBindingPushDescriptorBufferHandleEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
  VkDescriptorDataEXT* {.union.} = object
    pSampler*: ptr VkSampler
    pCombinedImageSampler*: ptr VkDescriptorImageInfo
    pInputAttachmentImage*: ptr VkDescriptorImageInfo
    pSampledImage*: ptr VkDescriptorImageInfo
    pStorageImage*: ptr VkDescriptorImageInfo
    pUniformTexelBuffer*: ptr VkDescriptorAddressInfoEXT
    pStorageTexelBuffer*: ptr VkDescriptorAddressInfoEXT
    pUniformBuffer*: ptr VkDescriptorAddressInfoEXT
    pStorageBuffer*: ptr VkDescriptorAddressInfoEXT
    accelerationStructure*: VkDeviceAddress
  VkDescriptorGetInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkDescriptorType
    data*: VkDescriptorDataEXT
  VkBufferCaptureDescriptorDataInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    buffer*: VkBuffer
  VkImageCaptureDescriptorDataInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    image*: VkImage
  VkImageViewCaptureDescriptorDataInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageView*: VkImageView
  VkSamplerCaptureDescriptorDataInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    sampler*: VkSampler
  VkAccelerationStructureCaptureDescriptorDataInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    accelerationStructure*: VkAccelerationStructureKHR
    accelerationStructureNV*: VkAccelerationStructureNV
  VkOpaqueCaptureDescriptorDataCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    opaqueCaptureDescriptorData*: pointer
  VkPhysicalDeviceShaderIntegerDotProductFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderIntegerDotProduct*: VkBool32
  VkPhysicalDeviceShaderIntegerDotProductFeaturesKHR* = object
  VkPhysicalDeviceShaderIntegerDotProductProperties* = object
    sType*: VkStructureType
    pNext*: pointer
    integerDotProduct8BitUnsignedAccelerated*: VkBool32
    integerDotProduct8BitSignedAccelerated*: VkBool32
    integerDotProduct8BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct4x8BitPackedUnsignedAccelerated*: VkBool32
    integerDotProduct4x8BitPackedSignedAccelerated*: VkBool32
    integerDotProduct4x8BitPackedMixedSignednessAccelerated*: VkBool32
    integerDotProduct16BitUnsignedAccelerated*: VkBool32
    integerDotProduct16BitSignedAccelerated*: VkBool32
    integerDotProduct16BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct32BitUnsignedAccelerated*: VkBool32
    integerDotProduct32BitSignedAccelerated*: VkBool32
    integerDotProduct32BitMixedSignednessAccelerated*: VkBool32
    integerDotProduct64BitUnsignedAccelerated*: VkBool32
    integerDotProduct64BitSignedAccelerated*: VkBool32
    integerDotProduct64BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating8BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating4x8BitPackedMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating16BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating32BitMixedSignednessAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitUnsignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitSignedAccelerated*: VkBool32
    integerDotProductAccumulatingSaturating64BitMixedSignednessAccelerated*: VkBool32
  VkPhysicalDeviceShaderIntegerDotProductPropertiesKHR* = object
  VkPhysicalDeviceDrmPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    hasPrimary*: VkBool32
    hasRender*: VkBool32
    primaryMajor*: int64
    primaryMinor*: int64
    renderMajor*: int64
    renderMinor*: int64
  VkPhysicalDeviceFragmentShaderBarycentricFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fragmentShaderBarycentric*: VkBool32
  VkPhysicalDeviceFragmentShaderBarycentricPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    triStripVertexOrderIndependentOfProvokingVertex*: VkBool32
  VkPhysicalDeviceRayTracingMotionBlurFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    rayTracingMotionBlur*: VkBool32
    rayTracingMotionBlurPipelineTraceRaysIndirect*: VkBool32
  VkAccelerationStructureGeometryMotionTrianglesDataNV* = object
    sType*: VkStructureType
    pNext*: pointer
    vertexData*: VkDeviceOrHostAddressConstKHR
  VkAccelerationStructureMotionInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    maxInstances*: uint32
    flags*: VkAccelerationStructureMotionInfoFlagsNV
  VkSRTDataNV* = object
    sx*: float32
    a*: float32
    b*: float32
    pvx*: float32
    sy*: float32
    c*: float32
    pvy*: float32
    sz*: float32
    pvz*: float32
    qx*: float32
    qy*: float32
    qz*: float32
    qw*: float32
    tx*: float32
    ty*: float32
    tz*: float32
  VkAccelerationStructureSRTMotionInstanceNV* = object
    transformT0*: VkSRTDataNV
    transformT1*: VkSRTDataNV
    instanceCustomIndex*: uint32
    mask*: uint32
    instanceShaderBindingTableRecordOffset*: uint32
    flags*: VkGeometryInstanceFlagsKHR
    accelerationStructureReference*: uint64
  VkAccelerationStructureMatrixMotionInstanceNV* = object
    transformT0*: VkTransformMatrixKHR
    transformT1*: VkTransformMatrixKHR
    instanceCustomIndex*: uint32
    mask*: uint32
    instanceShaderBindingTableRecordOffset*: uint32
    flags*: VkGeometryInstanceFlagsKHR
    accelerationStructureReference*: uint64
  VkAccelerationStructureMotionInstanceDataNV* {.union.} = object
    staticInstance*: VkAccelerationStructureInstanceKHR
    matrixMotionInstance*: VkAccelerationStructureMatrixMotionInstanceNV
    srtMotionInstance*: VkAccelerationStructureSRTMotionInstanceNV
  VkAccelerationStructureMotionInstanceNV* = object
    thetype*: VkAccelerationStructureMotionInstanceTypeNV
    flags*: VkAccelerationStructureMotionInstanceFlagsNV
    data*: VkAccelerationStructureMotionInstanceDataNV
  VkMemoryGetRemoteAddressInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkPhysicalDeviceRGBA10X6FormatsFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    formatRgba10x6WithoutYCbCrSampler*: VkBool32
  VkFormatProperties3* = object
    sType*: VkStructureType
    pNext*: pointer
    linearTilingFeatures*: VkFormatFeatureFlags2
    optimalTilingFeatures*: VkFormatFeatureFlags2
    bufferFeatures*: VkFormatFeatureFlags2
  VkFormatProperties3KHR* = object
  VkDrmFormatModifierPropertiesList2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    drmFormatModifierCount*: uint32
    pDrmFormatModifierProperties*: ptr VkDrmFormatModifierProperties2EXT
  VkDrmFormatModifierProperties2EXT* = object
    drmFormatModifier*: uint64
    drmFormatModifierPlaneCount*: uint32
    drmFormatModifierTilingFeatures*: VkFormatFeatureFlags2
  VkPipelineRenderingCreateInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    viewMask*: uint32
    colorAttachmentCount*: uint32
    pColorAttachmentFormats*: ptr VkFormat
    depthAttachmentFormat*: VkFormat
    stencilAttachmentFormat*: VkFormat
  VkPipelineRenderingCreateInfoKHR* = object
  VkRenderingInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkRenderingFlags
    renderArea*: VkRect2D
    layerCount*: uint32
    viewMask*: uint32
    colorAttachmentCount*: uint32
    pColorAttachments*: ptr VkRenderingAttachmentInfo
    pDepthAttachment*: ptr VkRenderingAttachmentInfo
    pStencilAttachment*: ptr VkRenderingAttachmentInfo
  VkRenderingInfoKHR* = object
  VkRenderingAttachmentInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    imageView*: VkImageView
    imageLayout*: VkImageLayout
    resolveMode*: VkResolveModeFlagBits
    resolveImageView*: VkImageView
    resolveImageLayout*: VkImageLayout
    loadOp*: VkAttachmentLoadOp
    storeOp*: VkAttachmentStoreOp
    clearValue*: VkClearValue
  VkRenderingAttachmentInfoKHR* = object
  VkRenderingFragmentShadingRateAttachmentInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    imageView*: VkImageView
    imageLayout*: VkImageLayout
    shadingRateAttachmentTexelSize*: VkExtent2D
  VkRenderingFragmentDensityMapAttachmentInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageView*: VkImageView
    imageLayout*: VkImageLayout
  VkPhysicalDeviceDynamicRenderingFeatures* = object
    sType*: VkStructureType
    pNext*: pointer
    dynamicRendering*: VkBool32
  VkPhysicalDeviceDynamicRenderingFeaturesKHR* = object
  VkCommandBufferInheritanceRenderingInfo* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkRenderingFlags
    viewMask*: uint32
    colorAttachmentCount*: uint32
    pColorAttachmentFormats*: ptr VkFormat
    depthAttachmentFormat*: VkFormat
    stencilAttachmentFormat*: VkFormat
    rasterizationSamples*: VkSampleCountFlagBits
  VkCommandBufferInheritanceRenderingInfoKHR* = object
  VkAttachmentSampleCountInfoAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    colorAttachmentCount*: uint32
    pColorAttachmentSamples*: ptr VkSampleCountFlagBits
    depthStencilAttachmentSamples*: VkSampleCountFlagBits
  VkAttachmentSampleCountInfoNV* = object
  VkMultiviewPerViewAttributesInfoNVX* = object
    sType*: VkStructureType
    pNext*: pointer
    perViewAttributes*: VkBool32
    perViewAttributesPositionXOnly*: VkBool32
  VkPhysicalDeviceImageViewMinLodFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    minLod*: VkBool32
  VkImageViewMinLodCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    minLod*: float32
  VkPhysicalDeviceRasterizationOrderAttachmentAccessFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    rasterizationOrderColorAttachmentAccess*: VkBool32
    rasterizationOrderDepthAttachmentAccess*: VkBool32
    rasterizationOrderStencilAttachmentAccess*: VkBool32
  VkPhysicalDeviceRasterizationOrderAttachmentAccessFeaturesARM* = object
  VkPhysicalDeviceLinearColorAttachmentFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    linearColorAttachment*: VkBool32
  VkPhysicalDeviceGraphicsPipelineLibraryFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    graphicsPipelineLibrary*: VkBool32
  VkPhysicalDeviceGraphicsPipelineLibraryPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    graphicsPipelineLibraryFastLinking*: VkBool32
    graphicsPipelineLibraryIndependentInterpolationDecoration*: VkBool32
  VkGraphicsPipelineLibraryCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkGraphicsPipelineLibraryFlagsEXT
  VkPhysicalDeviceDescriptorSetHostMappingFeaturesVALVE* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorSetHostMapping*: VkBool32
  VkDescriptorSetBindingReferenceVALVE* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorSetLayout*: VkDescriptorSetLayout
    binding*: uint32
  VkDescriptorSetLayoutHostMappingInfoVALVE* = object
    sType*: VkStructureType
    pNext*: pointer
    descriptorOffset*: csize_t
    descriptorSize*: uint32
  VkPhysicalDeviceShaderModuleIdentifierFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderModuleIdentifier*: VkBool32
  VkPhysicalDeviceShaderModuleIdentifierPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderModuleIdentifierAlgorithmUUID*: array[VK_UUID_SIZE, uint8]
  VkPipelineShaderStageModuleIdentifierCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    identifierSize*: uint32
    pIdentifier*: ptr uint8
  VkShaderModuleIdentifierEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    identifierSize*: uint32
    identifier*: array[VK_MAX_SHADER_MODULE_IDENTIFIER_SIZE_EXT, uint8]
  VkImageCompressionControlEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkImageCompressionFlagsEXT
    compressionControlPlaneCount*: uint32
    pFixedRateFlags*: ptr VkImageCompressionFixedRateFlagsEXT
  VkPhysicalDeviceImageCompressionControlFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageCompressionControl*: VkBool32
  VkImageCompressionPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageCompressionFlags*: VkImageCompressionFlagsEXT
    imageCompressionFixedRateFlags*: VkImageCompressionFixedRateFlagsEXT
  VkPhysicalDeviceImageCompressionControlSwapchainFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageCompressionControlSwapchain*: VkBool32
  VkImageSubresource2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    imageSubresource*: VkImageSubresource
  VkSubresourceLayout2EXT* = object
    sType*: VkStructureType
    pNext*: pointer
    subresourceLayout*: VkSubresourceLayout
  VkRenderPassCreationControlEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    disallowMerging*: VkBool32
  VkRenderPassCreationFeedbackInfoEXT* = object
    postMergeSubpassCount*: uint32
  VkRenderPassCreationFeedbackCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pRenderPassFeedback*: ptr VkRenderPassCreationFeedbackInfoEXT
  VkRenderPassSubpassFeedbackInfoEXT* = object
    subpassMergeStatus*: VkSubpassMergeStatusEXT
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    postMergeIndex*: uint32
  VkRenderPassSubpassFeedbackCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pSubpassFeedback*: ptr VkRenderPassSubpassFeedbackInfoEXT
  VkPhysicalDeviceSubpassMergeFeedbackFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    subpassMergeFeedback*: VkBool32
  VkMicromapBuildInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    thetype*: VkMicromapTypeEXT
    flags*: VkBuildMicromapFlagsEXT
    mode*: VkBuildMicromapModeEXT
    dstMicromap*: VkMicromapEXT
    usageCountsCount*: uint32
    pUsageCounts*: ptr VkMicromapUsageEXT
    ppUsageCounts*: ptr ptr VkMicromapUsageEXT
    data*: VkDeviceOrHostAddressConstKHR
    scratchData*: VkDeviceOrHostAddressKHR
    triangleArray*: VkDeviceOrHostAddressConstKHR
    triangleArrayStride*: VkDeviceSize
  VkMicromapCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    createFlags*: VkMicromapCreateFlagsEXT
    buffer*: VkBuffer
    offset*: VkDeviceSize
    size*: VkDeviceSize
    thetype*: VkMicromapTypeEXT
    deviceAddress*: VkDeviceAddress
  VkMicromapVersionInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pVersionData*: ptr uint8
  VkCopyMicromapInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkMicromapEXT
    dst*: VkMicromapEXT
    mode*: VkCopyMicromapModeEXT
  VkCopyMicromapToMemoryInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkMicromapEXT
    dst*: VkDeviceOrHostAddressKHR
    mode*: VkCopyMicromapModeEXT
  VkCopyMemoryToMicromapInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    src*: VkDeviceOrHostAddressConstKHR
    dst*: VkMicromapEXT
    mode*: VkCopyMicromapModeEXT
  VkMicromapBuildSizesInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    micromapSize*: VkDeviceSize
    buildScratchSize*: VkDeviceSize
    discardable*: VkBool32
  VkMicromapUsageEXT* = object
    count*: uint32
    subdivisionLevel*: uint32
    format*: uint32
  VkMicromapTriangleEXT* = object
    dataOffset*: uint32
    subdivisionLevel*: uint16
    format*: uint16
  VkPhysicalDeviceOpacityMicromapFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    micromap*: VkBool32
    micromapCaptureReplay*: VkBool32
    micromapHostCommands*: VkBool32
  VkPhysicalDeviceOpacityMicromapPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxOpacity2StateSubdivisionLevel*: uint32
    maxOpacity4StateSubdivisionLevel*: uint32
  VkAccelerationStructureTrianglesOpacityMicromapEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    indexType*: VkIndexType
    indexBuffer*: VkDeviceOrHostAddressConstKHR
    indexStride*: VkDeviceSize
    baseTriangle*: uint32
    usageCountsCount*: uint32
    pUsageCounts*: ptr VkMicromapUsageEXT
    ppUsageCounts*: ptr ptr VkMicromapUsageEXT
    micromap*: VkMicromapEXT
  VkPipelinePropertiesIdentifierEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineIdentifier*: array[VK_UUID_SIZE, uint8]
  VkPhysicalDevicePipelinePropertiesFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelinePropertiesIdentifier*: VkBool32
  VkPhysicalDeviceShaderEarlyAndLateFragmentTestsFeaturesAMD* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderEarlyAndLateFragmentTests*: VkBool32
  VkPhysicalDeviceNonSeamlessCubeMapFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    nonSeamlessCubeMap*: VkBool32
  VkPhysicalDevicePipelineRobustnessFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineRobustness*: VkBool32
  VkPipelineRobustnessCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    storageBuffers*: VkPipelineRobustnessBufferBehaviorEXT
    uniformBuffers*: VkPipelineRobustnessBufferBehaviorEXT
    vertexInputs*: VkPipelineRobustnessBufferBehaviorEXT
    images*: VkPipelineRobustnessImageBehaviorEXT
  VkPhysicalDevicePipelineRobustnessPropertiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    defaultRobustnessStorageBuffers*: VkPipelineRobustnessBufferBehaviorEXT
    defaultRobustnessUniformBuffers*: VkPipelineRobustnessBufferBehaviorEXT
    defaultRobustnessVertexInputs*: VkPipelineRobustnessBufferBehaviorEXT
    defaultRobustnessImages*: VkPipelineRobustnessImageBehaviorEXT
  VkImageViewSampleWeightCreateInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    filterCenter*: VkOffset2D
    filterSize*: VkExtent2D
    numPhases*: uint32
  VkPhysicalDeviceImageProcessingFeaturesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    textureSampleWeighted*: VkBool32
    textureBoxFilter*: VkBool32
    textureBlockMatch*: VkBool32
  VkPhysicalDeviceImageProcessingPropertiesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    maxWeightFilterPhases*: uint32
    maxWeightFilterDimension*: VkExtent2D
    maxBlockMatchRegion*: VkExtent2D
    maxBoxFilterBlockSize*: VkExtent2D
  VkPhysicalDeviceTilePropertiesFeaturesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    tileProperties*: VkBool32
  VkTilePropertiesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    tileSize*: VkExtent3D
    apronSize*: VkExtent2D
    origin*: VkOffset2D
  VkPhysicalDeviceAmigoProfilingFeaturesSEC* = object
    sType*: VkStructureType
    pNext*: pointer
    amigoProfiling*: VkBool32
  VkAmigoProfilingSubmitInfoSEC* = object
    sType*: VkStructureType
    pNext*: pointer
    firstDrawTimestamp*: uint64
    swapBufferTimestamp*: uint64
  VkPhysicalDeviceAttachmentFeedbackLoopLayoutFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    attachmentFeedbackLoopLayout*: VkBool32
  VkPhysicalDeviceDepthClampZeroOneFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    depthClampZeroOne*: VkBool32
  VkPhysicalDeviceAddressBindingReportFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    reportAddressBinding*: VkBool32
  VkDeviceAddressBindingCallbackDataEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDeviceAddressBindingFlagsEXT
    baseAddress*: VkDeviceAddress
    size*: VkDeviceSize
    bindingType*: VkDeviceAddressBindingTypeEXT
  VkPhysicalDeviceOpticalFlowFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    opticalFlow*: VkBool32
  VkPhysicalDeviceOpticalFlowPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    supportedOutputGridSizes*: VkOpticalFlowGridSizeFlagsNV
    supportedHintGridSizes*: VkOpticalFlowGridSizeFlagsNV
    hintSupported*: VkBool32
    costSupported*: VkBool32
    bidirectionalFlowSupported*: VkBool32
    globalFlowSupported*: VkBool32
    minWidth*: uint32
    minHeight*: uint32
    maxWidth*: uint32
    maxHeight*: uint32
    maxNumRegionsOfInterest*: uint32
  VkOpticalFlowImageFormatInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    usage*: VkOpticalFlowUsageFlagsNV
  VkOpticalFlowImageFormatPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
  VkOpticalFlowSessionCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    width*: uint32
    height*: uint32
    imageFormat*: VkFormat
    flowVectorFormat*: VkFormat
    costFormat*: VkFormat
    outputGridSize*: VkOpticalFlowGridSizeFlagsNV
    hintGridSize*: VkOpticalFlowGridSizeFlagsNV
    performanceLevel*: VkOpticalFlowPerformanceLevelNV
    flags*: VkOpticalFlowSessionCreateFlagsNV
  VkOpticalFlowSessionCreatePrivateDataInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    id*: uint32
    size*: uint32
    pPrivateData*: pointer
  VkOpticalFlowExecuteInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkOpticalFlowExecuteFlagsNV
    regionCount*: uint32
    pRegions*: ptr VkRect2D
  VkPhysicalDeviceFaultFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    deviceFault*: VkBool32
    deviceFaultVendorBinary*: VkBool32
  VkDeviceFaultAddressInfoEXT* = object
    addressType*: VkDeviceFaultAddressTypeEXT
    reportedAddress*: VkDeviceAddress
    addressPrecision*: VkDeviceSize
  VkDeviceFaultVendorInfoEXT* = object
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    vendorFaultCode*: uint64
    vendorFaultData*: uint64
  VkDeviceFaultCountsEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    addressInfoCount*: uint32
    vendorInfoCount*: uint32
    vendorBinarySize*: VkDeviceSize
  VkDeviceFaultInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    description*: array[VK_MAX_DESCRIPTION_SIZE, char]
    pAddressInfos*: ptr VkDeviceFaultAddressInfoEXT
    pVendorInfos*: ptr VkDeviceFaultVendorInfoEXT
    pVendorBinaryData*: pointer
  VkDeviceFaultVendorBinaryHeaderVersionOneEXT* = object
    headerSize*: uint32
    headerVersion*: VkDeviceFaultVendorBinaryHeaderVersionEXT
    vendorID*: uint32
    deviceID*: uint32
    driverVersion*: uint32
    pipelineCacheUUID*: array[VK_UUID_SIZE, uint8]
    applicationNameOffset*: uint32
    applicationVersion*: uint32
    engineNameOffset*: uint32
  VkPhysicalDevicePipelineLibraryGroupHandlesFeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pipelineLibraryGroupHandles*: VkBool32
  VkDecompressMemoryRegionNV* = object
    srcAddress*: VkDeviceAddress
    dstAddress*: VkDeviceAddress
    compressedSize*: VkDeviceSize
    decompressedSize*: VkDeviceSize
    decompressionMethod*: VkMemoryDecompressionMethodFlagsNV
  VkPhysicalDeviceShaderCoreBuiltinsPropertiesARM* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderCoreMask*: uint64
    shaderCoreCount*: uint32
    shaderWarpsPerCore*: uint32
  VkPhysicalDeviceShaderCoreBuiltinsFeaturesARM* = object
    sType*: VkStructureType
    pNext*: pointer
    shaderCoreBuiltins*: VkBool32
  VkSurfacePresentModeEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    presentMode*: VkPresentModeKHR
  VkSurfacePresentScalingCapabilitiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    supportedPresentScaling*: VkPresentScalingFlagsEXT
    supportedPresentGravityX*: VkPresentGravityFlagsEXT
    supportedPresentGravityY*: VkPresentGravityFlagsEXT
    minScaledImageExtent*: VkExtent2D
    maxScaledImageExtent*: VkExtent2D
  VkSurfacePresentModeCompatibilityEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    presentModeCount*: uint32
    pPresentModes*: ptr VkPresentModeKHR
  VkPhysicalDeviceSwapchainMaintenance1FeaturesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainMaintenance1*: VkBool32
  VkSwapchainPresentFenceInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pFences*: ptr VkFence
  VkSwapchainPresentModesCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    presentModeCount*: uint32
    pPresentModes*: ptr VkPresentModeKHR
  VkSwapchainPresentModeInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchainCount*: uint32
    pPresentModes*: ptr VkPresentModeKHR
  VkSwapchainPresentScalingCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    scalingBehavior*: VkPresentScalingFlagsEXT
    presentGravityX*: VkPresentGravityFlagsEXT
    presentGravityY*: VkPresentGravityFlagsEXT
  VkReleaseSwapchainImagesInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    swapchain*: VkSwapchainKHR
    imageIndexCount*: uint32
    pImageIndices*: ptr uint32
  VkPhysicalDeviceRayTracingInvocationReorderFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    rayTracingInvocationReorder*: VkBool32
  VkPhysicalDeviceRayTracingInvocationReorderPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    rayTracingInvocationReorderReorderingHint*: VkRayTracingInvocationReorderModeNV
  VkDirectDriverLoadingInfoLUNARG* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkDirectDriverLoadingFlagsLUNARG
    pfnGetInstanceProcAddr*: PFN_vkGetInstanceProcAddrLUNARG
  VkDirectDriverLoadingListLUNARG* = object
    sType*: VkStructureType
    pNext*: pointer
    mode*: VkDirectDriverLoadingModeLUNARG
    driverCount*: uint32
    pDrivers*: ptr VkDirectDriverLoadingInfoLUNARG
  VkPhysicalDeviceMultiviewPerViewViewportsFeaturesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    multiviewPerViewViewports*: VkBool32
  VkPhysicalDeviceShaderCorePropertiesARM* = object
    sType*: VkStructureType
    pNext*: pointer
    pixelRate*: uint32
    texelRate*: uint32
    fmaRate*: uint32
  VkPhysicalDeviceMultiviewPerViewRenderAreasFeaturesQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    multiviewPerViewRenderAreas*: VkBool32
  VkMultiviewPerViewRenderAreasRenderPassBeginInfoQCOM* = object
    sType*: VkStructureType
    pNext*: pointer
    perViewRenderAreaCount*: uint32
    pPerViewRenderAreas*: ptr VkRect2D
# feature VK_VERSION_1_0
var
  vkCreateInstance*: proc(pCreateInfo: ptr VkInstanceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pInstance: ptr VkInstance): VkResult {.stdcall.}
  vkDestroyInstance*: proc(instance: VkInstance, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkEnumeratePhysicalDevices*: proc(instance: VkInstance, pPhysicalDeviceCount: ptr uint32, pPhysicalDevices: ptr VkPhysicalDevice): VkResult {.stdcall.}
  vkGetPhysicalDeviceFeatures*: proc(physicalDevice: VkPhysicalDevice, pFeatures: ptr VkPhysicalDeviceFeatures): void {.stdcall.}
  vkGetPhysicalDeviceFormatProperties*: proc(physicalDevice: VkPhysicalDevice, format: VkFormat, pFormatProperties: ptr VkFormatProperties): void {.stdcall.}
  vkGetPhysicalDeviceImageFormatProperties*: proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, tiling: VkImageTiling, usage: VkImageUsageFlags, flags: VkImageCreateFlags, pImageFormatProperties: ptr VkImageFormatProperties): VkResult {.stdcall.}
  vkGetPhysicalDeviceProperties*: proc(physicalDevice: VkPhysicalDevice, pProperties: ptr VkPhysicalDeviceProperties): void {.stdcall.}
  vkGetPhysicalDeviceQueueFamilyProperties*: proc(physicalDevice: VkPhysicalDevice, pQueueFamilyPropertyCount: ptr uint32, pQueueFamilyProperties: ptr VkQueueFamilyProperties): void {.stdcall.}
  vkGetPhysicalDeviceMemoryProperties*: proc(physicalDevice: VkPhysicalDevice, pMemoryProperties: ptr VkPhysicalDeviceMemoryProperties): void {.stdcall.}
  vkGetDeviceProcAddr*: proc(device: VkDevice, pName: cstring): PFN_vkVoidFunction {.stdcall.}
  vkCreateDevice*: proc(physicalDevice: VkPhysicalDevice, pCreateInfo: ptr VkDeviceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDevice: ptr VkDevice): VkResult {.stdcall.}
  vkDestroyDevice*: proc(device: VkDevice, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkEnumerateInstanceExtensionProperties*: proc(pLayerName: cstring, pPropertyCount: ptr uint32, pProperties: ptr VkExtensionProperties): VkResult {.stdcall.}
  vkEnumerateDeviceExtensionProperties*: proc(physicalDevice: VkPhysicalDevice, pLayerName: cstring, pPropertyCount: ptr uint32, pProperties: ptr VkExtensionProperties): VkResult {.stdcall.}
  vkEnumerateInstanceLayerProperties*: proc(pPropertyCount: ptr uint32, pProperties: ptr VkLayerProperties): VkResult {.stdcall.}
  vkEnumerateDeviceLayerProperties*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkLayerProperties): VkResult {.stdcall.}
  vkGetDeviceQueue*: proc(device: VkDevice, queueFamilyIndex: uint32, queueIndex: uint32, pQueue: ptr VkQueue): void {.stdcall.}
  vkQueueSubmit*: proc(queue: VkQueue, submitCount: uint32, pSubmits: ptr VkSubmitInfo, fence: VkFence): VkResult {.stdcall.}
  vkQueueWaitIdle*: proc(queue: VkQueue): VkResult {.stdcall.}
  vkDeviceWaitIdle*: proc(device: VkDevice): VkResult {.stdcall.}
  vkAllocateMemory*: proc(device: VkDevice, pAllocateInfo: ptr VkMemoryAllocateInfo, pAllocator: ptr VkAllocationCallbacks, pMemory: ptr VkDeviceMemory): VkResult {.stdcall.}
  vkFreeMemory*: proc(device: VkDevice, memory: VkDeviceMemory, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkMapMemory*: proc(device: VkDevice, memory: VkDeviceMemory, offset: VkDeviceSize, size: VkDeviceSize, flags: VkMemoryMapFlags, ppData: ptr pointer): VkResult {.stdcall.}
  vkUnmapMemory*: proc(device: VkDevice, memory: VkDeviceMemory): void {.stdcall.}
  vkFlushMappedMemoryRanges*: proc(device: VkDevice, memoryRangeCount: uint32, pMemoryRanges: ptr VkMappedMemoryRange): VkResult {.stdcall.}
  vkInvalidateMappedMemoryRanges*: proc(device: VkDevice, memoryRangeCount: uint32, pMemoryRanges: ptr VkMappedMemoryRange): VkResult {.stdcall.}
  vkGetDeviceMemoryCommitment*: proc(device: VkDevice, memory: VkDeviceMemory, pCommittedMemoryInBytes: ptr VkDeviceSize): void {.stdcall.}
  vkBindBufferMemory*: proc(device: VkDevice, buffer: VkBuffer, memory: VkDeviceMemory, memoryOffset: VkDeviceSize): VkResult {.stdcall.}
  vkBindImageMemory*: proc(device: VkDevice, image: VkImage, memory: VkDeviceMemory, memoryOffset: VkDeviceSize): VkResult {.stdcall.}
  vkGetBufferMemoryRequirements*: proc(device: VkDevice, buffer: VkBuffer, pMemoryRequirements: ptr VkMemoryRequirements): void {.stdcall.}
  vkGetImageMemoryRequirements*: proc(device: VkDevice, image: VkImage, pMemoryRequirements: ptr VkMemoryRequirements): void {.stdcall.}
  vkGetImageSparseMemoryRequirements*: proc(device: VkDevice, image: VkImage, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements): void {.stdcall.}
  vkGetPhysicalDeviceSparseImageFormatProperties*: proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, samples: VkSampleCountFlagBits, usage: VkImageUsageFlags, tiling: VkImageTiling, pPropertyCount: ptr uint32, pProperties: ptr VkSparseImageFormatProperties): void {.stdcall.}
  vkQueueBindSparse*: proc(queue: VkQueue, bindInfoCount: uint32, pBindInfo: ptr VkBindSparseInfo, fence: VkFence): VkResult {.stdcall.}
  vkCreateFence*: proc(device: VkDevice, pCreateInfo: ptr VkFenceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}
  vkDestroyFence*: proc(device: VkDevice, fence: VkFence, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkResetFences*: proc(device: VkDevice, fenceCount: uint32, pFences: ptr VkFence): VkResult {.stdcall.}
  vkGetFenceStatus*: proc(device: VkDevice, fence: VkFence): VkResult {.stdcall.}
  vkWaitForFences*: proc(device: VkDevice, fenceCount: uint32, pFences: ptr VkFence, waitAll: VkBool32, timeout: uint64): VkResult {.stdcall.}
  vkCreateSemaphore*: proc(device: VkDevice, pCreateInfo: ptr VkSemaphoreCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSemaphore: ptr VkSemaphore): VkResult {.stdcall.}
  vkDestroySemaphore*: proc(device: VkDevice, semaphore: VkSemaphore, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateEvent*: proc(device: VkDevice, pCreateInfo: ptr VkEventCreateInfo, pAllocator: ptr VkAllocationCallbacks, pEvent: ptr VkEvent): VkResult {.stdcall.}
  vkDestroyEvent*: proc(device: VkDevice, event: VkEvent, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetEventStatus*: proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}
  vkSetEvent*: proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}
  vkResetEvent*: proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}
  vkCreateQueryPool*: proc(device: VkDevice, pCreateInfo: ptr VkQueryPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pQueryPool: ptr VkQueryPool): VkResult {.stdcall.}
  vkDestroyQueryPool*: proc(device: VkDevice, queryPool: VkQueryPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetQueryPoolResults*: proc(device: VkDevice, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32, dataSize: csize_t, pData: pointer, stride: VkDeviceSize, flags: VkQueryResultFlags): VkResult {.stdcall.}
  vkCreateBuffer*: proc(device: VkDevice, pCreateInfo: ptr VkBufferCreateInfo, pAllocator: ptr VkAllocationCallbacks, pBuffer: ptr VkBuffer): VkResult {.stdcall.}
  vkDestroyBuffer*: proc(device: VkDevice, buffer: VkBuffer, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateBufferView*: proc(device: VkDevice, pCreateInfo: ptr VkBufferViewCreateInfo, pAllocator: ptr VkAllocationCallbacks, pView: ptr VkBufferView): VkResult {.stdcall.}
  vkDestroyBufferView*: proc(device: VkDevice, bufferView: VkBufferView, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateImage*: proc(device: VkDevice, pCreateInfo: ptr VkImageCreateInfo, pAllocator: ptr VkAllocationCallbacks, pImage: ptr VkImage): VkResult {.stdcall.}
  vkDestroyImage*: proc(device: VkDevice, image: VkImage, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetImageSubresourceLayout*: proc(device: VkDevice, image: VkImage, pSubresource: ptr VkImageSubresource, pLayout: ptr VkSubresourceLayout): void {.stdcall.}
  vkCreateImageView*: proc(device: VkDevice, pCreateInfo: ptr VkImageViewCreateInfo, pAllocator: ptr VkAllocationCallbacks, pView: ptr VkImageView): VkResult {.stdcall.}
  vkDestroyImageView*: proc(device: VkDevice, imageView: VkImageView, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateShaderModule*: proc(device: VkDevice, pCreateInfo: ptr VkShaderModuleCreateInfo, pAllocator: ptr VkAllocationCallbacks, pShaderModule: ptr VkShaderModule): VkResult {.stdcall.}
  vkDestroyShaderModule*: proc(device: VkDevice, shaderModule: VkShaderModule, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreatePipelineCache*: proc(device: VkDevice, pCreateInfo: ptr VkPipelineCacheCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelineCache: ptr VkPipelineCache): VkResult {.stdcall.}
  vkDestroyPipelineCache*: proc(device: VkDevice, pipelineCache: VkPipelineCache, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetPipelineCacheData*: proc(device: VkDevice, pipelineCache: VkPipelineCache, pDataSize: ptr csize_t, pData: pointer): VkResult {.stdcall.}
  vkMergePipelineCaches*: proc(device: VkDevice, dstCache: VkPipelineCache, srcCacheCount: uint32, pSrcCaches: ptr VkPipelineCache): VkResult {.stdcall.}
  vkCreateGraphicsPipelines*: proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkGraphicsPipelineCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}
  vkCreateComputePipelines*: proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkComputePipelineCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}
  vkDestroyPipeline*: proc(device: VkDevice, pipeline: VkPipeline, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreatePipelineLayout*: proc(device: VkDevice, pCreateInfo: ptr VkPipelineLayoutCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelineLayout: ptr VkPipelineLayout): VkResult {.stdcall.}
  vkDestroyPipelineLayout*: proc(device: VkDevice, pipelineLayout: VkPipelineLayout, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateSampler*: proc(device: VkDevice, pCreateInfo: ptr VkSamplerCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSampler: ptr VkSampler): VkResult {.stdcall.}
  vkDestroySampler*: proc(device: VkDevice, sampler: VkSampler, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateDescriptorSetLayout*: proc(device: VkDevice, pCreateInfo: ptr VkDescriptorSetLayoutCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSetLayout: ptr VkDescriptorSetLayout): VkResult {.stdcall.}
  vkDestroyDescriptorSetLayout*: proc(device: VkDevice, descriptorSetLayout: VkDescriptorSetLayout, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateDescriptorPool*: proc(device: VkDevice, pCreateInfo: ptr VkDescriptorPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDescriptorPool: ptr VkDescriptorPool): VkResult {.stdcall.}
  vkDestroyDescriptorPool*: proc(device: VkDevice, descriptorPool: VkDescriptorPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkResetDescriptorPool*: proc(device: VkDevice, descriptorPool: VkDescriptorPool, flags: VkDescriptorPoolResetFlags): VkResult {.stdcall.}
  vkAllocateDescriptorSets*: proc(device: VkDevice, pAllocateInfo: ptr VkDescriptorSetAllocateInfo, pDescriptorSets: ptr VkDescriptorSet): VkResult {.stdcall.}
  vkFreeDescriptorSets*: proc(device: VkDevice, descriptorPool: VkDescriptorPool, descriptorSetCount: uint32, pDescriptorSets: ptr VkDescriptorSet): VkResult {.stdcall.}
  vkUpdateDescriptorSets*: proc(device: VkDevice, descriptorWriteCount: uint32, pDescriptorWrites: ptr VkWriteDescriptorSet, descriptorCopyCount: uint32, pDescriptorCopies: ptr VkCopyDescriptorSet): void {.stdcall.}
  vkCreateFramebuffer*: proc(device: VkDevice, pCreateInfo: ptr VkFramebufferCreateInfo, pAllocator: ptr VkAllocationCallbacks, pFramebuffer: ptr VkFramebuffer): VkResult {.stdcall.}
  vkDestroyFramebuffer*: proc(device: VkDevice, framebuffer: VkFramebuffer, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateRenderPass*: proc(device: VkDevice, pCreateInfo: ptr VkRenderPassCreateInfo, pAllocator: ptr VkAllocationCallbacks, pRenderPass: ptr VkRenderPass): VkResult {.stdcall.}
  vkDestroyRenderPass*: proc(device: VkDevice, renderPass: VkRenderPass, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetRenderAreaGranularity*: proc(device: VkDevice, renderPass: VkRenderPass, pGranularity: ptr VkExtent2D): void {.stdcall.}
  vkCreateCommandPool*: proc(device: VkDevice, pCreateInfo: ptr VkCommandPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pCommandPool: ptr VkCommandPool): VkResult {.stdcall.}
  vkDestroyCommandPool*: proc(device: VkDevice, commandPool: VkCommandPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkResetCommandPool*: proc(device: VkDevice, commandPool: VkCommandPool, flags: VkCommandPoolResetFlags): VkResult {.stdcall.}
  vkAllocateCommandBuffers*: proc(device: VkDevice, pAllocateInfo: ptr VkCommandBufferAllocateInfo, pCommandBuffers: ptr VkCommandBuffer): VkResult {.stdcall.}
  vkFreeCommandBuffers*: proc(device: VkDevice, commandPool: VkCommandPool, commandBufferCount: uint32, pCommandBuffers: ptr VkCommandBuffer): void {.stdcall.}
  vkBeginCommandBuffer*: proc(commandBuffer: VkCommandBuffer, pBeginInfo: ptr VkCommandBufferBeginInfo): VkResult {.stdcall.}
  vkEndCommandBuffer*: proc(commandBuffer: VkCommandBuffer): VkResult {.stdcall.}
  vkResetCommandBuffer*: proc(commandBuffer: VkCommandBuffer, flags: VkCommandBufferResetFlags): VkResult {.stdcall.}
  vkCmdBindPipeline*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, pipeline: VkPipeline): void {.stdcall.}
  vkCmdSetViewport*: proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewports: ptr VkViewport): void {.stdcall.}
  vkCmdSetScissor*: proc(commandBuffer: VkCommandBuffer, firstScissor: uint32, scissorCount: uint32, pScissors: ptr VkRect2D): void {.stdcall.}
  vkCmdSetLineWidth*: proc(commandBuffer: VkCommandBuffer, lineWidth: float32): void {.stdcall.}
  vkCmdSetDepthBias*: proc(commandBuffer: VkCommandBuffer, depthBiasConstantFactor: float32, depthBiasClamp: float32, depthBiasSlopeFactor: float32): void {.stdcall.}
  vkCmdSetBlendConstants*: proc(commandBuffer: VkCommandBuffer, blendConstants: array[4, float32]): void {.stdcall.}
  vkCmdSetDepthBounds*: proc(commandBuffer: VkCommandBuffer, minDepthBounds: float32, maxDepthBounds: float32): void {.stdcall.}
  vkCmdSetStencilCompareMask*: proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, compareMask: uint32): void {.stdcall.}
  vkCmdSetStencilWriteMask*: proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, writeMask: uint32): void {.stdcall.}
  vkCmdSetStencilReference*: proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, reference: uint32): void {.stdcall.}
  vkCmdBindDescriptorSets*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, firstSet: uint32, descriptorSetCount: uint32, pDescriptorSets: ptr VkDescriptorSet, dynamicOffsetCount: uint32, pDynamicOffsets: ptr uint32): void {.stdcall.}
  vkCmdBindIndexBuffer*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, indexType: VkIndexType): void {.stdcall.}
  vkCmdBindVertexBuffers*: proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize): void {.stdcall.}
  vkCmdDraw*: proc(commandBuffer: VkCommandBuffer, vertexCount: uint32, instanceCount: uint32, firstVertex: uint32, firstInstance: uint32): void {.stdcall.}
  vkCmdDrawIndexed*: proc(commandBuffer: VkCommandBuffer, indexCount: uint32, instanceCount: uint32, firstIndex: uint32, vertexOffset: int32, firstInstance: uint32): void {.stdcall.}
  vkCmdDrawIndirect*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdDrawIndexedIndirect*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdDispatch*: proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}
  vkCmdDispatchIndirect*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize): void {.stdcall.}
  vkCmdCopyBuffer*: proc(commandBuffer: VkCommandBuffer, srcBuffer: VkBuffer, dstBuffer: VkBuffer, regionCount: uint32, pRegions: ptr VkBufferCopy): void {.stdcall.}
  vkCmdCopyImage*: proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageCopy): void {.stdcall.}
  vkCmdBlitImage*: proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageBlit, filter: VkFilter): void {.stdcall.}
  vkCmdCopyBufferToImage*: proc(commandBuffer: VkCommandBuffer, srcBuffer: VkBuffer, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkBufferImageCopy): void {.stdcall.}
  vkCmdCopyImageToBuffer*: proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstBuffer: VkBuffer, regionCount: uint32, pRegions: ptr VkBufferImageCopy): void {.stdcall.}
  vkCmdUpdateBuffer*: proc(commandBuffer: VkCommandBuffer, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, dataSize: VkDeviceSize, pData: pointer): void {.stdcall.}
  vkCmdFillBuffer*: proc(commandBuffer: VkCommandBuffer, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, size: VkDeviceSize, data: uint32): void {.stdcall.}
  vkCmdClearColorImage*: proc(commandBuffer: VkCommandBuffer, image: VkImage, imageLayout: VkImageLayout, pColor: ptr VkClearColorValue, rangeCount: uint32, pRanges: ptr VkImageSubresourceRange): void {.stdcall.}
  vkCmdClearDepthStencilImage*: proc(commandBuffer: VkCommandBuffer, image: VkImage, imageLayout: VkImageLayout, pDepthStencil: ptr VkClearDepthStencilValue, rangeCount: uint32, pRanges: ptr VkImageSubresourceRange): void {.stdcall.}
  vkCmdClearAttachments*: proc(commandBuffer: VkCommandBuffer, attachmentCount: uint32, pAttachments: ptr VkClearAttachment, rectCount: uint32, pRects: ptr VkClearRect): void {.stdcall.}
  vkCmdResolveImage*: proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageResolve): void {.stdcall.}
  vkCmdSetEvent*: proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags): void {.stdcall.}
  vkCmdResetEvent*: proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags): void {.stdcall.}
  vkCmdWaitEvents*: proc(commandBuffer: VkCommandBuffer, eventCount: uint32, pEvents: ptr VkEvent, srcStageMask: VkPipelineStageFlags, dstStageMask: VkPipelineStageFlags, memoryBarrierCount: uint32, pMemoryBarriers: ptr VkMemoryBarrier, bufferMemoryBarrierCount: uint32, pBufferMemoryBarriers: ptr VkBufferMemoryBarrier, imageMemoryBarrierCount: uint32, pImageMemoryBarriers: ptr VkImageMemoryBarrier): void {.stdcall.}
  vkCmdPipelineBarrier*: proc(commandBuffer: VkCommandBuffer, srcStageMask: VkPipelineStageFlags, dstStageMask: VkPipelineStageFlags, dependencyFlags: VkDependencyFlags, memoryBarrierCount: uint32, pMemoryBarriers: ptr VkMemoryBarrier, bufferMemoryBarrierCount: uint32, pBufferMemoryBarriers: ptr VkBufferMemoryBarrier, imageMemoryBarrierCount: uint32, pImageMemoryBarriers: ptr VkImageMemoryBarrier): void {.stdcall.}
  vkCmdBeginQuery*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, flags: VkQueryControlFlags): void {.stdcall.}
  vkCmdEndQuery*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32): void {.stdcall.}
  vkCmdResetQueryPool*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32): void {.stdcall.}
  vkCmdWriteTimestamp*: proc(commandBuffer: VkCommandBuffer, pipelineStage: VkPipelineStageFlagBits, queryPool: VkQueryPool, query: uint32): void {.stdcall.}
  vkCmdCopyQueryPoolResults*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, stride: VkDeviceSize, flags: VkQueryResultFlags): void {.stdcall.}
  vkCmdPushConstants*: proc(commandBuffer: VkCommandBuffer, layout: VkPipelineLayout, stageFlags: VkShaderStageFlags, offset: uint32, size: uint32, pValues: pointer): void {.stdcall.}
  vkCmdBeginRenderPass*: proc(commandBuffer: VkCommandBuffer, pRenderPassBegin: ptr VkRenderPassBeginInfo, contents: VkSubpassContents): void {.stdcall.}
  vkCmdNextSubpass*: proc(commandBuffer: VkCommandBuffer, contents: VkSubpassContents): void {.stdcall.}
  vkCmdEndRenderPass*: proc(commandBuffer: VkCommandBuffer): void {.stdcall.}
  vkCmdExecuteCommands*: proc(commandBuffer: VkCommandBuffer, commandBufferCount: uint32, pCommandBuffers: ptr VkCommandBuffer): void {.stdcall.}
proc loadVK_VERSION_1_0*(instance: VkInstance) =
  vkDestroyInstance = cast[proc(instance: VkInstance, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyInstance"))
  vkEnumeratePhysicalDevices = cast[proc(instance: VkInstance, pPhysicalDeviceCount: ptr uint32, pPhysicalDevices: ptr VkPhysicalDevice): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDevices"))
  vkGetPhysicalDeviceFeatures = cast[proc(physicalDevice: VkPhysicalDevice, pFeatures: ptr VkPhysicalDeviceFeatures): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFeatures"))
  vkGetPhysicalDeviceFormatProperties = cast[proc(physicalDevice: VkPhysicalDevice, format: VkFormat, pFormatProperties: ptr VkFormatProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFormatProperties"))
  vkGetPhysicalDeviceImageFormatProperties = cast[proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, tiling: VkImageTiling, usage: VkImageUsageFlags, flags: VkImageCreateFlags, pImageFormatProperties: ptr VkImageFormatProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceImageFormatProperties"))
  vkGetPhysicalDeviceProperties = cast[proc(physicalDevice: VkPhysicalDevice, pProperties: ptr VkPhysicalDeviceProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceProperties"))
  vkGetPhysicalDeviceQueueFamilyProperties = cast[proc(physicalDevice: VkPhysicalDevice, pQueueFamilyPropertyCount: ptr uint32, pQueueFamilyProperties: ptr VkQueueFamilyProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties"))
  vkGetPhysicalDeviceMemoryProperties = cast[proc(physicalDevice: VkPhysicalDevice, pMemoryProperties: ptr VkPhysicalDeviceMemoryProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceMemoryProperties"))
  vkGetDeviceProcAddr = cast[proc(device: VkDevice, pName: cstring): PFN_vkVoidFunction {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceProcAddr"))
  vkCreateDevice = cast[proc(physicalDevice: VkPhysicalDevice, pCreateInfo: ptr VkDeviceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDevice: ptr VkDevice): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDevice"))
  vkDestroyDevice = cast[proc(device: VkDevice, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDevice"))
  vkEnumerateDeviceExtensionProperties = cast[proc(physicalDevice: VkPhysicalDevice, pLayerName: cstring, pPropertyCount: ptr uint32, pProperties: ptr VkExtensionProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumerateDeviceExtensionProperties"))
  vkEnumerateDeviceLayerProperties = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkLayerProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumerateDeviceLayerProperties"))
  vkGetDeviceQueue = cast[proc(device: VkDevice, queueFamilyIndex: uint32, queueIndex: uint32, pQueue: ptr VkQueue): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceQueue"))
  vkQueueSubmit = cast[proc(queue: VkQueue, submitCount: uint32, pSubmits: ptr VkSubmitInfo, fence: VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueSubmit"))
  vkQueueWaitIdle = cast[proc(queue: VkQueue): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueWaitIdle"))
  vkDeviceWaitIdle = cast[proc(device: VkDevice): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDeviceWaitIdle"))
  vkAllocateMemory = cast[proc(device: VkDevice, pAllocateInfo: ptr VkMemoryAllocateInfo, pAllocator: ptr VkAllocationCallbacks, pMemory: ptr VkDeviceMemory): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAllocateMemory"))
  vkFreeMemory = cast[proc(device: VkDevice, memory: VkDeviceMemory, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkFreeMemory"))
  vkMapMemory = cast[proc(device: VkDevice, memory: VkDeviceMemory, offset: VkDeviceSize, size: VkDeviceSize, flags: VkMemoryMapFlags, ppData: ptr pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkMapMemory"))
  vkUnmapMemory = cast[proc(device: VkDevice, memory: VkDeviceMemory): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkUnmapMemory"))
  vkFlushMappedMemoryRanges = cast[proc(device: VkDevice, memoryRangeCount: uint32, pMemoryRanges: ptr VkMappedMemoryRange): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkFlushMappedMemoryRanges"))
  vkInvalidateMappedMemoryRanges = cast[proc(device: VkDevice, memoryRangeCount: uint32, pMemoryRanges: ptr VkMappedMemoryRange): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkInvalidateMappedMemoryRanges"))
  vkGetDeviceMemoryCommitment = cast[proc(device: VkDevice, memory: VkDeviceMemory, pCommittedMemoryInBytes: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceMemoryCommitment"))
  vkBindBufferMemory = cast[proc(device: VkDevice, buffer: VkBuffer, memory: VkDeviceMemory, memoryOffset: VkDeviceSize): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindBufferMemory"))
  vkBindImageMemory = cast[proc(device: VkDevice, image: VkImage, memory: VkDeviceMemory, memoryOffset: VkDeviceSize): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindImageMemory"))
  vkGetBufferMemoryRequirements = cast[proc(device: VkDevice, buffer: VkBuffer, pMemoryRequirements: ptr VkMemoryRequirements): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferMemoryRequirements"))
  vkGetImageMemoryRequirements = cast[proc(device: VkDevice, image: VkImage, pMemoryRequirements: ptr VkMemoryRequirements): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageMemoryRequirements"))
  vkGetImageSparseMemoryRequirements = cast[proc(device: VkDevice, image: VkImage, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageSparseMemoryRequirements"))
  vkGetPhysicalDeviceSparseImageFormatProperties = cast[proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, samples: VkSampleCountFlagBits, usage: VkImageUsageFlags, tiling: VkImageTiling, pPropertyCount: ptr uint32, pProperties: ptr VkSparseImageFormatProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSparseImageFormatProperties"))
  vkQueueBindSparse = cast[proc(queue: VkQueue, bindInfoCount: uint32, pBindInfo: ptr VkBindSparseInfo, fence: VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueBindSparse"))
  vkCreateFence = cast[proc(device: VkDevice, pCreateInfo: ptr VkFenceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateFence"))
  vkDestroyFence = cast[proc(device: VkDevice, fence: VkFence, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyFence"))
  vkResetFences = cast[proc(device: VkDevice, fenceCount: uint32, pFences: ptr VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetFences"))
  vkGetFenceStatus = cast[proc(device: VkDevice, fence: VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetFenceStatus"))
  vkWaitForFences = cast[proc(device: VkDevice, fenceCount: uint32, pFences: ptr VkFence, waitAll: VkBool32, timeout: uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkWaitForFences"))
  vkCreateSemaphore = cast[proc(device: VkDevice, pCreateInfo: ptr VkSemaphoreCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSemaphore: ptr VkSemaphore): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateSemaphore"))
  vkDestroySemaphore = cast[proc(device: VkDevice, semaphore: VkSemaphore, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroySemaphore"))
  vkCreateEvent = cast[proc(device: VkDevice, pCreateInfo: ptr VkEventCreateInfo, pAllocator: ptr VkAllocationCallbacks, pEvent: ptr VkEvent): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateEvent"))
  vkDestroyEvent = cast[proc(device: VkDevice, event: VkEvent, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyEvent"))
  vkGetEventStatus = cast[proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetEventStatus"))
  vkSetEvent = cast[proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetEvent"))
  vkResetEvent = cast[proc(device: VkDevice, event: VkEvent): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetEvent"))
  vkCreateQueryPool = cast[proc(device: VkDevice, pCreateInfo: ptr VkQueryPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pQueryPool: ptr VkQueryPool): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateQueryPool"))
  vkDestroyQueryPool = cast[proc(device: VkDevice, queryPool: VkQueryPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyQueryPool"))
  vkGetQueryPoolResults = cast[proc(device: VkDevice, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32, dataSize: csize_t, pData: pointer, stride: VkDeviceSize, flags: VkQueryResultFlags): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetQueryPoolResults"))
  vkCreateBuffer = cast[proc(device: VkDevice, pCreateInfo: ptr VkBufferCreateInfo, pAllocator: ptr VkAllocationCallbacks, pBuffer: ptr VkBuffer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateBuffer"))
  vkDestroyBuffer = cast[proc(device: VkDevice, buffer: VkBuffer, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyBuffer"))
  vkCreateBufferView = cast[proc(device: VkDevice, pCreateInfo: ptr VkBufferViewCreateInfo, pAllocator: ptr VkAllocationCallbacks, pView: ptr VkBufferView): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateBufferView"))
  vkDestroyBufferView = cast[proc(device: VkDevice, bufferView: VkBufferView, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyBufferView"))
  vkCreateImage = cast[proc(device: VkDevice, pCreateInfo: ptr VkImageCreateInfo, pAllocator: ptr VkAllocationCallbacks, pImage: ptr VkImage): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateImage"))
  vkDestroyImage = cast[proc(device: VkDevice, image: VkImage, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyImage"))
  vkGetImageSubresourceLayout = cast[proc(device: VkDevice, image: VkImage, pSubresource: ptr VkImageSubresource, pLayout: ptr VkSubresourceLayout): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageSubresourceLayout"))
  vkCreateImageView = cast[proc(device: VkDevice, pCreateInfo: ptr VkImageViewCreateInfo, pAllocator: ptr VkAllocationCallbacks, pView: ptr VkImageView): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateImageView"))
  vkDestroyImageView = cast[proc(device: VkDevice, imageView: VkImageView, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyImageView"))
  vkCreateShaderModule = cast[proc(device: VkDevice, pCreateInfo: ptr VkShaderModuleCreateInfo, pAllocator: ptr VkAllocationCallbacks, pShaderModule: ptr VkShaderModule): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateShaderModule"))
  vkDestroyShaderModule = cast[proc(device: VkDevice, shaderModule: VkShaderModule, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyShaderModule"))
  vkCreatePipelineCache = cast[proc(device: VkDevice, pCreateInfo: ptr VkPipelineCacheCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelineCache: ptr VkPipelineCache): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreatePipelineCache"))
  vkDestroyPipelineCache = cast[proc(device: VkDevice, pipelineCache: VkPipelineCache, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyPipelineCache"))
  vkGetPipelineCacheData = cast[proc(device: VkDevice, pipelineCache: VkPipelineCache, pDataSize: ptr csize_t, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPipelineCacheData"))
  vkMergePipelineCaches = cast[proc(device: VkDevice, dstCache: VkPipelineCache, srcCacheCount: uint32, pSrcCaches: ptr VkPipelineCache): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkMergePipelineCaches"))
  vkCreateGraphicsPipelines = cast[proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkGraphicsPipelineCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateGraphicsPipelines"))
  vkCreateComputePipelines = cast[proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkComputePipelineCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateComputePipelines"))
  vkDestroyPipeline = cast[proc(device: VkDevice, pipeline: VkPipeline, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyPipeline"))
  vkCreatePipelineLayout = cast[proc(device: VkDevice, pCreateInfo: ptr VkPipelineLayoutCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPipelineLayout: ptr VkPipelineLayout): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreatePipelineLayout"))
  vkDestroyPipelineLayout = cast[proc(device: VkDevice, pipelineLayout: VkPipelineLayout, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyPipelineLayout"))
  vkCreateSampler = cast[proc(device: VkDevice, pCreateInfo: ptr VkSamplerCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSampler: ptr VkSampler): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateSampler"))
  vkDestroySampler = cast[proc(device: VkDevice, sampler: VkSampler, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroySampler"))
  vkCreateDescriptorSetLayout = cast[proc(device: VkDevice, pCreateInfo: ptr VkDescriptorSetLayoutCreateInfo, pAllocator: ptr VkAllocationCallbacks, pSetLayout: ptr VkDescriptorSetLayout): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDescriptorSetLayout"))
  vkDestroyDescriptorSetLayout = cast[proc(device: VkDevice, descriptorSetLayout: VkDescriptorSetLayout, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDescriptorSetLayout"))
  vkCreateDescriptorPool = cast[proc(device: VkDevice, pCreateInfo: ptr VkDescriptorPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDescriptorPool: ptr VkDescriptorPool): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDescriptorPool"))
  vkDestroyDescriptorPool = cast[proc(device: VkDevice, descriptorPool: VkDescriptorPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDescriptorPool"))
  vkResetDescriptorPool = cast[proc(device: VkDevice, descriptorPool: VkDescriptorPool, flags: VkDescriptorPoolResetFlags): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetDescriptorPool"))
  vkAllocateDescriptorSets = cast[proc(device: VkDevice, pAllocateInfo: ptr VkDescriptorSetAllocateInfo, pDescriptorSets: ptr VkDescriptorSet): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAllocateDescriptorSets"))
  vkFreeDescriptorSets = cast[proc(device: VkDevice, descriptorPool: VkDescriptorPool, descriptorSetCount: uint32, pDescriptorSets: ptr VkDescriptorSet): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkFreeDescriptorSets"))
  vkUpdateDescriptorSets = cast[proc(device: VkDevice, descriptorWriteCount: uint32, pDescriptorWrites: ptr VkWriteDescriptorSet, descriptorCopyCount: uint32, pDescriptorCopies: ptr VkCopyDescriptorSet): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkUpdateDescriptorSets"))
  vkCreateFramebuffer = cast[proc(device: VkDevice, pCreateInfo: ptr VkFramebufferCreateInfo, pAllocator: ptr VkAllocationCallbacks, pFramebuffer: ptr VkFramebuffer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateFramebuffer"))
  vkDestroyFramebuffer = cast[proc(device: VkDevice, framebuffer: VkFramebuffer, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyFramebuffer"))
  vkCreateRenderPass = cast[proc(device: VkDevice, pCreateInfo: ptr VkRenderPassCreateInfo, pAllocator: ptr VkAllocationCallbacks, pRenderPass: ptr VkRenderPass): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateRenderPass"))
  vkDestroyRenderPass = cast[proc(device: VkDevice, renderPass: VkRenderPass, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyRenderPass"))
  vkGetRenderAreaGranularity = cast[proc(device: VkDevice, renderPass: VkRenderPass, pGranularity: ptr VkExtent2D): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRenderAreaGranularity"))
  vkCreateCommandPool = cast[proc(device: VkDevice, pCreateInfo: ptr VkCommandPoolCreateInfo, pAllocator: ptr VkAllocationCallbacks, pCommandPool: ptr VkCommandPool): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateCommandPool"))
  vkDestroyCommandPool = cast[proc(device: VkDevice, commandPool: VkCommandPool, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyCommandPool"))
  vkResetCommandPool = cast[proc(device: VkDevice, commandPool: VkCommandPool, flags: VkCommandPoolResetFlags): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetCommandPool"))
  vkAllocateCommandBuffers = cast[proc(device: VkDevice, pAllocateInfo: ptr VkCommandBufferAllocateInfo, pCommandBuffers: ptr VkCommandBuffer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAllocateCommandBuffers"))
  vkFreeCommandBuffers = cast[proc(device: VkDevice, commandPool: VkCommandPool, commandBufferCount: uint32, pCommandBuffers: ptr VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkFreeCommandBuffers"))
  vkBeginCommandBuffer = cast[proc(commandBuffer: VkCommandBuffer, pBeginInfo: ptr VkCommandBufferBeginInfo): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBeginCommandBuffer"))
  vkEndCommandBuffer = cast[proc(commandBuffer: VkCommandBuffer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEndCommandBuffer"))
  vkResetCommandBuffer = cast[proc(commandBuffer: VkCommandBuffer, flags: VkCommandBufferResetFlags): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetCommandBuffer"))
  vkCmdBindPipeline = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, pipeline: VkPipeline): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindPipeline"))
  vkCmdSetViewport = cast[proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewports: ptr VkViewport): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewport"))
  vkCmdSetScissor = cast[proc(commandBuffer: VkCommandBuffer, firstScissor: uint32, scissorCount: uint32, pScissors: ptr VkRect2D): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetScissor"))
  vkCmdSetLineWidth = cast[proc(commandBuffer: VkCommandBuffer, lineWidth: float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetLineWidth"))
  vkCmdSetDepthBias = cast[proc(commandBuffer: VkCommandBuffer, depthBiasConstantFactor: float32, depthBiasClamp: float32, depthBiasSlopeFactor: float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthBias"))
  vkCmdSetBlendConstants = cast[proc(commandBuffer: VkCommandBuffer, blendConstants: array[4, float32]): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetBlendConstants"))
  vkCmdSetDepthBounds = cast[proc(commandBuffer: VkCommandBuffer, minDepthBounds: float32, maxDepthBounds: float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthBounds"))
  vkCmdSetStencilCompareMask = cast[proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, compareMask: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetStencilCompareMask"))
  vkCmdSetStencilWriteMask = cast[proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, writeMask: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetStencilWriteMask"))
  vkCmdSetStencilReference = cast[proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, reference: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetStencilReference"))
  vkCmdBindDescriptorSets = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, firstSet: uint32, descriptorSetCount: uint32, pDescriptorSets: ptr VkDescriptorSet, dynamicOffsetCount: uint32, pDynamicOffsets: ptr uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindDescriptorSets"))
  vkCmdBindIndexBuffer = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, indexType: VkIndexType): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindIndexBuffer"))
  vkCmdBindVertexBuffers = cast[proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindVertexBuffers"))
  vkCmdDraw = cast[proc(commandBuffer: VkCommandBuffer, vertexCount: uint32, instanceCount: uint32, firstVertex: uint32, firstInstance: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDraw"))
  vkCmdDrawIndexed = cast[proc(commandBuffer: VkCommandBuffer, indexCount: uint32, instanceCount: uint32, firstIndex: uint32, vertexOffset: int32, firstInstance: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndexed"))
  vkCmdDrawIndirect = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndirect"))
  vkCmdDrawIndexedIndirect = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndexedIndirect"))
  vkCmdDispatch = cast[proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDispatch"))
  vkCmdDispatchIndirect = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDispatchIndirect"))
  vkCmdCopyBuffer = cast[proc(commandBuffer: VkCommandBuffer, srcBuffer: VkBuffer, dstBuffer: VkBuffer, regionCount: uint32, pRegions: ptr VkBufferCopy): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyBuffer"))
  vkCmdCopyImage = cast[proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageCopy): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyImage"))
  vkCmdBlitImage = cast[proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageBlit, filter: VkFilter): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBlitImage"))
  vkCmdCopyBufferToImage = cast[proc(commandBuffer: VkCommandBuffer, srcBuffer: VkBuffer, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkBufferImageCopy): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyBufferToImage"))
  vkCmdCopyImageToBuffer = cast[proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstBuffer: VkBuffer, regionCount: uint32, pRegions: ptr VkBufferImageCopy): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyImageToBuffer"))
  vkCmdUpdateBuffer = cast[proc(commandBuffer: VkCommandBuffer, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, dataSize: VkDeviceSize, pData: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdUpdateBuffer"))
  vkCmdFillBuffer = cast[proc(commandBuffer: VkCommandBuffer, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, size: VkDeviceSize, data: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdFillBuffer"))
  vkCmdClearColorImage = cast[proc(commandBuffer: VkCommandBuffer, image: VkImage, imageLayout: VkImageLayout, pColor: ptr VkClearColorValue, rangeCount: uint32, pRanges: ptr VkImageSubresourceRange): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdClearColorImage"))
  vkCmdClearDepthStencilImage = cast[proc(commandBuffer: VkCommandBuffer, image: VkImage, imageLayout: VkImageLayout, pDepthStencil: ptr VkClearDepthStencilValue, rangeCount: uint32, pRanges: ptr VkImageSubresourceRange): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdClearDepthStencilImage"))
  vkCmdClearAttachments = cast[proc(commandBuffer: VkCommandBuffer, attachmentCount: uint32, pAttachments: ptr VkClearAttachment, rectCount: uint32, pRects: ptr VkClearRect): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdClearAttachments"))
  vkCmdResolveImage = cast[proc(commandBuffer: VkCommandBuffer, srcImage: VkImage, srcImageLayout: VkImageLayout, dstImage: VkImage, dstImageLayout: VkImageLayout, regionCount: uint32, pRegions: ptr VkImageResolve): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdResolveImage"))
  vkCmdSetEvent = cast[proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetEvent"))
  vkCmdResetEvent = cast[proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdResetEvent"))
  vkCmdWaitEvents = cast[proc(commandBuffer: VkCommandBuffer, eventCount: uint32, pEvents: ptr VkEvent, srcStageMask: VkPipelineStageFlags, dstStageMask: VkPipelineStageFlags, memoryBarrierCount: uint32, pMemoryBarriers: ptr VkMemoryBarrier, bufferMemoryBarrierCount: uint32, pBufferMemoryBarriers: ptr VkBufferMemoryBarrier, imageMemoryBarrierCount: uint32, pImageMemoryBarriers: ptr VkImageMemoryBarrier): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWaitEvents"))
  vkCmdPipelineBarrier = cast[proc(commandBuffer: VkCommandBuffer, srcStageMask: VkPipelineStageFlags, dstStageMask: VkPipelineStageFlags, dependencyFlags: VkDependencyFlags, memoryBarrierCount: uint32, pMemoryBarriers: ptr VkMemoryBarrier, bufferMemoryBarrierCount: uint32, pBufferMemoryBarriers: ptr VkBufferMemoryBarrier, imageMemoryBarrierCount: uint32, pImageMemoryBarriers: ptr VkImageMemoryBarrier): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPipelineBarrier"))
  vkCmdBeginQuery = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, flags: VkQueryControlFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginQuery"))
  vkCmdEndQuery = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndQuery"))
  vkCmdResetQueryPool = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdResetQueryPool"))
  vkCmdWriteTimestamp = cast[proc(commandBuffer: VkCommandBuffer, pipelineStage: VkPipelineStageFlagBits, queryPool: VkQueryPool, query: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteTimestamp"))
  vkCmdCopyQueryPoolResults = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, stride: VkDeviceSize, flags: VkQueryResultFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyQueryPoolResults"))
  vkCmdPushConstants = cast[proc(commandBuffer: VkCommandBuffer, layout: VkPipelineLayout, stageFlags: VkShaderStageFlags, offset: uint32, size: uint32, pValues: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPushConstants"))
  vkCmdBeginRenderPass = cast[proc(commandBuffer: VkCommandBuffer, pRenderPassBegin: ptr VkRenderPassBeginInfo, contents: VkSubpassContents): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginRenderPass"))
  vkCmdNextSubpass = cast[proc(commandBuffer: VkCommandBuffer, contents: VkSubpassContents): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdNextSubpass"))
  vkCmdEndRenderPass = cast[proc(commandBuffer: VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndRenderPass"))
  vkCmdExecuteCommands = cast[proc(commandBuffer: VkCommandBuffer, commandBufferCount: uint32, pCommandBuffers: ptr VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdExecuteCommands"))

# feature VK_VERSION_1_1
var
  vkEnumerateInstanceVersion*: proc(pApiVersion: ptr uint32): VkResult {.stdcall.}
  vkBindBufferMemory2*: proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindBufferMemoryInfo): VkResult {.stdcall.}
  vkBindImageMemory2*: proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindImageMemoryInfo): VkResult {.stdcall.}
  vkGetDeviceGroupPeerMemoryFeatures*: proc(device: VkDevice, heapIndex: uint32, localDeviceIndex: uint32, remoteDeviceIndex: uint32, pPeerMemoryFeatures: ptr VkPeerMemoryFeatureFlags): void {.stdcall.}
  vkCmdSetDeviceMask*: proc(commandBuffer: VkCommandBuffer, deviceMask: uint32): void {.stdcall.}
  vkCmdDispatchBase*: proc(commandBuffer: VkCommandBuffer, baseGroupX: uint32, baseGroupY: uint32, baseGroupZ: uint32, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}
  vkEnumeratePhysicalDeviceGroups*: proc(instance: VkInstance, pPhysicalDeviceGroupCount: ptr uint32, pPhysicalDeviceGroupProperties: ptr VkPhysicalDeviceGroupProperties): VkResult {.stdcall.}
  vkGetImageMemoryRequirements2*: proc(device: VkDevice, pInfo: ptr VkImageMemoryRequirementsInfo2, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}
  vkGetBufferMemoryRequirements2*: proc(device: VkDevice, pInfo: ptr VkBufferMemoryRequirementsInfo2, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}
  vkGetImageSparseMemoryRequirements2*: proc(device: VkDevice, pInfo: ptr VkImageSparseMemoryRequirementsInfo2, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements2): void {.stdcall.}
  vkGetPhysicalDeviceFeatures2*: proc(physicalDevice: VkPhysicalDevice, pFeatures: ptr VkPhysicalDeviceFeatures2): void {.stdcall.}
  vkGetPhysicalDeviceProperties2*: proc(physicalDevice: VkPhysicalDevice, pProperties: ptr VkPhysicalDeviceProperties2): void {.stdcall.}
  vkGetPhysicalDeviceFormatProperties2*: proc(physicalDevice: VkPhysicalDevice, format: VkFormat, pFormatProperties: ptr VkFormatProperties2): void {.stdcall.}
  vkGetPhysicalDeviceImageFormatProperties2*: proc(physicalDevice: VkPhysicalDevice, pImageFormatInfo: ptr VkPhysicalDeviceImageFormatInfo2, pImageFormatProperties: ptr VkImageFormatProperties2): VkResult {.stdcall.}
  vkGetPhysicalDeviceQueueFamilyProperties2*: proc(physicalDevice: VkPhysicalDevice, pQueueFamilyPropertyCount: ptr uint32, pQueueFamilyProperties: ptr VkQueueFamilyProperties2): void {.stdcall.}
  vkGetPhysicalDeviceMemoryProperties2*: proc(physicalDevice: VkPhysicalDevice, pMemoryProperties: ptr VkPhysicalDeviceMemoryProperties2): void {.stdcall.}
  vkGetPhysicalDeviceSparseImageFormatProperties2*: proc(physicalDevice: VkPhysicalDevice, pFormatInfo: ptr VkPhysicalDeviceSparseImageFormatInfo2, pPropertyCount: ptr uint32, pProperties: ptr VkSparseImageFormatProperties2): void {.stdcall.}
  vkTrimCommandPool*: proc(device: VkDevice, commandPool: VkCommandPool, flags: VkCommandPoolTrimFlags): void {.stdcall.}
  vkGetDeviceQueue2*: proc(device: VkDevice, pQueueInfo: ptr VkDeviceQueueInfo2, pQueue: ptr VkQueue): void {.stdcall.}
  vkCreateSamplerYcbcrConversion*: proc(device: VkDevice, pCreateInfo: ptr VkSamplerYcbcrConversionCreateInfo, pAllocator: ptr VkAllocationCallbacks, pYcbcrConversion: ptr VkSamplerYcbcrConversion): VkResult {.stdcall.}
  vkDestroySamplerYcbcrConversion*: proc(device: VkDevice, ycbcrConversion: VkSamplerYcbcrConversion, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCreateDescriptorUpdateTemplate*: proc(device: VkDevice, pCreateInfo: ptr VkDescriptorUpdateTemplateCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDescriptorUpdateTemplate: ptr VkDescriptorUpdateTemplate): VkResult {.stdcall.}
  vkDestroyDescriptorUpdateTemplate*: proc(device: VkDevice, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkUpdateDescriptorSetWithTemplate*: proc(device: VkDevice, descriptorSet: VkDescriptorSet, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, pData: pointer): void {.stdcall.}
  vkGetPhysicalDeviceExternalBufferProperties*: proc(physicalDevice: VkPhysicalDevice, pExternalBufferInfo: ptr VkPhysicalDeviceExternalBufferInfo, pExternalBufferProperties: ptr VkExternalBufferProperties): void {.stdcall.}
  vkGetPhysicalDeviceExternalFenceProperties*: proc(physicalDevice: VkPhysicalDevice, pExternalFenceInfo: ptr VkPhysicalDeviceExternalFenceInfo, pExternalFenceProperties: ptr VkExternalFenceProperties): void {.stdcall.}
  vkGetPhysicalDeviceExternalSemaphoreProperties*: proc(physicalDevice: VkPhysicalDevice, pExternalSemaphoreInfo: ptr VkPhysicalDeviceExternalSemaphoreInfo, pExternalSemaphoreProperties: ptr VkExternalSemaphoreProperties): void {.stdcall.}
  vkGetDescriptorSetLayoutSupport*: proc(device: VkDevice, pCreateInfo: ptr VkDescriptorSetLayoutCreateInfo, pSupport: ptr VkDescriptorSetLayoutSupport): void {.stdcall.}
proc loadVK_VERSION_1_1*(instance: VkInstance) =
  vkBindBufferMemory2 = cast[proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindBufferMemoryInfo): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindBufferMemory2"))
  vkBindImageMemory2 = cast[proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindImageMemoryInfo): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindImageMemory2"))
  vkGetDeviceGroupPeerMemoryFeatures = cast[proc(device: VkDevice, heapIndex: uint32, localDeviceIndex: uint32, remoteDeviceIndex: uint32, pPeerMemoryFeatures: ptr VkPeerMemoryFeatureFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceGroupPeerMemoryFeatures"))
  vkCmdSetDeviceMask = cast[proc(commandBuffer: VkCommandBuffer, deviceMask: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDeviceMask"))
  vkCmdDispatchBase = cast[proc(commandBuffer: VkCommandBuffer, baseGroupX: uint32, baseGroupY: uint32, baseGroupZ: uint32, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDispatchBase"))
  vkEnumeratePhysicalDeviceGroups = cast[proc(instance: VkInstance, pPhysicalDeviceGroupCount: ptr uint32, pPhysicalDeviceGroupProperties: ptr VkPhysicalDeviceGroupProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDeviceGroups"))
  vkGetImageMemoryRequirements2 = cast[proc(device: VkDevice, pInfo: ptr VkImageMemoryRequirementsInfo2, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageMemoryRequirements2"))
  vkGetBufferMemoryRequirements2 = cast[proc(device: VkDevice, pInfo: ptr VkBufferMemoryRequirementsInfo2, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferMemoryRequirements2"))
  vkGetImageSparseMemoryRequirements2 = cast[proc(device: VkDevice, pInfo: ptr VkImageSparseMemoryRequirementsInfo2, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageSparseMemoryRequirements2"))
  vkGetPhysicalDeviceFeatures2 = cast[proc(physicalDevice: VkPhysicalDevice, pFeatures: ptr VkPhysicalDeviceFeatures2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFeatures2"))
  vkGetPhysicalDeviceProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, pProperties: ptr VkPhysicalDeviceProperties2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceProperties2"))
  vkGetPhysicalDeviceFormatProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, format: VkFormat, pFormatProperties: ptr VkFormatProperties2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFormatProperties2"))
  vkGetPhysicalDeviceImageFormatProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, pImageFormatInfo: ptr VkPhysicalDeviceImageFormatInfo2, pImageFormatProperties: ptr VkImageFormatProperties2): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceImageFormatProperties2"))
  vkGetPhysicalDeviceQueueFamilyProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, pQueueFamilyPropertyCount: ptr uint32, pQueueFamilyProperties: ptr VkQueueFamilyProperties2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties2"))
  vkGetPhysicalDeviceMemoryProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, pMemoryProperties: ptr VkPhysicalDeviceMemoryProperties2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceMemoryProperties2"))
  vkGetPhysicalDeviceSparseImageFormatProperties2 = cast[proc(physicalDevice: VkPhysicalDevice, pFormatInfo: ptr VkPhysicalDeviceSparseImageFormatInfo2, pPropertyCount: ptr uint32, pProperties: ptr VkSparseImageFormatProperties2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSparseImageFormatProperties2"))
  vkTrimCommandPool = cast[proc(device: VkDevice, commandPool: VkCommandPool, flags: VkCommandPoolTrimFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkTrimCommandPool"))
  vkGetDeviceQueue2 = cast[proc(device: VkDevice, pQueueInfo: ptr VkDeviceQueueInfo2, pQueue: ptr VkQueue): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceQueue2"))
  vkCreateSamplerYcbcrConversion = cast[proc(device: VkDevice, pCreateInfo: ptr VkSamplerYcbcrConversionCreateInfo, pAllocator: ptr VkAllocationCallbacks, pYcbcrConversion: ptr VkSamplerYcbcrConversion): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateSamplerYcbcrConversion"))
  vkDestroySamplerYcbcrConversion = cast[proc(device: VkDevice, ycbcrConversion: VkSamplerYcbcrConversion, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroySamplerYcbcrConversion"))
  vkCreateDescriptorUpdateTemplate = cast[proc(device: VkDevice, pCreateInfo: ptr VkDescriptorUpdateTemplateCreateInfo, pAllocator: ptr VkAllocationCallbacks, pDescriptorUpdateTemplate: ptr VkDescriptorUpdateTemplate): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDescriptorUpdateTemplate"))
  vkDestroyDescriptorUpdateTemplate = cast[proc(device: VkDevice, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDescriptorUpdateTemplate"))
  vkUpdateDescriptorSetWithTemplate = cast[proc(device: VkDevice, descriptorSet: VkDescriptorSet, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, pData: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkUpdateDescriptorSetWithTemplate"))
  vkGetPhysicalDeviceExternalBufferProperties = cast[proc(physicalDevice: VkPhysicalDevice, pExternalBufferInfo: ptr VkPhysicalDeviceExternalBufferInfo, pExternalBufferProperties: ptr VkExternalBufferProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceExternalBufferProperties"))
  vkGetPhysicalDeviceExternalFenceProperties = cast[proc(physicalDevice: VkPhysicalDevice, pExternalFenceInfo: ptr VkPhysicalDeviceExternalFenceInfo, pExternalFenceProperties: ptr VkExternalFenceProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceExternalFenceProperties"))
  vkGetPhysicalDeviceExternalSemaphoreProperties = cast[proc(physicalDevice: VkPhysicalDevice, pExternalSemaphoreInfo: ptr VkPhysicalDeviceExternalSemaphoreInfo, pExternalSemaphoreProperties: ptr VkExternalSemaphoreProperties): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceExternalSemaphoreProperties"))
  vkGetDescriptorSetLayoutSupport = cast[proc(device: VkDevice, pCreateInfo: ptr VkDescriptorSetLayoutCreateInfo, pSupport: ptr VkDescriptorSetLayoutSupport): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorSetLayoutSupport"))

# feature VK_VERSION_1_2
var
  vkCmdDrawIndirectCount*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdDrawIndexedIndirectCount*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}
  vkCreateRenderPass2*: proc(device: VkDevice, pCreateInfo: ptr VkRenderPassCreateInfo2, pAllocator: ptr VkAllocationCallbacks, pRenderPass: ptr VkRenderPass): VkResult {.stdcall.}
  vkCmdBeginRenderPass2*: proc(commandBuffer: VkCommandBuffer, pRenderPassBegin: ptr VkRenderPassBeginInfo, pSubpassBeginInfo: ptr VkSubpassBeginInfo): void {.stdcall.}
  vkCmdNextSubpass2*: proc(commandBuffer: VkCommandBuffer, pSubpassBeginInfo: ptr VkSubpassBeginInfo, pSubpassEndInfo: ptr VkSubpassEndInfo): void {.stdcall.}
  vkCmdEndRenderPass2*: proc(commandBuffer: VkCommandBuffer, pSubpassEndInfo: ptr VkSubpassEndInfo): void {.stdcall.}
  vkResetQueryPool*: proc(device: VkDevice, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32): void {.stdcall.}
  vkGetSemaphoreCounterValue*: proc(device: VkDevice, semaphore: VkSemaphore, pValue: ptr uint64): VkResult {.stdcall.}
  vkWaitSemaphores*: proc(device: VkDevice, pWaitInfo: ptr VkSemaphoreWaitInfo, timeout: uint64): VkResult {.stdcall.}
  vkSignalSemaphore*: proc(device: VkDevice, pSignalInfo: ptr VkSemaphoreSignalInfo): VkResult {.stdcall.}
  vkGetBufferDeviceAddress*: proc(device: VkDevice, pInfo: ptr VkBufferDeviceAddressInfo): VkDeviceAddress {.stdcall.}
  vkGetBufferOpaqueCaptureAddress*: proc(device: VkDevice, pInfo: ptr VkBufferDeviceAddressInfo): uint64 {.stdcall.}
  vkGetDeviceMemoryOpaqueCaptureAddress*: proc(device: VkDevice, pInfo: ptr VkDeviceMemoryOpaqueCaptureAddressInfo): uint64 {.stdcall.}
proc loadVK_VERSION_1_2*(instance: VkInstance) =
  vkCmdDrawIndirectCount = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndirectCount"))
  vkCmdDrawIndexedIndirectCount = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndexedIndirectCount"))
  vkCreateRenderPass2 = cast[proc(device: VkDevice, pCreateInfo: ptr VkRenderPassCreateInfo2, pAllocator: ptr VkAllocationCallbacks, pRenderPass: ptr VkRenderPass): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateRenderPass2"))
  vkCmdBeginRenderPass2 = cast[proc(commandBuffer: VkCommandBuffer, pRenderPassBegin: ptr VkRenderPassBeginInfo, pSubpassBeginInfo: ptr VkSubpassBeginInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginRenderPass2"))
  vkCmdNextSubpass2 = cast[proc(commandBuffer: VkCommandBuffer, pSubpassBeginInfo: ptr VkSubpassBeginInfo, pSubpassEndInfo: ptr VkSubpassEndInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdNextSubpass2"))
  vkCmdEndRenderPass2 = cast[proc(commandBuffer: VkCommandBuffer, pSubpassEndInfo: ptr VkSubpassEndInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndRenderPass2"))
  vkResetQueryPool = cast[proc(device: VkDevice, queryPool: VkQueryPool, firstQuery: uint32, queryCount: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkResetQueryPool"))
  vkGetSemaphoreCounterValue = cast[proc(device: VkDevice, semaphore: VkSemaphore, pValue: ptr uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSemaphoreCounterValue"))
  vkWaitSemaphores = cast[proc(device: VkDevice, pWaitInfo: ptr VkSemaphoreWaitInfo, timeout: uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkWaitSemaphores"))
  vkSignalSemaphore = cast[proc(device: VkDevice, pSignalInfo: ptr VkSemaphoreSignalInfo): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSignalSemaphore"))
  vkGetBufferDeviceAddress = cast[proc(device: VkDevice, pInfo: ptr VkBufferDeviceAddressInfo): VkDeviceAddress {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferDeviceAddress"))
  vkGetBufferOpaqueCaptureAddress = cast[proc(device: VkDevice, pInfo: ptr VkBufferDeviceAddressInfo): uint64 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferOpaqueCaptureAddress"))
  vkGetDeviceMemoryOpaqueCaptureAddress = cast[proc(device: VkDevice, pInfo: ptr VkDeviceMemoryOpaqueCaptureAddressInfo): uint64 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceMemoryOpaqueCaptureAddress"))

# feature VK_VERSION_1_3
var
  vkGetPhysicalDeviceToolProperties*: proc(physicalDevice: VkPhysicalDevice, pToolCount: ptr uint32, pToolProperties: ptr VkPhysicalDeviceToolProperties): VkResult {.stdcall.}
  vkCreatePrivateDataSlot*: proc(device: VkDevice, pCreateInfo: ptr VkPrivateDataSlotCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPrivateDataSlot: ptr VkPrivateDataSlot): VkResult {.stdcall.}
  vkDestroyPrivateDataSlot*: proc(device: VkDevice, privateDataSlot: VkPrivateDataSlot, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkSetPrivateData*: proc(device: VkDevice, objectType: VkObjectType, objectHandle: uint64, privateDataSlot: VkPrivateDataSlot, data: uint64): VkResult {.stdcall.}
  vkGetPrivateData*: proc(device: VkDevice, objectType: VkObjectType, objectHandle: uint64, privateDataSlot: VkPrivateDataSlot, pData: ptr uint64): void {.stdcall.}
  vkCmdSetEvent2*: proc(commandBuffer: VkCommandBuffer, event: VkEvent, pDependencyInfo: ptr VkDependencyInfo): void {.stdcall.}
  vkCmdResetEvent2*: proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags2): void {.stdcall.}
  vkCmdWaitEvents2*: proc(commandBuffer: VkCommandBuffer, eventCount: uint32, pEvents: ptr VkEvent, pDependencyInfos: ptr VkDependencyInfo): void {.stdcall.}
  vkCmdPipelineBarrier2*: proc(commandBuffer: VkCommandBuffer, pDependencyInfo: ptr VkDependencyInfo): void {.stdcall.}
  vkCmdWriteTimestamp2*: proc(commandBuffer: VkCommandBuffer, stage: VkPipelineStageFlags2, queryPool: VkQueryPool, query: uint32): void {.stdcall.}
  vkQueueSubmit2*: proc(queue: VkQueue, submitCount: uint32, pSubmits: ptr VkSubmitInfo2, fence: VkFence): VkResult {.stdcall.}
  vkCmdCopyBuffer2*: proc(commandBuffer: VkCommandBuffer, pCopyBufferInfo: ptr VkCopyBufferInfo2): void {.stdcall.}
  vkCmdCopyImage2*: proc(commandBuffer: VkCommandBuffer, pCopyImageInfo: ptr VkCopyImageInfo2): void {.stdcall.}
  vkCmdCopyBufferToImage2*: proc(commandBuffer: VkCommandBuffer, pCopyBufferToImageInfo: ptr VkCopyBufferToImageInfo2): void {.stdcall.}
  vkCmdCopyImageToBuffer2*: proc(commandBuffer: VkCommandBuffer, pCopyImageToBufferInfo: ptr VkCopyImageToBufferInfo2): void {.stdcall.}
  vkCmdBlitImage2*: proc(commandBuffer: VkCommandBuffer, pBlitImageInfo: ptr VkBlitImageInfo2): void {.stdcall.}
  vkCmdResolveImage2*: proc(commandBuffer: VkCommandBuffer, pResolveImageInfo: ptr VkResolveImageInfo2): void {.stdcall.}
  vkCmdBeginRendering*: proc(commandBuffer: VkCommandBuffer, pRenderingInfo: ptr VkRenderingInfo): void {.stdcall.}
  vkCmdEndRendering*: proc(commandBuffer: VkCommandBuffer): void {.stdcall.}
  vkCmdSetCullMode*: proc(commandBuffer: VkCommandBuffer, cullMode: VkCullModeFlags): void {.stdcall.}
  vkCmdSetFrontFace*: proc(commandBuffer: VkCommandBuffer, frontFace: VkFrontFace): void {.stdcall.}
  vkCmdSetPrimitiveTopology*: proc(commandBuffer: VkCommandBuffer, primitiveTopology: VkPrimitiveTopology): void {.stdcall.}
  vkCmdSetViewportWithCount*: proc(commandBuffer: VkCommandBuffer, viewportCount: uint32, pViewports: ptr VkViewport): void {.stdcall.}
  vkCmdSetScissorWithCount*: proc(commandBuffer: VkCommandBuffer, scissorCount: uint32, pScissors: ptr VkRect2D): void {.stdcall.}
  vkCmdBindVertexBuffers2*: proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize, pSizes: ptr VkDeviceSize, pStrides: ptr VkDeviceSize): void {.stdcall.}
  vkCmdSetDepthTestEnable*: proc(commandBuffer: VkCommandBuffer, depthTestEnable: VkBool32): void {.stdcall.}
  vkCmdSetDepthWriteEnable*: proc(commandBuffer: VkCommandBuffer, depthWriteEnable: VkBool32): void {.stdcall.}
  vkCmdSetDepthCompareOp*: proc(commandBuffer: VkCommandBuffer, depthCompareOp: VkCompareOp): void {.stdcall.}
  vkCmdSetDepthBoundsTestEnable*: proc(commandBuffer: VkCommandBuffer, depthBoundsTestEnable: VkBool32): void {.stdcall.}
  vkCmdSetStencilTestEnable*: proc(commandBuffer: VkCommandBuffer, stencilTestEnable: VkBool32): void {.stdcall.}
  vkCmdSetStencilOp*: proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, failOp: VkStencilOp, passOp: VkStencilOp, depthFailOp: VkStencilOp, compareOp: VkCompareOp): void {.stdcall.}
  vkCmdSetRasterizerDiscardEnable*: proc(commandBuffer: VkCommandBuffer, rasterizerDiscardEnable: VkBool32): void {.stdcall.}
  vkCmdSetDepthBiasEnable*: proc(commandBuffer: VkCommandBuffer, depthBiasEnable: VkBool32): void {.stdcall.}
  vkCmdSetPrimitiveRestartEnable*: proc(commandBuffer: VkCommandBuffer, primitiveRestartEnable: VkBool32): void {.stdcall.}
  vkGetDeviceBufferMemoryRequirements*: proc(device: VkDevice, pInfo: ptr VkDeviceBufferMemoryRequirements, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}
  vkGetDeviceImageMemoryRequirements*: proc(device: VkDevice, pInfo: ptr VkDeviceImageMemoryRequirements, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}
  vkGetDeviceImageSparseMemoryRequirements*: proc(device: VkDevice, pInfo: ptr VkDeviceImageMemoryRequirements, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements2): void {.stdcall.}
proc loadVK_VERSION_1_3*(instance: VkInstance) =
  vkGetPhysicalDeviceToolProperties = cast[proc(physicalDevice: VkPhysicalDevice, pToolCount: ptr uint32, pToolProperties: ptr VkPhysicalDeviceToolProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceToolProperties"))
  vkCreatePrivateDataSlot = cast[proc(device: VkDevice, pCreateInfo: ptr VkPrivateDataSlotCreateInfo, pAllocator: ptr VkAllocationCallbacks, pPrivateDataSlot: ptr VkPrivateDataSlot): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreatePrivateDataSlot"))
  vkDestroyPrivateDataSlot = cast[proc(device: VkDevice, privateDataSlot: VkPrivateDataSlot, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyPrivateDataSlot"))
  vkSetPrivateData = cast[proc(device: VkDevice, objectType: VkObjectType, objectHandle: uint64, privateDataSlot: VkPrivateDataSlot, data: uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetPrivateData"))
  vkGetPrivateData = cast[proc(device: VkDevice, objectType: VkObjectType, objectHandle: uint64, privateDataSlot: VkPrivateDataSlot, pData: ptr uint64): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPrivateData"))
  vkCmdSetEvent2 = cast[proc(commandBuffer: VkCommandBuffer, event: VkEvent, pDependencyInfo: ptr VkDependencyInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetEvent2"))
  vkCmdResetEvent2 = cast[proc(commandBuffer: VkCommandBuffer, event: VkEvent, stageMask: VkPipelineStageFlags2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdResetEvent2"))
  vkCmdWaitEvents2 = cast[proc(commandBuffer: VkCommandBuffer, eventCount: uint32, pEvents: ptr VkEvent, pDependencyInfos: ptr VkDependencyInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWaitEvents2"))
  vkCmdPipelineBarrier2 = cast[proc(commandBuffer: VkCommandBuffer, pDependencyInfo: ptr VkDependencyInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPipelineBarrier2"))
  vkCmdWriteTimestamp2 = cast[proc(commandBuffer: VkCommandBuffer, stage: VkPipelineStageFlags2, queryPool: VkQueryPool, query: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteTimestamp2"))
  vkQueueSubmit2 = cast[proc(queue: VkQueue, submitCount: uint32, pSubmits: ptr VkSubmitInfo2, fence: VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueSubmit2"))
  vkCmdCopyBuffer2 = cast[proc(commandBuffer: VkCommandBuffer, pCopyBufferInfo: ptr VkCopyBufferInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyBuffer2"))
  vkCmdCopyImage2 = cast[proc(commandBuffer: VkCommandBuffer, pCopyImageInfo: ptr VkCopyImageInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyImage2"))
  vkCmdCopyBufferToImage2 = cast[proc(commandBuffer: VkCommandBuffer, pCopyBufferToImageInfo: ptr VkCopyBufferToImageInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyBufferToImage2"))
  vkCmdCopyImageToBuffer2 = cast[proc(commandBuffer: VkCommandBuffer, pCopyImageToBufferInfo: ptr VkCopyImageToBufferInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyImageToBuffer2"))
  vkCmdBlitImage2 = cast[proc(commandBuffer: VkCommandBuffer, pBlitImageInfo: ptr VkBlitImageInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBlitImage2"))
  vkCmdResolveImage2 = cast[proc(commandBuffer: VkCommandBuffer, pResolveImageInfo: ptr VkResolveImageInfo2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdResolveImage2"))
  vkCmdBeginRendering = cast[proc(commandBuffer: VkCommandBuffer, pRenderingInfo: ptr VkRenderingInfo): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginRendering"))
  vkCmdEndRendering = cast[proc(commandBuffer: VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndRendering"))
  vkCmdSetCullMode = cast[proc(commandBuffer: VkCommandBuffer, cullMode: VkCullModeFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCullMode"))
  vkCmdSetFrontFace = cast[proc(commandBuffer: VkCommandBuffer, frontFace: VkFrontFace): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetFrontFace"))
  vkCmdSetPrimitiveTopology = cast[proc(commandBuffer: VkCommandBuffer, primitiveTopology: VkPrimitiveTopology): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPrimitiveTopology"))
  vkCmdSetViewportWithCount = cast[proc(commandBuffer: VkCommandBuffer, viewportCount: uint32, pViewports: ptr VkViewport): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewportWithCount"))
  vkCmdSetScissorWithCount = cast[proc(commandBuffer: VkCommandBuffer, scissorCount: uint32, pScissors: ptr VkRect2D): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetScissorWithCount"))
  vkCmdBindVertexBuffers2 = cast[proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize, pSizes: ptr VkDeviceSize, pStrides: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindVertexBuffers2"))
  vkCmdSetDepthTestEnable = cast[proc(commandBuffer: VkCommandBuffer, depthTestEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthTestEnable"))
  vkCmdSetDepthWriteEnable = cast[proc(commandBuffer: VkCommandBuffer, depthWriteEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthWriteEnable"))
  vkCmdSetDepthCompareOp = cast[proc(commandBuffer: VkCommandBuffer, depthCompareOp: VkCompareOp): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthCompareOp"))
  vkCmdSetDepthBoundsTestEnable = cast[proc(commandBuffer: VkCommandBuffer, depthBoundsTestEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthBoundsTestEnable"))
  vkCmdSetStencilTestEnable = cast[proc(commandBuffer: VkCommandBuffer, stencilTestEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetStencilTestEnable"))
  vkCmdSetStencilOp = cast[proc(commandBuffer: VkCommandBuffer, faceMask: VkStencilFaceFlags, failOp: VkStencilOp, passOp: VkStencilOp, depthFailOp: VkStencilOp, compareOp: VkCompareOp): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetStencilOp"))
  vkCmdSetRasterizerDiscardEnable = cast[proc(commandBuffer: VkCommandBuffer, rasterizerDiscardEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetRasterizerDiscardEnable"))
  vkCmdSetDepthBiasEnable = cast[proc(commandBuffer: VkCommandBuffer, depthBiasEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthBiasEnable"))
  vkCmdSetPrimitiveRestartEnable = cast[proc(commandBuffer: VkCommandBuffer, primitiveRestartEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPrimitiveRestartEnable"))
  vkGetDeviceBufferMemoryRequirements = cast[proc(device: VkDevice, pInfo: ptr VkDeviceBufferMemoryRequirements, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceBufferMemoryRequirements"))
  vkGetDeviceImageMemoryRequirements = cast[proc(device: VkDevice, pInfo: ptr VkDeviceImageMemoryRequirements, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceImageMemoryRequirements"))
  vkGetDeviceImageSparseMemoryRequirements = cast[proc(device: VkDevice, pInfo: ptr VkDeviceImageMemoryRequirements, pSparseMemoryRequirementCount: ptr uint32, pSparseMemoryRequirements: ptr VkSparseImageMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceImageSparseMemoryRequirements"))


proc loadVulkan*(instance: VkInstance) =
  loadVK_VERSION_1_0(instance)
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_3(instance)

proc loadVK_NV_geometry_shader_passthrough*(instance: VkInstance) =
  discard

proc loadVK_EXT_rasterization_order_attachment_access*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_IMG_format_pvrtc*(instance: VkInstance) =
  discard

proc loadVK_AMD_shader_fragment_mask*(instance: VkInstance) =
  discard

proc loadVK_EXT_primitive_topology_list_restart*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_KHR_global_priority*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_QCOM_image_processing*(instance: VkInstance) =
  loadVK_VERSION_1_3(instance)

# extension VK_AMD_shader_info
var
  vkGetShaderInfoAMD*: proc(device: VkDevice, pipeline: VkPipeline, shaderStage: VkShaderStageFlagBits, infoType: VkShaderInfoTypeAMD, pInfoSize: ptr csize_t, pInfo: pointer): VkResult {.stdcall.}
proc loadVK_AMD_shader_info*(instance: VkInstance) =
  vkGetShaderInfoAMD = cast[proc(device: VkDevice, pipeline: VkPipeline, shaderStage: VkShaderStageFlagBits, infoType: VkShaderInfoTypeAMD, pInfoSize: ptr csize_t, pInfo: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetShaderInfoAMD"))

proc loadVK_AMD_gpu_shader_int16*(instance: VkInstance) =
  discard

proc loadVK_EXT_pipeline_robustness*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_sample_locations
var
  vkCmdSetSampleLocationsEXT*: proc(commandBuffer: VkCommandBuffer, pSampleLocationsInfo: ptr VkSampleLocationsInfoEXT): void {.stdcall.}
  vkGetPhysicalDeviceMultisamplePropertiesEXT*: proc(physicalDevice: VkPhysicalDevice, samples: VkSampleCountFlagBits, pMultisampleProperties: ptr VkMultisamplePropertiesEXT): void {.stdcall.}
proc loadVK_EXT_sample_locations*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetSampleLocationsEXT = cast[proc(commandBuffer: VkCommandBuffer, pSampleLocationsInfo: ptr VkSampleLocationsInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetSampleLocationsEXT"))
  vkGetPhysicalDeviceMultisamplePropertiesEXT = cast[proc(physicalDevice: VkPhysicalDevice, samples: VkSampleCountFlagBits, pMultisampleProperties: ptr VkMultisamplePropertiesEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceMultisamplePropertiesEXT"))

# extension VK_EXT_descriptor_buffer
var
  vkGetDescriptorSetLayoutSizeEXT*: proc(device: VkDevice, layout: VkDescriptorSetLayout, pLayoutSizeInBytes: ptr VkDeviceSize): void {.stdcall.}
  vkGetDescriptorSetLayoutBindingOffsetEXT*: proc(device: VkDevice, layout: VkDescriptorSetLayout, binding: uint32, pOffset: ptr VkDeviceSize): void {.stdcall.}
  vkGetDescriptorEXT*: proc(device: VkDevice, pDescriptorInfo: ptr VkDescriptorGetInfoEXT, dataSize: csize_t, pDescriptor: pointer): void {.stdcall.}
  vkCmdBindDescriptorBuffersEXT*: proc(commandBuffer: VkCommandBuffer, bufferCount: uint32, pBindingInfos: ptr VkDescriptorBufferBindingInfoEXT): void {.stdcall.}
  vkCmdSetDescriptorBufferOffsetsEXT*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, firstSet: uint32, setCount: uint32, pBufferIndices: ptr uint32, pOffsets: ptr VkDeviceSize): void {.stdcall.}
  vkCmdBindDescriptorBufferEmbeddedSamplersEXT*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, set: uint32): void {.stdcall.}
  vkGetBufferOpaqueCaptureDescriptorDataEXT*: proc(device: VkDevice, pInfo: ptr VkBufferCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}
  vkGetImageOpaqueCaptureDescriptorDataEXT*: proc(device: VkDevice, pInfo: ptr VkImageCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}
  vkGetImageViewOpaqueCaptureDescriptorDataEXT*: proc(device: VkDevice, pInfo: ptr VkImageViewCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}
  vkGetSamplerOpaqueCaptureDescriptorDataEXT*: proc(device: VkDevice, pInfo: ptr VkSamplerCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}
  vkGetAccelerationStructureOpaqueCaptureDescriptorDataEXT*: proc(device: VkDevice, pInfo: ptr VkAccelerationStructureCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}
proc loadVK_EXT_descriptor_buffer*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_3(instance)
  loadVK_VERSION_1_2(instance)
  vkGetDescriptorSetLayoutSizeEXT = cast[proc(device: VkDevice, layout: VkDescriptorSetLayout, pLayoutSizeInBytes: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorSetLayoutSizeEXT"))
  vkGetDescriptorSetLayoutBindingOffsetEXT = cast[proc(device: VkDevice, layout: VkDescriptorSetLayout, binding: uint32, pOffset: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorSetLayoutBindingOffsetEXT"))
  vkGetDescriptorEXT = cast[proc(device: VkDevice, pDescriptorInfo: ptr VkDescriptorGetInfoEXT, dataSize: csize_t, pDescriptor: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorEXT"))
  vkCmdBindDescriptorBuffersEXT = cast[proc(commandBuffer: VkCommandBuffer, bufferCount: uint32, pBindingInfos: ptr VkDescriptorBufferBindingInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindDescriptorBuffersEXT"))
  vkCmdSetDescriptorBufferOffsetsEXT = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, firstSet: uint32, setCount: uint32, pBufferIndices: ptr uint32, pOffsets: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDescriptorBufferOffsetsEXT"))
  vkCmdBindDescriptorBufferEmbeddedSamplersEXT = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, set: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindDescriptorBufferEmbeddedSamplersEXT"))
  vkGetBufferOpaqueCaptureDescriptorDataEXT = cast[proc(device: VkDevice, pInfo: ptr VkBufferCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetBufferOpaqueCaptureDescriptorDataEXT"))
  vkGetImageOpaqueCaptureDescriptorDataEXT = cast[proc(device: VkDevice, pInfo: ptr VkImageCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageOpaqueCaptureDescriptorDataEXT"))
  vkGetImageViewOpaqueCaptureDescriptorDataEXT = cast[proc(device: VkDevice, pInfo: ptr VkImageViewCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageViewOpaqueCaptureDescriptorDataEXT"))
  vkGetSamplerOpaqueCaptureDescriptorDataEXT = cast[proc(device: VkDevice, pInfo: ptr VkSamplerCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSamplerOpaqueCaptureDescriptorDataEXT"))
  vkGetAccelerationStructureOpaqueCaptureDescriptorDataEXT = cast[proc(device: VkDevice, pInfo: ptr VkAccelerationStructureCaptureDescriptorDataInfoEXT, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAccelerationStructureOpaqueCaptureDescriptorDataEXT"))

# extension VK_KHR_performance_query
var
  vkEnumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, pCounterCount: ptr uint32, pCounters: ptr VkPerformanceCounterKHR, pCounterDescriptions: ptr VkPerformanceCounterDescriptionKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR*: proc(physicalDevice: VkPhysicalDevice, pPerformanceQueryCreateInfo: ptr VkQueryPoolPerformanceCreateInfoKHR, pNumPasses: ptr uint32): void {.stdcall.}
  vkAcquireProfilingLockKHR*: proc(device: VkDevice, pInfo: ptr VkAcquireProfilingLockInfoKHR): VkResult {.stdcall.}
  vkReleaseProfilingLockKHR*: proc(device: VkDevice): void {.stdcall.}
proc loadVK_KHR_performance_query*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkEnumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, pCounterCount: ptr uint32, pCounters: ptr VkPerformanceCounterKHR, pCounterDescriptions: ptr VkPerformanceCounterDescriptionKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR"))
  vkGetPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pPerformanceQueryCreateInfo: ptr VkQueryPoolPerformanceCreateInfoKHR, pNumPasses: ptr uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR"))
  vkAcquireProfilingLockKHR = cast[proc(device: VkDevice, pInfo: ptr VkAcquireProfilingLockInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireProfilingLockKHR"))
  vkReleaseProfilingLockKHR = cast[proc(device: VkDevice): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkReleaseProfilingLockKHR"))

proc loadVK_GOOGLE_user_type*(instance: VkInstance) =
  discard

# extension VK_EXT_debug_report
var
  vkCreateDebugReportCallbackEXT*: proc(instance: VkInstance, pCreateInfo: ptr VkDebugReportCallbackCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pCallback: ptr VkDebugReportCallbackEXT): VkResult {.stdcall.}
  vkDestroyDebugReportCallbackEXT*: proc(instance: VkInstance, callback: VkDebugReportCallbackEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkDebugReportMessageEXT*: proc(instance: VkInstance, flags: VkDebugReportFlagsEXT, objectType: VkDebugReportObjectTypeEXT, theobject: uint64, location: csize_t, messageCode: int32, pLayerPrefix: cstring, pMessage: cstring): void {.stdcall.}
proc loadVK_EXT_debug_report*(instance: VkInstance) =
  vkCreateDebugReportCallbackEXT = cast[proc(instance: VkInstance, pCreateInfo: ptr VkDebugReportCallbackCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pCallback: ptr VkDebugReportCallbackEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDebugReportCallbackEXT"))
  vkDestroyDebugReportCallbackEXT = cast[proc(instance: VkInstance, callback: VkDebugReportCallbackEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDebugReportCallbackEXT"))
  vkDebugReportMessageEXT = cast[proc(instance: VkInstance, flags: VkDebugReportFlagsEXT, objectType: VkDebugReportObjectTypeEXT, theobject: uint64, location: csize_t, messageCode: int32, pLayerPrefix: cstring, pMessage: cstring): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDebugReportMessageEXT"))

proc loadVK_EXT_multisampled_render_to_single_sampled*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_2(instance)

proc loadVK_AMD_negative_viewport_height*(instance: VkInstance) =
  discard

proc loadVK_EXT_provoking_vertex*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_NV_device_diagnostics_config*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_NV_shader_subgroup_partitioned*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_image_sliced_view_of_3d*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_shader_image_load_store_lod*(instance: VkInstance) =
  discard

proc loadVK_INTEL_shader_integer_functions2*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_image_2d_view_of_3d*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)

# extension VK_NV_shading_rate_image
var
  vkCmdBindShadingRateImageNV*: proc(commandBuffer: VkCommandBuffer, imageView: VkImageView, imageLayout: VkImageLayout): void {.stdcall.}
  vkCmdSetViewportShadingRatePaletteNV*: proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pShadingRatePalettes: ptr VkShadingRatePaletteNV): void {.stdcall.}
  vkCmdSetCoarseSampleOrderNV*: proc(commandBuffer: VkCommandBuffer, sampleOrderType: VkCoarseSampleOrderTypeNV, customSampleOrderCount: uint32, pCustomSampleOrders: ptr VkCoarseSampleOrderCustomNV): void {.stdcall.}
proc loadVK_NV_shading_rate_image*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdBindShadingRateImageNV = cast[proc(commandBuffer: VkCommandBuffer, imageView: VkImageView, imageLayout: VkImageLayout): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindShadingRateImageNV"))
  vkCmdSetViewportShadingRatePaletteNV = cast[proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pShadingRatePalettes: ptr VkShadingRatePaletteNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewportShadingRatePaletteNV"))
  vkCmdSetCoarseSampleOrderNV = cast[proc(commandBuffer: VkCommandBuffer, sampleOrderType: VkCoarseSampleOrderTypeNV, customSampleOrderCount: uint32, pCustomSampleOrders: ptr VkCoarseSampleOrderCustomNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoarseSampleOrderNV"))

proc loadVK_EXT_fragment_density_map*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_NV_device_diagnostic_checkpoints
var
  vkCmdSetCheckpointNV*: proc(commandBuffer: VkCommandBuffer, pCheckpointMarker: pointer): void {.stdcall.}
  vkGetQueueCheckpointDataNV*: proc(queue: VkQueue, pCheckpointDataCount: ptr uint32, pCheckpointData: ptr VkCheckpointDataNV): void {.stdcall.}
proc loadVK_NV_device_diagnostic_checkpoints*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetCheckpointNV = cast[proc(commandBuffer: VkCommandBuffer, pCheckpointMarker: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCheckpointNV"))
  vkGetQueueCheckpointDataNV = cast[proc(queue: VkQueue, pCheckpointDataCount: ptr uint32, pCheckpointData: ptr VkCheckpointDataNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetQueueCheckpointDataNV"))

proc loadVK_EXT_pci_bus_info*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_queue_family_foreign*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_debug_utils
var
  vkSetDebugUtilsObjectNameEXT*: proc(device: VkDevice, pNameInfo: ptr VkDebugUtilsObjectNameInfoEXT): VkResult {.stdcall.}
  vkSetDebugUtilsObjectTagEXT*: proc(device: VkDevice, pTagInfo: ptr VkDebugUtilsObjectTagInfoEXT): VkResult {.stdcall.}
  vkQueueBeginDebugUtilsLabelEXT*: proc(queue: VkQueue, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}
  vkQueueEndDebugUtilsLabelEXT*: proc(queue: VkQueue): void {.stdcall.}
  vkQueueInsertDebugUtilsLabelEXT*: proc(queue: VkQueue, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}
  vkCmdBeginDebugUtilsLabelEXT*: proc(commandBuffer: VkCommandBuffer, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}
  vkCmdEndDebugUtilsLabelEXT*: proc(commandBuffer: VkCommandBuffer): void {.stdcall.}
  vkCmdInsertDebugUtilsLabelEXT*: proc(commandBuffer: VkCommandBuffer, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}
  vkCreateDebugUtilsMessengerEXT*: proc(instance: VkInstance, pCreateInfo: ptr VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pMessenger: ptr VkDebugUtilsMessengerEXT): VkResult {.stdcall.}
  vkDestroyDebugUtilsMessengerEXT*: proc(instance: VkInstance, messenger: VkDebugUtilsMessengerEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkSubmitDebugUtilsMessageEXT*: proc(instance: VkInstance, messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageTypes: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT): void {.stdcall.}
proc loadVK_EXT_debug_utils*(instance: VkInstance) =
  vkSetDebugUtilsObjectNameEXT = cast[proc(device: VkDevice, pNameInfo: ptr VkDebugUtilsObjectNameInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetDebugUtilsObjectNameEXT"))
  vkSetDebugUtilsObjectTagEXT = cast[proc(device: VkDevice, pTagInfo: ptr VkDebugUtilsObjectTagInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetDebugUtilsObjectTagEXT"))
  vkQueueBeginDebugUtilsLabelEXT = cast[proc(queue: VkQueue, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueBeginDebugUtilsLabelEXT"))
  vkQueueEndDebugUtilsLabelEXT = cast[proc(queue: VkQueue): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueEndDebugUtilsLabelEXT"))
  vkQueueInsertDebugUtilsLabelEXT = cast[proc(queue: VkQueue, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueInsertDebugUtilsLabelEXT"))
  vkCmdBeginDebugUtilsLabelEXT = cast[proc(commandBuffer: VkCommandBuffer, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginDebugUtilsLabelEXT"))
  vkCmdEndDebugUtilsLabelEXT = cast[proc(commandBuffer: VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndDebugUtilsLabelEXT"))
  vkCmdInsertDebugUtilsLabelEXT = cast[proc(commandBuffer: VkCommandBuffer, pLabelInfo: ptr VkDebugUtilsLabelEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdInsertDebugUtilsLabelEXT"))
  vkCreateDebugUtilsMessengerEXT = cast[proc(instance: VkInstance, pCreateInfo: ptr VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pMessenger: ptr VkDebugUtilsMessengerEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"))
  vkDestroyDebugUtilsMessengerEXT = cast[proc(instance: VkInstance, messenger: VkDebugUtilsMessengerEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT"))
  vkSubmitDebugUtilsMessageEXT = cast[proc(instance: VkInstance, messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageTypes: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSubmitDebugUtilsMessageEXT"))

proc loadVK_KHR_portability_enumeration*(instance: VkInstance) =
  discard

proc loadVK_EXT_memory_priority*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_shader_core_properties*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_KHR_external_fence_fd
var
  vkImportFenceFdKHR*: proc(device: VkDevice, pImportFenceFdInfo: ptr VkImportFenceFdInfoKHR): VkResult {.stdcall.}
  vkGetFenceFdKHR*: proc(device: VkDevice, pGetFdInfo: ptr VkFenceGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}
proc loadVK_KHR_external_fence_fd*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkImportFenceFdKHR = cast[proc(device: VkDevice, pImportFenceFdInfo: ptr VkImportFenceFdInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkImportFenceFdKHR"))
  vkGetFenceFdKHR = cast[proc(device: VkDevice, pGetFdInfo: ptr VkFenceGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetFenceFdKHR"))

# extension VK_NV_device_generated_commands
var
  vkGetGeneratedCommandsMemoryRequirementsNV*: proc(device: VkDevice, pInfo: ptr VkGeneratedCommandsMemoryRequirementsInfoNV, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}
  vkCmdPreprocessGeneratedCommandsNV*: proc(commandBuffer: VkCommandBuffer, pGeneratedCommandsInfo: ptr VkGeneratedCommandsInfoNV): void {.stdcall.}
  vkCmdExecuteGeneratedCommandsNV*: proc(commandBuffer: VkCommandBuffer, isPreprocessed: VkBool32, pGeneratedCommandsInfo: ptr VkGeneratedCommandsInfoNV): void {.stdcall.}
  vkCmdBindPipelineShaderGroupNV*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, pipeline: VkPipeline, groupIndex: uint32): void {.stdcall.}
  vkCreateIndirectCommandsLayoutNV*: proc(device: VkDevice, pCreateInfo: ptr VkIndirectCommandsLayoutCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pIndirectCommandsLayout: ptr VkIndirectCommandsLayoutNV): VkResult {.stdcall.}
  vkDestroyIndirectCommandsLayoutNV*: proc(device: VkDevice, indirectCommandsLayout: VkIndirectCommandsLayoutNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
proc loadVK_NV_device_generated_commands*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  vkGetGeneratedCommandsMemoryRequirementsNV = cast[proc(device: VkDevice, pInfo: ptr VkGeneratedCommandsMemoryRequirementsInfoNV, pMemoryRequirements: ptr VkMemoryRequirements2): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetGeneratedCommandsMemoryRequirementsNV"))
  vkCmdPreprocessGeneratedCommandsNV = cast[proc(commandBuffer: VkCommandBuffer, pGeneratedCommandsInfo: ptr VkGeneratedCommandsInfoNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPreprocessGeneratedCommandsNV"))
  vkCmdExecuteGeneratedCommandsNV = cast[proc(commandBuffer: VkCommandBuffer, isPreprocessed: VkBool32, pGeneratedCommandsInfo: ptr VkGeneratedCommandsInfoNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdExecuteGeneratedCommandsNV"))
  vkCmdBindPipelineShaderGroupNV = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, pipeline: VkPipeline, groupIndex: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindPipelineShaderGroupNV"))
  vkCreateIndirectCommandsLayoutNV = cast[proc(device: VkDevice, pCreateInfo: ptr VkIndirectCommandsLayoutCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pIndirectCommandsLayout: ptr VkIndirectCommandsLayoutNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateIndirectCommandsLayoutNV"))
  vkDestroyIndirectCommandsLayoutNV = cast[proc(device: VkDevice, indirectCommandsLayout: VkIndirectCommandsLayoutNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyIndirectCommandsLayoutNV"))

proc loadVK_NV_viewport_array2*(instance: VkInstance) =
  discard

proc loadVK_NVX_multiview_per_view_attributes*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_KHR_external_memory_fd
var
  vkGetMemoryFdKHR*: proc(device: VkDevice, pGetFdInfo: ptr VkMemoryGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}
  vkGetMemoryFdPropertiesKHR*: proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, fd: cint, pMemoryFdProperties: ptr VkMemoryFdPropertiesKHR): VkResult {.stdcall.}
proc loadVK_KHR_external_memory_fd*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetMemoryFdKHR = cast[proc(device: VkDevice, pGetFdInfo: ptr VkMemoryGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryFdKHR"))
  vkGetMemoryFdPropertiesKHR = cast[proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, fd: cint, pMemoryFdProperties: ptr VkMemoryFdPropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryFdPropertiesKHR"))

proc loadVK_EXT_rgba10x6_formats*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_NV_dedicated_allocation_image_aliasing*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)

# extension VK_NV_cooperative_matrix
var
  vkGetPhysicalDeviceCooperativeMatrixPropertiesNV*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkCooperativeMatrixPropertiesNV): VkResult {.stdcall.}
proc loadVK_NV_cooperative_matrix*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetPhysicalDeviceCooperativeMatrixPropertiesNV = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkCooperativeMatrixPropertiesNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceCooperativeMatrixPropertiesNV"))

proc loadVK_EXT_depth_clamp_zero_one*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_NV_linear_color_attachment*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_shader_subgroup_ballot*(instance: VkInstance) =
  discard

# extension VK_EXT_image_drm_format_modifier
var
  vkGetImageDrmFormatModifierPropertiesEXT*: proc(device: VkDevice, image: VkImage, pProperties: ptr VkImageDrmFormatModifierPropertiesEXT): VkResult {.stdcall.}
proc loadVK_EXT_image_drm_format_modifier*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_1(instance)
  vkGetImageDrmFormatModifierPropertiesEXT = cast[proc(device: VkDevice, image: VkImage, pProperties: ptr VkImageDrmFormatModifierPropertiesEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageDrmFormatModifierPropertiesEXT"))

# extension VK_EXT_mesh_shader
var
  vkCmdDrawMeshTasksEXT*: proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}
  vkCmdDrawMeshTasksIndirectEXT*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdDrawMeshTasksIndirectCountEXT*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}
proc loadVK_EXT_mesh_shader*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  vkCmdDrawMeshTasksEXT = cast[proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksEXT"))
  vkCmdDrawMeshTasksIndirectEXT = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksIndirectEXT"))
  vkCmdDrawMeshTasksIndirectCountEXT = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksIndirectCountEXT"))

# extension VK_EXT_transform_feedback
var
  vkCmdBindTransformFeedbackBuffersEXT*: proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize, pSizes: ptr VkDeviceSize): void {.stdcall.}
  vkCmdBeginTransformFeedbackEXT*: proc(commandBuffer: VkCommandBuffer, firstCounterBuffer: uint32, counterBufferCount: uint32, pCounterBuffers: ptr VkBuffer, pCounterBufferOffsets: ptr VkDeviceSize): void {.stdcall.}
  vkCmdEndTransformFeedbackEXT*: proc(commandBuffer: VkCommandBuffer, firstCounterBuffer: uint32, counterBufferCount: uint32, pCounterBuffers: ptr VkBuffer, pCounterBufferOffsets: ptr VkDeviceSize): void {.stdcall.}
  vkCmdBeginQueryIndexedEXT*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, flags: VkQueryControlFlags, index: uint32): void {.stdcall.}
  vkCmdEndQueryIndexedEXT*: proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, index: uint32): void {.stdcall.}
  vkCmdDrawIndirectByteCountEXT*: proc(commandBuffer: VkCommandBuffer, instanceCount: uint32, firstInstance: uint32, counterBuffer: VkBuffer, counterBufferOffset: VkDeviceSize, counterOffset: uint32, vertexStride: uint32): void {.stdcall.}
proc loadVK_EXT_transform_feedback*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdBindTransformFeedbackBuffersEXT = cast[proc(commandBuffer: VkCommandBuffer, firstBinding: uint32, bindingCount: uint32, pBuffers: ptr VkBuffer, pOffsets: ptr VkDeviceSize, pSizes: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindTransformFeedbackBuffersEXT"))
  vkCmdBeginTransformFeedbackEXT = cast[proc(commandBuffer: VkCommandBuffer, firstCounterBuffer: uint32, counterBufferCount: uint32, pCounterBuffers: ptr VkBuffer, pCounterBufferOffsets: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginTransformFeedbackEXT"))
  vkCmdEndTransformFeedbackEXT = cast[proc(commandBuffer: VkCommandBuffer, firstCounterBuffer: uint32, counterBufferCount: uint32, pCounterBuffers: ptr VkBuffer, pCounterBufferOffsets: ptr VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndTransformFeedbackEXT"))
  vkCmdBeginQueryIndexedEXT = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, flags: VkQueryControlFlags, index: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginQueryIndexedEXT"))
  vkCmdEndQueryIndexedEXT = cast[proc(commandBuffer: VkCommandBuffer, queryPool: VkQueryPool, query: uint32, index: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndQueryIndexedEXT"))
  vkCmdDrawIndirectByteCountEXT = cast[proc(commandBuffer: VkCommandBuffer, instanceCount: uint32, firstInstance: uint32, counterBuffer: VkBuffer, counterBufferOffset: VkDeviceSize, counterOffset: uint32, vertexStride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawIndirectByteCountEXT"))

proc loadVK_AMD_shader_early_and_late_fragment_tests*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_shader_core_properties2*(instance: VkInstance) =
  loadVK_AMD_shader_core_properties(instance)

proc loadVK_GOOGLE_hlsl_functionality1*(instance: VkInstance) =
  discard

proc loadVK_EXT_robustness2*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_image_view_min_lod*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_shader_trinary_minmax*(instance: VkInstance) =
  discard

proc loadVK_EXT_custom_border_color*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_rasterization_order*(instance: VkInstance) =
  discard

# extension VK_EXT_vertex_input_dynamic_state
var
  vkCmdSetVertexInputEXT*: proc(commandBuffer: VkCommandBuffer, vertexBindingDescriptionCount: uint32, pVertexBindingDescriptions: ptr VkVertexInputBindingDescription2EXT, vertexAttributeDescriptionCount: uint32, pVertexAttributeDescriptions: ptr VkVertexInputAttributeDescription2EXT): void {.stdcall.}
proc loadVK_EXT_vertex_input_dynamic_state*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetVertexInputEXT = cast[proc(commandBuffer: VkCommandBuffer, vertexBindingDescriptionCount: uint32, pVertexBindingDescriptions: ptr VkVertexInputBindingDescription2EXT, vertexAttributeDescriptionCount: uint32, pVertexAttributeDescriptions: ptr VkVertexInputAttributeDescription2EXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetVertexInputEXT"))

# extension VK_KHR_fragment_shading_rate
var
  vkGetPhysicalDeviceFragmentShadingRatesKHR*: proc(physicalDevice: VkPhysicalDevice, pFragmentShadingRateCount: ptr uint32, pFragmentShadingRates: ptr VkPhysicalDeviceFragmentShadingRateKHR): VkResult {.stdcall.}
  vkCmdSetFragmentShadingRateKHR*: proc(commandBuffer: VkCommandBuffer, pFragmentSize: ptr VkExtent2D, combinerOps: array[2, VkFragmentShadingRateCombinerOpKHR]): void {.stdcall.}
proc loadVK_KHR_fragment_shading_rate*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_1(instance)
  vkGetPhysicalDeviceFragmentShadingRatesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pFragmentShadingRateCount: ptr uint32, pFragmentShadingRates: ptr VkPhysicalDeviceFragmentShadingRateKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFragmentShadingRatesKHR"))
  vkCmdSetFragmentShadingRateKHR = cast[proc(commandBuffer: VkCommandBuffer, pFragmentSize: ptr VkExtent2D, combinerOps: array[2, VkFragmentShadingRateCombinerOpKHR]): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetFragmentShadingRateKHR"))

proc loadVK_EXT_depth_clip_enable*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_subpass_merge_feedback*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_KHR_external_semaphore_fd
var
  vkImportSemaphoreFdKHR*: proc(device: VkDevice, pImportSemaphoreFdInfo: ptr VkImportSemaphoreFdInfoKHR): VkResult {.stdcall.}
  vkGetSemaphoreFdKHR*: proc(device: VkDevice, pGetFdInfo: ptr VkSemaphoreGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}
proc loadVK_KHR_external_semaphore_fd*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkImportSemaphoreFdKHR = cast[proc(device: VkDevice, pImportSemaphoreFdInfo: ptr VkImportSemaphoreFdInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkImportSemaphoreFdKHR"))
  vkGetSemaphoreFdKHR = cast[proc(device: VkDevice, pGetFdInfo: ptr VkSemaphoreGetFdInfoKHR, pFd: ptr cint): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSemaphoreFdKHR"))

proc loadVK_KHR_fragment_shader_barycentric*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_memory_budget*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_device_coherent_memory*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_device_memory_report*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_memory_overallocation_behavior*(instance: VkInstance) =
  discard

# extension VK_NV_mesh_shader
var
  vkCmdDrawMeshTasksNV*: proc(commandBuffer: VkCommandBuffer, taskCount: uint32, firstTask: uint32): void {.stdcall.}
  vkCmdDrawMeshTasksIndirectNV*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdDrawMeshTasksIndirectCountNV*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}
proc loadVK_NV_mesh_shader*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdDrawMeshTasksNV = cast[proc(commandBuffer: VkCommandBuffer, taskCount: uint32, firstTask: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksNV"))
  vkCmdDrawMeshTasksIndirectNV = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, drawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksIndirectNV"))
  vkCmdDrawMeshTasksIndirectCountNV = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize, countBuffer: VkBuffer, countBufferOffset: VkDeviceSize, maxDrawCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMeshTasksIndirectCountNV"))

# extension VK_EXT_image_compression_control
var
  vkGetImageSubresourceLayout2EXT*: proc(device: VkDevice, image: VkImage, pSubresource: ptr VkImageSubresource2EXT, pLayout: ptr VkSubresourceLayout2EXT): void {.stdcall.}
proc loadVK_EXT_image_compression_control*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetImageSubresourceLayout2EXT = cast[proc(device: VkDevice, image: VkImage, pSubresource: ptr VkImageSubresource2EXT, pLayout: ptr VkSubresourceLayout2EXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageSubresourceLayout2EXT"))

# extension VK_EXT_buffer_device_address
var
  vkGetBufferDeviceAddressEXT*: proc(device: VkDevice, pInfo: ptr VkBufferDeviceAddressInfo): VkDeviceAddress {.stdcall.}
proc loadVK_EXT_buffer_device_address*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetBufferDeviceAddressEXT = vkGetBufferDeviceAddress

proc loadVK_QCOM_render_pass_shader_resolve*(instance: VkInstance) =
  discard

proc loadVK_EXT_depth_range_unrestricted*(instance: VkInstance) =
  discard

# extension VK_HUAWEI_subpass_shading
var
  vkGetDeviceSubpassShadingMaxWorkgroupSizeHUAWEI*: proc(device: VkDevice, renderpass: VkRenderPass, pMaxWorkgroupSize: ptr VkExtent2D): VkResult {.stdcall.}
  vkCmdSubpassShadingHUAWEI*: proc(commandBuffer: VkCommandBuffer): void {.stdcall.}
proc loadVK_HUAWEI_subpass_shading*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_3(instance)
  vkGetDeviceSubpassShadingMaxWorkgroupSizeHUAWEI = cast[proc(device: VkDevice, renderpass: VkRenderPass, pMaxWorkgroupSize: ptr VkExtent2D): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceSubpassShadingMaxWorkgroupSizeHUAWEI"))
  vkCmdSubpassShadingHUAWEI = cast[proc(commandBuffer: VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSubpassShadingHUAWEI"))

# extension VK_VALVE_descriptor_set_host_mapping
var
  vkGetDescriptorSetLayoutHostMappingInfoVALVE*: proc(device: VkDevice, pBindingReference: ptr VkDescriptorSetBindingReferenceVALVE, pHostMapping: ptr VkDescriptorSetLayoutHostMappingInfoVALVE): void {.stdcall.}
  vkGetDescriptorSetHostMappingVALVE*: proc(device: VkDevice, descriptorSet: VkDescriptorSet, ppData: ptr pointer): void {.stdcall.}
proc loadVK_VALVE_descriptor_set_host_mapping*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetDescriptorSetLayoutHostMappingInfoVALVE = cast[proc(device: VkDevice, pBindingReference: ptr VkDescriptorSetBindingReferenceVALVE, pHostMapping: ptr VkDescriptorSetLayoutHostMappingInfoVALVE): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorSetLayoutHostMappingInfoVALVE"))
  vkGetDescriptorSetHostMappingVALVE = cast[proc(device: VkDevice, descriptorSet: VkDescriptorSet, ppData: ptr pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDescriptorSetHostMappingVALVE"))

# extension VK_NV_external_memory_capabilities
var
  vkGetPhysicalDeviceExternalImageFormatPropertiesNV*: proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, tiling: VkImageTiling, usage: VkImageUsageFlags, flags: VkImageCreateFlags, externalHandleType: VkExternalMemoryHandleTypeFlagsNV, pExternalImageFormatProperties: ptr VkExternalImageFormatPropertiesNV): VkResult {.stdcall.}
proc loadVK_NV_external_memory_capabilities*(instance: VkInstance) =
  vkGetPhysicalDeviceExternalImageFormatPropertiesNV = cast[proc(physicalDevice: VkPhysicalDevice, format: VkFormat, thetype: VkImageType, tiling: VkImageTiling, usage: VkImageUsageFlags, flags: VkImageCreateFlags, externalHandleType: VkExternalMemoryHandleTypeFlagsNV, pExternalImageFormatProperties: ptr VkExternalImageFormatPropertiesNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceExternalImageFormatPropertiesNV"))

# extension VK_NV_optical_flow
var
  vkGetPhysicalDeviceOpticalFlowImageFormatsNV*: proc(physicalDevice: VkPhysicalDevice, pOpticalFlowImageFormatInfo: ptr VkOpticalFlowImageFormatInfoNV, pFormatCount: ptr uint32, pImageFormatProperties: ptr VkOpticalFlowImageFormatPropertiesNV): VkResult {.stdcall.}
  vkCreateOpticalFlowSessionNV*: proc(device: VkDevice, pCreateInfo: ptr VkOpticalFlowSessionCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pSession: ptr VkOpticalFlowSessionNV): VkResult {.stdcall.}
  vkDestroyOpticalFlowSessionNV*: proc(device: VkDevice, session: VkOpticalFlowSessionNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkBindOpticalFlowSessionImageNV*: proc(device: VkDevice, session: VkOpticalFlowSessionNV, bindingPoint: VkOpticalFlowSessionBindingPointNV, view: VkImageView, layout: VkImageLayout): VkResult {.stdcall.}
  vkCmdOpticalFlowExecuteNV*: proc(commandBuffer: VkCommandBuffer, session: VkOpticalFlowSessionNV, pExecuteInfo: ptr VkOpticalFlowExecuteInfoNV): void {.stdcall.}
proc loadVK_NV_optical_flow*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_3(instance)
  loadVK_VERSION_1_3(instance)
  vkGetPhysicalDeviceOpticalFlowImageFormatsNV = cast[proc(physicalDevice: VkPhysicalDevice, pOpticalFlowImageFormatInfo: ptr VkOpticalFlowImageFormatInfoNV, pFormatCount: ptr uint32, pImageFormatProperties: ptr VkOpticalFlowImageFormatPropertiesNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceOpticalFlowImageFormatsNV"))
  vkCreateOpticalFlowSessionNV = cast[proc(device: VkDevice, pCreateInfo: ptr VkOpticalFlowSessionCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pSession: ptr VkOpticalFlowSessionNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateOpticalFlowSessionNV"))
  vkDestroyOpticalFlowSessionNV = cast[proc(device: VkDevice, session: VkOpticalFlowSessionNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyOpticalFlowSessionNV"))
  vkBindOpticalFlowSessionImageNV = cast[proc(device: VkDevice, session: VkOpticalFlowSessionNV, bindingPoint: VkOpticalFlowSessionBindingPointNV, view: VkImageView, layout: VkImageLayout): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindOpticalFlowSessionImageNV"))
  vkCmdOpticalFlowExecuteNV = cast[proc(commandBuffer: VkCommandBuffer, session: VkOpticalFlowSessionNV, pExecuteInfo: ptr VkOpticalFlowExecuteInfoNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdOpticalFlowExecuteNV"))

proc loadVK_EXT_vertex_attribute_divisor*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_line_rasterization
var
  vkCmdSetLineStippleEXT*: proc(commandBuffer: VkCommandBuffer, lineStippleFactor: uint32, lineStipplePattern: uint16): void {.stdcall.}
proc loadVK_EXT_line_rasterization*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetLineStippleEXT = cast[proc(commandBuffer: VkCommandBuffer, lineStippleFactor: uint32, lineStipplePattern: uint16): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetLineStippleEXT"))

proc loadVK_AMD_texture_gather_bias_lod*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_KHR_shader_subgroup_uniform_control_flow*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_external_memory_dma_buf*(instance: VkInstance) =
  loadVK_KHR_external_memory_fd(instance)

proc loadVK_IMG_filter_cubic*(instance: VkInstance) =
  discard

proc loadVK_AMD_shader_ballot*(instance: VkInstance) =
  discard

# extension VK_AMD_buffer_marker
var
  vkCmdWriteBufferMarkerAMD*: proc(commandBuffer: VkCommandBuffer, pipelineStage: VkPipelineStageFlagBits, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, marker: uint32): void {.stdcall.}
proc loadVK_AMD_buffer_marker*(instance: VkInstance) =
  vkCmdWriteBufferMarkerAMD = cast[proc(commandBuffer: VkCommandBuffer, pipelineStage: VkPipelineStageFlagBits, dstBuffer: VkBuffer, dstOffset: VkDeviceSize, marker: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteBufferMarkerAMD"))

proc loadVK_NV_corner_sampled_image*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_KHR_pipeline_library*(instance: VkInstance) =
  discard

proc loadVK_EXT_blend_operation_advanced*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_NV_scissor_exclusive
var
  vkCmdSetExclusiveScissorEnableNV*: proc(commandBuffer: VkCommandBuffer, firstExclusiveScissor: uint32, exclusiveScissorCount: uint32, pExclusiveScissorEnables: ptr VkBool32): void {.stdcall.}
  vkCmdSetExclusiveScissorNV*: proc(commandBuffer: VkCommandBuffer, firstExclusiveScissor: uint32, exclusiveScissorCount: uint32, pExclusiveScissors: ptr VkRect2D): void {.stdcall.}
proc loadVK_NV_scissor_exclusive*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetExclusiveScissorEnableNV = cast[proc(commandBuffer: VkCommandBuffer, firstExclusiveScissor: uint32, exclusiveScissorCount: uint32, pExclusiveScissorEnables: ptr VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetExclusiveScissorEnableNV"))
  vkCmdSetExclusiveScissorNV = cast[proc(commandBuffer: VkCommandBuffer, firstExclusiveScissor: uint32, exclusiveScissorCount: uint32, pExclusiveScissors: ptr VkRect2D): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetExclusiveScissorNV"))

proc loadVK_NV_framebuffer_mixed_samples*(instance: VkInstance) =
  discard

proc loadVK_NV_sample_mask_override_coverage*(instance: VkInstance) =
  discard

proc loadVK_EXT_filter_cubic*(instance: VkInstance) =
  discard

# extension VK_KHR_pipeline_executable_properties
var
  vkGetPipelineExecutablePropertiesKHR*: proc(device: VkDevice, pPipelineInfo: ptr VkPipelineInfoKHR, pExecutableCount: ptr uint32, pProperties: ptr VkPipelineExecutablePropertiesKHR): VkResult {.stdcall.}
  vkGetPipelineExecutableStatisticsKHR*: proc(device: VkDevice, pExecutableInfo: ptr VkPipelineExecutableInfoKHR, pStatisticCount: ptr uint32, pStatistics: ptr VkPipelineExecutableStatisticKHR): VkResult {.stdcall.}
  vkGetPipelineExecutableInternalRepresentationsKHR*: proc(device: VkDevice, pExecutableInfo: ptr VkPipelineExecutableInfoKHR, pInternalRepresentationCount: ptr uint32, pInternalRepresentations: ptr VkPipelineExecutableInternalRepresentationKHR): VkResult {.stdcall.}
proc loadVK_KHR_pipeline_executable_properties*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetPipelineExecutablePropertiesKHR = cast[proc(device: VkDevice, pPipelineInfo: ptr VkPipelineInfoKHR, pExecutableCount: ptr uint32, pProperties: ptr VkPipelineExecutablePropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPipelineExecutablePropertiesKHR"))
  vkGetPipelineExecutableStatisticsKHR = cast[proc(device: VkDevice, pExecutableInfo: ptr VkPipelineExecutableInfoKHR, pStatisticCount: ptr uint32, pStatistics: ptr VkPipelineExecutableStatisticKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPipelineExecutableStatisticsKHR"))
  vkGetPipelineExecutableInternalRepresentationsKHR = cast[proc(device: VkDevice, pExecutableInfo: ptr VkPipelineExecutableInfoKHR, pInternalRepresentationCount: ptr uint32, pInternalRepresentations: ptr VkPipelineExecutableInternalRepresentationKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPipelineExecutableInternalRepresentationsKHR"))

# extension VK_EXT_extended_dynamic_state3
var
  vkCmdSetTessellationDomainOriginEXT*: proc(commandBuffer: VkCommandBuffer, domainOrigin: VkTessellationDomainOrigin): void {.stdcall.}
  vkCmdSetDepthClampEnableEXT*: proc(commandBuffer: VkCommandBuffer, depthClampEnable: VkBool32): void {.stdcall.}
  vkCmdSetPolygonModeEXT*: proc(commandBuffer: VkCommandBuffer, polygonMode: VkPolygonMode): void {.stdcall.}
  vkCmdSetRasterizationSamplesEXT*: proc(commandBuffer: VkCommandBuffer, rasterizationSamples: VkSampleCountFlagBits): void {.stdcall.}
  vkCmdSetSampleMaskEXT*: proc(commandBuffer: VkCommandBuffer, samples: VkSampleCountFlagBits, pSampleMask: ptr VkSampleMask): void {.stdcall.}
  vkCmdSetAlphaToCoverageEnableEXT*: proc(commandBuffer: VkCommandBuffer, alphaToCoverageEnable: VkBool32): void {.stdcall.}
  vkCmdSetAlphaToOneEnableEXT*: proc(commandBuffer: VkCommandBuffer, alphaToOneEnable: VkBool32): void {.stdcall.}
  vkCmdSetLogicOpEnableEXT*: proc(commandBuffer: VkCommandBuffer, logicOpEnable: VkBool32): void {.stdcall.}
  vkCmdSetColorBlendEnableEXT*: proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendEnables: ptr VkBool32): void {.stdcall.}
  vkCmdSetColorBlendEquationEXT*: proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendEquations: ptr VkColorBlendEquationEXT): void {.stdcall.}
  vkCmdSetColorWriteMaskEXT*: proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorWriteMasks: ptr VkColorComponentFlags): void {.stdcall.}
  vkCmdSetRasterizationStreamEXT*: proc(commandBuffer: VkCommandBuffer, rasterizationStream: uint32): void {.stdcall.}
  vkCmdSetConservativeRasterizationModeEXT*: proc(commandBuffer: VkCommandBuffer, conservativeRasterizationMode: VkConservativeRasterizationModeEXT): void {.stdcall.}
  vkCmdSetExtraPrimitiveOverestimationSizeEXT*: proc(commandBuffer: VkCommandBuffer, extraPrimitiveOverestimationSize: float32): void {.stdcall.}
  vkCmdSetDepthClipEnableEXT*: proc(commandBuffer: VkCommandBuffer, depthClipEnable: VkBool32): void {.stdcall.}
  vkCmdSetSampleLocationsEnableEXT*: proc(commandBuffer: VkCommandBuffer, sampleLocationsEnable: VkBool32): void {.stdcall.}
  vkCmdSetColorBlendAdvancedEXT*: proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendAdvanced: ptr VkColorBlendAdvancedEXT): void {.stdcall.}
  vkCmdSetProvokingVertexModeEXT*: proc(commandBuffer: VkCommandBuffer, provokingVertexMode: VkProvokingVertexModeEXT): void {.stdcall.}
  vkCmdSetLineRasterizationModeEXT*: proc(commandBuffer: VkCommandBuffer, lineRasterizationMode: VkLineRasterizationModeEXT): void {.stdcall.}
  vkCmdSetLineStippleEnableEXT*: proc(commandBuffer: VkCommandBuffer, stippledLineEnable: VkBool32): void {.stdcall.}
  vkCmdSetDepthClipNegativeOneToOneEXT*: proc(commandBuffer: VkCommandBuffer, negativeOneToOne: VkBool32): void {.stdcall.}
  vkCmdSetViewportWScalingEnableNV*: proc(commandBuffer: VkCommandBuffer, viewportWScalingEnable: VkBool32): void {.stdcall.}
  vkCmdSetViewportSwizzleNV*: proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewportSwizzles: ptr VkViewportSwizzleNV): void {.stdcall.}
  vkCmdSetCoverageToColorEnableNV*: proc(commandBuffer: VkCommandBuffer, coverageToColorEnable: VkBool32): void {.stdcall.}
  vkCmdSetCoverageToColorLocationNV*: proc(commandBuffer: VkCommandBuffer, coverageToColorLocation: uint32): void {.stdcall.}
  vkCmdSetCoverageModulationModeNV*: proc(commandBuffer: VkCommandBuffer, coverageModulationMode: VkCoverageModulationModeNV): void {.stdcall.}
  vkCmdSetCoverageModulationTableEnableNV*: proc(commandBuffer: VkCommandBuffer, coverageModulationTableEnable: VkBool32): void {.stdcall.}
  vkCmdSetCoverageModulationTableNV*: proc(commandBuffer: VkCommandBuffer, coverageModulationTableCount: uint32, pCoverageModulationTable: ptr float32): void {.stdcall.}
  vkCmdSetShadingRateImageEnableNV*: proc(commandBuffer: VkCommandBuffer, shadingRateImageEnable: VkBool32): void {.stdcall.}
  vkCmdSetRepresentativeFragmentTestEnableNV*: proc(commandBuffer: VkCommandBuffer, representativeFragmentTestEnable: VkBool32): void {.stdcall.}
  vkCmdSetCoverageReductionModeNV*: proc(commandBuffer: VkCommandBuffer, coverageReductionMode: VkCoverageReductionModeNV): void {.stdcall.}
proc loadVK_EXT_extended_dynamic_state3*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetTessellationDomainOriginEXT = cast[proc(commandBuffer: VkCommandBuffer, domainOrigin: VkTessellationDomainOrigin): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetTessellationDomainOriginEXT"))
  vkCmdSetDepthClampEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, depthClampEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthClampEnableEXT"))
  vkCmdSetPolygonModeEXT = cast[proc(commandBuffer: VkCommandBuffer, polygonMode: VkPolygonMode): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPolygonModeEXT"))
  vkCmdSetRasterizationSamplesEXT = cast[proc(commandBuffer: VkCommandBuffer, rasterizationSamples: VkSampleCountFlagBits): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetRasterizationSamplesEXT"))
  vkCmdSetSampleMaskEXT = cast[proc(commandBuffer: VkCommandBuffer, samples: VkSampleCountFlagBits, pSampleMask: ptr VkSampleMask): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetSampleMaskEXT"))
  vkCmdSetAlphaToCoverageEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, alphaToCoverageEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetAlphaToCoverageEnableEXT"))
  vkCmdSetAlphaToOneEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, alphaToOneEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetAlphaToOneEnableEXT"))
  vkCmdSetLogicOpEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, logicOpEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetLogicOpEnableEXT"))
  vkCmdSetColorBlendEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendEnables: ptr VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetColorBlendEnableEXT"))
  vkCmdSetColorBlendEquationEXT = cast[proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendEquations: ptr VkColorBlendEquationEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetColorBlendEquationEXT"))
  vkCmdSetColorWriteMaskEXT = cast[proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorWriteMasks: ptr VkColorComponentFlags): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetColorWriteMaskEXT"))
  vkCmdSetRasterizationStreamEXT = cast[proc(commandBuffer: VkCommandBuffer, rasterizationStream: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetRasterizationStreamEXT"))
  vkCmdSetConservativeRasterizationModeEXT = cast[proc(commandBuffer: VkCommandBuffer, conservativeRasterizationMode: VkConservativeRasterizationModeEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetConservativeRasterizationModeEXT"))
  vkCmdSetExtraPrimitiveOverestimationSizeEXT = cast[proc(commandBuffer: VkCommandBuffer, extraPrimitiveOverestimationSize: float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetExtraPrimitiveOverestimationSizeEXT"))
  vkCmdSetDepthClipEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, depthClipEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthClipEnableEXT"))
  vkCmdSetSampleLocationsEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, sampleLocationsEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetSampleLocationsEnableEXT"))
  vkCmdSetColorBlendAdvancedEXT = cast[proc(commandBuffer: VkCommandBuffer, firstAttachment: uint32, attachmentCount: uint32, pColorBlendAdvanced: ptr VkColorBlendAdvancedEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetColorBlendAdvancedEXT"))
  vkCmdSetProvokingVertexModeEXT = cast[proc(commandBuffer: VkCommandBuffer, provokingVertexMode: VkProvokingVertexModeEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetProvokingVertexModeEXT"))
  vkCmdSetLineRasterizationModeEXT = cast[proc(commandBuffer: VkCommandBuffer, lineRasterizationMode: VkLineRasterizationModeEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetLineRasterizationModeEXT"))
  vkCmdSetLineStippleEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, stippledLineEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetLineStippleEnableEXT"))
  vkCmdSetDepthClipNegativeOneToOneEXT = cast[proc(commandBuffer: VkCommandBuffer, negativeOneToOne: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDepthClipNegativeOneToOneEXT"))
  vkCmdSetViewportWScalingEnableNV = cast[proc(commandBuffer: VkCommandBuffer, viewportWScalingEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewportWScalingEnableNV"))
  vkCmdSetViewportSwizzleNV = cast[proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewportSwizzles: ptr VkViewportSwizzleNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewportSwizzleNV"))
  vkCmdSetCoverageToColorEnableNV = cast[proc(commandBuffer: VkCommandBuffer, coverageToColorEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageToColorEnableNV"))
  vkCmdSetCoverageToColorLocationNV = cast[proc(commandBuffer: VkCommandBuffer, coverageToColorLocation: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageToColorLocationNV"))
  vkCmdSetCoverageModulationModeNV = cast[proc(commandBuffer: VkCommandBuffer, coverageModulationMode: VkCoverageModulationModeNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageModulationModeNV"))
  vkCmdSetCoverageModulationTableEnableNV = cast[proc(commandBuffer: VkCommandBuffer, coverageModulationTableEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageModulationTableEnableNV"))
  vkCmdSetCoverageModulationTableNV = cast[proc(commandBuffer: VkCommandBuffer, coverageModulationTableCount: uint32, pCoverageModulationTable: ptr float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageModulationTableNV"))
  vkCmdSetShadingRateImageEnableNV = cast[proc(commandBuffer: VkCommandBuffer, shadingRateImageEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetShadingRateImageEnableNV"))
  vkCmdSetRepresentativeFragmentTestEnableNV = cast[proc(commandBuffer: VkCommandBuffer, representativeFragmentTestEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetRepresentativeFragmentTestEnableNV"))
  vkCmdSetCoverageReductionModeNV = cast[proc(commandBuffer: VkCommandBuffer, coverageReductionMode: VkCoverageReductionModeNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetCoverageReductionModeNV"))

proc loadVK_EXT_device_address_binding_report*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_EXT_debug_utils(instance)

# extension VK_NV_clip_space_w_scaling
var
  vkCmdSetViewportWScalingNV*: proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewportWScalings: ptr VkViewportWScalingNV): void {.stdcall.}
proc loadVK_NV_clip_space_w_scaling*(instance: VkInstance) =
  vkCmdSetViewportWScalingNV = cast[proc(commandBuffer: VkCommandBuffer, firstViewport: uint32, viewportCount: uint32, pViewportWScalings: ptr VkViewportWScalingNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetViewportWScalingNV"))

proc loadVK_NV_fill_rectangle*(instance: VkInstance) =
  discard

proc loadVK_EXT_shader_image_atomic_int64*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_ycbcr_image_arrays*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_calibrated_timestamps
var
  vkGetPhysicalDeviceCalibrateableTimeDomainsEXT*: proc(physicalDevice: VkPhysicalDevice, pTimeDomainCount: ptr uint32, pTimeDomains: ptr VkTimeDomainEXT): VkResult {.stdcall.}
  vkGetCalibratedTimestampsEXT*: proc(device: VkDevice, timestampCount: uint32, pTimestampInfos: ptr VkCalibratedTimestampInfoEXT, pTimestamps: ptr uint64, pMaxDeviation: ptr uint64): VkResult {.stdcall.}
proc loadVK_EXT_calibrated_timestamps*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetPhysicalDeviceCalibrateableTimeDomainsEXT = cast[proc(physicalDevice: VkPhysicalDevice, pTimeDomainCount: ptr uint32, pTimeDomains: ptr VkTimeDomainEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceCalibrateableTimeDomainsEXT"))
  vkGetCalibratedTimestampsEXT = cast[proc(device: VkDevice, timestampCount: uint32, pTimestampInfos: ptr VkCalibratedTimestampInfoEXT, pTimestamps: ptr uint64, pMaxDeviation: ptr uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetCalibratedTimestampsEXT"))

proc loadVK_EXT_attachment_feedback_loop_layout*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_mixed_attachment_samples*(instance: VkInstance) =
  discard

# extension VK_EXT_external_memory_host
var
  vkGetMemoryHostPointerPropertiesEXT*: proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, pHostPointer: pointer, pMemoryHostPointerProperties: ptr VkMemoryHostPointerPropertiesEXT): VkResult {.stdcall.}
proc loadVK_EXT_external_memory_host*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetMemoryHostPointerPropertiesEXT = cast[proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, pHostPointer: pointer, pMemoryHostPointerProperties: ptr VkMemoryHostPointerPropertiesEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryHostPointerPropertiesEXT"))

proc loadVK_ARM_shader_core_properties*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_shader_module_identifier
var
  vkGetShaderModuleIdentifierEXT*: proc(device: VkDevice, shaderModule: VkShaderModule, pIdentifier: ptr VkShaderModuleIdentifierEXT): void {.stdcall.}
  vkGetShaderModuleCreateInfoIdentifierEXT*: proc(device: VkDevice, pCreateInfo: ptr VkShaderModuleCreateInfo, pIdentifier: ptr VkShaderModuleIdentifierEXT): void {.stdcall.}
proc loadVK_EXT_shader_module_identifier*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_3(instance)
  vkGetShaderModuleIdentifierEXT = cast[proc(device: VkDevice, shaderModule: VkShaderModule, pIdentifier: ptr VkShaderModuleIdentifierEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetShaderModuleIdentifierEXT"))
  vkGetShaderModuleCreateInfoIdentifierEXT = cast[proc(device: VkDevice, pCreateInfo: ptr VkShaderModuleCreateInfo, pIdentifier: ptr VkShaderModuleIdentifierEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetShaderModuleCreateInfoIdentifierEXT"))

proc loadVK_EXT_border_color_swizzle*(instance: VkInstance) =
  loadVK_EXT_custom_border_color(instance)

# extension VK_NV_memory_decompression
var
  vkCmdDecompressMemoryNV*: proc(commandBuffer: VkCommandBuffer, decompressRegionCount: uint32, pDecompressMemoryRegions: ptr VkDecompressMemoryRegionNV): void {.stdcall.}
  vkCmdDecompressMemoryIndirectCountNV*: proc(commandBuffer: VkCommandBuffer, indirectCommandsAddress: VkDeviceAddress, indirectCommandsCountAddress: VkDeviceAddress, stride: uint32): void {.stdcall.}
proc loadVK_NV_memory_decompression*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  vkCmdDecompressMemoryNV = cast[proc(commandBuffer: VkCommandBuffer, decompressRegionCount: uint32, pDecompressMemoryRegions: ptr VkDecompressMemoryRegionNV): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDecompressMemoryNV"))
  vkCmdDecompressMemoryIndirectCountNV = cast[proc(commandBuffer: VkCommandBuffer, indirectCommandsAddress: VkDeviceAddress, indirectCommandsCountAddress: VkDeviceAddress, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDecompressMemoryIndirectCountNV"))

proc loadVK_EXT_fragment_shader_interlock*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_NV_coverage_reduction_mode
var
  vkGetPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV*: proc(physicalDevice: VkPhysicalDevice, pCombinationCount: ptr uint32, pCombinations: ptr VkFramebufferMixedSamplesCombinationNV): VkResult {.stdcall.}
proc loadVK_NV_coverage_reduction_mode*(instance: VkInstance) =
  loadVK_NV_framebuffer_mixed_samples(instance)
  loadVK_VERSION_1_1(instance)
  vkGetPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV = cast[proc(physicalDevice: VkPhysicalDevice, pCombinationCount: ptr uint32, pCombinations: ptr VkFramebufferMixedSamplesCombinationNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV"))

proc loadVK_NV_glsl_shader*(instance: VkInstance) =
  discard

proc loadVK_KHR_shader_clock*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_QCOM_tile_properties
var
  vkGetFramebufferTilePropertiesQCOM*: proc(device: VkDevice, framebuffer: VkFramebuffer, pPropertiesCount: ptr uint32, pProperties: ptr VkTilePropertiesQCOM): VkResult {.stdcall.}
  vkGetDynamicRenderingTilePropertiesQCOM*: proc(device: VkDevice, pRenderingInfo: ptr VkRenderingInfo, pProperties: ptr VkTilePropertiesQCOM): VkResult {.stdcall.}
proc loadVK_QCOM_tile_properties*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetFramebufferTilePropertiesQCOM = cast[proc(device: VkDevice, framebuffer: VkFramebuffer, pPropertiesCount: ptr uint32, pProperties: ptr VkTilePropertiesQCOM): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetFramebufferTilePropertiesQCOM"))
  vkGetDynamicRenderingTilePropertiesQCOM = cast[proc(device: VkDevice, pRenderingInfo: ptr VkRenderingInfo, pProperties: ptr VkTilePropertiesQCOM): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDynamicRenderingTilePropertiesQCOM"))

# extension VK_KHR_push_descriptor
var
  vkCmdPushDescriptorSetKHR*: proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, set: uint32, descriptorWriteCount: uint32, pDescriptorWrites: ptr VkWriteDescriptorSet): void {.stdcall.}
  vkCmdPushDescriptorSetWithTemplateKHR*: proc(commandBuffer: VkCommandBuffer, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, layout: VkPipelineLayout, set: uint32, pData: pointer): void {.stdcall.}
proc loadVK_KHR_push_descriptor*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdPushDescriptorSetKHR = cast[proc(commandBuffer: VkCommandBuffer, pipelineBindPoint: VkPipelineBindPoint, layout: VkPipelineLayout, set: uint32, descriptorWriteCount: uint32, pDescriptorWrites: ptr VkWriteDescriptorSet): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPushDescriptorSetKHR"))
  vkCmdPushDescriptorSetWithTemplateKHR = cast[proc(commandBuffer: VkCommandBuffer, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, layout: VkPipelineLayout, set: uint32, pData: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPushDescriptorSetWithTemplateKHR"))
  vkCmdPushDescriptorSetWithTemplateKHR = cast[proc(commandBuffer: VkCommandBuffer, descriptorUpdateTemplate: VkDescriptorUpdateTemplate, layout: VkPipelineLayout, set: uint32, pData: pointer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdPushDescriptorSetWithTemplateKHR"))

proc loadVK_NV_viewport_swizzle*(instance: VkInstance) =
  discard

proc loadVK_NV_external_memory*(instance: VkInstance) =
  loadVK_NV_external_memory_capabilities(instance)

proc loadVK_EXT_depth_clip_control*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_validation_flags*(instance: VkInstance) =
  discard

proc loadVK_EXT_conservative_rasterization*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_AMD_gcn_shader*(instance: VkInstance) =
  discard

# extension VK_INTEL_performance_query
var
  vkInitializePerformanceApiINTEL*: proc(device: VkDevice, pInitializeInfo: ptr VkInitializePerformanceApiInfoINTEL): VkResult {.stdcall.}
  vkUninitializePerformanceApiINTEL*: proc(device: VkDevice): void {.stdcall.}
  vkCmdSetPerformanceMarkerINTEL*: proc(commandBuffer: VkCommandBuffer, pMarkerInfo: ptr VkPerformanceMarkerInfoINTEL): VkResult {.stdcall.}
  vkCmdSetPerformanceStreamMarkerINTEL*: proc(commandBuffer: VkCommandBuffer, pMarkerInfo: ptr VkPerformanceStreamMarkerInfoINTEL): VkResult {.stdcall.}
  vkCmdSetPerformanceOverrideINTEL*: proc(commandBuffer: VkCommandBuffer, pOverrideInfo: ptr VkPerformanceOverrideInfoINTEL): VkResult {.stdcall.}
  vkAcquirePerformanceConfigurationINTEL*: proc(device: VkDevice, pAcquireInfo: ptr VkPerformanceConfigurationAcquireInfoINTEL, pConfiguration: ptr VkPerformanceConfigurationINTEL): VkResult {.stdcall.}
  vkReleasePerformanceConfigurationINTEL*: proc(device: VkDevice, configuration: VkPerformanceConfigurationINTEL): VkResult {.stdcall.}
  vkQueueSetPerformanceConfigurationINTEL*: proc(queue: VkQueue, configuration: VkPerformanceConfigurationINTEL): VkResult {.stdcall.}
  vkGetPerformanceParameterINTEL*: proc(device: VkDevice, parameter: VkPerformanceParameterTypeINTEL, pValue: ptr VkPerformanceValueINTEL): VkResult {.stdcall.}
proc loadVK_INTEL_performance_query*(instance: VkInstance) =
  vkInitializePerformanceApiINTEL = cast[proc(device: VkDevice, pInitializeInfo: ptr VkInitializePerformanceApiInfoINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkInitializePerformanceApiINTEL"))
  vkUninitializePerformanceApiINTEL = cast[proc(device: VkDevice): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkUninitializePerformanceApiINTEL"))
  vkCmdSetPerformanceMarkerINTEL = cast[proc(commandBuffer: VkCommandBuffer, pMarkerInfo: ptr VkPerformanceMarkerInfoINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPerformanceMarkerINTEL"))
  vkCmdSetPerformanceStreamMarkerINTEL = cast[proc(commandBuffer: VkCommandBuffer, pMarkerInfo: ptr VkPerformanceStreamMarkerInfoINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPerformanceStreamMarkerINTEL"))
  vkCmdSetPerformanceOverrideINTEL = cast[proc(commandBuffer: VkCommandBuffer, pOverrideInfo: ptr VkPerformanceOverrideInfoINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetPerformanceOverrideINTEL"))
  vkAcquirePerformanceConfigurationINTEL = cast[proc(device: VkDevice, pAcquireInfo: ptr VkPerformanceConfigurationAcquireInfoINTEL, pConfiguration: ptr VkPerformanceConfigurationINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquirePerformanceConfigurationINTEL"))
  vkReleasePerformanceConfigurationINTEL = cast[proc(device: VkDevice, configuration: VkPerformanceConfigurationINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkReleasePerformanceConfigurationINTEL"))
  vkQueueSetPerformanceConfigurationINTEL = cast[proc(queue: VkQueue, configuration: VkPerformanceConfigurationINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueueSetPerformanceConfigurationINTEL"))
  vkGetPerformanceParameterINTEL = cast[proc(device: VkDevice, parameter: VkPerformanceParameterTypeINTEL, pValue: ptr VkPerformanceValueINTEL): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPerformanceParameterINTEL"))

proc loadVK_EXT_primitives_generated_query*(instance: VkInstance) =
  loadVK_EXT_transform_feedback(instance)

proc loadVK_AMD_pipeline_compiler_control*(instance: VkInstance) =
  discard

proc loadVK_EXT_post_depth_coverage*(instance: VkInstance) =
  discard

# extension VK_EXT_conditional_rendering
var
  vkCmdBeginConditionalRenderingEXT*: proc(commandBuffer: VkCommandBuffer, pConditionalRenderingBegin: ptr VkConditionalRenderingBeginInfoEXT): void {.stdcall.}
  vkCmdEndConditionalRenderingEXT*: proc(commandBuffer: VkCommandBuffer): void {.stdcall.}
proc loadVK_EXT_conditional_rendering*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdBeginConditionalRenderingEXT = cast[proc(commandBuffer: VkCommandBuffer, pConditionalRenderingBegin: ptr VkConditionalRenderingBeginInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginConditionalRenderingEXT"))
  vkCmdEndConditionalRenderingEXT = cast[proc(commandBuffer: VkCommandBuffer): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndConditionalRenderingEXT"))

proc loadVK_QCOM_multiview_per_view_viewports*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_multi_draw
var
  vkCmdDrawMultiEXT*: proc(commandBuffer: VkCommandBuffer, drawCount: uint32, pVertexInfo: ptr VkMultiDrawInfoEXT, instanceCount: uint32, firstInstance: uint32, stride: uint32): void {.stdcall.}
  vkCmdDrawMultiIndexedEXT*: proc(commandBuffer: VkCommandBuffer, drawCount: uint32, pIndexInfo: ptr VkMultiDrawIndexedInfoEXT, instanceCount: uint32, firstInstance: uint32, stride: uint32, pVertexOffset: ptr int32): void {.stdcall.}
proc loadVK_EXT_multi_draw*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdDrawMultiEXT = cast[proc(commandBuffer: VkCommandBuffer, drawCount: uint32, pVertexInfo: ptr VkMultiDrawInfoEXT, instanceCount: uint32, firstInstance: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMultiEXT"))
  vkCmdDrawMultiIndexedEXT = cast[proc(commandBuffer: VkCommandBuffer, drawCount: uint32, pIndexInfo: ptr VkMultiDrawIndexedInfoEXT, instanceCount: uint32, firstInstance: uint32, stride: uint32, pVertexOffset: ptr int32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawMultiIndexedEXT"))

proc loadVK_NV_fragment_coverage_to_color*(instance: VkInstance) =
  discard

proc loadVK_EXT_load_store_op_none*(instance: VkInstance) =
  discard

proc loadVK_EXT_validation_features*(instance: VkInstance) =
  discard

proc loadVK_KHR_workgroup_memory_explicit_layout*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_index_type_uint8*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_GOOGLE_decorate_string*(instance: VkInstance) =
  discard

proc loadVK_EXT_shader_atomic_float*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_pipeline_properties
var
  vkGetPipelinePropertiesEXT*: proc(device: VkDevice, pPipelineInfo: ptr VkPipelineInfoEXT, pPipelineProperties: ptr VkBaseOutStructure): VkResult {.stdcall.}
proc loadVK_EXT_pipeline_properties*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetPipelinePropertiesEXT = cast[proc(device: VkDevice, pPipelineInfo: ptr VkPipelineInfoEXT, pPipelineProperties: ptr VkBaseOutStructure): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPipelinePropertiesEXT"))

proc loadVK_EXT_graphics_pipeline_library*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_pipeline_library(instance)

# extension VK_KHR_surface
var
  vkDestroySurfaceKHR*: proc(instance: VkInstance, surface: VkSurfaceKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetPhysicalDeviceSurfaceSupportKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, surface: VkSurfaceKHR, pSupported: ptr VkBool32): VkResult {.stdcall.}
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR*: proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceCapabilities: ptr VkSurfaceCapabilitiesKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceSurfaceFormatsKHR*: proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceFormatCount: ptr uint32, pSurfaceFormats: ptr VkSurfaceFormatKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceSurfacePresentModesKHR*: proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pPresentModeCount: ptr uint32, pPresentModes: ptr VkPresentModeKHR): VkResult {.stdcall.}
proc loadVK_KHR_surface*(instance: VkInstance) =
  vkDestroySurfaceKHR = cast[proc(instance: VkInstance, surface: VkSurfaceKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroySurfaceKHR"))
  vkGetPhysicalDeviceSurfaceSupportKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32, surface: VkSurfaceKHR, pSupported: ptr VkBool32): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceSupportKHR"))
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceCapabilities: ptr VkSurfaceCapabilitiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"))
  vkGetPhysicalDeviceSurfaceFormatsKHR = cast[proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceFormatCount: ptr uint32, pSurfaceFormats: ptr VkSurfaceFormatKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR"))
  vkGetPhysicalDeviceSurfacePresentModesKHR = cast[proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pPresentModeCount: ptr uint32, pPresentModes: ptr VkPresentModeKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR"))

proc loadVK_AMD_gpu_shader_half_float*(instance: VkInstance) =
  discard

# extension VK_KHR_deferred_host_operations
var
  vkCreateDeferredOperationKHR*: proc(device: VkDevice, pAllocator: ptr VkAllocationCallbacks, pDeferredOperation: ptr VkDeferredOperationKHR): VkResult {.stdcall.}
  vkDestroyDeferredOperationKHR*: proc(device: VkDevice, operation: VkDeferredOperationKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetDeferredOperationMaxConcurrencyKHR*: proc(device: VkDevice, operation: VkDeferredOperationKHR): uint32 {.stdcall.}
  vkGetDeferredOperationResultKHR*: proc(device: VkDevice, operation: VkDeferredOperationKHR): VkResult {.stdcall.}
  vkDeferredOperationJoinKHR*: proc(device: VkDevice, operation: VkDeferredOperationKHR): VkResult {.stdcall.}
proc loadVK_KHR_deferred_host_operations*(instance: VkInstance) =
  vkCreateDeferredOperationKHR = cast[proc(device: VkDevice, pAllocator: ptr VkAllocationCallbacks, pDeferredOperation: ptr VkDeferredOperationKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDeferredOperationKHR"))
  vkDestroyDeferredOperationKHR = cast[proc(device: VkDevice, operation: VkDeferredOperationKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyDeferredOperationKHR"))
  vkGetDeferredOperationMaxConcurrencyKHR = cast[proc(device: VkDevice, operation: VkDeferredOperationKHR): uint32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeferredOperationMaxConcurrencyKHR"))
  vkGetDeferredOperationResultKHR = cast[proc(device: VkDevice, operation: VkDeferredOperationKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeferredOperationResultKHR"))
  vkDeferredOperationJoinKHR = cast[proc(device: VkDevice, operation: VkDeferredOperationKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDeferredOperationJoinKHR"))

proc loadVK_NV_dedicated_allocation*(instance: VkInstance) =
  discard

# extension VK_NVX_image_view_handle
var
  vkGetImageViewHandleNVX*: proc(device: VkDevice, pInfo: ptr VkImageViewHandleInfoNVX): uint32 {.stdcall.}
  vkGetImageViewAddressNVX*: proc(device: VkDevice, imageView: VkImageView, pProperties: ptr VkImageViewAddressPropertiesNVX): VkResult {.stdcall.}
proc loadVK_NVX_image_view_handle*(instance: VkInstance) =
  vkGetImageViewHandleNVX = cast[proc(device: VkDevice, pInfo: ptr VkImageViewHandleInfoNVX): uint32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageViewHandleNVX"))
  vkGetImageViewAddressNVX = cast[proc(device: VkDevice, imageView: VkImageView, pProperties: ptr VkImageViewAddressPropertiesNVX): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetImageViewAddressNVX"))

proc loadVK_EXT_non_seamless_cube_map*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_QCOM_render_pass_store_ops*(instance: VkInstance) =
  discard

# extension VK_EXT_device_fault
var
  vkGetDeviceFaultInfoEXT*: proc(device: VkDevice, pFaultCounts: ptr VkDeviceFaultCountsEXT, pFaultInfo: ptr VkDeviceFaultInfoEXT): VkResult {.stdcall.}
proc loadVK_EXT_device_fault*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetDeviceFaultInfoEXT = cast[proc(device: VkDevice, pFaultCounts: ptr VkDeviceFaultCountsEXT, pFaultInfo: ptr VkDeviceFaultInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceFaultInfoEXT"))

proc loadVK_EXT_mutable_descriptor_type*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_color_write_enable
var
  vkCmdSetColorWriteEnableEXT*: proc(commandBuffer: VkCommandBuffer, attachmentCount: uint32, pColorWriteEnables: ptr VkBool32): void {.stdcall.}
proc loadVK_EXT_color_write_enable*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetColorWriteEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, attachmentCount: uint32, pColorWriteEnables: ptr VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetColorWriteEnableEXT"))

proc loadVK_SEC_amigo_profiling*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_NVX_binary_import
var
  vkCreateCuModuleNVX*: proc(device: VkDevice, pCreateInfo: ptr VkCuModuleCreateInfoNVX, pAllocator: ptr VkAllocationCallbacks, pModule: ptr VkCuModuleNVX): VkResult {.stdcall.}
  vkCreateCuFunctionNVX*: proc(device: VkDevice, pCreateInfo: ptr VkCuFunctionCreateInfoNVX, pAllocator: ptr VkAllocationCallbacks, pFunction: ptr VkCuFunctionNVX): VkResult {.stdcall.}
  vkDestroyCuModuleNVX*: proc(device: VkDevice, module: VkCuModuleNVX, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkDestroyCuFunctionNVX*: proc(device: VkDevice, function: VkCuFunctionNVX, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCmdCuLaunchKernelNVX*: proc(commandBuffer: VkCommandBuffer, pLaunchInfo: ptr VkCuLaunchInfoNVX): void {.stdcall.}
proc loadVK_NVX_binary_import*(instance: VkInstance) =
  vkCreateCuModuleNVX = cast[proc(device: VkDevice, pCreateInfo: ptr VkCuModuleCreateInfoNVX, pAllocator: ptr VkAllocationCallbacks, pModule: ptr VkCuModuleNVX): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateCuModuleNVX"))
  vkCreateCuFunctionNVX = cast[proc(device: VkDevice, pCreateInfo: ptr VkCuFunctionCreateInfoNVX, pAllocator: ptr VkAllocationCallbacks, pFunction: ptr VkCuFunctionNVX): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateCuFunctionNVX"))
  vkDestroyCuModuleNVX = cast[proc(device: VkDevice, module: VkCuModuleNVX, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyCuModuleNVX"))
  vkDestroyCuFunctionNVX = cast[proc(device: VkDevice, function: VkCuFunctionNVX, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyCuFunctionNVX"))
  vkCmdCuLaunchKernelNVX = cast[proc(commandBuffer: VkCommandBuffer, pLaunchInfo: ptr VkCuLaunchInfoNVX): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCuLaunchKernelNVX"))

proc loadVK_NV_representative_fragment_test*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_validation_cache
var
  vkCreateValidationCacheEXT*: proc(device: VkDevice, pCreateInfo: ptr VkValidationCacheCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pValidationCache: ptr VkValidationCacheEXT): VkResult {.stdcall.}
  vkDestroyValidationCacheEXT*: proc(device: VkDevice, validationCache: VkValidationCacheEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkMergeValidationCachesEXT*: proc(device: VkDevice, dstCache: VkValidationCacheEXT, srcCacheCount: uint32, pSrcCaches: ptr VkValidationCacheEXT): VkResult {.stdcall.}
  vkGetValidationCacheDataEXT*: proc(device: VkDevice, validationCache: VkValidationCacheEXT, pDataSize: ptr csize_t, pData: pointer): VkResult {.stdcall.}
proc loadVK_EXT_validation_cache*(instance: VkInstance) =
  vkCreateValidationCacheEXT = cast[proc(device: VkDevice, pCreateInfo: ptr VkValidationCacheCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pValidationCache: ptr VkValidationCacheEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateValidationCacheEXT"))
  vkDestroyValidationCacheEXT = cast[proc(device: VkDevice, validationCache: VkValidationCacheEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyValidationCacheEXT"))
  vkMergeValidationCachesEXT = cast[proc(device: VkDevice, dstCache: VkValidationCacheEXT, srcCacheCount: uint32, pSrcCaches: ptr VkValidationCacheEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkMergeValidationCachesEXT"))
  vkGetValidationCacheDataEXT = cast[proc(device: VkDevice, validationCache: VkValidationCacheEXT, pDataSize: ptr csize_t, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetValidationCacheDataEXT"))

proc loadVK_NV_inherited_viewport_scissor*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_legacy_dithering*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_physical_device_drm*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_pipeline_protected_access*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_EXT_discard_rectangles
var
  vkCmdSetDiscardRectangleEXT*: proc(commandBuffer: VkCommandBuffer, firstDiscardRectangle: uint32, discardRectangleCount: uint32, pDiscardRectangles: ptr VkRect2D): void {.stdcall.}
  vkCmdSetDiscardRectangleEnableEXT*: proc(commandBuffer: VkCommandBuffer, discardRectangleEnable: VkBool32): void {.stdcall.}
  vkCmdSetDiscardRectangleModeEXT*: proc(commandBuffer: VkCommandBuffer, discardRectangleMode: VkDiscardRectangleModeEXT): void {.stdcall.}
proc loadVK_EXT_discard_rectangles*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdSetDiscardRectangleEXT = cast[proc(commandBuffer: VkCommandBuffer, firstDiscardRectangle: uint32, discardRectangleCount: uint32, pDiscardRectangles: ptr VkRect2D): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDiscardRectangleEXT"))
  vkCmdSetDiscardRectangleEnableEXT = cast[proc(commandBuffer: VkCommandBuffer, discardRectangleEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDiscardRectangleEnableEXT"))
  vkCmdSetDiscardRectangleModeEXT = cast[proc(commandBuffer: VkCommandBuffer, discardRectangleMode: VkDiscardRectangleModeEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetDiscardRectangleModeEXT"))

proc loadVK_EXT_shader_stencil_export*(instance: VkInstance) =
  discard

# extension VK_NV_external_memory_rdma
var
  vkGetMemoryRemoteAddressNV*: proc(device: VkDevice, pMemoryGetRemoteAddressInfo: ptr VkMemoryGetRemoteAddressInfoNV, pAddress: ptr VkRemoteAddressNV): VkResult {.stdcall.}
proc loadVK_NV_external_memory_rdma*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetMemoryRemoteAddressNV = cast[proc(device: VkDevice, pMemoryGetRemoteAddressInfo: ptr VkMemoryGetRemoteAddressInfoNV, pAddress: ptr VkRemoteAddressNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryRemoteAddressNV"))

proc loadVK_ARM_shader_core_builtins*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_QCOM_multiview_per_view_render_areas*(instance: VkInstance) =
  discard

proc loadVK_LUNARG_direct_driver_loading*(instance: VkInstance) =
  discard

proc loadVK_AMD_shader_explicit_vertex_parameter*(instance: VkInstance) =
  discard

# extension VK_EXT_headless_surface
var
  vkCreateHeadlessSurfaceEXT*: proc(instance: VkInstance, pCreateInfo: ptr VkHeadlessSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_EXT_headless_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateHeadlessSurfaceEXT = cast[proc(instance: VkInstance, pCreateInfo: ptr VkHeadlessSurfaceCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateHeadlessSurfaceEXT"))

proc loadVK_NV_shader_sm_builtins*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_shader_subgroup_vote*(instance: VkInstance) =
  discard

# extension VK_NV_copy_memory_indirect
var
  vkCmdCopyMemoryIndirectNV*: proc(commandBuffer: VkCommandBuffer, copyBufferAddress: VkDeviceAddress, copyCount: uint32, stride: uint32): void {.stdcall.}
  vkCmdCopyMemoryToImageIndirectNV*: proc(commandBuffer: VkCommandBuffer, copyBufferAddress: VkDeviceAddress, copyCount: uint32, stride: uint32, dstImage: VkImage, dstImageLayout: VkImageLayout, pImageSubresources: ptr VkImageSubresourceLayers): void {.stdcall.}
proc loadVK_NV_copy_memory_indirect*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  vkCmdCopyMemoryIndirectNV = cast[proc(commandBuffer: VkCommandBuffer, copyBufferAddress: VkDeviceAddress, copyCount: uint32, stride: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMemoryIndirectNV"))
  vkCmdCopyMemoryToImageIndirectNV = cast[proc(commandBuffer: VkCommandBuffer, copyBufferAddress: VkDeviceAddress, copyCount: uint32, stride: uint32, dstImage: VkImage, dstImageLayout: VkImageLayout, pImageSubresources: ptr VkImageSubresourceLayers): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMemoryToImageIndirectNV"))

proc loadVK_EXT_astc_decode_mode*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

# extension VK_KHR_get_surface_capabilities2
var
  vkGetPhysicalDeviceSurfaceCapabilities2KHR*: proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pSurfaceCapabilities: ptr VkSurfaceCapabilities2KHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceSurfaceFormats2KHR*: proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pSurfaceFormatCount: ptr uint32, pSurfaceFormats: ptr VkSurfaceFormat2KHR): VkResult {.stdcall.}
proc loadVK_KHR_get_surface_capabilities2*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkGetPhysicalDeviceSurfaceCapabilities2KHR = cast[proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pSurfaceCapabilities: ptr VkSurfaceCapabilities2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilities2KHR"))
  vkGetPhysicalDeviceSurfaceFormats2KHR = cast[proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pSurfaceFormatCount: ptr uint32, pSurfaceFormats: ptr VkSurfaceFormat2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormats2KHR"))

# extension VK_HUAWEI_cluster_culling_shader
var
  vkCmdDrawClusterHUAWEI*: proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}
  vkCmdDrawClusterIndirectHUAWEI*: proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize): void {.stdcall.}
proc loadVK_HUAWEI_cluster_culling_shader*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkCmdDrawClusterHUAWEI = cast[proc(commandBuffer: VkCommandBuffer, groupCountX: uint32, groupCountY: uint32, groupCountZ: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawClusterHUAWEI"))
  vkCmdDrawClusterIndirectHUAWEI = cast[proc(commandBuffer: VkCommandBuffer, buffer: VkBuffer, offset: VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDrawClusterIndirectHUAWEI"))

proc loadVK_KHR_surface_protected_capabilities*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_get_surface_capabilities2(instance)

proc loadVK_NV_shader_image_footprint*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_NV_compute_shader_derivatives*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_QCOM_fragment_density_map_offset*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_EXT_fragment_density_map(instance)

proc loadVK_EXT_shader_atomic_float2*(instance: VkInstance) =
  loadVK_EXT_shader_atomic_float(instance)

# extension VK_EXT_pageable_device_local_memory
var
  vkSetDeviceMemoryPriorityEXT*: proc(device: VkDevice, memory: VkDeviceMemory, priority: float32): void {.stdcall.}
proc loadVK_EXT_pageable_device_local_memory*(instance: VkInstance) =
  loadVK_EXT_memory_priority(instance)
  vkSetDeviceMemoryPriorityEXT = cast[proc(device: VkDevice, memory: VkDeviceMemory, priority: float32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetDeviceMemoryPriorityEXT"))

# extension VK_KHR_swapchain
var
  vkCreateSwapchainKHR*: proc(device: VkDevice, pCreateInfo: ptr VkSwapchainCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSwapchain: ptr VkSwapchainKHR): VkResult {.stdcall.}
  vkDestroySwapchainKHR*: proc(device: VkDevice, swapchain: VkSwapchainKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetSwapchainImagesKHR*: proc(device: VkDevice, swapchain: VkSwapchainKHR, pSwapchainImageCount: ptr uint32, pSwapchainImages: ptr VkImage): VkResult {.stdcall.}
  vkAcquireNextImageKHR*: proc(device: VkDevice, swapchain: VkSwapchainKHR, timeout: uint64, semaphore: VkSemaphore, fence: VkFence, pImageIndex: ptr uint32): VkResult {.stdcall.}
  vkQueuePresentKHR*: proc(queue: VkQueue, pPresentInfo: ptr VkPresentInfoKHR): VkResult {.stdcall.}
  vkGetDeviceGroupPresentCapabilitiesKHR*: proc(device: VkDevice, pDeviceGroupPresentCapabilities: ptr VkDeviceGroupPresentCapabilitiesKHR): VkResult {.stdcall.}
  vkGetDeviceGroupSurfacePresentModesKHR*: proc(device: VkDevice, surface: VkSurfaceKHR, pModes: ptr VkDeviceGroupPresentModeFlagsKHR): VkResult {.stdcall.}
  vkGetPhysicalDevicePresentRectanglesKHR*: proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pRectCount: ptr uint32, pRects: ptr VkRect2D): VkResult {.stdcall.}
  vkAcquireNextImage2KHR*: proc(device: VkDevice, pAcquireInfo: ptr VkAcquireNextImageInfoKHR, pImageIndex: ptr uint32): VkResult {.stdcall.}
proc loadVK_KHR_swapchain*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateSwapchainKHR = cast[proc(device: VkDevice, pCreateInfo: ptr VkSwapchainCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSwapchain: ptr VkSwapchainKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateSwapchainKHR"))
  vkDestroySwapchainKHR = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroySwapchainKHR"))
  vkGetSwapchainImagesKHR = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, pSwapchainImageCount: ptr uint32, pSwapchainImages: ptr VkImage): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSwapchainImagesKHR"))
  vkAcquireNextImageKHR = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, timeout: uint64, semaphore: VkSemaphore, fence: VkFence, pImageIndex: ptr uint32): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireNextImageKHR"))
  vkQueuePresentKHR = cast[proc(queue: VkQueue, pPresentInfo: ptr VkPresentInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkQueuePresentKHR"))
  vkGetDeviceGroupPresentCapabilitiesKHR = cast[proc(device: VkDevice, pDeviceGroupPresentCapabilities: ptr VkDeviceGroupPresentCapabilitiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceGroupPresentCapabilitiesKHR"))
  vkGetDeviceGroupSurfacePresentModesKHR = cast[proc(device: VkDevice, surface: VkSurfaceKHR, pModes: ptr VkDeviceGroupPresentModeFlagsKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceGroupSurfacePresentModesKHR"))
  vkGetPhysicalDevicePresentRectanglesKHR = cast[proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pRectCount: ptr uint32, pRects: ptr VkRect2D): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDevicePresentRectanglesKHR"))
  vkAcquireNextImage2KHR = cast[proc(device: VkDevice, pAcquireInfo: ptr VkAcquireNextImageInfoKHR, pImageIndex: ptr uint32): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireNextImage2KHR"))

proc loadVK_EXT_fragment_density_map2*(instance: VkInstance) =
  loadVK_EXT_fragment_density_map(instance)

# extension VK_NV_fragment_shading_rate_enums
var
  vkCmdSetFragmentShadingRateEnumNV*: proc(commandBuffer: VkCommandBuffer, shadingRate: VkFragmentShadingRateNV, combinerOps: array[2, VkFragmentShadingRateCombinerOpKHR]): void {.stdcall.}
proc loadVK_NV_fragment_shading_rate_enums*(instance: VkInstance) =
  loadVK_KHR_fragment_shading_rate(instance)
  vkCmdSetFragmentShadingRateEnumNV = cast[proc(commandBuffer: VkCommandBuffer, shadingRate: VkFragmentShadingRateNV, combinerOps: array[2, VkFragmentShadingRateCombinerOpKHR]): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetFragmentShadingRateEnumNV"))

# extension VK_AMD_display_native_hdr
var
  vkSetLocalDimmingAMD*: proc(device: VkDevice, swapChain: VkSwapchainKHR, localDimmingEnable: VkBool32): void {.stdcall.}
proc loadVK_AMD_display_native_hdr*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_get_surface_capabilities2(instance)
  loadVK_KHR_swapchain(instance)
  vkSetLocalDimmingAMD = cast[proc(device: VkDevice, swapChain: VkSwapchainKHR, localDimmingEnable: VkBool32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetLocalDimmingAMD"))

proc loadVK_NV_present_barrier*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_surface(instance)
  loadVK_KHR_get_surface_capabilities2(instance)
  loadVK_KHR_swapchain(instance)

proc loadVK_QCOM_rotated_copy_commands*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_VERSION_1_3(instance)

proc loadVK_EXT_surface_maintenance1*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  loadVK_KHR_get_surface_capabilities2(instance)

# extension VK_KHR_acceleration_structure
var
  vkCreateAccelerationStructureKHR*: proc(device: VkDevice, pCreateInfo: ptr VkAccelerationStructureCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pAccelerationStructure: ptr VkAccelerationStructureKHR): VkResult {.stdcall.}
  vkDestroyAccelerationStructureKHR*: proc(device: VkDevice, accelerationStructure: VkAccelerationStructureKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCmdBuildAccelerationStructuresKHR*: proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, ppBuildRangeInfos: ptr ptr VkAccelerationStructureBuildRangeInfoKHR): void {.stdcall.}
  vkCmdBuildAccelerationStructuresIndirectKHR*: proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, pIndirectDeviceAddresses: ptr VkDeviceAddress, pIndirectStrides: ptr uint32, ppMaxPrimitiveCounts: ptr ptr uint32): void {.stdcall.}
  vkBuildAccelerationStructuresKHR*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, ppBuildRangeInfos: ptr ptr VkAccelerationStructureBuildRangeInfoKHR): VkResult {.stdcall.}
  vkCopyAccelerationStructureKHR*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyAccelerationStructureInfoKHR): VkResult {.stdcall.}
  vkCopyAccelerationStructureToMemoryKHR*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyAccelerationStructureToMemoryInfoKHR): VkResult {.stdcall.}
  vkCopyMemoryToAccelerationStructureKHR*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMemoryToAccelerationStructureInfoKHR): VkResult {.stdcall.}
  vkWriteAccelerationStructuresPropertiesKHR*: proc(device: VkDevice, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureKHR, queryType: VkQueryType, dataSize: csize_t, pData: pointer, stride: csize_t): VkResult {.stdcall.}
  vkCmdCopyAccelerationStructureKHR*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyAccelerationStructureInfoKHR): void {.stdcall.}
  vkCmdCopyAccelerationStructureToMemoryKHR*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyAccelerationStructureToMemoryInfoKHR): void {.stdcall.}
  vkCmdCopyMemoryToAccelerationStructureKHR*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMemoryToAccelerationStructureInfoKHR): void {.stdcall.}
  vkGetAccelerationStructureDeviceAddressKHR*: proc(device: VkDevice, pInfo: ptr VkAccelerationStructureDeviceAddressInfoKHR): VkDeviceAddress {.stdcall.}
  vkCmdWriteAccelerationStructuresPropertiesKHR*: proc(commandBuffer: VkCommandBuffer, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureKHR, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}
  vkGetDeviceAccelerationStructureCompatibilityKHR*: proc(device: VkDevice, pVersionInfo: ptr VkAccelerationStructureVersionInfoKHR, pCompatibility: ptr VkAccelerationStructureCompatibilityKHR): void {.stdcall.}
  vkGetAccelerationStructureBuildSizesKHR*: proc(device: VkDevice, buildType: VkAccelerationStructureBuildTypeKHR, pBuildInfo: ptr VkAccelerationStructureBuildGeometryInfoKHR, pMaxPrimitiveCounts: ptr uint32, pSizeInfo: ptr VkAccelerationStructureBuildSizesInfoKHR): void {.stdcall.}
proc loadVK_KHR_acceleration_structure*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)
  loadVK_VERSION_1_2(instance)
  loadVK_KHR_deferred_host_operations(instance)
  vkCreateAccelerationStructureKHR = cast[proc(device: VkDevice, pCreateInfo: ptr VkAccelerationStructureCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pAccelerationStructure: ptr VkAccelerationStructureKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateAccelerationStructureKHR"))
  vkDestroyAccelerationStructureKHR = cast[proc(device: VkDevice, accelerationStructure: VkAccelerationStructureKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyAccelerationStructureKHR"))
  vkCmdBuildAccelerationStructuresKHR = cast[proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, ppBuildRangeInfos: ptr ptr VkAccelerationStructureBuildRangeInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBuildAccelerationStructuresKHR"))
  vkCmdBuildAccelerationStructuresIndirectKHR = cast[proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, pIndirectDeviceAddresses: ptr VkDeviceAddress, pIndirectStrides: ptr uint32, ppMaxPrimitiveCounts: ptr ptr uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBuildAccelerationStructuresIndirectKHR"))
  vkBuildAccelerationStructuresKHR = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, infoCount: uint32, pInfos: ptr VkAccelerationStructureBuildGeometryInfoKHR, ppBuildRangeInfos: ptr ptr VkAccelerationStructureBuildRangeInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBuildAccelerationStructuresKHR"))
  vkCopyAccelerationStructureKHR = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyAccelerationStructureInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyAccelerationStructureKHR"))
  vkCopyAccelerationStructureToMemoryKHR = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyAccelerationStructureToMemoryInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyAccelerationStructureToMemoryKHR"))
  vkCopyMemoryToAccelerationStructureKHR = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMemoryToAccelerationStructureInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyMemoryToAccelerationStructureKHR"))
  vkWriteAccelerationStructuresPropertiesKHR = cast[proc(device: VkDevice, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureKHR, queryType: VkQueryType, dataSize: csize_t, pData: pointer, stride: csize_t): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkWriteAccelerationStructuresPropertiesKHR"))
  vkCmdCopyAccelerationStructureKHR = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyAccelerationStructureInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyAccelerationStructureKHR"))
  vkCmdCopyAccelerationStructureToMemoryKHR = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyAccelerationStructureToMemoryInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyAccelerationStructureToMemoryKHR"))
  vkCmdCopyMemoryToAccelerationStructureKHR = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMemoryToAccelerationStructureInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMemoryToAccelerationStructureKHR"))
  vkGetAccelerationStructureDeviceAddressKHR = cast[proc(device: VkDevice, pInfo: ptr VkAccelerationStructureDeviceAddressInfoKHR): VkDeviceAddress {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAccelerationStructureDeviceAddressKHR"))
  vkCmdWriteAccelerationStructuresPropertiesKHR = cast[proc(commandBuffer: VkCommandBuffer, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureKHR, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteAccelerationStructuresPropertiesKHR"))
  vkGetDeviceAccelerationStructureCompatibilityKHR = cast[proc(device: VkDevice, pVersionInfo: ptr VkAccelerationStructureVersionInfoKHR, pCompatibility: ptr VkAccelerationStructureCompatibilityKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceAccelerationStructureCompatibilityKHR"))
  vkGetAccelerationStructureBuildSizesKHR = cast[proc(device: VkDevice, buildType: VkAccelerationStructureBuildTypeKHR, pBuildInfo: ptr VkAccelerationStructureBuildGeometryInfoKHR, pMaxPrimitiveCounts: ptr uint32, pSizeInfo: ptr VkAccelerationStructureBuildSizesInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAccelerationStructureBuildSizesKHR"))

# extension VK_GOOGLE_display_timing
var
  vkGetRefreshCycleDurationGOOGLE*: proc(device: VkDevice, swapchain: VkSwapchainKHR, pDisplayTimingProperties: ptr VkRefreshCycleDurationGOOGLE): VkResult {.stdcall.}
  vkGetPastPresentationTimingGOOGLE*: proc(device: VkDevice, swapchain: VkSwapchainKHR, pPresentationTimingCount: ptr uint32, pPresentationTimings: ptr VkPastPresentationTimingGOOGLE): VkResult {.stdcall.}
proc loadVK_GOOGLE_display_timing*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  vkGetRefreshCycleDurationGOOGLE = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, pDisplayTimingProperties: ptr VkRefreshCycleDurationGOOGLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRefreshCycleDurationGOOGLE"))
  vkGetPastPresentationTimingGOOGLE = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, pPresentationTimingCount: ptr uint32, pPresentationTimings: ptr VkPastPresentationTimingGOOGLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPastPresentationTimingGOOGLE"))

proc loadVK_QCOM_render_pass_transform*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_KHR_surface(instance)

proc loadVK_GOOGLE_surfaceless_query*(instance: VkInstance) =
  loadVK_KHR_surface(instance)

proc loadVK_EXT_image_compression_control_swapchain*(instance: VkInstance) =
  loadVK_EXT_image_compression_control(instance)

# extension VK_KHR_display
var
  vkGetPhysicalDeviceDisplayPropertiesKHR*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPropertiesKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceDisplayPlanePropertiesKHR*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPlanePropertiesKHR): VkResult {.stdcall.}
  vkGetDisplayPlaneSupportedDisplaysKHR*: proc(physicalDevice: VkPhysicalDevice, planeIndex: uint32, pDisplayCount: ptr uint32, pDisplays: ptr VkDisplayKHR): VkResult {.stdcall.}
  vkGetDisplayModePropertiesKHR*: proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayModePropertiesKHR): VkResult {.stdcall.}
  vkCreateDisplayModeKHR*: proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pCreateInfo: ptr VkDisplayModeCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pMode: ptr VkDisplayModeKHR): VkResult {.stdcall.}
  vkGetDisplayPlaneCapabilitiesKHR*: proc(physicalDevice: VkPhysicalDevice, mode: VkDisplayModeKHR, planeIndex: uint32, pCapabilities: ptr VkDisplayPlaneCapabilitiesKHR): VkResult {.stdcall.}
  vkCreateDisplayPlaneSurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkDisplaySurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
proc loadVK_KHR_display*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkGetPhysicalDeviceDisplayPropertiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceDisplayPropertiesKHR"))
  vkGetPhysicalDeviceDisplayPlanePropertiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPlanePropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceDisplayPlanePropertiesKHR"))
  vkGetDisplayPlaneSupportedDisplaysKHR = cast[proc(physicalDevice: VkPhysicalDevice, planeIndex: uint32, pDisplayCount: ptr uint32, pDisplays: ptr VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDisplayPlaneSupportedDisplaysKHR"))
  vkGetDisplayModePropertiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayModePropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDisplayModePropertiesKHR"))
  vkCreateDisplayModeKHR = cast[proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pCreateInfo: ptr VkDisplayModeCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pMode: ptr VkDisplayModeKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDisplayModeKHR"))
  vkGetDisplayPlaneCapabilitiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, mode: VkDisplayModeKHR, planeIndex: uint32, pCapabilities: ptr VkDisplayPlaneCapabilitiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDisplayPlaneCapabilitiesKHR"))
  vkCreateDisplayPlaneSurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkDisplaySurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateDisplayPlaneSurfaceKHR"))

# extension VK_EXT_swapchain_maintenance1
var
  vkReleaseSwapchainImagesEXT*: proc(device: VkDevice, pReleaseInfo: ptr VkReleaseSwapchainImagesInfoEXT): VkResult {.stdcall.}
proc loadVK_EXT_swapchain_maintenance1*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_EXT_surface_maintenance1(instance)
  loadVK_VERSION_1_1(instance)
  vkReleaseSwapchainImagesEXT = cast[proc(device: VkDevice, pReleaseInfo: ptr VkReleaseSwapchainImagesInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkReleaseSwapchainImagesEXT"))

# extension VK_EXT_direct_mode_display
var
  vkReleaseDisplayEXT*: proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR): VkResult {.stdcall.}
proc loadVK_EXT_direct_mode_display*(instance: VkInstance) =
  loadVK_KHR_display(instance)
  vkReleaseDisplayEXT = cast[proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkReleaseDisplayEXT"))

proc loadVK_KHR_swapchain_mutable_format*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_2(instance)

proc loadVK_EXT_swapchain_colorspace*(instance: VkInstance) =
  loadVK_KHR_surface(instance)

# extension VK_EXT_opacity_micromap
var
  vkCreateMicromapEXT*: proc(device: VkDevice, pCreateInfo: ptr VkMicromapCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pMicromap: ptr VkMicromapEXT): VkResult {.stdcall.}
  vkDestroyMicromapEXT*: proc(device: VkDevice, micromap: VkMicromapEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCmdBuildMicromapsEXT*: proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkMicromapBuildInfoEXT): void {.stdcall.}
  vkBuildMicromapsEXT*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, infoCount: uint32, pInfos: ptr VkMicromapBuildInfoEXT): VkResult {.stdcall.}
  vkCopyMicromapEXT*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMicromapInfoEXT): VkResult {.stdcall.}
  vkCopyMicromapToMemoryEXT*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMicromapToMemoryInfoEXT): VkResult {.stdcall.}
  vkCopyMemoryToMicromapEXT*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMemoryToMicromapInfoEXT): VkResult {.stdcall.}
  vkWriteMicromapsPropertiesEXT*: proc(device: VkDevice, micromapCount: uint32, pMicromaps: ptr VkMicromapEXT, queryType: VkQueryType, dataSize: csize_t, pData: pointer, stride: csize_t): VkResult {.stdcall.}
  vkCmdCopyMicromapEXT*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMicromapInfoEXT): void {.stdcall.}
  vkCmdCopyMicromapToMemoryEXT*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMicromapToMemoryInfoEXT): void {.stdcall.}
  vkCmdCopyMemoryToMicromapEXT*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMemoryToMicromapInfoEXT): void {.stdcall.}
  vkCmdWriteMicromapsPropertiesEXT*: proc(commandBuffer: VkCommandBuffer, micromapCount: uint32, pMicromaps: ptr VkMicromapEXT, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}
  vkGetDeviceMicromapCompatibilityEXT*: proc(device: VkDevice, pVersionInfo: ptr VkMicromapVersionInfoEXT, pCompatibility: ptr VkAccelerationStructureCompatibilityKHR): void {.stdcall.}
  vkGetMicromapBuildSizesEXT*: proc(device: VkDevice, buildType: VkAccelerationStructureBuildTypeKHR, pBuildInfo: ptr VkMicromapBuildInfoEXT, pSizeInfo: ptr VkMicromapBuildSizesInfoEXT): void {.stdcall.}
proc loadVK_EXT_opacity_micromap*(instance: VkInstance) =
  loadVK_KHR_acceleration_structure(instance)
  loadVK_VERSION_1_3(instance)
  vkCreateMicromapEXT = cast[proc(device: VkDevice, pCreateInfo: ptr VkMicromapCreateInfoEXT, pAllocator: ptr VkAllocationCallbacks, pMicromap: ptr VkMicromapEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateMicromapEXT"))
  vkDestroyMicromapEXT = cast[proc(device: VkDevice, micromap: VkMicromapEXT, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyMicromapEXT"))
  vkCmdBuildMicromapsEXT = cast[proc(commandBuffer: VkCommandBuffer, infoCount: uint32, pInfos: ptr VkMicromapBuildInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBuildMicromapsEXT"))
  vkBuildMicromapsEXT = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, infoCount: uint32, pInfos: ptr VkMicromapBuildInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBuildMicromapsEXT"))
  vkCopyMicromapEXT = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMicromapInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyMicromapEXT"))
  vkCopyMicromapToMemoryEXT = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMicromapToMemoryInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyMicromapToMemoryEXT"))
  vkCopyMemoryToMicromapEXT = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pInfo: ptr VkCopyMemoryToMicromapInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCopyMemoryToMicromapEXT"))
  vkWriteMicromapsPropertiesEXT = cast[proc(device: VkDevice, micromapCount: uint32, pMicromaps: ptr VkMicromapEXT, queryType: VkQueryType, dataSize: csize_t, pData: pointer, stride: csize_t): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkWriteMicromapsPropertiesEXT"))
  vkCmdCopyMicromapEXT = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMicromapInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMicromapEXT"))
  vkCmdCopyMicromapToMemoryEXT = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMicromapToMemoryInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMicromapToMemoryEXT"))
  vkCmdCopyMemoryToMicromapEXT = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkCopyMemoryToMicromapInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyMemoryToMicromapEXT"))
  vkCmdWriteMicromapsPropertiesEXT = cast[proc(commandBuffer: VkCommandBuffer, micromapCount: uint32, pMicromaps: ptr VkMicromapEXT, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteMicromapsPropertiesEXT"))
  vkGetDeviceMicromapCompatibilityEXT = cast[proc(device: VkDevice, pVersionInfo: ptr VkMicromapVersionInfoEXT, pCompatibility: ptr VkAccelerationStructureCompatibilityKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceMicromapCompatibilityEXT"))
  vkGetMicromapBuildSizesEXT = cast[proc(device: VkDevice, buildType: VkAccelerationStructureBuildTypeKHR, pBuildInfo: ptr VkMicromapBuildInfoEXT, pSizeInfo: ptr VkMicromapBuildSizesInfoEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMicromapBuildSizesEXT"))

proc loadVK_KHR_incremental_present*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)

# extension VK_KHR_shared_presentable_image
var
  vkGetSwapchainStatusKHR*: proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}
proc loadVK_KHR_shared_presentable_image*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_get_surface_capabilities2(instance)
  vkGetSwapchainStatusKHR = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSwapchainStatusKHR"))

# extension VK_EXT_hdr_metadata
var
  vkSetHdrMetadataEXT*: proc(device: VkDevice, swapchainCount: uint32, pSwapchains: ptr VkSwapchainKHR, pMetadata: ptr VkHdrMetadataEXT): void {.stdcall.}
proc loadVK_EXT_hdr_metadata*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  vkSetHdrMetadataEXT = cast[proc(device: VkDevice, swapchainCount: uint32, pSwapchains: ptr VkSwapchainKHR, pMetadata: ptr VkHdrMetadataEXT): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkSetHdrMetadataEXT"))

proc loadVK_KHR_present_id*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_VERSION_1_1(instance)

# extension VK_KHR_ray_tracing_maintenance1
var
  vkCmdTraceRaysIndirect2KHR*: proc(commandBuffer: VkCommandBuffer, indirectDeviceAddress: VkDeviceAddress): void {.stdcall.}
proc loadVK_KHR_ray_tracing_maintenance1*(instance: VkInstance) =
  loadVK_KHR_acceleration_structure(instance)
  vkCmdTraceRaysIndirect2KHR = cast[proc(commandBuffer: VkCommandBuffer, indirectDeviceAddress: VkDeviceAddress): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdTraceRaysIndirect2KHR"))

# extension VK_KHR_ray_tracing_pipeline
var
  vkCmdTraceRaysKHR*: proc(commandBuffer: VkCommandBuffer, pRaygenShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pMissShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pHitShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pCallableShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, width: uint32, height: uint32, depth: uint32): void {.stdcall.}
  vkCreateRayTracingPipelinesKHR*: proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkRayTracingPipelineCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}
  vkGetRayTracingShaderGroupHandlesKHR*: proc(device: VkDevice, pipeline: VkPipeline, firstGroup: uint32, groupCount: uint32, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}
  vkGetRayTracingCaptureReplayShaderGroupHandlesKHR*: proc(device: VkDevice, pipeline: VkPipeline, firstGroup: uint32, groupCount: uint32, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}
  vkCmdTraceRaysIndirectKHR*: proc(commandBuffer: VkCommandBuffer, pRaygenShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pMissShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pHitShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pCallableShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, indirectDeviceAddress: VkDeviceAddress): void {.stdcall.}
  vkGetRayTracingShaderGroupStackSizeKHR*: proc(device: VkDevice, pipeline: VkPipeline, group: uint32, groupShader: VkShaderGroupShaderKHR): VkDeviceSize {.stdcall.}
  vkCmdSetRayTracingPipelineStackSizeKHR*: proc(commandBuffer: VkCommandBuffer, pipelineStackSize: uint32): void {.stdcall.}
proc loadVK_KHR_ray_tracing_pipeline*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  loadVK_KHR_acceleration_structure(instance)
  vkCmdTraceRaysKHR = cast[proc(commandBuffer: VkCommandBuffer, pRaygenShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pMissShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pHitShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pCallableShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, width: uint32, height: uint32, depth: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdTraceRaysKHR"))
  vkCreateRayTracingPipelinesKHR = cast[proc(device: VkDevice, deferredOperation: VkDeferredOperationKHR, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkRayTracingPipelineCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateRayTracingPipelinesKHR"))
  vkGetRayTracingShaderGroupHandlesKHR = cast[proc(device: VkDevice, pipeline: VkPipeline, firstGroup: uint32, groupCount: uint32, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRayTracingShaderGroupHandlesKHR"))
  vkGetRayTracingCaptureReplayShaderGroupHandlesKHR = cast[proc(device: VkDevice, pipeline: VkPipeline, firstGroup: uint32, groupCount: uint32, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRayTracingCaptureReplayShaderGroupHandlesKHR"))
  vkCmdTraceRaysIndirectKHR = cast[proc(commandBuffer: VkCommandBuffer, pRaygenShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pMissShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pHitShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, pCallableShaderBindingTable: ptr VkStridedDeviceAddressRegionKHR, indirectDeviceAddress: VkDeviceAddress): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdTraceRaysIndirectKHR"))
  vkGetRayTracingShaderGroupStackSizeKHR = cast[proc(device: VkDevice, pipeline: VkPipeline, group: uint32, groupShader: VkShaderGroupShaderKHR): VkDeviceSize {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetRayTracingShaderGroupStackSizeKHR"))
  vkCmdSetRayTracingPipelineStackSizeKHR = cast[proc(commandBuffer: VkCommandBuffer, pipelineStackSize: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdSetRayTracingPipelineStackSizeKHR"))

# extension VK_HUAWEI_invocation_mask
var
  vkCmdBindInvocationMaskHUAWEI*: proc(commandBuffer: VkCommandBuffer, imageView: VkImageView, imageLayout: VkImageLayout): void {.stdcall.}
proc loadVK_HUAWEI_invocation_mask*(instance: VkInstance) =
  loadVK_KHR_ray_tracing_pipeline(instance)
  loadVK_VERSION_1_3(instance)
  vkCmdBindInvocationMaskHUAWEI = cast[proc(commandBuffer: VkCommandBuffer, imageView: VkImageView, imageLayout: VkImageLayout): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBindInvocationMaskHUAWEI"))

# extension VK_EXT_display_surface_counter
var
  vkGetPhysicalDeviceSurfaceCapabilities2EXT*: proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceCapabilities: ptr VkSurfaceCapabilities2EXT): VkResult {.stdcall.}
proc loadVK_EXT_display_surface_counter*(instance: VkInstance) =
  loadVK_KHR_display(instance)
  vkGetPhysicalDeviceSurfaceCapabilities2EXT = cast[proc(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR, pSurfaceCapabilities: ptr VkSurfaceCapabilities2EXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilities2EXT"))

# extension VK_KHR_get_display_properties2
var
  vkGetPhysicalDeviceDisplayProperties2KHR*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayProperties2KHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceDisplayPlaneProperties2KHR*: proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPlaneProperties2KHR): VkResult {.stdcall.}
  vkGetDisplayModeProperties2KHR*: proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayModeProperties2KHR): VkResult {.stdcall.}
  vkGetDisplayPlaneCapabilities2KHR*: proc(physicalDevice: VkPhysicalDevice, pDisplayPlaneInfo: ptr VkDisplayPlaneInfo2KHR, pCapabilities: ptr VkDisplayPlaneCapabilities2KHR): VkResult {.stdcall.}
proc loadVK_KHR_get_display_properties2*(instance: VkInstance) =
  loadVK_KHR_display(instance)
  vkGetPhysicalDeviceDisplayProperties2KHR = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayProperties2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceDisplayProperties2KHR"))
  vkGetPhysicalDeviceDisplayPlaneProperties2KHR = cast[proc(physicalDevice: VkPhysicalDevice, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayPlaneProperties2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceDisplayPlaneProperties2KHR"))
  vkGetDisplayModeProperties2KHR = cast[proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR, pPropertyCount: ptr uint32, pProperties: ptr VkDisplayModeProperties2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDisplayModeProperties2KHR"))
  vkGetDisplayPlaneCapabilities2KHR = cast[proc(physicalDevice: VkPhysicalDevice, pDisplayPlaneInfo: ptr VkDisplayPlaneInfo2KHR, pCapabilities: ptr VkDisplayPlaneCapabilities2KHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDisplayPlaneCapabilities2KHR"))

proc loadVK_KHR_ray_query*(instance: VkInstance) =
  loadVK_VERSION_1_2(instance)
  loadVK_KHR_acceleration_structure(instance)

# extension VK_KHR_display_swapchain
var
  vkCreateSharedSwapchainsKHR*: proc(device: VkDevice, swapchainCount: uint32, pCreateInfos: ptr VkSwapchainCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSwapchains: ptr VkSwapchainKHR): VkResult {.stdcall.}
proc loadVK_KHR_display_swapchain*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_KHR_display(instance)
  vkCreateSharedSwapchainsKHR = cast[proc(device: VkDevice, swapchainCount: uint32, pCreateInfos: ptr VkSwapchainCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSwapchains: ptr VkSwapchainKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateSharedSwapchainsKHR"))

# extension VK_EXT_acquire_drm_display
var
  vkAcquireDrmDisplayEXT*: proc(physicalDevice: VkPhysicalDevice, drmFd: int32, display: VkDisplayKHR): VkResult {.stdcall.}
  vkGetDrmDisplayEXT*: proc(physicalDevice: VkPhysicalDevice, drmFd: int32, connectorId: uint32, display: ptr VkDisplayKHR): VkResult {.stdcall.}
proc loadVK_EXT_acquire_drm_display*(instance: VkInstance) =
  loadVK_EXT_direct_mode_display(instance)
  vkAcquireDrmDisplayEXT = cast[proc(physicalDevice: VkPhysicalDevice, drmFd: int32, display: VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireDrmDisplayEXT"))
  vkGetDrmDisplayEXT = cast[proc(physicalDevice: VkPhysicalDevice, drmFd: int32, connectorId: uint32, display: ptr VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDrmDisplayEXT"))

# extension VK_EXT_display_control
var
  vkDisplayPowerControlEXT*: proc(device: VkDevice, display: VkDisplayKHR, pDisplayPowerInfo: ptr VkDisplayPowerInfoEXT): VkResult {.stdcall.}
  vkRegisterDeviceEventEXT*: proc(device: VkDevice, pDeviceEventInfo: ptr VkDeviceEventInfoEXT, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}
  vkRegisterDisplayEventEXT*: proc(device: VkDevice, display: VkDisplayKHR, pDisplayEventInfo: ptr VkDisplayEventInfoEXT, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}
  vkGetSwapchainCounterEXT*: proc(device: VkDevice, swapchain: VkSwapchainKHR, counter: VkSurfaceCounterFlagBitsEXT, pCounterValue: ptr uint64): VkResult {.stdcall.}
proc loadVK_EXT_display_control*(instance: VkInstance) =
  loadVK_EXT_display_surface_counter(instance)
  loadVK_KHR_swapchain(instance)
  vkDisplayPowerControlEXT = cast[proc(device: VkDevice, display: VkDisplayKHR, pDisplayPowerInfo: ptr VkDisplayPowerInfoEXT): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDisplayPowerControlEXT"))
  vkRegisterDeviceEventEXT = cast[proc(device: VkDevice, pDeviceEventInfo: ptr VkDeviceEventInfoEXT, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkRegisterDeviceEventEXT"))
  vkRegisterDisplayEventEXT = cast[proc(device: VkDevice, display: VkDisplayKHR, pDisplayEventInfo: ptr VkDisplayEventInfoEXT, pAllocator: ptr VkAllocationCallbacks, pFence: ptr VkFence): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkRegisterDisplayEventEXT"))
  vkGetSwapchainCounterEXT = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, counter: VkSurfaceCounterFlagBitsEXT, pCounterValue: ptr uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSwapchainCounterEXT"))

proc loadVK_NV_ray_tracing_motion_blur*(instance: VkInstance) =
  loadVK_KHR_ray_tracing_pipeline(instance)

proc loadVK_EXT_pipeline_library_group_handles*(instance: VkInstance) =
  loadVK_KHR_ray_tracing_pipeline(instance)
  loadVK_KHR_pipeline_library(instance)

# extension VK_NV_ray_tracing
var
  vkCreateAccelerationStructureNV*: proc(device: VkDevice, pCreateInfo: ptr VkAccelerationStructureCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pAccelerationStructure: ptr VkAccelerationStructureNV): VkResult {.stdcall.}
  vkDestroyAccelerationStructureNV*: proc(device: VkDevice, accelerationStructure: VkAccelerationStructureNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetAccelerationStructureMemoryRequirementsNV*: proc(device: VkDevice, pInfo: ptr VkAccelerationStructureMemoryRequirementsInfoNV, pMemoryRequirements: ptr VkMemoryRequirements2KHR): void {.stdcall.}
  vkBindAccelerationStructureMemoryNV*: proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindAccelerationStructureMemoryInfoNV): VkResult {.stdcall.}
  vkCmdBuildAccelerationStructureNV*: proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkAccelerationStructureInfoNV, instanceData: VkBuffer, instanceOffset: VkDeviceSize, update: VkBool32, dst: VkAccelerationStructureNV, src: VkAccelerationStructureNV, scratch: VkBuffer, scratchOffset: VkDeviceSize): void {.stdcall.}
  vkCmdCopyAccelerationStructureNV*: proc(commandBuffer: VkCommandBuffer, dst: VkAccelerationStructureNV, src: VkAccelerationStructureNV, mode: VkCopyAccelerationStructureModeKHR): void {.stdcall.}
  vkCmdTraceRaysNV*: proc(commandBuffer: VkCommandBuffer, raygenShaderBindingTableBuffer: VkBuffer, raygenShaderBindingOffset: VkDeviceSize, missShaderBindingTableBuffer: VkBuffer, missShaderBindingOffset: VkDeviceSize, missShaderBindingStride: VkDeviceSize, hitShaderBindingTableBuffer: VkBuffer, hitShaderBindingOffset: VkDeviceSize, hitShaderBindingStride: VkDeviceSize, callableShaderBindingTableBuffer: VkBuffer, callableShaderBindingOffset: VkDeviceSize, callableShaderBindingStride: VkDeviceSize, width: uint32, height: uint32, depth: uint32): void {.stdcall.}
  vkCreateRayTracingPipelinesNV*: proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkRayTracingPipelineCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}
  vkGetRayTracingShaderGroupHandlesNV*: proc(device: VkDevice, pipeline: VkPipeline, firstGroup: uint32, groupCount: uint32, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}
  vkGetAccelerationStructureHandleNV*: proc(device: VkDevice, accelerationStructure: VkAccelerationStructureNV, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}
  vkCmdWriteAccelerationStructuresPropertiesNV*: proc(commandBuffer: VkCommandBuffer, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureNV, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}
  vkCompileDeferredNV*: proc(device: VkDevice, pipeline: VkPipeline, shader: uint32): VkResult {.stdcall.}
proc loadVK_NV_ray_tracing*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_1(instance)
  vkCreateAccelerationStructureNV = cast[proc(device: VkDevice, pCreateInfo: ptr VkAccelerationStructureCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pAccelerationStructure: ptr VkAccelerationStructureNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateAccelerationStructureNV"))
  vkDestroyAccelerationStructureNV = cast[proc(device: VkDevice, accelerationStructure: VkAccelerationStructureNV, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyAccelerationStructureNV"))
  vkGetAccelerationStructureMemoryRequirementsNV = cast[proc(device: VkDevice, pInfo: ptr VkAccelerationStructureMemoryRequirementsInfoNV, pMemoryRequirements: ptr VkMemoryRequirements2KHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAccelerationStructureMemoryRequirementsNV"))
  vkBindAccelerationStructureMemoryNV = cast[proc(device: VkDevice, bindInfoCount: uint32, pBindInfos: ptr VkBindAccelerationStructureMemoryInfoNV): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindAccelerationStructureMemoryNV"))
  vkCmdBuildAccelerationStructureNV = cast[proc(commandBuffer: VkCommandBuffer, pInfo: ptr VkAccelerationStructureInfoNV, instanceData: VkBuffer, instanceOffset: VkDeviceSize, update: VkBool32, dst: VkAccelerationStructureNV, src: VkAccelerationStructureNV, scratch: VkBuffer, scratchOffset: VkDeviceSize): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBuildAccelerationStructureNV"))
  vkCmdCopyAccelerationStructureNV = cast[proc(commandBuffer: VkCommandBuffer, dst: VkAccelerationStructureNV, src: VkAccelerationStructureNV, mode: VkCopyAccelerationStructureModeKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdCopyAccelerationStructureNV"))
  vkCmdTraceRaysNV = cast[proc(commandBuffer: VkCommandBuffer, raygenShaderBindingTableBuffer: VkBuffer, raygenShaderBindingOffset: VkDeviceSize, missShaderBindingTableBuffer: VkBuffer, missShaderBindingOffset: VkDeviceSize, missShaderBindingStride: VkDeviceSize, hitShaderBindingTableBuffer: VkBuffer, hitShaderBindingOffset: VkDeviceSize, hitShaderBindingStride: VkDeviceSize, callableShaderBindingTableBuffer: VkBuffer, callableShaderBindingOffset: VkDeviceSize, callableShaderBindingStride: VkDeviceSize, width: uint32, height: uint32, depth: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdTraceRaysNV"))
  vkCreateRayTracingPipelinesNV = cast[proc(device: VkDevice, pipelineCache: VkPipelineCache, createInfoCount: uint32, pCreateInfos: ptr VkRayTracingPipelineCreateInfoNV, pAllocator: ptr VkAllocationCallbacks, pPipelines: ptr VkPipeline): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateRayTracingPipelinesNV"))
  vkGetRayTracingShaderGroupHandlesNV = vkGetRayTracingShaderGroupHandlesKHR
  vkGetAccelerationStructureHandleNV = cast[proc(device: VkDevice, accelerationStructure: VkAccelerationStructureNV, dataSize: csize_t, pData: pointer): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetAccelerationStructureHandleNV"))
  vkCmdWriteAccelerationStructuresPropertiesNV = cast[proc(commandBuffer: VkCommandBuffer, accelerationStructureCount: uint32, pAccelerationStructures: ptr VkAccelerationStructureNV, queryType: VkQueryType, queryPool: VkQueryPool, firstQuery: uint32): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdWriteAccelerationStructuresPropertiesNV"))
  vkCompileDeferredNV = cast[proc(device: VkDevice, pipeline: VkPipeline, shader: uint32): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCompileDeferredNV"))

# extension VK_KHR_present_wait
var
  vkWaitForPresentKHR*: proc(device: VkDevice, swapchain: VkSwapchainKHR, presentId: uint64, timeout: uint64): VkResult {.stdcall.}
proc loadVK_KHR_present_wait*(instance: VkInstance) =
  loadVK_KHR_swapchain(instance)
  loadVK_KHR_present_id(instance)
  vkWaitForPresentKHR = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR, presentId: uint64, timeout: uint64): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkWaitForPresentKHR"))

proc loadVK_NV_ray_tracing_invocation_reorder*(instance: VkInstance) =
  loadVK_KHR_ray_tracing_pipeline(instance)

var EXTENSION_LOADERS = {
  "VK_NV_optical_flow": loadVK_NV_optical_flow,
  "VK_EXT_vertex_attribute_divisor": loadVK_EXT_vertex_attribute_divisor,
  "VK_EXT_pipeline_library_group_handles": loadVK_EXT_pipeline_library_group_handles,
  "VK_NV_geometry_shader_passthrough": loadVK_NV_geometry_shader_passthrough,
  "VK_EXT_line_rasterization": loadVK_EXT_line_rasterization,
  "VK_EXT_rasterization_order_attachment_access": loadVK_EXT_rasterization_order_attachment_access,
  "VK_EXT_shader_atomic_float2": loadVK_EXT_shader_atomic_float2,
  "VK_IMG_format_pvrtc": loadVK_IMG_format_pvrtc,
  "VK_AMD_texture_gather_bias_lod": loadVK_AMD_texture_gather_bias_lod,
  "VK_KHR_shader_subgroup_uniform_control_flow": loadVK_KHR_shader_subgroup_uniform_control_flow,
  "VK_AMD_shader_fragment_mask": loadVK_AMD_shader_fragment_mask,
  "VK_EXT_external_memory_dma_buf": loadVK_EXT_external_memory_dma_buf,
  "VK_IMG_filter_cubic": loadVK_IMG_filter_cubic,
  "VK_EXT_pageable_device_local_memory": loadVK_EXT_pageable_device_local_memory,
  "VK_EXT_primitive_topology_list_restart": loadVK_EXT_primitive_topology_list_restart,
  "VK_KHR_global_priority": loadVK_KHR_global_priority,
  "VK_AMD_shader_ballot": loadVK_AMD_shader_ballot,
  "VK_AMD_buffer_marker": loadVK_AMD_buffer_marker,
  "VK_NV_corner_sampled_image": loadVK_NV_corner_sampled_image,
  "VK_NV_ray_tracing_invocation_reorder": loadVK_NV_ray_tracing_invocation_reorder,
  "VK_QCOM_image_processing": loadVK_QCOM_image_processing,
  "VK_AMD_shader_info": loadVK_AMD_shader_info,
  "VK_KHR_pipeline_library": loadVK_KHR_pipeline_library,
  "VK_EXT_blend_operation_advanced": loadVK_EXT_blend_operation_advanced,
  "VK_AMD_gpu_shader_int16": loadVK_AMD_gpu_shader_int16,
  "VK_EXT_pipeline_robustness": loadVK_EXT_pipeline_robustness,
  "VK_NV_scissor_exclusive": loadVK_NV_scissor_exclusive,
  "VK_EXT_sample_locations": loadVK_EXT_sample_locations,
  "VK_NV_framebuffer_mixed_samples": loadVK_NV_framebuffer_mixed_samples,
  "VK_NV_sample_mask_override_coverage": loadVK_NV_sample_mask_override_coverage,
  "VK_KHR_present_id": loadVK_KHR_present_id,
  "VK_EXT_descriptor_buffer": loadVK_EXT_descriptor_buffer,
  "VK_EXT_filter_cubic": loadVK_EXT_filter_cubic,
  "VK_KHR_pipeline_executable_properties": loadVK_KHR_pipeline_executable_properties,
  "VK_EXT_extended_dynamic_state3": loadVK_EXT_extended_dynamic_state3,
  "VK_KHR_performance_query": loadVK_KHR_performance_query,
  "VK_GOOGLE_user_type": loadVK_GOOGLE_user_type,
  "VK_KHR_ray_tracing_maintenance1": loadVK_KHR_ray_tracing_maintenance1,
  "VK_EXT_debug_report": loadVK_EXT_debug_report,
  "VK_EXT_multisampled_render_to_single_sampled": loadVK_EXT_multisampled_render_to_single_sampled,
  "VK_EXT_device_address_binding_report": loadVK_EXT_device_address_binding_report,
  "VK_NV_clip_space_w_scaling": loadVK_NV_clip_space_w_scaling,
  "VK_NV_fill_rectangle": loadVK_NV_fill_rectangle,
  "VK_EXT_shader_image_atomic_int64": loadVK_EXT_shader_image_atomic_int64,
  "VK_KHR_swapchain": loadVK_KHR_swapchain,
  "VK_NV_ray_tracing": loadVK_NV_ray_tracing,
  "VK_EXT_swapchain_maintenance1": loadVK_EXT_swapchain_maintenance1,
  "VK_KHR_ray_tracing_pipeline": loadVK_KHR_ray_tracing_pipeline,
  "VK_EXT_ycbcr_image_arrays": loadVK_EXT_ycbcr_image_arrays,
  "VK_AMD_negative_viewport_height": loadVK_AMD_negative_viewport_height,
  "VK_EXT_provoking_vertex": loadVK_EXT_provoking_vertex,
  "VK_EXT_calibrated_timestamps": loadVK_EXT_calibrated_timestamps,
  "VK_EXT_attachment_feedback_loop_layout": loadVK_EXT_attachment_feedback_loop_layout,
  "VK_AMD_mixed_attachment_samples": loadVK_AMD_mixed_attachment_samples,
  "VK_HUAWEI_invocation_mask": loadVK_HUAWEI_invocation_mask,
  "VK_EXT_external_memory_host": loadVK_EXT_external_memory_host,
  "VK_NV_device_diagnostics_config": loadVK_NV_device_diagnostics_config,
  "VK_EXT_fragment_density_map2": loadVK_EXT_fragment_density_map2,
  "VK_NV_shader_subgroup_partitioned": loadVK_NV_shader_subgroup_partitioned,
  "VK_EXT_image_sliced_view_of_3d": loadVK_EXT_image_sliced_view_of_3d,
  "VK_NV_fragment_shading_rate_enums": loadVK_NV_fragment_shading_rate_enums,
  "VK_EXT_display_surface_counter": loadVK_EXT_display_surface_counter,
  "VK_ARM_shader_core_properties": loadVK_ARM_shader_core_properties,
  "VK_EXT_shader_module_identifier": loadVK_EXT_shader_module_identifier,
  "VK_EXT_border_color_swizzle": loadVK_EXT_border_color_swizzle,
  "VK_AMD_shader_image_load_store_lod": loadVK_AMD_shader_image_load_store_lod,
  "VK_AMD_display_native_hdr": loadVK_AMD_display_native_hdr,
  "VK_NV_memory_decompression": loadVK_NV_memory_decompression,
  "VK_EXT_direct_mode_display": loadVK_EXT_direct_mode_display,
  "VK_EXT_fragment_shader_interlock": loadVK_EXT_fragment_shader_interlock,
  "VK_NV_coverage_reduction_mode": loadVK_NV_coverage_reduction_mode,
  "VK_KHR_get_display_properties2": loadVK_KHR_get_display_properties2,
  "VK_INTEL_shader_integer_functions2": loadVK_INTEL_shader_integer_functions2,
  "VK_NV_glsl_shader": loadVK_NV_glsl_shader,
  "VK_KHR_shader_clock": loadVK_KHR_shader_clock,
  "VK_EXT_image_2d_view_of_3d": loadVK_EXT_image_2d_view_of_3d,
  "VK_QCOM_tile_properties": loadVK_QCOM_tile_properties,
  "VK_KHR_push_descriptor": loadVK_KHR_push_descriptor,
  "VK_NV_viewport_swizzle": loadVK_NV_viewport_swizzle,
  "VK_KHR_ray_query": loadVK_KHR_ray_query,
  "VK_KHR_present_wait": loadVK_KHR_present_wait,
  "VK_NV_shading_rate_image": loadVK_NV_shading_rate_image,
  "VK_EXT_fragment_density_map": loadVK_EXT_fragment_density_map,
  "VK_NV_device_diagnostic_checkpoints": loadVK_NV_device_diagnostic_checkpoints,
  "VK_EXT_pci_bus_info": loadVK_EXT_pci_bus_info,
  "VK_NV_external_memory": loadVK_NV_external_memory,
  "VK_EXT_queue_family_foreign": loadVK_EXT_queue_family_foreign,
  "VK_KHR_swapchain_mutable_format": loadVK_KHR_swapchain_mutable_format,
  "VK_EXT_depth_clip_control": loadVK_EXT_depth_clip_control,
  "VK_EXT_debug_utils": loadVK_EXT_debug_utils,
  "VK_KHR_portability_enumeration": loadVK_KHR_portability_enumeration,
  "VK_EXT_memory_priority": loadVK_EXT_memory_priority,
  "VK_EXT_validation_flags": loadVK_EXT_validation_flags,
  "VK_AMD_shader_core_properties": loadVK_AMD_shader_core_properties,
  "VK_EXT_conservative_rasterization": loadVK_EXT_conservative_rasterization,
  "VK_KHR_external_fence_fd": loadVK_KHR_external_fence_fd,
  "VK_NV_device_generated_commands": loadVK_NV_device_generated_commands,
  "VK_NV_present_barrier": loadVK_NV_present_barrier,
  "VK_AMD_gcn_shader": loadVK_AMD_gcn_shader,
  "VK_NV_viewport_array2": loadVK_NV_viewport_array2,
  "VK_INTEL_performance_query": loadVK_INTEL_performance_query,
  "VK_NVX_multiview_per_view_attributes": loadVK_NVX_multiview_per_view_attributes,
  "VK_EXT_primitives_generated_query": loadVK_EXT_primitives_generated_query,
  "VK_AMD_pipeline_compiler_control": loadVK_AMD_pipeline_compiler_control,
  "VK_EXT_post_depth_coverage": loadVK_EXT_post_depth_coverage,
  "VK_EXT_rgba10x6_formats": loadVK_EXT_rgba10x6_formats,
  "VK_KHR_external_memory_fd": loadVK_KHR_external_memory_fd,
  "VK_NV_dedicated_allocation_image_aliasing": loadVK_NV_dedicated_allocation_image_aliasing,
  "VK_NV_cooperative_matrix": loadVK_NV_cooperative_matrix,
  "VK_EXT_depth_clamp_zero_one": loadVK_EXT_depth_clamp_zero_one,
  "VK_EXT_conditional_rendering": loadVK_EXT_conditional_rendering,
  "VK_QCOM_multiview_per_view_viewports": loadVK_QCOM_multiview_per_view_viewports,
  "VK_NV_linear_color_attachment": loadVK_NV_linear_color_attachment,
  "VK_EXT_shader_subgroup_ballot": loadVK_EXT_shader_subgroup_ballot,
  "VK_EXT_multi_draw": loadVK_EXT_multi_draw,
  "VK_NV_fragment_coverage_to_color": loadVK_NV_fragment_coverage_to_color,
  "VK_EXT_load_store_op_none": loadVK_EXT_load_store_op_none,
  "VK_QCOM_rotated_copy_commands": loadVK_QCOM_rotated_copy_commands,
  "VK_EXT_surface_maintenance1": loadVK_EXT_surface_maintenance1,
  "VK_EXT_swapchain_colorspace": loadVK_EXT_swapchain_colorspace,
  "VK_EXT_image_drm_format_modifier": loadVK_EXT_image_drm_format_modifier,
  "VK_EXT_validation_features": loadVK_EXT_validation_features,
  "VK_KHR_workgroup_memory_explicit_layout": loadVK_KHR_workgroup_memory_explicit_layout,
  "VK_EXT_index_type_uint8": loadVK_EXT_index_type_uint8,
  "VK_EXT_mesh_shader": loadVK_EXT_mesh_shader,
  "VK_AMD_shader_early_and_late_fragment_tests": loadVK_AMD_shader_early_and_late_fragment_tests,
  "VK_KHR_display_swapchain": loadVK_KHR_display_swapchain,
  "VK_EXT_transform_feedback": loadVK_EXT_transform_feedback,
  "VK_GOOGLE_decorate_string": loadVK_GOOGLE_decorate_string,
  "VK_EXT_shader_atomic_float": loadVK_EXT_shader_atomic_float,
  "VK_EXT_acquire_drm_display": loadVK_EXT_acquire_drm_display,
  "VK_EXT_pipeline_properties": loadVK_EXT_pipeline_properties,
  "VK_EXT_graphics_pipeline_library": loadVK_EXT_graphics_pipeline_library,
  "VK_KHR_acceleration_structure": loadVK_KHR_acceleration_structure,
  "VK_AMD_shader_core_properties2": loadVK_AMD_shader_core_properties2,
  "VK_KHR_surface": loadVK_KHR_surface,
  "VK_AMD_gpu_shader_half_float": loadVK_AMD_gpu_shader_half_float,
  "VK_KHR_deferred_host_operations": loadVK_KHR_deferred_host_operations,
  "VK_NV_dedicated_allocation": loadVK_NV_dedicated_allocation,
  "VK_GOOGLE_hlsl_functionality1": loadVK_GOOGLE_hlsl_functionality1,
  "VK_EXT_robustness2": loadVK_EXT_robustness2,
  "VK_NVX_image_view_handle": loadVK_NVX_image_view_handle,
  "VK_EXT_non_seamless_cube_map": loadVK_EXT_non_seamless_cube_map,
  "VK_EXT_opacity_micromap": loadVK_EXT_opacity_micromap,
  "VK_EXT_image_view_min_lod": loadVK_EXT_image_view_min_lod,
  "VK_AMD_shader_trinary_minmax": loadVK_AMD_shader_trinary_minmax,
  "VK_QCOM_render_pass_store_ops": loadVK_QCOM_render_pass_store_ops,
  "VK_EXT_device_fault": loadVK_EXT_device_fault,
  "VK_EXT_custom_border_color": loadVK_EXT_custom_border_color,
  "VK_EXT_mutable_descriptor_type": loadVK_EXT_mutable_descriptor_type,
  "VK_AMD_rasterization_order": loadVK_AMD_rasterization_order,
  "VK_EXT_vertex_input_dynamic_state": loadVK_EXT_vertex_input_dynamic_state,
  "VK_KHR_incremental_present": loadVK_KHR_incremental_present,
  "VK_KHR_fragment_shading_rate": loadVK_KHR_fragment_shading_rate,
  "VK_EXT_color_write_enable": loadVK_EXT_color_write_enable,
  "VK_SEC_amigo_profiling": loadVK_SEC_amigo_profiling,
  "VK_GOOGLE_display_timing": loadVK_GOOGLE_display_timing,
  "VK_NVX_binary_import": loadVK_NVX_binary_import,
  "VK_EXT_depth_clip_enable": loadVK_EXT_depth_clip_enable,
  "VK_EXT_subpass_merge_feedback": loadVK_EXT_subpass_merge_feedback,
  "VK_NV_representative_fragment_test": loadVK_NV_representative_fragment_test,
  "VK_EXT_validation_cache": loadVK_EXT_validation_cache,
  "VK_EXT_display_control": loadVK_EXT_display_control,
  "VK_KHR_external_semaphore_fd": loadVK_KHR_external_semaphore_fd,
  "VK_KHR_fragment_shader_barycentric": loadVK_KHR_fragment_shader_barycentric,
  "VK_NV_inherited_viewport_scissor": loadVK_NV_inherited_viewport_scissor,
  "VK_EXT_legacy_dithering": loadVK_EXT_legacy_dithering,
  "VK_NV_ray_tracing_motion_blur": loadVK_NV_ray_tracing_motion_blur,
  "VK_EXT_physical_device_drm": loadVK_EXT_physical_device_drm,
  "VK_EXT_pipeline_protected_access": loadVK_EXT_pipeline_protected_access,
  "VK_QCOM_render_pass_transform": loadVK_QCOM_render_pass_transform,
  "VK_GOOGLE_surfaceless_query": loadVK_GOOGLE_surfaceless_query,
  "VK_EXT_memory_budget": loadVK_EXT_memory_budget,
  "VK_EXT_discard_rectangles": loadVK_EXT_discard_rectangles,
  "VK_EXT_shader_stencil_export": loadVK_EXT_shader_stencil_export,
  "VK_KHR_shared_presentable_image": loadVK_KHR_shared_presentable_image,
  "VK_NV_external_memory_rdma": loadVK_NV_external_memory_rdma,
  "VK_EXT_image_compression_control_swapchain": loadVK_EXT_image_compression_control_swapchain,
  "VK_EXT_hdr_metadata": loadVK_EXT_hdr_metadata,
  "VK_AMD_device_coherent_memory": loadVK_AMD_device_coherent_memory,
  "VK_EXT_device_memory_report": loadVK_EXT_device_memory_report,
  "VK_ARM_shader_core_builtins": loadVK_ARM_shader_core_builtins,
  "VK_QCOM_multiview_per_view_render_areas": loadVK_QCOM_multiview_per_view_render_areas,
  "VK_LUNARG_direct_driver_loading": loadVK_LUNARG_direct_driver_loading,
  "VK_AMD_memory_overallocation_behavior": loadVK_AMD_memory_overallocation_behavior,
  "VK_NV_mesh_shader": loadVK_NV_mesh_shader,
  "VK_AMD_shader_explicit_vertex_parameter": loadVK_AMD_shader_explicit_vertex_parameter,
  "VK_EXT_headless_surface": loadVK_EXT_headless_surface,
  "VK_NV_shader_sm_builtins": loadVK_NV_shader_sm_builtins,
  "VK_EXT_shader_subgroup_vote": loadVK_EXT_shader_subgroup_vote,
  "VK_NV_copy_memory_indirect": loadVK_NV_copy_memory_indirect,
  "VK_EXT_image_compression_control": loadVK_EXT_image_compression_control,
  "VK_EXT_astc_decode_mode": loadVK_EXT_astc_decode_mode,
  "VK_EXT_buffer_device_address": loadVK_EXT_buffer_device_address,
  "VK_KHR_get_surface_capabilities2": loadVK_KHR_get_surface_capabilities2,
  "VK_KHR_display": loadVK_KHR_display,
  "VK_QCOM_render_pass_shader_resolve": loadVK_QCOM_render_pass_shader_resolve,
  "VK_EXT_depth_range_unrestricted": loadVK_EXT_depth_range_unrestricted,
  "VK_HUAWEI_subpass_shading": loadVK_HUAWEI_subpass_shading,
  "VK_VALVE_descriptor_set_host_mapping": loadVK_VALVE_descriptor_set_host_mapping,
  "VK_HUAWEI_cluster_culling_shader": loadVK_HUAWEI_cluster_culling_shader,
  "VK_KHR_surface_protected_capabilities": loadVK_KHR_surface_protected_capabilities,
  "VK_NV_shader_image_footprint": loadVK_NV_shader_image_footprint,
  "VK_NV_external_memory_capabilities": loadVK_NV_external_memory_capabilities,
  "VK_NV_compute_shader_derivatives": loadVK_NV_compute_shader_derivatives,
  "VK_QCOM_fragment_density_map_offset": loadVK_QCOM_fragment_density_map_offset,
}.toTable
when defined(VK_USE_PLATFORM_XLIB_KHR):
  include ../vulkan/platform/xlib
  EXTENSION_LOADERS["VK_KHR_xlib_surface"] = loadVK_KHR_xlib_surface
when defined(VK_USE_PLATFORM_XLIB_XRANDR_EXT):
  include ../vulkan/platform/xlib_xrandr
  EXTENSION_LOADERS["VK_EXT_acquire_xlib_display"] = loadVK_EXT_acquire_xlib_display
when defined(VK_USE_PLATFORM_XCB_KHR):
  include ../vulkan/platform/xcb
  EXTENSION_LOADERS["VK_KHR_xcb_surface"] = loadVK_KHR_xcb_surface
when defined(VK_USE_PLATFORM_WAYLAND_KHR):
  include ../vulkan/platform/wayland
  EXTENSION_LOADERS["VK_KHR_wayland_surface"] = loadVK_KHR_wayland_surface
when defined(VK_USE_PLATFORM_DIRECTFB_EXT):
  include ../vulkan/platform/directfb
  EXTENSION_LOADERS["VK_EXT_directfb_surface"] = loadVK_EXT_directfb_surface
when defined(VK_USE_PLATFORM_ANDROID_KHR):
  include ../vulkan/platform/android
  EXTENSION_LOADERS["VK_KHR_android_surface"] = loadVK_KHR_android_surface
  EXTENSION_LOADERS["VK_ANDROID_external_memory_android_hardware_buffer"] = loadVK_ANDROID_external_memory_android_hardware_buffer
when defined(VK_USE_PLATFORM_WIN32_KHR):
  include ../vulkan/platform/win32
  EXTENSION_LOADERS["VK_KHR_external_semaphore_win32"] = loadVK_KHR_external_semaphore_win32
  EXTENSION_LOADERS["VK_EXT_full_screen_exclusive"] = loadVK_EXT_full_screen_exclusive
  EXTENSION_LOADERS["VK_NV_external_memory_win32"] = loadVK_NV_external_memory_win32
  EXTENSION_LOADERS["VK_KHR_external_memory_win32"] = loadVK_KHR_external_memory_win32
  EXTENSION_LOADERS["VK_NV_acquire_winrt_display"] = loadVK_NV_acquire_winrt_display
  EXTENSION_LOADERS["VK_KHR_win32_surface"] = loadVK_KHR_win32_surface
  EXTENSION_LOADERS["VK_KHR_external_fence_win32"] = loadVK_KHR_external_fence_win32
  EXTENSION_LOADERS["VK_KHR_win32_keyed_mutex"] = loadVK_KHR_win32_keyed_mutex
when defined(VK_USE_PLATFORM_VI_NN):
  include ../vulkan/platform/vi
  EXTENSION_LOADERS["VK_NN_vi_surface"] = loadVK_NN_vi_surface
when defined(VK_USE_PLATFORM_IOS_MVK):
  include ../vulkan/platform/ios
  EXTENSION_LOADERS["VK_MVK_ios_surface"] = loadVK_MVK_ios_surface
when defined(VK_USE_PLATFORM_MACOS_MVK):
  include ../vulkan/platform/macos
  EXTENSION_LOADERS["VK_MVK_macos_surface"] = loadVK_MVK_macos_surface
when defined(VK_USE_PLATFORM_METAL_EXT):
  include ../vulkan/platform/metal
  EXTENSION_LOADERS["VK_EXT_metal_objects"] = loadVK_EXT_metal_objects
  EXTENSION_LOADERS["VK_EXT_metal_surface"] = loadVK_EXT_metal_surface
when defined(VK_USE_PLATFORM_FUCHSIA):
  include ../vulkan/platform/fuchsia
  EXTENSION_LOADERS["VK_FUCHSIA_external_semaphore"] = loadVK_FUCHSIA_external_semaphore
  EXTENSION_LOADERS["VK_FUCHSIA_imagepipe_surface"] = loadVK_FUCHSIA_imagepipe_surface
  EXTENSION_LOADERS["VK_FUCHSIA_external_memory"] = loadVK_FUCHSIA_external_memory
  EXTENSION_LOADERS["VK_FUCHSIA_buffer_collection"] = loadVK_FUCHSIA_buffer_collection
when defined(VK_USE_PLATFORM_GGP):
  include ../vulkan/platform/ggp
  EXTENSION_LOADERS["VK_GGP_frame_token"] = loadVK_GGP_frame_token
  EXTENSION_LOADERS["VK_GGP_stream_descriptor_surface"] = loadVK_GGP_stream_descriptor_surface
when defined(VK_USE_PLATFORM_SCI):
  include ../vulkan/platform/sci
when defined(VK_ENABLE_BETA_EXTENSIONS):
  include ../vulkan/platform/provisional
  EXTENSION_LOADERS["VK_KHR_video_encode_queue"] = loadVK_KHR_video_encode_queue
  EXTENSION_LOADERS["VK_KHR_video_queue"] = loadVK_KHR_video_queue
  EXTENSION_LOADERS["VK_EXT_video_encode_h264"] = loadVK_EXT_video_encode_h264
  EXTENSION_LOADERS["VK_EXT_video_encode_h265"] = loadVK_EXT_video_encode_h265
  EXTENSION_LOADERS["VK_KHR_video_decode_queue"] = loadVK_KHR_video_decode_queue
  EXTENSION_LOADERS["VK_KHR_video_decode_h264"] = loadVK_KHR_video_decode_h264
  EXTENSION_LOADERS["VK_KHR_portability_subset"] = loadVK_KHR_portability_subset
  EXTENSION_LOADERS["VK_KHR_video_decode_h265"] = loadVK_KHR_video_decode_h265
when defined(VK_USE_PLATFORM_SCREEN_QNX):
  include ../vulkan/platform/screen
  EXTENSION_LOADERS["VK_QNX_screen_surface"] = loadVK_QNX_screen_surface

proc loadExtension*(instance: VkInstance, extension: string) =
  if extension in EXTENSION_LOADERS:
    EXTENSION_LOADERS[extension](instance)

# load global functions immediately
block globalFunctions:
  let instance = VkInstance(0)
  vkEnumerateInstanceVersion = cast[proc(pApiVersion: ptr uint32): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumerateInstanceVersion"))
  vkEnumerateInstanceExtensionProperties = cast[proc(pLayerName: cstring, pPropertyCount: ptr uint32, pProperties: ptr VkExtensionProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumerateInstanceExtensionProperties"))
  vkEnumerateInstanceLayerProperties = cast[proc(pPropertyCount: ptr uint32, pProperties: ptr VkLayerProperties): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkEnumerateInstanceLayerProperties"))
  vkCreateInstance = cast[proc(pCreateInfo: ptr VkInstanceCreateInfo, pAllocator: ptr VkAllocationCallbacks, pInstance: ptr VkInstance): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateInstance"))

converter NimBool2VkBool*(a: bool): VkBool32 = VkBool32(a)
