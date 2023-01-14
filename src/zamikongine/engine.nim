import std/times
import std/typetraits
import std/strformat
import std/enumerate
import std/logging


import ./vulkan
import ./vulkan_helpers
import ./window
import ./events
import ./shader
import ./vertex
import ./buffer
import ./thing
import ./mesh
import ./descriptor

const MAX_FRAMES_IN_FLIGHT = 2
const DEBUG_LOG = not defined(release)

var logger = newConsoleLogger()
addHandler(logger)


const VULKAN_VERSION = VK_MAKE_API_VERSION(0'u32, 1'u32, 2'u32, 0'u32)

type
  Device = object
    device: VkDevice
    physicalDevice: PhysicalDevice
    graphicsQueueFamily: uint32
    presentationQueueFamily: uint32
    graphicsQueue: VkQueue
    presentationQueue: VkQueue
  Swapchain = object
    swapchain: VkSwapchainKHR
    images: seq[VkImage]
    imageviews: seq[VkImageView]
  RenderPipeline[T] = object
    device*: VkDevice
    shaders*: seq[ShaderProgram[T]]
    layout*: VkPipelineLayout
    pipeline*: VkPipeline
    uniformLayout*: VkDescriptorSetLayout
    vertexBuffers*: seq[(seq[Buffer], uint32)]
    indexedVertexBuffers*: seq[(seq[Buffer], Buffer, uint32, VkIndexType)]
    uniformBuffers*: array[MAX_FRAMES_IN_FLIGHT, Buffer]
  QueueFamily = object
    properties*: VkQueueFamilyProperties
    hasSurfaceSupport*: bool
  PhysicalDevice = object
    device*: VkPhysicalDevice
    extensions*: seq[string]
    properties*: VkPhysicalDeviceProperties
    features*: VkPhysicalDeviceFeatures
    queueFamilies*: seq[QueueFamily]
    formats: seq[VkSurfaceFormatKHR]
    presentModes: seq[VkPresentModeKHR]
  Vulkan* = object
    debugMessenger*: VkDebugUtilsMessengerEXT
    instance*: VkInstance
    deviceList*: seq[PhysicalDevice]
    device*: Device
    surface*: VkSurfaceKHR
    surfaceFormat*: VkSurfaceFormatKHR
    frameDimension*: VkExtent2D
    swapchain*: Swapchain
    framebuffers*: seq[VkFramebuffer]
    renderPass*: VkRenderPass
    commandPool*: VkCommandPool
    commandBuffers*: array[MAX_FRAMES_IN_FLIGHT, VkCommandBuffer]
    imageAvailableSemaphores*: array[MAX_FRAMES_IN_FLIGHT, VkSemaphore]
    renderFinishedSemaphores*: array[MAX_FRAMES_IN_FLIGHT, VkSemaphore]
    inFlightFences*: array[MAX_FRAMES_IN_FLIGHT, VkFence]
  Engine* = object
    vulkan*: Vulkan
    window*: NativeWindow
    currentscenedata*: ref Thing

proc getAllPhysicalDevices(instance: VkInstance, surface: VkSurfaceKHR): seq[PhysicalDevice] =
  for vulkanPhysicalDevice in getVulkanPhysicalDevices(instance):
    var device = PhysicalDevice(device: vulkanPhysicalDevice, extensions: getDeviceExtensions(vulkanPhysicalDevice))
    vkGetPhysicalDeviceProperties(vulkanPhysicalDevice, addr(device.properties))
    vkGetPhysicalDeviceFeatures(vulkanPhysicalDevice, addr(device.features))
    device.formats = vulkanPhysicalDevice.getDeviceSurfaceFormats(surface)
    device.presentModes = vulkanPhysicalDevice.getDeviceSurfacePresentModes(surface)

    debug(&"Physical device nr {int(vulkanPhysicalDevice)} {cleanString(device.properties.deviceName)}")
    for i, queueFamilyProperty in enumerate(getQueueFamilies(vulkanPhysicalDevice)):
      var hasSurfaceSupport: VkBool32 = VK_FALSE
      checkVkResult vkGetPhysicalDeviceSurfaceSupportKHR(vulkanPhysicalDevice, uint32(i), surface, addr(hasSurfaceSupport))
      device.queueFamilies.add(QueueFamily(properties: queueFamilyProperty, hasSurfaceSupport: bool(hasSurfaceSupport)))
      debug(&"  Queue family {i} {queueFamilyProperty}")

    result.add(device)

