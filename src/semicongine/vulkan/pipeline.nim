import std/tables
import std/strformat
import std/sequtils

import ./api
import ./device
import ./descriptor
import ./shader
import ./buffer
import ./utils
import ./image

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

proc setupDescriptors*(pipeline: var Pipeline, buffers: seq[Buffer], textures: Table[string, seq[Texture]], inFlightFrames: int) =
  assert pipeline.vk.valid
  assert buffers.len == 0 or buffers.len == inFlightFrames # need to guard against this in case we have no uniforms, then we also create no buffers
  assert pipeline.descriptorSets.len > 0

  for i in 0 ..< inFlightFrames:
    var offset = 0'u64
    # first descriptor is always uniform for globals, match should be better somehow
    for descriptor in pipeline.descriptorSets[i].layout.descriptors.mitems:
      if descriptor.thetype == Uniform and buffers.len > 0:
        let size = VkDeviceSize(descriptor.itemsize * descriptor.count)
        descriptor.buffer = buffers[i]
        descriptor.offset = offset
        descriptor.size = size
        offset += size
      elif descriptor.thetype == ImageSampler:
        if not (descriptor.name in textures):
          raise newException(Exception, "Missing shader texture in scene: " & descriptor.name)
        if uint32(textures[descriptor.name].len) != descriptor.count:
          raise newException(Exception, &"Incorrect number of textures in array for {descriptor.name}: has {textures[descriptor.name].len} but needs {descriptor.count}")
        for t in textures[descriptor.name]:
          descriptor.imageviews.add t.imageView
          descriptor.samplers.add t.sampler

proc createPipeline*(device: Device, renderPass: VkRenderPass, vertexCode: ShaderCode, fragmentCode: ShaderCode, inFlightFrames: int, subpass = 0'u32): Pipeline =
  assert renderPass.valid
  assert device.vk.valid

  var
    vertexShader = device.createShaderModule(vertexCode)
    fragmentShader = device.createShaderModule(fragmentCode)
  assert vertexShader.stage == VK_SHADER_STAGE_VERTEX_BIT
  assert fragmentShader.stage == VK_SHADER_STAGE_FRAGMENT_BIT
  assert vertexShader.outputs == fragmentShader.inputs
  assert vertexShader.uniforms == fragmentShader.uniforms
  assert vertexShader.samplers == fragmentShader.samplers

  result.device = device
  result.shaders = @[vertexShader, fragmentShader]
  
  var descriptors: seq[Descriptor]

  if vertexCode.uniforms.len > 0:
    for uniform in vertexCode.uniforms:
      assert uniform.arrayCount == 0, "arrays not yet supported for uniforms"
    descriptors.add Descriptor(
      name: "Uniforms",
      thetype: Uniform,
      count: 1,
      stages: @[VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT],
      itemsize: vertexShader.uniforms.size(),
    )
  for sampler in vertexShader.samplers:
    descriptors.add Descriptor(
      name: sampler.name,
      thetype: ImageSampler,
      count: (if sampler.arrayCount == 0: 1 else: sampler.arrayCount),
      stages: @[VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT],
      itemsize: 0,
    )
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
  var poolsizes = @[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, uint32(inFlightFrames))]
  if vertexShader.samplers.len > 0:
    poolsizes.add (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, uint32(inFlightFrames * vertexShader.samplers.len))

  result.descriptorPool = result.device.createDescriptorSetPool(poolsizes)
  result.descriptorSets = result.descriptorPool.allocateDescriptorSet(result.descriptorSetLayout, inFlightFrames)
  discard result.uniforms # just for assertion


proc destroy*(pipeline: var Pipeline) =
  assert pipeline.device.vk.valid
  assert pipeline.vk.valid
  assert pipeline.layout.valid
  assert pipeline.descriptorSetLayout.vk.valid

  if pipeline.descriptorPool.vk.valid:
    pipeline.descriptorPool.destroy()

  for shader in pipeline.shaders.mitems:
    shader.destroy()
  pipeline.descriptorSetLayout.destroy()
  pipeline.device.vk.vkDestroyPipelineLayout(pipeline.layout, nil)
  pipeline.device.vk.vkDestroyPipeline(pipeline.vk, nil)
  pipeline.descriptorSetLayout.reset()
  pipeline.layout.reset()
  pipeline.vk.reset()
