import std/tables
import std/sequtils
import std/strformat

import ../core
import ./device
import ./descriptor
import ./shader
import ./buffer
import ./image

type
  ShaderPipeline* = object
    device*: Device
    vk*: VkPipeline
    layout*: VkPipelineLayout
    shaderConfiguration*: ShaderConfiguration
    shaderModules*: (ShaderModule, ShaderModule)
    descriptorSetLayout*: DescriptorSetLayout

func inputs*(pipeline: ShaderPipeline): seq[ShaderAttribute] =
  pipeline.shaderConfiguration.inputs

func uniforms*(pipeline: ShaderPipeline): seq[ShaderAttribute] =
  pipeline.shaderConfiguration.uniforms

func samplers*(pipeline: ShaderPipeline): seq[ShaderAttribute] =
  pipeline.shaderConfiguration.samplers

proc setupDescriptors*(pipeline: ShaderPipeline, descriptorPool: DescriptorPool, buffers: seq[Buffer], textures: var Table[string, seq[VulkanTexture]], inFlightFrames: int, emptyTexture: VulkanTexture): seq[DescriptorSet] =
  assert pipeline.vk.valid
  assert buffers.len == 0 or buffers.len == inFlightFrames # need to guard against this in case we have no uniforms, then we also create no buffers

  result = descriptorPool.allocateDescriptorSet(pipeline.descriptorSetLayout, inFlightFrames)

  for i in 0 ..< inFlightFrames:
    var offset = 0'u64
    # first descriptor is always uniform for globals, match should be better somehow
    for descriptor in result[i].layout.descriptors.mitems:
      if descriptor.thetype == Uniform and buffers.len > 0:
        let size = descriptor.size
        descriptor.buffer = buffers[i]
        descriptor.offset = offset
        descriptor.size = size
        offset += size
      elif descriptor.thetype == ImageSampler:
        if not (descriptor.name in textures):
          raise newException(Exception, &"Missing shader texture in scene: {descriptor.name}, available are {textures.keys.toSeq}")

        for textureIndex in 0 ..< int(descriptor.count):
          if textureIndex < textures[descriptor.name].len:
            descriptor.imageviews.add textures[descriptor.name][textureIndex].imageView
            descriptor.samplers.add textures[descriptor.name][textureIndex].sampler
          else:
            descriptor.imageviews.add emptyTexture.imageView
            descriptor.samplers.add emptyTexture.sampler

proc createPipeline*(device: Device, renderPass: VkRenderPass, shaderConfiguration: ShaderConfiguration, inFlightFrames: int, subpass = 0'u32, backFaceCulling = true): ShaderPipeline =
  assert renderPass.valid
  assert device.vk.valid

  result.device = device
  result.shaderModules = device.createShaderModules(shaderConfiguration)
  result.shaderConfiguration = shaderConfiguration

  var descriptors: seq[Descriptor]
  if result.shaderConfiguration.uniforms.len > 0:
    descriptors.add Descriptor(
      name: "Uniforms",
      thetype: Uniform,
      count: 1,
      stages: @[VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT],
      size: result.shaderConfiguration.uniforms.size(),
    )
  for sampler in result.shaderConfiguration.samplers:
    descriptors.add Descriptor(
      name: sampler.name,
      thetype: ImageSampler,
      count: (if sampler.arrayCount == 0: 1 else: sampler.arrayCount),
      stages: @[VK_SHADER_STAGE_VERTEX_BIT, VK_SHADER_STAGE_FRAGMENT_BIT],
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
    vertexInputInfo = result.shaderConfiguration.getVertexInputInfo(bindings, attributes)
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
      cullMode: if backFaceCulling: toBits [VK_CULL_MODE_BACK_BIT] else: VkCullModeFlags(0),
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
    stages = @[result.shaderModules[0].getPipelineInfo(), result.shaderModules[1].getPipelineInfo()]
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

  discard result.uniforms # just for assertion


proc destroy*(pipeline: var ShaderPipeline) =
  assert pipeline.device.vk.valid
  assert pipeline.vk.valid
  assert pipeline.layout.valid
  assert pipeline.descriptorSetLayout.vk.valid

  pipeline.shaderModules[0].destroy()
  pipeline.shaderModules[1].destroy()
  pipeline.descriptorSetLayout.destroy()
  pipeline.device.vk.vkDestroyPipelineLayout(pipeline.layout, nil)
  pipeline.device.vk.vkDestroyPipeline(pipeline.vk, nil)
  pipeline.descriptorSetLayout.reset()
  pipeline.layout.reset()
  pipeline.vk.reset()