proc filterForDevice(devices: seq[PhysicalDevice]): seq[(PhysicalDevice, uint32, uint32)] =
  for device in devices:
    if not (device.formats.len > 0 and device.presentModes.len > 0 and "VK_KHR_swapchain" in device.extensions):
      continue
    var graphicsQueueFamily = high(uint32)
    var presentationQueueFamily = high(uint32)
    for i, queueFamily in enumerate(device.queueFamilies):
      if queueFamily.hasSurfaceSupport:
        presentationQueueFamily = uint32(i)
      if bool(uint32(queueFamily.properties.queueFlags) and ord(VK_QUEUE_GRAPHICS_BIT)):
        graphicsQueueFamily = uint32(i)
    if graphicsQueueFamily != high(uint32) and presentationQueueFamily != high(uint32):
      result.add((device, graphicsQueueFamily, presentationQueueFamily))

  for (device, graphicsQueueFamily, presentationQueueFamily) in result:
    debug(&"Viable device: {cleanString(device.properties.deviceName)} (graphics queue family {graphicsQueueFamily}, presentation queue family {presentationQueueFamily})")


proc getFrameDimension(window: NativeWindow, device: VkPhysicalDevice, surface: VkSurfaceKHR): VkExtent2D =
  let capabilities = device.getSurfaceCapabilities(surface)
  if capabilities.currentExtent.width != high(uint32):
    return capabilities.currentExtent
  else:
    let (width, height) = window.size()
    return VkExtent2D(
      width: min(max(uint32(width), capabilities.minImageExtent.width), capabilities.maxImageExtent.width),
      height: min(max(uint32(height), capabilities.minImageExtent.height), capabilities.maxImageExtent.height),
    )

when DEBUG_LOG:
  proc setupDebugLog(instance: VkInstance): VkDebugUtilsMessengerEXT =
    var createInfo = VkDebugUtilsMessengerCreateInfoEXT(
      sType: VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
      messageSeverity: VkDebugUtilsMessageSeverityFlagsEXT(
        ord(VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT) or
        ord(VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) or
        ord(VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
      ),
      messageType: VkDebugUtilsMessageTypeFlagsEXT(
        ord(VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT) or
        ord(VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT) or
        ord(VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT)
      ),
      pfnUserCallback: debugCallback,
      pUserData: nil,
    )
    checkVkResult instance.vkCreateDebugUtilsMessengerEXT(addr(createInfo), nil, addr(result))

proc setupVulkanDeviceAndQueues(instance: VkInstance, surface: VkSurfaceKHR): Device =
  let usableDevices = instance.getAllPhysicalDevices(surface).filterForDevice()
  if len(usableDevices) == 0:
    raise newException(Exception, "No suitable graphics device found")
  result.physicalDevice = usableDevices[0][0]
  result.graphicsQueueFamily = usableDevices[0][1]
  result.presentationQueueFamily = usableDevices[0][2]

  debug(&"Chose device {cleanString(result.physicalDevice.properties.deviceName)}")
  
  (result.device, result.graphicsQueue, result.presentationQueue) = getVulcanDevice(
    result.physicalDevice.device,
    result.physicalDevice.features,
    result.graphicsQueueFamily,
    result.presentationQueueFamily,
  )

proc setupSwapChain(device: VkDevice, physicalDevice: PhysicalDevice, surface: VkSurfaceKHR, dimension: VkExtent2D, surfaceFormat: VkSurfaceFormatKHR): Swapchain =

  let capabilities = physicalDevice.device.getSurfaceCapabilities(surface)
  var selectedPresentationMode = getPresentMode(physicalDevice.presentModes)
  # setup swapchain
  var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: surface,
    minImageCount: max(capabilities.minImageCount + 1, capabilities.maxImageCount),
    imageFormat: surfaceFormat.format,
    imageColorSpace: surfaceFormat.colorSpace,
    imageExtent: dimension,
    imageArrayLayers: 1,
    imageUsage: VkImageUsageFlags(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
    # VK_SHARING_MODE_CONCURRENT no supported (i.e cannot use different queue families for  drawing to swap surface?)
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    presentMode: selectedPresentationMode,
    clipped: VK_TRUE,
    oldSwapchain: VkSwapchainKHR(0),
  )
  checkVkResult device.vkCreateSwapchainKHR(addr(swapchainCreateInfo), nil, addr(result.swapchain))
  result.images = device.getSwapChainImages(result.swapchain)

  # setup swapchian image views

  result.imageviews = newSeq[VkImageView](result.images.len)
  for i, image in enumerate(result.images):
    var imageViewCreateInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      image: image,
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: surfaceFormat.format,
      components: VkComponentMapping(
        r: VK_COMPONENT_SWIZZLE_IDENTITY,
        g: VK_COMPONENT_SWIZZLE_IDENTITY,
        b: VK_COMPONENT_SWIZZLE_IDENTITY,
        a: VK_COMPONENT_SWIZZLE_IDENTITY,
      ),
      subresourceRange: VkImageSubresourceRange(
        aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1,
      ),
    )
    checkVkResult device.vkCreateImageView(addr(imageViewCreateInfo), nil, addr(result.imageviews[i]))

