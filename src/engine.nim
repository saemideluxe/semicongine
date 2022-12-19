import std/strformat
import std/enumerate
import std/logging


import ./vulkan
import ./vulkan_helpers
import ./xlib_helpers

import ./glslang/glslang

const MAX_FRAMES_IN_FLIGHT = 2

var logger = newConsoleLogger()
addHandler(logger)


var vertexShaderCode: string = """#version 450
layout(location = 0) out vec3 fragColor;
vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);
vec2 positions[3] = vec2[](
  vec2(0.0, -0.5),
  vec2(0.5, 0.5),
  vec2(-0.5, 0.5)
);
void main() {
  gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
  fragColor = colors[gl_VertexIndex];
}"""

var fragmentShaderCode: string = """#version 450
layout(location = 0) out vec4 outColor;
layout(location = 0) in vec3 fragColor;
void main() {
  outColor = vec4(fragColor, 1.0);
}"""

import
  x11/xlib,
  x11/x

const VULKAN_VERSION = VK_MAKE_API_VERSION(0'u32, 1'u32, 2'u32, 0'u32)

type
  GraphicsPipeline = object
    shaderStages*: seq[VkPipelineShaderStageCreateInfo]
    layout*: VkPipelineLayout
    renderPass*: VkRenderPass
    pipeline*: VkPipeline
  QueueFamily = object
    properties*: VkQueueFamilyProperties
    hasSurfaceSupport*: bool
  PhysicalDevice = object
    device*: VkPhysicalDevice
    extensions*: seq[string]
    properties*: VkPhysicalDeviceProperties
    features*: VkPhysicalDeviceFeatures
    queueFamilies*: seq[QueueFamily]
    surfaceCapabilities*: VkSurfaceCapabilitiesKHR
    surfaceFormats: seq[VkSurfaceFormatKHR]
    presentModes: seq[VkPresentModeKHR]
  Vulkan* = object
    debugMessenger: VkDebugUtilsMessengerEXT
    instance*: VkInstance
    deviceList*: seq[PhysicalDevice]
    activePhysicalDevice*: PhysicalDevice
    graphicsQueueFamily*: uint32
    graphicsQueue*: VkQueue
    presentationQueueFamily*: uint32
    presentationQueue*: VkQueue
    device*: VkDevice
    surface*: VkSurfaceKHR
    selectedSurfaceFormat: VkSurfaceFormatKHR
    selectedPresentationMode: VkPresentModeKHR
    frameDimension: VkExtent2D
    swapChain: VkSwapchainKHR
    swapImages: seq[VkImage]
    swapFramebuffers: seq[VkFramebuffer]
    swapImageViews: seq[VkImageView]
    pipeline*: GraphicsPipeline
    commandPool*: VkCommandPool
    commandBuffers*: array[MAX_FRAMES_IN_FLIGHT, VkCommandBuffer]
    viewport*: VkViewport
    scissor*: VkRect2D
    imageAvailableSemaphores*: array[MAX_FRAMES_IN_FLIGHT, VkSemaphore]
    renderFinishedSemaphores*: array[MAX_FRAMES_IN_FLIGHT, VkSemaphore]
    inFlightFences*: array[MAX_FRAMES_IN_FLIGHT, VkFence]
  Engine* = object
    display*: PDisplay
    window*: x.Window
    vulkan*: Vulkan


