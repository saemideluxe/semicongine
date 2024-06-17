import std/macros
import std/typetraits

import semicongine/core/vector
import semicongine/core/matrix
import semicongine/core/vulkanapi

template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}

type
  SupportedGPUType* = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]

func VkType[T: SupportedGPUType](value: T): VkFormat =
  when T is float32: VK_FORMAT_R32_SFLOAT
  elif T is float64: VK_FORMAT_R64_SFLOAT
  elif T is int8: VK_FORMAT_R8_SINT
  elif T is int16: VK_FORMAT_R16_SINT
  elif T is int32: VK_FORMAT_R32_SINT
  elif T is int64: VK_FORMAT_R64_SINT
  elif T is uint8: VK_FORMAT_R8_UINT
  elif T is uint16: VK_FORMAT_R16_UINT
  elif T is uint32: VK_FORMAT_R32_UINT
  elif T is uint64: VK_FORMAT_R64_UINT
  elif T is TVec2[int32]: VK_FORMAT_R32G32_SINT
  elif T is TVec2[int64]: VK_FORMAT_R64G64_SINT
  elif T is TVec3[int32]: VK_FORMAT_R32G32B32_SINT
  elif T is TVec3[int64]: VK_FORMAT_R64G64B64_SINT
  elif T is TVec4[int32]: VK_FORMAT_R32G32B32A32_SINT
  elif T is TVec4[int64]: VK_FORMAT_R64G64B64A64_SINT
  elif T is TVec2[uint32]: VK_FORMAT_R32G32_UINT
  elif T is TVec2[uint64]: VK_FORMAT_R64G64_UINT
  elif T is TVec3[uint32]: VK_FORMAT_R32G32B32_UINT
  elif T is TVec3[uint64]: VK_FORMAT_R64G64B64_UINT
  elif T is TVec4[uint32]: VK_FORMAT_R32G32B32A32_UINT
  elif T is TVec4[uint64]: VK_FORMAT_R64G64B64A64_UINT
  elif T is TVec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TVec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TVec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TVec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TVec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TVec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  elif T is Mat2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is Mat2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is Mat23[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is Mat23[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is Mat32[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is Mat32[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is Mat3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is Mat3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is Mat34[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is Mat34[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  elif T is Mat43[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is Mat43[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is Mat4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is Mat4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  else: {.error: "Unsupported data type on GPU".}

template getElementType(field: typed): untyped =
  when not (typeof(field) is seq or typeof(field) is array):
    {.error: "getElementType can only be used with seq or array".}
  genericParams(typeof(field)).get(0)

proc isVertexAttribute[T](value: T): bool {.compileTime.} =
  hasCustomPragma(T, VertexAttribute)

proc isInstanceAttribute[T](value: T): bool {.compileTime.} =
  hasCustomPragma(T, InstanceAttribute)

template ForAttributeFields*(inputData: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(inputData):
    when isVertexAttribute(value) or isInstanceAttribute(value):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        let `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = default(getElementType(value))
        let `isinstancename` {.inject.} = value.isInstanceAttribute()
        body

func NumberOfVertexInputAttributeDescriptors[T: SupportedGPUType](value: T): uint32 =
  when T is TMat2[float32] or T is TMat2[float64] or T is TMat23[float32] or T is TMat23[float64]:
    2
  elif T is TMat32[float32] or T is TMat32[float64] or T is TMat3[float32] or T is TMat3[float64] or T is TMat34[float32] or T is TMat34[float64]:
    3
  elif T is TMat43[float32] or T is TMat43[float64] or T is TMat4[float32] or T is TMat4[float64]:
    4
  else:
    1

func NLocationSlots[T: SupportedGPUType](value: T): uint32 =
  #[
  single location:
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  when typeof(value) is TVec3 and sizeof(getElementType(value)) == 8:
    return 2
  elif typeof(value) is TVec4 and sizeof(getElementType(value)) == 8:
    return 2
  else:
    return 1


type
  Renderable[IndexType: static VkIndexType] = object
    buffers: seq[VkBuffer]
    offsets: seq[VkDeviceSize]
    instanceCount: uint32
    when IndexType == VK_INDEX_TYPE_NONE_KHR:
      vertexCount: uint32
    else:
      indexBuffer: VkBuffer
      indexCount: uint32
      indexBufferOffset: VkDeviceSize
  Pipeline = object
    pipeline: VkPipeline
    layout: VkPipelineLayout
    descriptorSets: array[2, seq[VkDescriptorSet]]
  ShaderSet[ShaderInputType, ShaderDescriptorType] = object
    vertexShader: VkShaderModule
    fragmentShader: VkShaderModule
    # TODO: I think this needs more fields?

proc CreatePipeline*[ShaderInputType, ShaderDescriptorType](
  device: VkDevice,
  renderPass: VkRenderPass,
  shaderSet: ShaderSet[ShaderInputType, ShaderDescriptorType],
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
): Pipeline =
  # assumptions/limitations:
  # - we are only using vertex and fragment shaders (2 stages)
  # - we only support one subpass

  # CONTINUE HERE, WITH PIPELINE LAYOUT!!!!
  # Rely on ShaderDescriptorType
  checkVkResult vkCreatePipelineLayout(device.vk, addr(pipelineLayoutInfo), nil, addr(result.layout))

  let stages = [
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_VERTEX_BIT,
      module: shaderSet.vertexShader,
      pName: "main",
    ),
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_FRAGMENT_BIT,
      module: shaderSet.fragmentShader,
      pName: "main",
    ),
  ]
  let
    bindings: var seq[VkVertexInputBindingDescription]
    attributes: var seq[VkVertexInputAttributeDescription]
  var inputBindingNumber = 0'u32
  var inputLocationNumber = 0'u32
  ForAttributeFields(default(ShaderInputType), fieldname, value, isInstanceAttr):
    bindings.add VkVertexInputBindingDescription(
      binding: inputBindingNumber,
      stride: sizeof(value).uint32,
      inputRate: if isInstanceAttr: VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    let perDescriptorSize = sizeof(value).uint32 div NumberOfVertexInputAttributeDescriptors(value)
    for i in 0'u32 ..< NumberOfVertexInputAttributeDescriptors(value):
      attributes.add VkVertexInputAttributeDescription(
        binding: inputBindingNumber,
        inputLocationNumber: inputLocationNumber,
        format: VkType(value),
        offset: i * perDescriptorSize,
      )
      inputLocationNumber += NLocationSlots(value)
    inc inputBindingNumber

  let
    vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
      vertexBindingDescriptionCount: uint32(bindings.len),
      pVertexBindingDescriptions: bindings.ToCPointer,
      vertexAttributeDescriptionCount: uint32(attributes.len),
      pVertexAttributeDescriptions: attributes.ToCPointer,
    )
    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: topology,
      primitiveRestartEnable: false,
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
      polygonMode: polygonMode,
      lineWidth: 1.0,
      cullMode: toBits [cullMode],
      frontFace: frontFace,
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
    dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
    dynamicState = VkPipelineDynamicStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
      dynamicStateCount: dynamicStates.len.uint32,
      pDynamicStates: dynamicStates.ToCPointer,
    )
  let createInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount: 2,
    pStages: addr(stages),
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
    addr(createInfo),
    nil,
    addr(result.pipeline)
  )


proc Render*[IndexType: static VkIndexType](renderable: Renderable[IndexType], commandBuffer: VkCommandBuffer, pipeline: Pipeline, frameInFlight: int) =
  assert 0 <= frameInFlight and frameInFlight < 2
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)
  commandBuffer.vkCmdBindDescriptorSets(
    VK_PIPELINE_BIND_POINT_GRAPHICS,
    pipeline.layout,
    0,
    pipeline.descriptorSets[frameInFlight].len,
    pipeline.descriptorSets[frameInFlight],
    0,
    nil,
  )
  commandBuffer.vkCmdBindVertexBuffers(
    firstBinding = 0'u32,
    bindingCount = uint32(renderable.buffers.len),
    pBuffers = renderable.buffers.ToCPointer(),
    pOffsets = renderable.offsets.ToCPointer()
  )
  when IndexType != VK_INDEX_TYPE_NONE_KHR:
    commandBuffer.vkCmdBindIndexBuffer(
      renderable.indexBuffer,
      renderable.indexBufferOffset,
      IndexType,
    )
    commandBuffer.vkCmdDrawIndexed(
      indexCount = drawable.indexCount,
      instanceCount = drawable.instanceCount,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0
    )
  else:
    commandBuffer.vkCmdDraw(
      vertexCount = drawable.vertexCount,
      instanceCount = drawable.instanceCount,
      firstVertex = 0,
      firstInstance = 0
    )
