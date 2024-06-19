import std/macros
import std/strformat
import std/typetraits

import semicongine/core/utils
import semicongine/core/imagetypes
import semicongine/core/vector
import semicongine/core/matrix
import semicongine/core/vulkanapi
import semicongine/vulkan/buffer

template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}
template DescriptorAttribute* {.pragma.}


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

template ForVertexDataFields*(inputData: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(inputData):
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        let `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = default(getElementType(value))
        let `isinstancename` {.inject.} = value.isInstanceAttribute()
        body

template ForDescriptorFields*(inputData: typed, fieldname, valuename, typename, countname, body: untyped): untyped =
  for theFieldname, value in fieldPairs(inputData):
    when hasCustomPragma(value, DescriptorAttribute):
      when not (
          typeof(value) is SupportedGPUType
          or (typeof(value) is array and elementType(value) is SupportedGPUType)
          or typeof(value) is Texture
      ):
        {.error: "field '" & theFieldname & "' needs to be a SupportedGPUType or an array of SupportedGPUType".}
      block:
        let `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = default(getElementType(value))

        # TODO
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER

        when typeof(value) is array:
          let `countname` {.inject.} = genericParams(typeof(value)).get(0)
        else:
          let `countname` {.inject.} = 1
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
  IndexType = enum
    None, UInt8, UInt16, UInt32
  RenderBuffers = object
    deviceBuffers: seq[Buffer]      # for fast reads
    hostVisibleBuffers: seq[Buffer] # for fast writes
  Renderable[TMesh, TInstance] = object
    vertexBuffers: seq[VkBuffer]
    bufferOffsets: seq[VkDeviceSize]
    instanceCount: uint32
    case indexType: IndexType
      of None:
        vertexCount: uint32
      else:
        indexBuffer: VkBuffer
        indexCount: uint32
        indexBufferOffset: VkDeviceSize
  Pipeline[TShaderInputs] = object
    pipeline: VkPipeline
    layout: VkPipelineLayout
    descriptorSets: array[2, seq[VkDescriptorSet]]
  ShaderSet[TShaderInputs] = object
    vertexShader: VkShaderModule
    fragmentShader: VkShaderModule
converter toVkIndexType(indexType: IndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of UInt8: VK_INDEX_TYPE_UINT8_EXT
    of UInt16: VK_INDEX_TYPE_UINT16
    of UInt32: VK_INDEX_TYPE_UINT32


proc CreatePipeline*[TShaderInputs](
  device: VkDevice,
  renderPass: VkRenderPass,
  shaderSet: ShaderSet[TShaderInputs],
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
): Pipeline[TShaderInputs] =
  # assumptions/limitations:
  # - we are only using vertex and fragment shaders (2 stages)
  # - we only support one subpass

  # CONTINUE HERE, WITH PIPELINE LAYOUT!!!!
  # Rely on TShaderInputs

  var layoutbindings: seq[VkDescriptorSetLayoutBinding]
  let descriptors = [
    (VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1), # more than 1 for arrays
    (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1),
  ]
  var descriptorBindingNumber = 0'u32
  ForDescriptorFields(default(TShaderInputs), fieldname, value, descriptorCount):
    layoutbindings.add VkDescriptorSetLayoutBinding(
      binding: descriptorBindingNumber,
      descriptorType: descriptorType,
      descriptorCount: descriptorCount,
      stageFlags: VK_SHADER_STAGE_ALL_GRAPHICS,
      pImmutableSamplers: nil,
    )
    inc descriptorBindingNumber
  var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount: uint32(layoutbindings.len),
    pBindings: layoutbindings.ToCPointer
  )
  var descriptorSetLayout: VkDescriptorSetLayout
  checkVkResult vkCreateDescriptorSetLayout(device.vk, addr(layoutCreateInfo), nil, addr(descriptorSetLayout))
  let pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount: 1,
    pSetLayouts: addr(descriptorSetLayout),
    # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.ToCPointer,
  )
  checkVkResult vkCreatePipelineLayout(device, addr(pipelineLayoutInfo), nil, addr(result.layout))

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
  ForVertexDataFields(default(TShaderInputs), fieldname, value, isInstanceAttr):
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

proc CreateRenderable[TMesh, TInstance](
  mesh: TMesh,
  instance: TInstance,
  buffers: RenderBuffers,
): Renderable[TMesh, TInstance] =
  result.indexType = None

proc Bind(pipeline: Pipeline, commandBuffer: VkCommandBuffer, currentFrameInFlight: int) =
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)
  commandBuffer.vkCmdBindDescriptorSets(
    VK_PIPELINE_BIND_POINT_GRAPHICS,
    pipeline.layout,
    0,
    pipeline.descriptorSets[currentFrameInFlight].len,
    pipeline.descriptorSets[currentFrameInFlight],
    0,
    nil,
  )