proc setupRenderPass(device: VkDevice, format: VkFormat): VkRenderPass =
  var
    colorAttachment = VkAttachmentDescription(
      format: format,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )
    colorAttachmentRef = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    subpass = VkSubpassDescription(
      pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
      colorAttachmentCount: 1,
      pColorAttachments: addr(colorAttachmentRef)
    )
    dependency = VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
      srcAccessMask: VkAccessFlags(0),
      dstStageMask: VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
      dstAccessMask: VkAccessFlags(VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT),
    )
    renderPassCreateInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: 1,
      pAttachments: addr(colorAttachment),
      subpassCount: 1,
      pSubpasses: addr(subpass),
      dependencyCount: 1,
      pDependencies: addr(dependency),
    )
  checkVkResult device.vkCreateRenderPass(addr(renderPassCreateInfo), nil, addr(result))

proc initRenderPipeline[VertextType, T](device: VkDevice, frameDimension: VkExtent2D, renderPass: VkRenderPass, vertexShader, fragmentShader: static string): RenderPipeline[T] =
  # load shaders
  result.device = device
  result.shaders.add(initShaderProgram[T](device, VK_SHADER_STAGE_VERTEX_BIT, vertexShader))
  result.shaders.add(initShaderProgram[T](device, VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShader))

  var
    # define which parts can be dynamic (pipeline is fixed after setup)
    dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
    dynamicState = VkPipelineDynamicStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
      dynamicStateCount: uint32(dynamicStates.len),
      pDynamicStates: addr(dynamicStates[0]),
    )
    vertexbindings = generateInputVertexBinding[VertextType]()
    attributebindings = generateInputAttributeBinding[VertextType]()

    # define input data format
    vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
      vertexBindingDescriptionCount: uint32(vertexbindings.len),
      pVertexBindingDescriptions: addr(vertexbindings[0]),
      vertexAttributeDescriptionCount: uint32(attributebindings.len),
      pVertexAttributeDescriptions: addr(attributebindings[0]),
    )
    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
      primitiveRestartEnable: VK_FALSE,
    )

  # setup viewport
  var viewportState = VkPipelineViewportStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount: 1,
    scissorCount: 1,
  )

  # rasterizerization config
  var
    rasterizer = VkPipelineRasterizationStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
      depthClampEnable: VK_FALSE,
      rasterizerDiscardEnable: VK_FALSE,
      polygonMode: VK_POLYGON_MODE_FILL,
      lineWidth: 1.0,
      cullMode: VkCullModeFlags(VK_CULL_MODE_BACK_BIT),
      frontFace: VK_FRONT_FACE_CLOCKWISE,
      depthBiasEnable: VK_FALSE,
      depthBiasConstantFactor: 0.0,
      depthBiasClamp: 0.0,
      depthBiasSlopeFactor: 0.0,
    )
    multisampling = VkPipelineMultisampleStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
      sampleShadingEnable: VK_FALSE,
      rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
      minSampleShading: 1.0,
      pSampleMask: nil,
      alphaToCoverageEnable: VK_FALSE,
      alphaToOneEnable: VK_FALSE,
    )
    colorBlendAttachment = VkPipelineColorBlendAttachmentState(
      colorWriteMask: VkColorComponentFlags(
        ord(VK_COLOR_COMPONENT_R_BIT) or
        ord(VK_COLOR_COMPONENT_G_BIT) or
        ord(VK_COLOR_COMPONENT_B_BIT) or
        ord(VK_COLOR_COMPONENT_A_BIT)
      ),
      blendEnable: VK_TRUE,
      srcColorBlendFactor: VK_BLEND_FACTOR_SRC_ALPHA,
      dstColorBlendFactor: VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
      colorBlendOp: VK_BLEND_OP_ADD,
      srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
      dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
      alphaBlendOp: VK_BLEND_OP_ADD,
    )
    colorBlending = VkPipelineColorBlendStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
      logicOpEnable: VK_TRUE,
      logicOp: VK_LOGIC_OP_COPY,
      attachmentCount: 1,
      pAttachments: addr(colorBlendAttachment),
      blendConstants: [0.0'f, 0.0'f, 0.0'f, 0.0'f],
    )

  result.uniformLayout = device.createUniformDescriptorLayout(VkShaderStageFlags(VK_SHADER_STAGE_VERTEX_BIT), 0)
  var 
    # "globals" that go into the shader, uniforms etc.
    pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      setLayoutCount: 1,
      pSetLayouts: addr(result.uniformLayout),
      pushConstantRangeCount: 0,
      pPushConstantRanges: nil,
    )
  checkVkResult vkCreatePipelineLayout(device, addr(pipelineLayoutInfo), nil, addr(result.layout))

  var stages: seq[VkPipelineShaderStageCreateInfo]
  for shader in result.shaders:
    stages.add(shader.shader)
  var pipelineInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount: uint32(stages.len),
    pStages: addr(stages[0]),
    pVertexInputState: addr(vertexInputInfo),
    pInputAssemblyState: addr(inputAssembly),
    pViewportState: addr(viewportState),
    pRasterizationState: addr(rasterizer),
    pMultisampleState: addr(multisampling),
    pDepthStencilState: nil,
    pColorBlendState: addr(colorBlending),
    pDynamicState: addr(dynamicState),
    layout: result.layout,
    renderPass: renderPass,
    subpass: 0,
    basePipelineHandle: VkPipeline(0),
    basePipelineIndex: -1,
  )
  checkVkResult vkCreateGraphicsPipelines(
    device,
    VkPipelineCache(0),
    1,
    addr(pipelineInfo),
    nil,
    addr(result.pipeline)
  )