proc getAllPhysicalDevices(instance: VkInstance, surface: VkSurfaceKHR): seq[PhysicalDevice] =
  for vulkanPhysicalDevice in getVulkanPhysicalDevices(instance):
    var device = PhysicalDevice(device: vulkanPhysicalDevice, extensions: getDeviceExtensions(vulkanPhysicalDevice))
    vkGetPhysicalDeviceProperties(vulkanPhysicalDevice, addr(device.properties))
    vkGetPhysicalDeviceFeatures(vulkanPhysicalDevice, addr(device.features))
    checkVkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vulkanPhysicalDevice, surface, addr(device.surfaceCapabilities))
    device.surfaceFormats = getDeviceSurfaceFormats(vulkanPhysicalDevice, surface)
    device.presentModes = getDeviceSurfacePresentModes(vulkanPhysicalDevice, surface)

    debug(&"Physical device nr {int(vulkanPhysicalDevice)} {cleanString(device.properties.deviceName)}")
    for i, queueFamilyProperty in enumerate(getQueueFamilies(vulkanPhysicalDevice)):
      var hasSurfaceSupport: VkBool32 = VK_FALSE
      checkVkResult vkGetPhysicalDeviceSurfaceSupportKHR(vulkanPhysicalDevice, uint32(i), surface, addr(hasSurfaceSupport))
      device.queueFamilies.add(QueueFamily(properties: queueFamilyProperty, hasSurfaceSupport: bool(hasSurfaceSupport)))
      debug(&"  Queue family {i} {queueFamilyProperty}")

    result.add(device)

proc filterForDevice(devices: seq[PhysicalDevice]): seq[(PhysicalDevice, uint32, uint32)] =
  for device in devices:
    if not (device.surfaceFormats.len > 0 and device.presentModes.len > 0 and "VK_KHR_swapchain" in device.extensions):
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


proc getFrameDimension(display: PDisplay, window: Window, capabilities: VkSurfaceCapabilitiesKHR): VkExtent2D =
  if capabilities.currentExtent.width != high(uint32):
    return capabilities.currentExtent
  else:
    let (width, height) = xlibFramebufferSize(display, window)
    return VkExtent2D(
      width: min(max(uint32(width), capabilities.minImageExtent.width), capabilities.maxImageExtent.width),
      height: min(max(uint32(height), capabilities.minImageExtent.height), capabilities.maxImageExtent.height),
    )

proc createVulkanSurface(instance: VkInstance, display: PDisplay, window: Window): VkSurfaceKHR =
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: display,
    window: window,
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))

proc setupVulkanDeviceAndQueues(instance: VkInstance, surface: VkSurfaceKHR): (PhysicalDevice, uint32, uint32, VkDevice, VkQueue, VkQueue) =
  let usableDevices = instance.getAllPhysicalDevices(surface).filterForDevice()
  if len(usableDevices) == 0:
    raise newException(Exception, "No suitable graphics device found")
  result[0] = usableDevices[0][0]
  result[1] = usableDevices[0][1]
  result[2] = usableDevices[0][2]

  debug(&"Chose device {cleanString(result[0].properties.deviceName)}")
  
  (result[3], result[4], result[5]) = getVulcanDevice(
    result[0].device,
    result[0].features,
    result[1],
    result[2],
  )