proc AssertCompatible(TShaderInputs, TMesh, TInstance, TGlobals: typedesc) =
  # assert seq-fields of TMesh|TInstance == seq-fields of TShaderInputs
  # assert normal fields of TMesh|Globals == normal fields of TShaderDescriptors
  for inputName, inputValue in default(TShaderInputs).fieldPairs:
    echo "checking shader input '" & inputName & "'"
    var foundField = false
    when hasCustomPragma(inputValue, VertexAttribute):
      echo "  is vertex attribute"
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == inputName:
          assert foundField == false, "Shader input '" & TShaderInputs.name & "." & inputName & "' has been found more than once"
          assert getElementType(meshValue) is typeof(inputValue), "Shader input " & TShaderInputs.name & "." & inputName & " is of type '" & typeof(inputValue).name & "' but mesh attribute is of type '" & getElementType(meshValue).name & "'"
          foundField = true
      assert foundField, "Shader input '" & TShaderInputs.name & "." & inputName & ": " & typeof(inputValue).name & "' not found in '" & TMesh.name & "'"
    elif hasCustomPragma(inputValue, InstanceAttribute):
      echo "  is instance attribute"
      for instanceName, instanceValue in default(TInstance).fieldPairs:
        when instanceName == inputName:
          assert foundField == false, "Shader input '" & TShaderInputs.name & "." & inputName & "' has been found more than once"
          assert getElementType(instanceValue) is typeof(inputValue), "Shader input " & TShaderInputs.name & "." & inputName & " is of type '" & typeof(inputValue).name & "' but instance attribute is of type '" & getElementType(instanceValue).name & "'"
          foundField = true
      assert foundField, "Shader input '" & TShaderInputs.name & "." & inputName & ": " & typeof(inputValue).name & "' not found in '" & TInstance.name & "'"
    elif hasCustomPragma(inputValue, DescriptorAttribute):
      echo "  is descriptor attribute"
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == inputName:
          assert foundField == false, "Shader input '" & TShaderInputs.name & "." & inputName & "' has been found more than once"
          assert typeof(meshValue) is typeof(inputValue), "Shader input " & TShaderInputs.name & "." & inputName & " is of type '" & typeof(inputValue).name & "' but mesh attribute is of type '" & getElementType(meshValue).name & "'"
          foundField = true
      for globalName, globalValue in default(TGlobals).fieldPairs:
        when globalName == inputName:
          assert foundField == false, "Shader input '" & TShaderInputs.name & "." & inputName & "' has been found more than once"
          assert typeof(globalValue) is typeof(inputValue), "Shader input " & TShaderInputs.name & "." & inputName & " is of type '" & typeof(inputValue).name & "' but global attribute is of type '" & typeof(globalValue).name & "'"
          foundField = true
      assert foundField, "Shader input '" & TShaderInputs.name & "." & inputName & ": " & typeof(inputValue).name & "' not found in '" & TMesh.name & "|" & TGlobals.name & "'"
    echo "  found"


proc Render[TShaderInputs, TMesh, TInstance, TGlobals](
  pipeline: Pipeline[TShaderInputs],
  renderable: Renderable[TMesh, TInstance],
  globals: TGlobals,
  commandBuffer: VkCommandBuffer,
) =
  static:
    AssertCompatible(TShaderInputs, TMesh, TInstance, TGlobals)
  commandBuffer.vkCmdBindVertexBuffers(
    firstBinding = 0'u32,
    bindingCount = uint32(renderable.vertexBuffers.len),
    pBuffers = renderable.vertexBuffers.ToCPointer(),
    pOffsets = renderable.bufferOffsets.ToCPointer()
  )
  if renderable.indexType != None:
    commandBuffer.vkCmdBindIndexBuffer(
      renderable.indexBuffer,
      renderable.indexBufferOffset,
      renderable.indexType,
    )
    commandBuffer.vkCmdDrawIndexed(
      indexCount = renderable.indexCount,
      instanceCount = renderable.instanceCount,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0
    )
  else:
    commandBuffer.vkCmdDraw(
      vertexCount = renderable.vertexCount,
      instanceCount = renderable.instanceCount,
      firstVertex = 0,
      firstInstance = 0
    )

when isMainModule:
  type
    MeshA = object
      position: seq[Vec3f]
      transparency: float
    InstanceA = object
      transform: seq[Mat4]
      position: seq[Vec3f]
    Globals = object
      color: Vec4f

    ShaderInputsA = object
      position {.VertexAttribute.}: Vec3f
      transform {.InstanceAttribute.}: Mat4
      color {.DescriptorAttribute.}: Vec4f

  var p: Pipeline[ShaderInputsA]
  var r: Renderable[MeshA, InstanceA]
  var g: Globals
  var s: ShaderSet[ShaderInputsA]

  var p1 = CreatePipeline(device = VkDevice(0), renderPass = VkRenderPass(0), shaderSet = s)
  Render(p, r, g, VkCommandBuffer(0))