proc setupFramebuffers(device: VkDevice, swapchain: var Swapchain, renderPass: VkRenderPass, dimension: VkExtent2D): seq[VkFramebuffer] =
  result = newSeq[VkFramebuffer](swapchain.images.len)
  for i, imageview in enumerate(swapchain.imageviews):
    var framebufferInfo = VkFramebufferCreateInfo(
      sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
      renderPass: renderPass,
      attachmentCount: 1,
      pAttachments: addr(swapchain.imageviews[i]),
      width: dimension.width,
      height: dimension.height,
      layers: 1,
    )
    checkVkResult device.vkCreateFramebuffer(addr(framebufferInfo), nil, addr(result[i]))
  
proc trash(device: VkDevice, swapchain: Swapchain, framebuffers: seq[VkFramebuffer]) =
  for framebuffer in framebuffers:
    device.vkDestroyFramebuffer(framebuffer, nil)
  for imageview in swapchain.imageviews:
    device.vkDestroyImageView(imageview, nil)
  device.vkDestroySwapchainKHR(swapchain.swapchain, nil)

proc recreateSwapchain(vulkan: Vulkan): (Swapchain, seq[VkFramebuffer]) =
  debug(&"Recreate swapchain with dimension {vulkan.frameDimension}")
  checkVkResult vulkan.device.device.vkDeviceWaitIdle()

  vulkan.device.device.trash(vulkan.swapchain, vulkan.framebuffers)

  result[0] = vulkan.device.device.setupSwapChain(
    vulkan.device.physicalDevice,
    vulkan.surface,
    vulkan.frameDimension,
    vulkan.surfaceFormat
  )
  result[1] = vulkan.device.device.setupFramebuffers(
    result[0],
    vulkan.renderPass,
    vulkan.frameDimension
  )


