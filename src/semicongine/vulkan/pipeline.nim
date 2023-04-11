import std/tables
import std/sequtils

import ./api
import ./device
import ./descriptor
import ./shader
import ./buffer
import ./utils

import ../entity
import ../gpu_data

type
  Pipeline* = object
    device*: Device
    vk*: VkPipeline
    layout*: VkPipelineLayout
    shaders*: seq[Shader]
    descriptorSetLayout*: DescriptorSetLayout
    descriptorPool*: DescriptorPool
    descriptorSets*: seq[DescriptorSet]
    uniformBuffers: seq[Buffer]

func inputs*(pipeline: Pipeline): seq[ShaderAttribute] =
  for shader in pipeline.shaders:
    if shader.stage == VK_SHADER_STAGE_VERTEX_BIT:
      return shader.inputs

func uniforms*(pipeline: Pipeline): seq[ShaderAttribute] =
  var uniformList: Table[string, ShaderAttribute]
  for shader in pipeline.shaders:
    for attribute in shader.uniforms:
      if attribute.name in uniformList:
        assert uniformList[attribute.name] == attribute
      else:
        uniformList[attribute.name] = attribute
  result = uniformList.values.toSeq

proc setupUniforms(pipeline: var Pipeline, inFlightFrames: int) =
  assert pipeline.vk.valid

  var uniformBufferSize = 0'u64
  for uniform in pipeline.uniforms:
    uniformBufferSize += uniform.thetype.size

  for i in 0 ..< inFlightFrames:
    var buffer = pipeline.device.createBuffer(
      size=uniformBufferSize,
      usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
      useVRAM=true,
      mappable=true,
    )
    pipeline.uniformBuffers.add buffer
    pipeline.descriptorSets[i].setDescriptorSet(buffer)

proc createPipeline*(device: Device, renderPass: VkRenderPass, vertexShader: Shader, fragmentShader: Shader, inFlightFrames: int, subpass = 0'u32): Pipeline =
  assert renderPass.valid
  assert device.vk.valid
  assert vertexShader.stage == VK_SHADER_STAGE_VERTEX_BIT
  assert fragmentShader.stage == VK_SHADER_STAGE_FRAGMENT_BIT
  assert vertexShader.outputs == fragmentShader.inputs
  assert vertexShader.uniforms == fragmentShader.uniforms

  result.device = device
  result.shaders = @[vertexShader, fragmentShader]
  
  var descriptors = @[
    Descriptor(
      thetype: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
      count: 1,
      stages: @[VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT],
      itemsize: vertexShader.uniforms.size(),
    ),
  ]
  result.descriptorSetLayout = device.createDescriptorSetLayout(descriptors)

  # TODO: Push constants
  # var pushConstant = VkPushConstantRange(
    # stageFlags: toBits shaderStage,
    # offset: 0,
    # size: 0,
  # )
  var descriptorSetLayouts: seq[VkDescriptorSetLayout] = @[result.descriptorSetLayout.vk]
  # var pushConstants: seq[VkPushConstantRange] = @[pushConstant]
  var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      setLayoutCount: uint32(descriptorSetLayouts.len),
      pSetLayouts: descriptorSetLayouts.toCPointer,
      # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.toCPointer,
    )
  checkVkResult vkCreatePipelineLayout(device.vk, addr(pipelineLayoutInfo), nil, addr(result.layout))

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
      logicOpEnable: false,
      attachmentCount: 1,
      pAttachments: addr(colorBlendAttachment),
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
      renderPass: renderPass,
      subpass: subpass,
      basePipelineHandle: VkPipeline(0),
      basePipelineIndex: -1,
    )
  checkVkResult vkCreateGraphicsPipelines(
    device.vk,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.vk)
  )
  result.descriptorPool = result.device.createDescriptorSetPool(@[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1'u32)])
  result.descriptorSets = result.descriptorPool.allocateDescriptorSet(result.descriptorSetLayout, inFlightFrames)
  discard result.uniforms # just for assertion
  result.setupUniforms(inFlightFrames=inFlightFrames)

proc updateUniforms*(pipeline: Pipeline, rootEntity: Entity, currentInFlight: int) =
  assert pipeline.vk.valid
  assert pipeline.uniformBuffers[currentInFlight].vk.valid

  var globalsByName: Table[string, DataValue]
  for component in allComponentsOfType[ShaderGlobal](rootEntity):
    globalsByName[component.name] = component.value

  var offset = 0'u64
  for uniform in pipeline.uniforms:
    assert uniform.thetype == globalsByName[uniform.name].thetype
    let (pdata, size) = globalsByName[uniform.name].getRawData()
    pipeline.uniformBuffers[currentInFlight].setData(pdata, size, offset)
    offset += size


proc destroy*(pipeline: var Pipeline) =
  assert pipeline.device.vk.valid
  assert pipeline.vk.valid
  assert pipeline.layout.valid
  assert pipeline.descriptorSetLayout.vk.valid

  for buffer in pipeline.uniformBuffers.mitems:
    assert buffer.vk.valid
    buffer.destroy()
  
  if pipeline.descriptorPool.vk.valid:
    pipeline.descriptorPool.destroy()
  pipeline.descriptorSetLayout.destroy()
  pipeline.device.vk.vkDestroyPipelineLayout(pipeline.layout, nil)
  pipeline.device.vk.vkDestroyPipeline(pipeline.vk, nil)
  pipeline.descriptorSetLayout.reset()
  pipeline.layout.reset()
  pipeline.vk.reset()
