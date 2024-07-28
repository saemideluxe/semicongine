# in this file:
# - const defintions for rendering
# - custom pragma defintions for rendering
# - type defintions for rendering
# - some utils code that is used in mutiple rendering files
# - inclusion of all rendering files


# const definitions
const INFLIGHTFRAMES* = 2'u32
const BUFFER_ALIGNMENT = 64'u64 # align offsets inside buffers along this alignment
const MEMORY_BLOCK_ALLOCATION_SIZE = 100_000_000'u64 # ca. 100mb per block, seems reasonable
const BUFFER_ALLOCATION_SIZE = 9_000_000'u64 # ca. 9mb per block, seems reasonable, can put 10 buffers into one memory block
const MAX_DESCRIPTORSETS = 4
const SURFACE_FORMAT* = VK_FORMAT_B8G8R8A8_SRGB
const DEPTH_FORMAT* = VK_FORMAT_D32_SFLOAT
const PUSH_CONSTANT_SIZE = 128

# custom pragmas to classify shader attributes
template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}
template PushConstantAttribute* {.pragma.}
template Pass* {.pragma.}
template PassFlat* {.pragma.}
template ShaderOutput* {.pragma.}
template DescriptorSets* {.pragma.}

# there is a big, bad global vulkan object
# believe me, this makes everything much, much easier

when defined(windows):
  include ./rendering/platform/windows
when defined(linux):
  include ./rendering/platform/linux

type
  VulkanGlobals* = object
    # populated through InitVulkan proc
    instance*: VkInstance
    device*: VkDevice
    physicalDevice*: VkPhysicalDevice
    surface: VkSurfaceKHR
    window: NativeWindow
    graphicsQueueFamily*: uint32
    graphicsQueue*: VkQueue
    debugMessenger: VkDebugUtilsMessengerEXT
    # populated through the InitSwapchain proc
    swapchain*: Swapchain
    # unclear as of yet
    anisotropy*: float32 = 0 # needs to be enable during device creation
  Renderpass* = ref object
    vk*: VkRenderPass
    samples*: VkSampleCountFlagBits
    depthBuffer*: bool
  Swapchain* = ref object
    # parameters to InitSwapchain, required for swapchain recreation
    renderPass*: RenderPass
    vSync: bool
    # populated through InitSwapchain proc
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

var vulkan*: VulkanGlobals
var fullscreen: bool

type
  # type aliases
  SupportedGPUType = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]

  # shader related types
  DescriptorSet*[T: object] = object
    data*: T
    vk: array[INFLIGHTFRAMES.int, VkDescriptorSet]
  Pipeline*[TShader] = object
    vk: VkPipeline
    vertexShaderModule: VkShaderModule
    fragmentShaderModule: VkShaderModule
    layout: VkPipelineLayout
    descriptorSetLayouts*: array[MAX_DESCRIPTORSETS, VkDescriptorSetLayout]

  # memory/buffer related types
  MemoryBlock* = object
    vk: VkDeviceMemory
    size: uint64
    rawPointer: pointer # if not nil, this is mapped memory
    offsetNextFree: uint64
  BufferType* = enum
    VertexBuffer
    VertexBufferMapped
    IndexBuffer
    IndexBufferMapped
    UniformBuffer
    UniformBufferMapped
  Buffer* = object
    vk: VkBuffer
    size: uint64
    rawPointer: pointer # if not nil, buffer is using mapped memory
    offsetNextFree: uint64
    memoryOffset: uint64
    memory: VkDeviceMemory
  GPUArray*[T: SupportedGPUType, TBuffer: static BufferType] = object
    data*: seq[T]
    buffer*: Buffer
    offset*: uint64
  GPUValue*[T: object, TBuffer: static BufferType] = object
    data*: T
    buffer*: Buffer
    offset: uint64
  GPUData = GPUArray | GPUValue

  RenderData* = object
    descriptorPool: VkDescriptorPool
    memory: array[VK_MAX_MEMORY_TYPES.int, seq[MemoryBlock]]
    buffers: array[BufferType, seq[Buffer]]
    images: seq[VkImage]
    imageViews: seq[VkImageView]
    samplers: seq[VkSampler]

template ForDescriptorFields(shader: typed, fieldname, valuename, typename, countname, bindingNumber, body: untyped): untyped =
  var `bindingNumber` {.inject.} = 0'u32
  for theFieldname, value in fieldPairs(shader):
    when typeof(value) is Image:
      block:
        const `fieldname` {.inject.} = theFieldname
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        const `countname` {.inject.} = 1'u32
        let `valuename` {.inject.} = value
        body
        `bindingNumber`.inc
    elif typeof(value) is GPUValue:
      block:
        const `fieldname` {.inject.} = theFieldname
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        const `countname` {.inject.} = 1'u32
        let `valuename` {.inject.} = value
        body
        `bindingNumber`.inc
    elif typeof(value) is array:
      when elementType(value) is Image:
        block:
          const `fieldname` {.inject.} = theFieldname
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
          const `countname` {.inject.} = uint32(typeof(value).len)
          let `valuename` {.inject.} = value
          body
          `bindingNumber`.inc
      elif elementType(value) is GPUValue:
        block:
          const `fieldname` {.inject.} = theFieldname
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
          const `countname` {.inject.} = len(value).uint32
          let `valuename` {.inject.} = value
          body
          `bindingNumber`.inc
      else:
        {.error: "Unsupported descriptor type: " & typetraits.name(typeof(value)).}
    else:
      {.error: "Unsupported descriptor type: " & typetraits.name(typeof(value)).}