proc setupCommandBuffers(device: VkDevice, graphicsQueueFamily: uint32): (VkCommandPool, array[MAX_FRAMES_IN_FLIGHT, VkCommandBuffer]) =
  # set up command buffer
  var poolInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: VkCommandPoolCreateFlags(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT),
    queueFamilyIndex: graphicsQueueFamily,
  )
  checkVkResult device.vkCreateCommandPool(addr(poolInfo), nil, addr(result[0]))

  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: result[0],
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: result[1].len.uint32,
  )
  checkVkResult device.vkAllocateCommandBuffers(addr(allocInfo), addr(result[1][0]))

proc setupSyncPrimitives(device: VkDevice): (
    array[MAX_FRAMES_IN_FLIGHT, VkSemaphore],
    array[MAX_FRAMES_IN_FLIGHT, VkSemaphore],
    array[MAX_FRAMES_IN_FLIGHT, VkFence],
) =
  var semaphoreInfo = VkSemaphoreCreateInfo(sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO)
  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: VkFenceCreateFlags(VK_FENCE_CREATE_SIGNALED_BIT)
  )
  for i in 0 ..< MAX_FRAMES_IN_FLIGHT:
    checkVkResult device.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result[0][i]))
    checkVkResult device.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result[1][i]))
    checkVkResult device.vkCreateFence(addr(fenceInfo), nil, addr(result[2][i]))

proc igniteEngine*(windowTitle: string): Engine =

  result.window = createWindow(windowTitle)

  # setup vulkan functions
  vkLoad1_0()
  vkLoad1_1()
  vkLoad1_2()

  # create vulkan instance
  result.vulkan.instance = createVulkanInstance(VULKAN_VERSION)
  when DEBUG_LOG:
    result.vulkan.debugMessenger = result.vulkan.instance.setupDebugLog()
  result.vulkan.surface = result.vulkan.instance.createVulkanSurface(result.window)
  result.vulkan.device = result.vulkan.instance.setupVulkanDeviceAndQueues(result.vulkan.surface)

  # get basic frame information
  result.vulkan.surfaceFormat = result.vulkan.device.physicalDevice.formats.getSuitableSurfaceFormat()
  result.vulkan.frameDimension = result.window.getFrameDimension(result.vulkan.device.physicalDevice.device, result.vulkan.surface)

  # setup swapchain and render pipeline
  result.vulkan.swapchain = result.vulkan.device.device.setupSwapChain(
    result.vulkan.device.physicalDevice,
    result.vulkan.surface,
    result.vulkan.frameDimension,
    result.vulkan.surfaceFormat
  )
  result.vulkan.renderPass = result.vulkan.device.device.setupRenderPass(result.vulkan.surfaceFormat.format)
  result.vulkan.framebuffers = result.vulkan.device.device.setupFramebuffers(
    result.vulkan.swapchain,
    result.vulkan.renderPass,
    result.vulkan.frameDimension
  )
  (
    result.vulkan.commandPool,
    result.vulkan.commandBuffers,
  ) = result.vulkan.device.device.setupCommandBuffers(result.vulkan.device.graphicsQueueFamily)

  (
    result.vulkan.imageAvailableSemaphores,
    result.vulkan.renderFinishedSemaphores,
    result.vulkan.inFlightFences,
  ) = result.vulkan.device.device.setupSyncPrimitives()