proc igniteEngine*(): Engine =

  # init X11 window
  (result.display, result.window) = xlibInit()

  # create vulkan instance
  vkLoad1_0()
  vkLoad1_1()
  vkLoad1_2()
  result.vulkan.instance = createVulkanInstance(VULKAN_VERSION)
  when ENABLEVULKANVALIDATIONLAYERS:
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
    checkVkResult vkCreateDebugUtilsMessengerEXT(result.vulkan.instance, addr(createInfo), nil, addr(result.vulkan.debugMessenger))

  result.vulkan.surface = result.vulkan.instance.createVulkanSurface(result.display, result.window)

  (
    result.vulkan.activePhysicalDevice,
    result.vulkan.graphicsQueueFamily,
    result.vulkan.presentationQueueFamily,
    result.vulkan.device,
    result.vulkan.graphicsQueue,
    result.vulkan.presentationQueue
  ) = result.vulkan.instance.setupVulkanDeviceAndQueues(result.vulkan.surface)
  
  # determine surface format for swapchain
  let usableSurfaceFormats = filterForSurfaceFormat(result.vulkan.activePhysicalDevice.surfaceFormats)
  if len(usableSurfaceFormats) == 0:
    raise newException(Exception, "No suitable surface formats found")
  result.vulkan.selectedSurfaceFormat = usableSurfaceFormats[0]
  result.vulkan.selectedPresentationMode = getPresentMode(result.vulkan.activePhysicalDevice.presentModes)
  result.vulkan.frameDimension = result.display.getFrameDimension(result.window, result.vulkan.activePhysicalDevice.surfaceCapabilities)

  # setup swapchain
  var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: result.vulkan.surface,
    minImageCount: max(result.vulkan.activePhysicalDevice.surfaceCapabilities.minImageCount + 1, result.vulkan.activePhysicalDevice.surfaceCapabilities.maxImageCount),
    imageFormat: result.vulkan.selectedSurfaceFormat.format,
    imageColorSpace: result.vulkan.selectedSurfaceFormat.colorSpace,
    imageExtent: result.vulkan.frameDimension,
    imageArrayLayers: 1,
    imageUsage: VkImageUsageFlags(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
    # VK_SHARING_MODE_CONCURRENT no supported (i.e cannot use different queue families for  drawing to swap surface?)
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: result.vulkan.activePhysicalDevice.surfaceCapabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    presentMode: result.vulkan.selectedPresentationMode,
    clipped: VK_TRUE,
    oldSwapchain: VkSwapchainKHR(0),
  )
  checkVkResult result.vulkan.device.vkCreateSwapchainKHR(addr(swapchainCreateInfo), nil, addr(result.vulkan.swapChain))
  result.vulkan.swapImages = result.vulkan.device.getSwapChainImages(result.vulkan.swapChain)

  # setup swapchian image views
  result.vulkan.swapImageViews = newSeq[VkImageView](result.vulkan.swapImages.len)
  for i, image in enumerate(result.vulkan.swapImages):
    var imageViewCreateInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      image: image,
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: result.vulkan.selectedSurfaceFormat.format,
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
    checkVkResult result.vulkan.device.vkCreateImageView(addr(imageViewCreateInfo), nil, addr(result.vulkan.swapImageViews[i]))

  # init shader system
  checkGlslangResult glslang_initialize_process()

  # load shaders
  result.vulkan.pipeline.shaderStages.add(result.vulkan.device.createShaderStage(VK_SHADER_STAGE_VERTEX_BIT, vertexShaderCode))
  result.vulkan.pipeline.shaderStages.add(result.vulkan.device.createShaderStage(VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShaderCode))

  # setup render passes
  var
    colorAttachment = VkAttachmentDescription(
      format: result.vulkan.selectedSurfaceFormat.format,
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
  checkVkResult result.vulkan.device.vkCreateRenderPass(addr(renderPassCreateInfo), nil, addr(result.vulkan.pipeline.renderPass))

  # create graphis pipeline
  
  var
    # define which parts can be dynamic (pipeline is fixed after setup)
    dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
    dynamicState = VkPipelineDynamicStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
      dynamicStateCount: uint32(dynamicStates.len),
      pDynamicStates: addr(dynamicStates[0]),
    )

    # define input data format
    vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
      vertexBindingDescriptionCount: 0,
      pVertexBindingDescriptions: nil,
      vertexAttributeDescriptionCount: 0,
      pVertexAttributeDescriptions: nil,
    )
    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
      primitiveRestartEnable: VK_FALSE,
    )

  # setup viewport
  result.vulkan.viewport = VkViewport(
    x: 0.0,
    y: 0.0,
    width: (float) result.vulkan.frameDimension.width,
    height: (float) result.vulkan.frameDimension.height,
    minDepth: 0.0,
    maxDepth: 1.0,
  )
  result.vulkan.scissor = VkRect2D(
    offset: VkOffset2D(x: 0, y: 0),
    extent: result.vulkan.frameDimension
  )
  var viewportState = VkPipelineViewportStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount: 1,
    pViewports: addr(result.vulkan.viewport),
    scissorCount: 1,
    pScissors: addr(result.vulkan.scissor),
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

    # create pipeline
    pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      setLayoutCount: 0,
      pSetLayouts: nil,
      pushConstantRangeCount: 0,
      pPushConstantRanges: nil,
    )
  checkVkResult result.vulkan.device.vkCreatePipelineLayout(addr(pipelineLayoutInfo), nil, addr(result.vulkan.pipeline.layout))

  var pipelineInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount: 2,
    pStages: addr(result.vulkan.pipeline.shaderStages[0]),
    pVertexInputState: addr(vertexInputInfo),
    pInputAssemblyState: addr(inputAssembly),
    pViewportState: addr(viewportState),
    pRasterizationState: addr(rasterizer),
    pMultisampleState: addr(multisampling),
    pDepthStencilState: nil,
    pColorBlendState: addr(colorBlending),
    pDynamicState: addr(dynamicState),
    layout: result.vulkan.pipeline.layout,
    renderPass: result.vulkan.pipeline.renderPass,
    subpass: 0,
    basePipelineHandle: VkPipeline(0),
    basePipelineIndex: -1,
  )
  checkVkResult result.vulkan.device.vkCreateGraphicsPipelines(
    VkPipelineCache(0),
    1,
    addr(pipelineInfo),
    nil,
    addr(result.vulkan.pipeline.pipeline)
  )

  # set up framebuffers
  result.vulkan.swapFramebuffers  = newSeq[VkFramebuffer](result.vulkan.swapImages.len)

  for i, imageview in enumerate(result.vulkan.swapImageViews):
    var framebufferInfo = VkFramebufferCreateInfo(
      sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
      renderPass: result.vulkan.pipeline.renderPass,
      attachmentCount: 1,
      pAttachments: addr(result.vulkan.swapImageViews[i]),
      width: result.vulkan.frameDimension.width,
      height: result.vulkan.frameDimension.height,
      layers: 1,
    )
    checkVkResult result.vulkan.device.vkCreateFramebuffer(addr(framebufferInfo), nil, addr(result.vulkan.swapFramebuffers[i]))
  
  # set up command buffer
  var poolInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    flags: VkCommandPoolCreateFlags(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT),
    queueFamilyIndex: result.vulkan.graphicsQueueFamily,
  )
  checkVkResult result.vulkan.device.vkCreateCommandPool(addr(poolInfo), nil, addr(result.vulkan.commandPool))

  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: result.vulkan.commandPool,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: result.vulkan.commandBuffers.len.uint32,
  )
  checkVkResult result.vulkan.device.vkAllocateCommandBuffers(addr(allocInfo), addr(result.vulkan.commandBuffers[0]))

  # create semaphores for syncing rendering
  var semaphoreInfo = VkSemaphoreCreateInfo(sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO)
  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: VkFenceCreateFlags(VK_FENCE_CREATE_SIGNALED_BIT)
  )
  for i in 0 ..< MAX_FRAMES_IN_FLIGHT:
    checkVkResult result.vulkan.device.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result.vulkan.imageAvailableSemaphores[i]))
    checkVkResult result.vulkan.device.vkCreateSemaphore(addr(semaphoreInfo), nil, addr(result.vulkan.renderFinishedSemaphores[i]))
    checkVkResult result.vulkan.device.vkCreateFence(addr(fenceInfo), nil, addr(result.vulkan.inFlightFences[i]))