include ./rendering/vulkan_wrappers
include ./rendering/renderpasses
include ./rendering/swapchain
include ./rendering/shaders
include ./rendering/renderer

proc debugCallback(
  messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
  messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
  pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
  userData: pointer
): VkBool32 {.cdecl.} =
  const LOG_LEVEL_MAPPING = {
      VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT: lvlDebug,
      VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT: lvlInfo,
      VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT: lvlWarn,
      VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT: lvlError,
  }.toTable
  log LOG_LEVEL_MAPPING[messageSeverity], &"{toEnums messageTypes}: {pCallbackData.pMessage}"
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    stderr.writeLine "-----------------------------------"
    stderr.write getStackTrace()
    stderr.writeLine LOG_LEVEL_MAPPING[messageSeverity], &"{toEnums messageTypes}: {pCallbackData.pMessage}"
    stderr.writeLine "-----------------------------------"
    let errorMsg = getStackTrace() & &"\n{toEnums messageTypes}: {pCallbackData.pMessage}"
    raise newException(Exception, errorMsg)
  return false

proc InitVulkan*(appName: string = "semicongine app") =

  # instance creation

  # enagle all kind of debug stuff
  when not defined(release):
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface", "VK_EXT_debug_utils"]
    let layers: seq[string] = if hasValidationLayer(): @["VK_LAYER_KHRONOS_validation"] else: @[]
    putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")
  else:
    let requiredExtensions = REQUIRED_PLATFORM_EXTENSIONS & @["VK_KHR_surface"]
    let layers: seq[string]

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
      ppEnabledExtensionNames: instanceExtensionsC
    )
  checkVkResult vkCreateInstance(addr(createinfo), nil, addr(vulkan.instance))
  loadVulkan(vulkan.instance)

  # load extensions
  #
  for extension in requiredExtensions:
    loadExtension(vulkan.instance, $extension)
  vulkan.window = CreateWindow(appName)
  vulkan.surface = CreateNativeSurface(vulkan.instance, vulkan.window)

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
      vulkan.instance,
      addr(debugMessengerCreateInfo),
      nil,
      addr(vulkan.debugMessenger)
    )

  # get physical device and graphics queue family
  vulkan.physicalDevice = GetBestPhysicalDevice(vulkan.instance)
  vulkan.graphicsQueueFamily = GetQueueFamily(vulkan.physicalDevice, VK_QUEUE_GRAPHICS_BIT)

  let
    priority = cfloat(1)
    queueInfo = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: vulkan.graphicsQueueFamily,
      queueCount: 1,
      pQueuePriorities: addr(priority),
    )
    deviceExtensionsC = allocCStringArray(deviceExtensions)
  defer: deallocCStringArray(deviceExtensionsC)
  let enabledFeatures = VkPhysicalDeviceFeatures(
   fillModeNonSolid: true,
   depthClamp: true,
   wideLines: true,
   largePoints: true,
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
    pDevice = addr vulkan.device
  )
  vulkan.graphicsQueue = svkGetDeviceQueue(vulkan.device, vulkan.graphicsQueueFamily, VK_QUEUE_GRAPHICS_BIT)

proc ClearSwapchain*() =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  DestroySwapchain(vulkan.swapchain)
  vulkan.swapchain = nil

proc SetupSwapchain*(renderPass: RenderPass, vSync: bool = false) =
  assert vulkan.swapchain == nil, "Swapchain has already been initialized yet"
  vulkan.swapchain = InitSwapchain(renderPass, vSync = vSync)

proc DestroyVulkan*() =
  if vulkan.swapchain != nil:
    DestroySwapchain(vulkan.swapchain)
  vkDestroyDevice(vulkan.device, nil)
  vkDestroySurfaceKHR(vulkan.instance, vulkan.surface, nil)
  vkDestroyDebugUtilsMessengerEXT(vulkan.instance, vulkan.debugMessenger, nil)
  vkDestroyInstance(vulkan.instance, nil)

proc ShowSystemCursor*(value: bool) = vulkan.window.ShowSystemCursor(value)
proc Fullscreen*(): bool = fullscreen
proc SetFullscreen*(enable: bool) =
  if enable != fullscreen:
    fullscreen = enable
    vulkan.window.SetFullscreen(fullscreen)

proc GetAspectRatio*(): float32 =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  vulkan.swapchain.width.float32 / vulkan.swapchain.height.float32

proc currentFiF*(): int =
  assert vulkan.swapchain != nil, "Swapchain has not been initialized yet"
  vulkan.swapchain.currentFiF

proc MaxFramebufferSampleCount*(maxSamples = VK_SAMPLE_COUNT_8_BIT): VkSampleCountFlagBits =
  let limits = svkGetPhysicalDeviceProperties().limits
  let available = VkSampleCountFlags(
    limits.framebufferColorSampleCounts.uint32 and limits.framebufferDepthSampleCounts.uint32
  ).toEnums
  return min(max(available), maxSamples)


proc `[]`*(image: Image, x, y: uint32): auto =
  assert x < image.width, &"{x} < {image.width} is not true"
  assert y < image.height, &"{y} < {image.height} is not true"

  image.data[y * image.width + x]

proc `[]=`*[T](image: var Image[T], x, y: uint32, value: T) =
  assert x < image.width
  assert y < image.height

  image.data[y * image.width + x] = value
