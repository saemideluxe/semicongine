import std/logging
import std/enumerate
import std/hashes
import std/macros
import std/os
import std/sequtils
import std/strformat
import std/strutils
import std/typetraits

import ./rendering/vulkan/api

import ./image

# in this file:
# - const defintions for rendering
# - custom pragma defintions for rendering
# - type defintions for rendering
# - some utils code that is used in mutiple rendering files
# - inclusion of all rendering files

# const definitions
const INFLIGHTFRAMES* = 2'u32
const BUFFER_ALIGNMENT = 64'u64 # align offsets inside buffers along this alignment
const MEMORY_BLOCK_ALLOCATION_SIZE = 100_000_000'u64
  # ca. 100mb per block, seems reasonable
const BUFFER_ALLOCATION_SIZE = 9_000_000'u64
  # ca. 9mb per block, seems reasonable, can put 10 buffers into one memory block
const MAX_DESCRIPTORSETS = 4
const SURFACE_FORMAT* = VK_FORMAT_B8G8R8A8_SRGB
const DEPTH_FORMAT* = VK_FORMAT_D32_SFLOAT
const PUSH_CONSTANT_SIZE = 128

# custom pragmas to classify shader attributes
type DescriptorSetIndex = range[0 .. MAX_DESCRIPTORSETS - 1]
template VertexAttribute*() {.pragma.}
template InstanceAttribute*() {.pragma.}
template PushConstant*() {.pragma.}
template Pass*() {.pragma.}
template PassFlat*() {.pragma.}
template ShaderOutput*() {.pragma.}
template DescriptorSet*(index: DescriptorSetIndex) {.pragma.}

# there is a big, bad global vulkan object
# believe me, this makes everything much, much easier

when defined(windows):
  include ./rendering/platform/windows
when defined(linux):
  include ./rendering/platform/linux

type
  # type aliases
  SupportedGPUType =
    float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 |
    TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] |
    TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] |
    TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] |
    TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] |
    TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] |
    TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[
      float32
    ] | TMat43[float64] | TMat4[float32] | TMat4[float64]

  VulkanGlobals* = object # populated through InitVulkan proc
    instance*: VkInstance
    device*: VkDevice
    physicalDevice*: VkPhysicalDevice
    surface: VkSurfaceKHR
    window*: NativeWindow
    graphicsQueueFamily*: uint32
    graphicsQueue*: VkQueue
    debugMessenger: VkDebugUtilsMessengerEXT
    # populated through the initSwapchain proc
    swapchain*: Swapchain
    # unclear as of yet
    anisotropy*: float32 = 0 # needs to be enable during device creation

  RenderPass* = ref object
    vk*: VkRenderPass
    samples*: VkSampleCountFlagBits
    depthBuffer*: bool

  Swapchain* = ref object
    # parameters to initSwapchain, required for swapchain recreation
    renderPass*: RenderPass
    vSync*: bool
    # populated through initSwapchain proc
    vk: VkSwapchainKHR
    width*: uint32
    height*: uint32
    framebuffers: seq[VkFramebuffer]
    framebufferViews: seq[VkImageView]
    currentFramebufferIndex: uint32
    commandBufferPool: VkCommandPool
    # depth buffer stuff, if enabled
    depthImage: VkImage
    depthImageView*: VkImageView
    depthMemory: VkDeviceMemory
    # MSAA stuff, if enabled
    msaaImage: VkImage
    msaaImageView*: VkImageView
    msaaMemory: VkDeviceMemory
    # frame-in-flight handling
    currentFiF: range[0 .. (INFLIGHTFRAMES - 1).int]
    queueFinishedFence*: array[INFLIGHTFRAMES.int, VkFence]
    imageAvailableSemaphore*: array[INFLIGHTFRAMES.int, VkSemaphore]
    renderFinishedSemaphore*: array[INFLIGHTFRAMES.int, VkSemaphore]
    commandBuffers: array[INFLIGHTFRAMES.int, VkCommandBuffer]
    oldSwapchain: Swapchain
    oldSwapchainCounter: int # swaps until old swapchain will be destroyed

  # shader related types
  DescriptorSetData*[T: object] = object
    data*: T
    vk: array[INFLIGHTFRAMES.int, VkDescriptorSet]

  Pipeline*[TShader] = object
    vk: VkPipeline
    vertexShaderModule: VkShaderModule
    fragmentShaderModule: VkShaderModule
    layout: VkPipelineLayout
    descriptorSetLayouts*: array[MAX_DESCRIPTORSETS, VkDescriptorSetLayout]

  # memory/buffer related types
  BufferType* = enum
    VertexBuffer
    VertexBufferMapped
    IndexBuffer
    IndexBufferMapped
    UniformBuffer
    UniformBufferMapped

  MemoryBlock* = object
    vk: VkDeviceMemory
    size: uint64
    rawPointer: pointer # if not nil, this is mapped memory
    offsetNextFree: uint64

  Buffer* = object
    vk: VkBuffer
    size: uint64
    rawPointer: pointer # if not nil, buffer is using mapped memory
    offsetNextFree: uint64
    memoryOffset: uint64
    memory: VkDeviceMemory

  GPUArray*[T: SupportedGPUType, TBuffer: static BufferType] = object
    # TODO: when using mapped buffer memory, directly write values to mapped location
    # instead of using data as buffer
    data*: seq[T]
    buffer*: Buffer
    offset*: uint64

  GPUValue*[T: object, TBuffer: static BufferType] = object
    data*: T
    buffer*: Buffer
    offset: uint64

  GPUData* = GPUArray | GPUValue

  RenderDataObject = object
    descriptorPool: VkDescriptorPool
    memory: array[VK_MAX_MEMORY_TYPES.int, seq[MemoryBlock]]
    buffers: array[BufferType, seq[Buffer]]
    images: seq[VkImage]
    imageViews: seq[VkImageView]
    samplers: seq[VkSampler]

  RenderData* = ref RenderDataObject