proc recordCommandBuffer(vulkan: var Vulkan, commandBuffer: VkCommandBuffer, imageIndex: uint32) =
  var beginInfo = VkCommandBufferBeginInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    pInheritanceInfo: nil,
  )
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))

  var
    clearColor = VkClearValue(color: VkClearColorValue(float32: [0.2'f, 0.2'f, 0.2'f, 1.0'f]))
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: vulkan.pipeline.renderPass,
      framebuffer: vulkan.swapFramebuffers[imageIndex],
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: vulkan.frameDimension,
      ),
      clearValueCount: 1,
      pClearValues: addr(clearColor),
    )
  commandBuffer.vkCmdBeginRenderPass(addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, vulkan.pipeline.pipeline)

  commandBuffer.vkCmdSetViewport(firstViewport=0, viewportCount=1, addr(vulkan.viewport))
  commandBuffer.vkCmdSetScissor(firstScissor=0, scissorCount=1, addr(vulkan.scissor))
  commandBuffer.vkCmdDraw(vertexCount=3, instanceCount=1, firstVertex=0, firstInstance=0)
  commandBuffer.vkCmdEndRenderPass()
  checkVkResult commandBuffer.vkEndCommandBuffer()

proc drawFrame(vulkan: var Vulkan, currentFrame: int) =
  checkVkResult vulkan.device.vkWaitForFences(1, addr(vulkan.inFlightFences[currentFrame]), VK_TRUE, high(uint64))
  checkVkResult vulkan.device.vkResetFences(1, addr(vulkan.inFlightFences[currentFrame]))
  var bufferImageIndex: uint32
  checkVkResult vulkan.device.vkAcquireNextImageKHR(
    vulkan.swapChain,
    high(uint64),
    vulkan.imageAvailableSemaphores[currentFrame],
    VkFence(0),
    addr(bufferImageIndex)
  )

  checkVkResult vkResetCommandBuffer(vulkan.commandBuffers[currentFrame], VkCommandBufferResetFlags(0))
  recordCommandBuffer(vulkan, vulkan.commandBuffers[currentFrame], bufferImageIndex)
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
  checkVkResult vkQueueSubmit(vulkan.graphicsQueue, 1, addr(submitInfo), vulkan.inFlightFences[currentFrame])

  var presentInfo = VkPresentInfoKHR(
    sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    waitSemaphoreCount: 1,
    pWaitSemaphores: addr(signalSemaphores[0]),
    swapchainCount: 1,
    pSwapchains: addr(vulkan.swapChain),
    pImageIndices: addr(bufferImageIndex),
    pResults: nil,
  )
  checkVkResult vkQueuePresentKHR(vulkan.presentationQueue, addr(presentInfo))