proc setupPipeline*[VertexType, UniformType, T: object, IndexType: uint16|uint32](engine: var Engine, scenedata: ref Thing, vertexShader, fragmentShader: static string): RenderPipeline[T] =
  engine.currentscenedata = scenedata
  result = initRenderPipeline[VertexType, T](
    engine.vulkan.device.device,
    engine.vulkan.frameDimension,
    engine.vulkan.renderPass,
    vertexShader,
    fragmentShader,
  )
  # vertex buffers
  var allmeshes: seq[Mesh[VertexType]]
  for mesh in partsOfType[ref Mesh[VertexType]](engine.currentscenedata):
    allmeshes.add(mesh[])
  if allmeshes.len > 0:
    var ubermesh = createUberMesh(allmeshes)
    result.vertexBuffers.add createVertexBuffers(ubermesh, engine.vulkan.device.device, engine.vulkan.device.physicalDevice.device, engine.vulkan.commandPool, engine.vulkan.device.graphicsQueue)

  # vertex buffers with indexes
  var allindexedmeshes: seq[IndexedMesh[VertexType, IndexType]]
  for mesh in partsOfType[ref IndexedMesh[VertexType, IndexType]](engine.currentscenedata):
    allindexedmeshes.add(mesh[])
  if allindexedmeshes.len > 0:
    var indexedubermesh = createUberMesh(allindexedmeshes)
    result.indexedVertexBuffers.add createIndexedVertexBuffers(indexedubermesh, engine.vulkan.device.device, engine.vulkan.device.physicalDevice.device, engine.vulkan.commandPool, engine.vulkan.device.graphicsQueue)

  # uniform buffers
  result.uniformBuffers = createUniformBuffers[MAX_FRAMES_IN_FLIGHT, UniformType](
    engine.vulkan.device.device,
    engine.vulkan.device.physicalDevice.device
  )


proc runPipeline(commandBuffer: VkCommandBuffer, pipeline: RenderPipeline) =
  vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)

  for (vertexBufferSet, vertexCount) in pipeline.vertexBuffers:
    var
      vertexBuffers: seq[VkBuffer]
      offsets: seq[VkDeviceSize]
    for buffer in vertexBufferSet:
      vertexBuffers.add buffer.vkBuffer
      offsets.add VkDeviceSize(0)

    vkCmdBindVertexBuffers(commandBuffer, firstBinding=0'u32, bindingCount=2'u32, pBuffers=addr(vertexBuffers[0]), pOffsets=addr(offsets[0]))
    vkCmdDraw(commandBuffer, vertexCount=vertexCount, instanceCount=1'u32, firstVertex=0'u32, firstInstance=0'u32)

  for (vertexBufferSet, indexBuffer, indicesCount, indexType) in pipeline.indexedVertexBuffers:
    var
      vertexBuffers: seq[VkBuffer]
      offsets: seq[VkDeviceSize]
    for buffer in vertexBufferSet:
      vertexBuffers.add buffer.vkBuffer
      offsets.add VkDeviceSize(0)

    vkCmdBindVertexBuffers(commandBuffer, firstBinding=0'u32, bindingCount=2'u32, pBuffers=addr(vertexBuffers[0]), pOffsets=addr(offsets[0]))
    vkCmdBindIndexBuffer(commandBuffer, indexBuffer.vkBuffer, VkDeviceSize(0), indexType);
    vkCmdDrawIndexed(commandBuffer, indicesCount, 1, 0, 0, 0);

proc recordCommandBuffer(renderPass: VkRenderPass, pipeline: RenderPipeline, commandBuffer: VkCommandBuffer, framebuffer: VkFramebuffer, frameDimension: VkExtent2D) =
  var
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pInheritanceInfo: nil,
    )
    clearColor = VkClearValue(color: VkClearColorValue(float32: [0.2'f, 0.2'f, 0.2'f, 1.0'f]))
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: renderPass,
      framebuffer: framebuffer,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: frameDimension,
      ),
      clearValueCount: 1,
      pClearValues: addr(clearColor),
    )
    viewport = VkViewport(
      x: 0.0,
      y: 0.0,
      width: (float) frameDimension.width,
      height: (float) frameDimension.height,
      minDepth: 0.0,
      maxDepth: 1.0,
    )
    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: frameDimension
    )
  checkVkResult vkBeginCommandBuffer(commandBuffer, addr(beginInfo))
  block:
    vkCmdBeginRenderPass(commandBuffer, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)
    vkCmdSetViewport(commandBuffer, firstViewport=0, viewportCount=1, addr(viewport))
    vkCmdSetScissor(commandBuffer, firstScissor=0, scissorCount=1, addr(scissor))
    runPipeline(commandBuffer, pipeline)
    vkCmdEndRenderPass(commandBuffer)
  checkVkResult vkEndCommandBuffer(commandBuffer)