var vulkan* = VulkanGlobals()
var fullscreen_internal: bool

proc `=copy`(dest: var VulkanGlobals, source: VulkanGlobals) {.error.}
proc `=copy`(dest: var RenderDataObject, source: RenderDataObject) {.error.}
proc `=copy`[T, S](dest: var GPUValue[T, S], source: GPUValue[T, S]) {.error.}
proc `=copy`[T, S](dest: var GPUArray[T, S], source: GPUArray[T, S]) {.error.}
proc `=copy`(dest: var MemoryBlock, source: MemoryBlock) {.error.}
proc `=copy`[T](dest: var Pipeline[T], source: Pipeline[T]) {.error.}
proc `=copy`[T](dest: var DescriptorSetData[T], source: DescriptorSetData[T]) {.error.}

proc `[]`*[T, S](a: GPUArray[T, S], i: SomeInteger): T =
  a.data[i]

proc `[]=`*[T, S](a: var GPUArray[T, S], i: SomeInteger, value: T) =
  a.data[i] = value

template forDescriptorFields(
    shader: typed, valuename, typename, countname, bindingNumber, body: untyped
): untyped =
  var `bindingNumber` {.inject.} = 0'u32
  for theFieldname, `valuename` in fieldPairs(shader):
    when typeof(`valuename`) is ImageObject:
      block:
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        const `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(`valuename`) is GPUValue:
      block:
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        const `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(`valuename`) is array:
      when elementType(`valuename`) is ImageObject:
        block:
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
          const `countname` {.inject.} = uint32(typeof(`valuename`).len)
          body
          `bindingNumber`.inc
      elif elementType(`valuename`) is GPUValue:
        block:
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
          const `countname` {.inject.} = len(`valuename`).uint32
          body
          `bindingNumber`.inc
      else:
        {.
          error: "Unsupported descriptor type: " & typetraits.name(typeof(`valuename`))
        .}
    else:
      {.error: "Unsupported descriptor type: " & typetraits.name(typeof(`valuename`)).}

proc currentFiF*(): int =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  vulkan.swapchain.currentFiF

include ./rendering/vulkan_wrappers
include ./rendering/renderpasses
include ./rendering/swapchain
include ./rendering/shaders
include ./rendering/renderer

proc debugCallback(
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
    userData: pointer,
): VkBool32 {.cdecl.} =
  const LOG_LEVEL_MAPPING = {
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT: lvlDebug,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT: lvlInfo,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT: lvlWarn,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT: lvlError,
  }.toTable
  log LOG_LEVEL_MAPPING[messageSeverity],
    &"{toEnums messageTypes}: {pCallbackData.pMessage}"
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    stderr.writeLine "-----------------------------------"
    stderr.write getStackTrace()
    stderr.writeLine LOG_LEVEL_MAPPING[messageSeverity],
      &"{toEnums messageTypes}: {pCallbackData.pMessage}"
    stderr.writeLine "-----------------------------------"
    let errorMsg =
      getStackTrace() & &"\n{toEnums messageTypes}: {pCallbackData.pMessage}"
    raise newException(Exception, errorMsg)
  return false