proc fullThrottle*(engine: var Engine) =
  var
    event: XEvent
    killed = false
    currentFrame = 0

  while not killed:
    while engine.display.XPending() > 0 and not killed:
      discard engine.display.XNextEvent(addr(event))
      case event.theType
      of ClientMessage:
        if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
          killed = true
      of KeyPress:
        let key = XLookupKeysym(cast[PXKeyEvent](addr(event)), 0)
        if key == XK_Escape:
          killed = true
      else:
        discard
    drawFrame(engine.vulkan, currentFrame)
    currentFrame = (currentFrame + 1) mod MAX_FRAMES_IN_FLIGHT;
  checkVkResult engine.vulkan.device.vkDeviceWaitIdle()


proc trash*(engine: Engine) =
  for i in 0 ..< MAX_FRAMES_IN_FLIGHT:
    engine.vulkan.device.vkDestroySemaphore(engine.vulkan.imageAvailableSemaphores[i], nil)
    engine.vulkan.device.vkDestroySemaphore(engine.vulkan.renderFinishedSemaphores[i], nil)
    engine.vulkan.device.vkDestroyFence(engine.vulkan.inFlightFences[i], nil)

  engine.vulkan.device.vkDestroyCommandPool(engine.vulkan.commandPool, nil)
  for framebuffer in engine.vulkan.swapFramebuffers:
    engine.vulkan.device.vkDestroyFramebuffer(framebuffer, nil)

  engine.vulkan.device.vkDestroyPipeline(engine.vulkan.pipeline.pipeline, nil)
  engine.vulkan.device.vkDestroyPipelineLayout(engine.vulkan.pipeline.layout, nil)
  engine.vulkan.device.vkDestroyRenderPass(engine.vulkan.pipeline.renderPass, nil)

  for shaderStage in engine.vulkan.pipeline.shaderStages:
    engine.vulkan.device.vkDestroyShaderModule(shaderStage.module, nil)

  glslang_finalize_process()
  engine.vulkan.device.vkDestroySwapchainKHR(engine.vulkan.swapChain, nil)
  engine.vulkan.instance.vkDestroySurfaceKHR(engine.vulkan.surface, nil)
  engine.vulkan.device.vkDestroyDevice(nil)
  engine.vulkan.instance.vkDestroyInstance(nil)
  checkXlibResult engine.display.XDestroyWindow(engine.window)
  discard engine.display.XCloseDisplay() # always returns 0