proc drawFrame(window: NativeWindow, vulkan: var Vulkan, currentFrame: int, resized: bool, pipeline: RenderPipeline) =
  checkVkResult vkWaitForFences(vulkan.device.device, 1, addr(vulkan.inFlightFences[currentFrame]), VK_TRUE, high(uint64))
  var bufferImageIndex: uint32
  let nextImageResult = vkAcquireNextImageKHR(
    vulkan.device.device,
    vulkan.swapchain.swapchain,
    high(uint64),
    vulkan.imageAvailableSemaphores[currentFrame],
    VkFence(0),
    addr(bufferImageIndex)
  )
  if nextImageResult == VK_ERROR_OUT_OF_DATE_KHR:
    vulkan.frameDimension = window.getFrameDimension(vulkan.device.physicalDevice.device, vulkan.surface)
    (vulkan.swapchain, vulkan.framebuffers) = vulkan.recreateSwapchain()
  elif not (nextImageResult in [VK_SUCCESS, VK_SUBOPTIMAL_KHR]):
    raise newException(Exception, "Vulkan error: vkAcquireNextImageKHR returned " & $nextImageResult)
  checkVkResult vkResetFences(vulkan.device.device, 1, addr(vulkan.inFlightFences[currentFrame]))

  checkVkResult vkResetCommandBuffer(vulkan.commandBuffers[currentFrame], VkCommandBufferResetFlags(0))
  vulkan.renderPass.recordCommandBuffer(pipeline, vulkan.commandBuffers[currentFrame], vulkan.framebuffers[bufferImageIndex], vulkan.frameDimension)
  var
    waitSemaphores = [vulkan.imageAvailableSemaphores[currentFrame]]
    waitStages = [VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)]
    signalSemaphores = [vulkan.renderFinishedSemaphores[currentFrame]]
    submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      waitSemaphoreCount: 1,
      pWaitSemaphores: addr(waitSemaphores[0]),
      pWaitDstStageMask: addr(waitStages[0]),
      commandBufferCount: 1,
      pCommandBuffers: addr(vulkan.commandBuffers[currentFrame]),
      signalSemaphoreCount: 1,
      pSignalSemaphores: addr(signalSemaphores[0]),
    )
  checkVkResult vkQueueSubmit(vulkan.device.graphicsQueue, 1, addr(submitInfo), vulkan.inFlightFences[currentFrame])

  var presentInfo = VkPresentInfoKHR(
    sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    waitSemaphoreCount: 1,
    pWaitSemaphores: addr(signalSemaphores[0]),
    swapchainCount: 1,
    pSwapchains: addr(vulkan.swapchain.swapchain),
    pImageIndices: addr(bufferImageIndex),
    pResults: nil,
  )
  let presentResult = vkQueuePresentKHR(vulkan.device.presentationQueue, addr(presentInfo))

  if presentResult == VK_ERROR_OUT_OF_DATE_KHR or presentResult == VK_SUBOPTIMAL_KHR or resized:
    vulkan.frameDimension = window.getFrameDimension(vulkan.device.physicalDevice.device, vulkan.surface)
    (vulkan.swapchain, vulkan.framebuffers) = vulkan.recreateSwapchain()


