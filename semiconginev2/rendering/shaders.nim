func GlslType[T: SupportedGPUType|Texture](value: T): string =
  when T is float32: "float"
  elif T is float64: "double"
  elif T is int8 or T is int16 or T is int32 or T is int64: "int"
  elif T is uint8 or T is uint16 or T is uint32 or T is uint64: "uint"
  elif T is TVec2[int32]: "ivec2"
  elif T is TVec2[int64]: "ivec2"
  elif T is TVec3[int32]: "ivec3"
  elif T is TVec3[int64]: "ivec3"
  elif T is TVec4[int32]: "ivec4"
  elif T is TVec4[int64]: "ivec4"
  elif T is TVec2[uint32]: "uvec2"
  elif T is TVec2[uint64]: "uvec2"
  elif T is TVec3[uint32]: "uvec3"
  elif T is TVec3[uint64]: "uvec3"
  elif T is TVec4[uint32]: "uvec4"
  elif T is TVec4[uint64]: "uvec4"
  elif T is TVec2[float32]: "vec2"
  elif T is TVec2[float64]: "dvec2"
  elif T is TVec3[float32]: "vec3"
  elif T is TVec3[float64]: "dvec3"
  elif T is TVec4[float32]: "vec4"
  elif T is TVec4[float64]: "dvec4"
  elif T is TMat2[float32]: "mat2"
  elif T is TMat2[float64]: "dmat2"
  elif T is TMat23[float32]: "mat23"
  elif T is TMat23[float64]: "dmat23"
  elif T is TMat32[float32]: "mat32"
  elif T is TMat32[float64]: "dmat32"
  elif T is TMat3[float32]: "mat3"
  elif T is TMat3[float64]: "dmat3"
  elif T is TMat34[float32]: "mat34"
  elif T is TMat34[float64]: "dmat34"
  elif T is TMat43[float32]: "mat43"
  elif T is TMat43[float64]: "dmat43"
  elif T is TMat4[float32]: "mat4"
  elif T is TMat4[float64]: "dmat4"
  elif T is Texture: "sampler2D"
  else: {.error: "Unsupported data type on GPU".}

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
  elif T is TMat2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TMat2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TMat23[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat23[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat32[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TMat32[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TMat3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat34[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TMat34[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  elif T is TMat43[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat43[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TMat4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  else: {.error: "Unsupported data type on GPU".}


func NumberOfVertexInputAttributeDescriptors[T: SupportedGPUType|Texture](value: T): uint32 =
  when T is TMat2[float32] or T is TMat2[float64] or T is TMat23[float32] or T is TMat23[float64]:
    2
  elif T is TMat32[float32] or T is TMat32[float64] or T is TMat3[float32] or T is TMat3[float64] or T is TMat34[float32] or T is TMat34[float64]:
    3
  elif T is TMat43[float32] or T is TMat43[float64] or T is TMat4[float32] or T is TMat4[float64]:
    4
  else:
    1

func NLocationSlots[T: SupportedGPUType|Texture](value: T): uint32 =
  #[
  single location:
    - any scalar
    - any 16-bit vector
    - any 32-bit vector
    - any 64-bit vector that has max. 2 components
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  when T is TVec3[int64] or
    T is TVec4[int64] or
    T is TVec3[uint64] or
    T is TVec4[uint64] or
    T is TVec3[float64] or
    T is TVec4[float64] or
    T is TMat23[float64] or
    T is TMat3[float64] or
    T is TMat34[float64] or
    T is TMat43[float64] or
    T is TMat4[float64]:
    return 2
  else:
    return 1

proc generateShaderSource[TShader](shader: TShader): (string, string) {.compileTime.} =
  const GLSL_VERSION = "450"
  var vsInput: seq[string]
  var vsOutput: seq[string]
  var fsInput: seq[string]
  var fsOutput: seq[string]
  var uniforms: seq[string]
  var samplers: seq[string]
  var vsInputLocation = 0'u32
  var passLocation = 0
  var fsOutputLocation = 0

  var sawDescriptorSets = false
  for fieldname, value in fieldPairs(shader):
    # vertex shader inputs
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      assert typeof(value) is SupportedGPUType
      vsInput.add "layout(location = " & $vsInputLocation & ") in " & GlslType(value) & " " & fieldname & ";"
      for j in 0 ..< NumberOfVertexInputAttributeDescriptors(value):
        vsInputLocation += NLocationSlots(value)

    # intermediate values, passed between shaders
    elif hasCustomPragma(value, Pass) or hasCustomPragma(value, PassFlat):
      let flat = if hasCustomPragma(value, PassFlat): "flat " else: ""
      vsOutput.add "layout(location = " & $passLocation & ") " & flat & "out " & GlslType(value) & " " & fieldname & ";"
      fsInput.add "layout(location = " & $passLocation & ") " & flat & "in " & GlslType(value) & " " & fieldname & ";"
      passLocation.inc

    # fragment shader output
    elif hasCustomPragma(value, ShaderOutput):
      fsOutput.add &"layout(location = " & $fsOutputLocation & ") out " & GlslType(value) & " " & fieldname & ";"
      fsOutputLocation.inc

    # descriptor sets
    # need to consider 4 cases: uniform block, texture, uniform block array, texture array
    elif hasCustomPragma(value, DescriptorSets):
      assert not sawDescriptorSets, "Only one field with pragma DescriptorSets allowed per shader"
      assert typeof(value) is tuple, "Descriptor field '" & fieldname & "' must be of type tuple"
      assert tupleLen(typeof(value)) <= MAX_DESCRIPTORSETS, typetraits.name(TShader) & ": maximum " & $MAX_DESCRIPTORSETS & " allowed"
      sawDescriptorSets = true
      var descriptorSetIndex = 0
      for descriptor in value.fields:

        var descriptorBinding = 0

        for descriptorName, descriptorValue in fieldPairs(descriptor):

          when typeof(descriptorValue) is Texture:
            samplers.add "layout(set=" & $descriptorSetIndex & ", binding = " & $descriptorBinding & ") uniform " & GlslType(descriptorValue) & " " & descriptorName & ";"
            descriptorBinding.inc

          elif typeof(descriptorValue) is GPUValue:

            uniforms.add "layout(set=" & $descriptorSetIndex & ", binding = " & $descriptorBinding & ") uniform T" & descriptorName & " {"
            when typeof(descriptorValue.data) is object:

              for blockFieldName, blockFieldValue in descriptorValue.data.fieldPairs():
                assert typeof(blockFieldValue) is SupportedGPUType, "uniform block field '" & blockFieldName & "' is not a SupportedGPUType"
                uniforms.add "  " & GlslType(blockFieldValue) & " " & blockFieldName & ";"
              uniforms.add "} " & descriptorName & ";"

            else:
              {.error: "Unsupported shader descriptor field " & descriptorName & " (must be object)".}
            descriptorBinding.inc

          elif typeof(descriptorValue) is array:

            when elementType(descriptorValue) is Texture:

              let arrayDecl = "[" & $typeof(descriptorValue).len & "]"
              samplers.add "layout(set=" & $descriptorSetIndex & ", binding = " & $descriptorBinding & ") uniform " & GlslType(default(elementType(descriptorValue))) & " " & descriptorName & "" & arrayDecl & ";"
              descriptorBinding.inc

            elif elementType(descriptorValue) is GPUValue:

              uniforms.add "layout(set=" & $descriptorSetIndex & ", binding = " & $descriptorBinding & ") uniform T" & descriptorName & " {"

              for blockFieldName, blockFieldValue in default(elementType(descriptorValue)).data.fieldPairs():
                assert typeof(blockFieldValue) is SupportedGPUType, "uniform block field '" & blockFieldName & "' is not a SupportedGPUType"
                uniforms.add "  " & GlslType(blockFieldValue) & " " & blockFieldName & ";"
              uniforms.add "} " & descriptorName & "[" & $descriptorValue.len & "];"
              descriptorBinding.inc

            else:
              {.error: "Unsupported shader descriptor field " & descriptorName.}

        descriptorSetIndex.inc
    elif fieldname in ["vertexCode", "fragmentCode"]:
      discard
    else:
      {.error: "Unsupported shader field '" & typetraits.name(TShader) & "." & fieldname & "' of type " & typetraits.name(typeof(value)).}

  result[0] = (@[&"#version {GLSL_VERSION}", "#extension GL_EXT_scalar_block_layout : require", ""] &
    vsInput &
    uniforms &
    samplers &
    vsOutput &
    @[shader.vertexCode]).join("\n")

  result[1] = (@[&"#version {GLSL_VERSION}", "#extension GL_EXT_scalar_block_layout : require", ""] &
    fsInput &
    uniforms &
    samplers &
    fsOutput &
    @[shader.fragmentCode]).join("\n")

proc compileGlslToSPIRV(stage: VkShaderStageFlagBits, shaderSource: string): seq[uint32] {.compileTime.} =
  func stage2string(stage: VkShaderStageFlagBits): string {.compileTime.} =
    case stage
    of VK_SHADER_STAGE_VERTEX_BIT: "vert"
    of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
    of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
    of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
    of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
    of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
    else: ""

  when defined(nimcheck): # will not run if nimcheck is running
    return result

  let
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"

  if not shaderfile.fileExists:
    echo "shader of type ", stage
    for i, line in enumerate(shaderSource.splitlines()):
      echo "  ", i + 1, " ", line
    var glslExe = currentSourcePath.parentDir.parentDir.parentDir / "tools" / "glslangValidator"
    when defined(windows):
      glslExe = glslExe & "." & ExeExt
    let command = &"{glslExe} --entry-point main -V --stdin -S {stagename} -o {shaderfile}"
    echo "run: ", command
    discard StaticExecChecked(
        command = command,
        input = shaderSource
    )
  else:
    echo &"shaderfile {shaderfile} is up-to-date"

  when defined(mingw) and defined(linux): # required for crosscompilation, path separators get messed up
    let shaderbinary = staticRead shaderfile.replace("\\", "/")
  else:
    let shaderbinary = staticRead shaderfile

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl 0) or
      (uint32(shaderbinary[i + 1]) shl 8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4


proc CompileShader[TShader](shader: static TShader): (VkShaderModule, VkShaderModule) =
  const (vertexShaderSource, fragmentShaderSource) = generateShaderSource(shader)

  let vertexBinary = compileGlslToSPIRV(VK_SHADER_STAGE_VERTEX_BIT, vertexShaderSource)
  let fragmentBinary = compileGlslToSPIRV(VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShaderSource)

  var createInfoVertex = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(vertexBinary.len * sizeof(uint32)),
    pCode: vertexBinary.ToCPointer,
  )
  checkVkResult vulkan.device.vkCreateShaderModule(addr(createInfoVertex), nil, addr(result[0]))
  var createInfoFragment = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(fragmentBinary.len * sizeof(uint32)),
    pCode: fragmentBinary.ToCPointer,
  )
  checkVkResult vulkan.device.vkCreateShaderModule(addr(createInfoFragment), nil, addr(result[1]))

template ForVertexDataFields(shader: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(shader):
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        const `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = value
        const `isinstancename` {.inject.} = hasCustomPragma(value, InstanceAttribute)
        body

proc GetDescriptorSetCount[TShader](): uint32 =
  for _, value in fieldPairs(default(TShader)):
    when hasCustomPragma(value, DescriptorSets):
      return tupleLen(typeof(value)).uint32

proc CreateDescriptorSetLayouts[TShader](): array[MAX_DESCRIPTORSETS, VkDescriptorSetLayout] =
  var setNumber: int
  for _, value in fieldPairs(default(TShader)):
    when hasCustomPragma(value, DescriptorSets):
      for descriptorSet in value.fields:
        var layoutbindings: seq[VkDescriptorSetLayoutBinding]
        ForDescriptorFields(descriptorSet, fieldName, fieldValue, descriptorType, descriptorCount, descriptorBindingNumber):
          layoutbindings.add VkDescriptorSetLayoutBinding(
            binding: descriptorBindingNumber,
            descriptorType: descriptorType,
            descriptorCount: descriptorCount,
            stageFlags: VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
            pImmutableSamplers: nil,
          )
        var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
          sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
          bindingCount: layoutbindings.len.uint32,
          pBindings: layoutbindings.ToCPointer
        )
        checkVkResult vkCreateDescriptorSetLayout(
          vulkan.device,
          addr(layoutCreateInfo),
          nil,
          addr(result[setNumber])
        )
        inc setNumber

proc CreatePipeline*[TShader](
  renderPass: VkRenderPass,
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
  descriptorPoolLimit = 1024,
  samples = VK_SAMPLE_COUNT_1_BIT,
): Pipeline[TShader] =
  # create pipeline

  const shader = default(TShader)
  (result.vertexShaderModule, result.fragmentShaderModule) = CompileShader(shader)

  var nSets = GetDescriptorSetCount[TShader]()
  result.descriptorSetLayouts = CreateDescriptorSetLayouts[TShader]()
  let pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount: nSets,
    pSetLayouts: if nSets == 0: nil else: result.descriptorSetLayouts.ToCPointer,
    # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.ToCPointer,
  )
  checkVkResult vkCreatePipelineLayout(vulkan.device, addr(pipelineLayoutInfo), nil, addr(result.layout))

  let stages = [
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_VERTEX_BIT,
      module: result.vertexShaderModule,
      pName: "main",
    ),
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_FRAGMENT_BIT,
      module: result.fragmentShaderModule,
      pName: "main",
    ),
  ]
  var
    bindings: seq[VkVertexInputBindingDescription]
    attributes: seq[VkVertexInputAttributeDescription]
  var inputBindingNumber = 0'u32
  var location = 0'u32
  ForVertexDataFields(default(TShader), fieldname, value, isInstanceAttr):
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
        location: location,
        format: VkType(value),
        offset: i * perDescriptorSize,
      )
      location += NLocationSlots(value)
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
      rasterizationSamples: samples,
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
    pStages: stages.ToCPointer,
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
    vulkan.device,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.vk)
  )

template WithPipeline*(commandbuffer: VkCommandBuffer, pipeline: Pipeline, body: untyped): untyped =
  block:
    vkCmdBindPipeline(commandbuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.vk)
    body

proc DestroyPipeline*(pipeline: Pipeline) =

  for descriptorSetLayout in pipeline.descriptorSetLayouts:
    vkDestroyDescriptorSetLayout(vulkan.device, descriptorSetLayout, nil)

  vkDestroyShaderModule(vulkan.device, pipeline.vertexShaderModule, nil)
  vkDestroyShaderModule(vulkan.device, pipeline.fragmentShaderModule, nil)
  vkDestroyPipelineLayout(vulkan.device, pipeline.layout, nil)
  vkDestroyPipeline(vulkan.device, pipeline.vk, nil)
