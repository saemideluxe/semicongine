import ./api
import ./utils
import ./renderpass
import ./vertex
import ./device
import ./shader

type
  Pipeline = object
    device: Device
    vk*: VkPipeline
    layout: VkPipelineLayout
    descriptorLayout: VkDescriptorSetLayout


proc createPipeline*[VertexShader: Shader, FragmentShader: Shader](renderPass: RenderPass, vertexShader: VertexShader, fragmentShader: FragmentShader): Pipeline =
  assert renderPass.vk.valid
  assert renderPass.device.vk.valid
  assert vertexShader.stage == VK_SHADER_STAGE_VERTEX_BIT
  assert fragmentShader.stage == VK_SHADER_STAGE_FRAGMENT_BIT
  result.device = renderPass.device

  var descriptorType: VkDescriptorType
  var bindingNumber = 0'u32
  var arrayLen = 1
  var shaderStage: seq[VkShaderStageFlagBits]
  var layoutbinding = VkDescriptorSetLayoutBinding(
    binding: bindingNumber,
    descriptorType: descriptorType,
    descriptorCount: uint32(arrayLen),
    stageFlags: toBits shaderStage,
    pImmutableSamplers: nil,
  )
  var descriptorLayoutBinding: seq[VkDescriptorSetLayoutBinding] = @[layoutbinding]
  var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount: uint32(descriptorLayoutBinding.len),
    pBindings: descriptorLayoutBinding.toCPointer
  )
  checkVkResult vkCreateDescriptorSetLayout(
    renderPass.device.vk,
    addr(layoutCreateInfo),
    nil,
    addr(result.descriptorLayout),
  )
  # var pushConstant = VkPushConstantRange(
    # stageFlags: toBits shaderStage,
    # offset: 0,
    # size: 0,
  # )
  var descriptorSets: seq[VkDescriptorSetLayout] = @[result.descriptorLayout]
  # var pushConstants: seq[VkPushConstantRange] = @[pushConstant]
  var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      setLayoutCount: uint32(descriptorSets.len),
      pSetLayouts: descriptorSets.toCPointer,
      # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.toCPointer,
    )
  checkVkResult vkCreatePipelineLayout(renderPass.device.vk, addr(pipelineLayoutInfo), nil, addr(result.layout))

  var
    bindings: seq[VkVertexInputBindingDescription]
    attributes: seq[VkVertexInputAttributeDescription]
    vertexInputInfo = vertexShader.getVertexInputInfo(bindings, attributes)
    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
      primitiveRestartEnable: VK_FALSE,
    )
    viewportState = VkPipelineViewportStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
      viewportCount: 1,
      scissorCount: 1,
    )
    rasterizer = VkPipelineRasterizationStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
      depthClampEnable: VK_FALSE,
      rasterizerDiscardEnable: VK_FALSE,
      polygonMode: VK_POLYGON_MODE_FILL,
      lineWidth: 1.0,
      cullMode: toBits [VK_CULL_MODE_BACK_BIT],
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
      colorWriteMask: toBits [VK_COLOR_COMPONENT_R_BIT, VK_COLOR_COMPONENT_G_BIT, VK_COLOR_COMPONENT_B_BIT, VK_COLOR_COMPONENT_A_BIT],
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
    dynamicStates = @[VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
    dynamicState = VkPipelineDynamicStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
      dynamicStateCount: uint32(dynamicStates.len),
      pDynamicStates: dynamicStates.toCPointer,
    )
    stages = @[vertexShader.getPipelineInfo(), fragmentShader.getPipelineInfo()]
    createInfo = VkGraphicsPipelineCreateInfo(
      sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
      stageCount: uint32(stages.len),
      pStages: stages.toCPointer,
      pVertexInputState: addr(vertexInputInfo),
      pInputAssemblyState: addr(inputAssembly),
      pViewportState: addr(viewportState),
      pRasterizationState: addr(rasterizer),
      pMultisampleState: addr(multisampling),
      pDepthStencilState: nil,
      pColorBlendState: addr(colorBlending),
      pDynamicState: addr(dynamicState),
      layout: result.layout,
      renderPass: renderPass.vk,
      subpass: 0,
      basePipelineHandle: VkPipeline(0),
      basePipelineIndex: -1,
    )
  checkVkResult vkCreateGraphicsPipelines(
    renderpass.device.vk,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.vk)
  )

proc destroy*(pipeline: var Pipeline) =
  assert pipeline.device.vk.valid
  assert pipeline.vk.valid
  assert pipeline.layout.valid
  assert pipeline.descriptorLayout.valid

  pipeline.device.vk.vkDestroyDescriptorSetLayout(pipeline.descriptorLayout, nil)
  pipeline.device.vk.vkDestroyPipelineLayout(pipeline.layout, nil)
  pipeline.device.vk.vkDestroyPipeline(pipeline.vk, nil)
  pipeline.descriptorLayout.reset()
  pipeline.layout.reset()
  pipeline.vk.reset()