proc initVulkan*(appName: string = "semicongine app") =
  # instance creation

  # enagle all kind of debug stuff
  when not defined(release):
    let requiredExtensions =
      REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface", "VK_EXT_debug_utils"]
    let layers: seq[string] =
      if hasValidationLayer():
        @["VK_LAYER_KHRONOS_validation"]
      else:
        @[]
    putEnv(
      "VK_LAYER_ENABLES",
      "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT",
    )
  else:
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface"]
    let layers: seq[string] = @[]

  var
    layersC = allocCStringArray(layers)
    instanceExtensionsC = allocCStringArray(requiredExtensions)
  defer:
    deallocCStringArray(layersC)
    deallocCStringArray(instanceExtensionsC)

  var
    appinfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: appName,
      pEngineName: "semicongine",
      apiVersion: VK_MAKE_API_VERSION(0, 1, 3, 0),
    )
    createinfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: addr(appinfo),
      enabledLayerCount: layers.len.uint32,
      ppEnabledLayerNames: layersC,
      enabledExtensionCount: requiredExtensions.len.uint32,
      ppEnabledExtensionNames: instanceExtensionsC,
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(vulkan.instance))
  loadVulkan(vulkan.instance)

  # load extensions
  #
  for extension in requiredExtensions:
    loadExtension(vulkan.instance, $extension)
  vulkan.window = createWindow(appName)
  vulkan.surface = createNativeSurface(vulkan.instance, vulkan.window)

  # logical device creation

  # TODO: allowing support for physical devices without hasUniformBufferStandardLayout
  # would require us to ship different shaders, so we don't support standard layout
  # if that will be added, check the function vulkan/shaders.nim:glslUniforms and update accordingly
  # let hasUniformBufferStandardLayout = "VK_KHR_uniform_buffer_standard_layout" in physicalDevice.getExtensions()
  # var deviceExtensions  = @["VK_KHR_swapchain", "VK_KHR_uniform_buffer_standard_layout"]
  var deviceExtensions = @["VK_KHR_swapchain"]
  for extension in deviceExtensions:
    loadExtension(vulkan.instance, extension)

  when not defined(release):
    var debugMessengerCreateInfo = VkDebugUtilsMessengerCreateInfoEXT(
      sType: VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
      messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT.items.toSeq.toBits,
      messageType: VkDebugUtilsMessageTypeFlagBitsEXT.items.toSeq.toBits,
      pfnUserCallback: debugCallback,
      pUserData: nil,
    )
    checkVkResult vkCreateDebugUtilsMessengerEXT(
      vulkan.instance, addr(debugMessengerCreateInfo), nil, addr(vulkan.debugMessenger)
    )

  # get physical device and graphics queue family
  vulkan.physicalDevice = getBestPhysicalDevice(vulkan.instance)
  vulkan.graphicsQueueFamily =
    getQueueFamily(vulkan.physicalDevice, VK_QUEUE_GRAPHICS_BIT)

  let
    priority = cfloat(1)
    queueInfo = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: vulkan.graphicsQueueFamily,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )
    deviceExtensionsC = allocCStringArray(deviceExtensions)
  defer:
    deallocCStringArray(deviceExtensionsC)
  let enabledFeatures = VkPhysicalDeviceFeatures(
    fillModeNonSolid: true, depthClamp: true, wideLines: true, largePoints: true
  )
  var createDeviceInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    queueCreateInfoCount: 1,
    pQueueCreateInfos: addr(queueInfo),
    enabledLayerCount: 0,
    ppEnabledLayerNames: nil,
    enabledExtensionCount: uint32(deviceExtensions.len),
    ppEnabledExtensionNames: deviceExtensionsC,
    pEnabledFeatures: addr(enabledFeatures),
  )
  checkVkResult vkCreateDevice(
    physicalDevice = vulkan.physicalDevice,
    pCreateInfo = addr createDeviceInfo,
    pAllocator = nil,
    pDevice = addr vulkan.device,
  )
  vulkan.graphicsQueue =
    svkGetDeviceQueue(vulkan.device, vulkan.graphicsQueueFamily, VK_QUEUE_GRAPHICS_BIT)

proc clearSwapchain*() =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  destroySwapchain(vulkan.swapchain)
  vulkan.swapchain = nil

proc setupSwapchain*(renderPass: RenderPass, vSync: bool = false) =
  assert vulkan.swapchain == nil, "Swapchain has already been initialized yet"
  vulkan.swapchain = initSwapchain(renderPass, vSync = vSync)

proc destroyVulkan*() =
  if vulkan.swapchain != nil:
    destroySwapchain(vulkan.swapchain)
  vkDestroyDevice(vulkan.device, nil)
  vkDestroySurfaceKHR(vulkan.instance, vulkan.surface, nil)
  if vulkan.debugMessenger.Valid:
    vkDestroyDebugUtilsMessengerEXT(vulkan.instance, vulkan.debugMessenger, nil)
  vkDestroyInstance(vulkan.instance, nil)

proc showSystemCursor*(value: bool) =
  vulkan.window.showSystemCursor(value)

proc fullscreen*(): bool =
  fullscreen_internal

proc setFullscreen*(enable: bool) =
  if enable != fullscreen_internal:
    fullscreen_internal = enable
    vulkan.window.setFullscreen(fullscreen_internal)

proc getAspectRatio*(): float32 =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  vulkan.swapchain.width.float32 / vulkan.swapchain.height.float32

proc maxFramebufferSampleCount*(
    maxSamples = VK_SAMPLE_COUNT_8_BIT
): VkSampleCountFlagBits =
  let limits = svkGetPhysicalDeviceProperties().limits
  let available = VkSampleCountFlags(
    limits.framebufferColorSampleCounts.uint32 and
      limits.framebufferDepthSampleCounts.uint32
  ).toEnums
  return min(max(available), maxSamples)