proc run*(engine: var Engine, pipeline: RenderPipeline, globalUpdate: proc(engine: var Engine, dt: Duration)) =
  var
    killed = false
    currentFrame = 0
    resized = false
    lastUpdate = getTime()

  while not killed:

    # process input
    for event in engine.window.pendingEvents():
      case event.eventType:
        of Quit:
          killed = true
        of ResizedWindow:
          resized = true
        of KeyDown:
          echo event
          if event.key == Escape:
            killed = true
        else:
          discard

    # game logic update
    let
      now = getTime()
      dt = now - lastUpdate
    lastUpdate = now
    engine.globalUpdate(dt)
    for entity in allEntities(engine.currentscenedata):
      entity.update(dt)

    # submit frame for drawing
    engine.window.drawFrame(engine.vulkan, currentFrame, resized, pipeline)
    resized = false
    currentFrame = (currentFrame + 1) mod MAX_FRAMES_IN_FLIGHT;
  checkVkResult vkDeviceWaitIdle(engine.vulkan.device.device)

proc trash*(pipeline: var RenderPipeline) =
  vkDestroyDescriptorSetLayout(pipeline.device, pipeline.uniformLayout, nil);
  vkDestroyPipeline(pipeline.device, pipeline.pipeline, nil)
  vkDestroyPipelineLayout(pipeline.device, pipeline.layout, nil)
  for shader in pipeline.shaders:
    vkDestroyShaderModule(pipeline.device, shader.shader.module, nil)

  for (bufferset, cnt) in pipeline.vertexBuffers.mitems:
    for buffer in bufferset.mitems:
      buffer.trash()
  for (bufferset, indexbuffer, cnt, t) in pipeline.indexedVertexBuffers.mitems:
    indexbuffer.trash()
    for buffer in bufferset.mitems:
      buffer.trash()
  for buffer in pipeline.uniformBuffers.mitems:
    buffer.trash()

proc trash*(engine: var Engine) =
  checkVkResult vkDeviceWaitIdle(engine.vulkan.device.device)
  engine.vulkan.device.device.trash(engine.vulkan.swapchain, engine.vulkan.framebuffers)

  for i in 0 ..< MAX_FRAMES_IN_FLIGHT:
    engine.vulkan.device.device.vkDestroySemaphore(engine.vulkan.imageAvailableSemaphores[i], nil)
    engine.vulkan.device.device.vkDestroySemaphore(engine.vulkan.renderFinishedSemaphores[i], nil)
    engine.vulkan.device.device.vkDestroyFence(engine.vulkan.inFlightFences[i], nil)

  engine.vulkan.device.device.vkDestroyRenderPass(engine.vulkan.renderPass, nil)
  engine.vulkan.device.device.vkDestroyCommandPool(engine.vulkan.commandPool, nil)

  engine.vulkan.instance.vkDestroySurfaceKHR(engine.vulkan.surface, nil)
  engine.vulkan.device.device.vkDestroyDevice(nil)
  when DEBUG_LOG:
    engine.vulkan.instance.vkDestroyDebugUtilsMessengerEXT(engine.vulkan.debugMessenger, nil)
  engine.window.trash()
  engine.vulkan.instance.vkDestroyInstance(nil) # needs to happen after window is trashed as the driver might have a hook registered for the window destruction
