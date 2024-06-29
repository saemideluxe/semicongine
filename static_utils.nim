import std/os
import std/enumerate
import std/hashes
import std/macros
import std/strformat
import std/strutils
import std/sequtils
import std/typetraits as tt

import semicongine/core/utils
import semicongine/core/imagetypes
import semicongine/core/vector
import semicongine/core/matrix
import semicongine/core/vulkanapi
import semicongine/vulkan/buffer

template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}
template Pass* {.pragma.}
template PassFlat* {.pragma.}
template ShaderOutput* {.pragma.}

const INFLIGHTFRAMES = 2'u32
type
  SupportedGPUType* = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]
  ShaderObject*[TShader] = object
    vertexShader: VkShaderModule
    fragmentShader: VkShaderModule

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

template ForVertexDataFields*(inputData: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(inputData):
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        let `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = value
        let `isinstancename` {.inject.} = hasCustomPragma(value, InstanceAttribute)
        body

template ForDescriptorFields*(inputData: typed, typename, countname, bindingNumber, body: untyped): untyped =
  var `bindingNumber` {.inject.} = 1'u32
  for theFieldname, value in fieldPairs(inputData):
    when typeof(value) is Texture:
      block:
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        let `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(value) is object:
      block:
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        let `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(value) is array:
      when elementType(value) is Texture:
        block:
          let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
          let `countname` {.inject.} = uint32(typeof(value).len)
          body
          `bindingNumber`.inc
      elif elementType(value) is object:
        block:
          let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
          let `countname` {.inject.} = uint32(typeof(value).len)
          body
          `bindingNumber`.inc

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
  Pipeline[TShader] = object
    pipeline: VkPipeline
    layout: VkPipelineLayout
    descriptorSets: array[INFLIGHTFRAMES.int, VkDescriptorSet]

converter toVkIndexType(indexType: IndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of UInt8: VK_INDEX_TYPE_UINT8_EXT
    of UInt16: VK_INDEX_TYPE_UINT16
    of UInt32: VK_INDEX_TYPE_UINT32

proc CreateRenderPass*(
  device: VkDevice,
  format: VkFormat,
): VkRenderPass =

  var
    attachments = @[VkAttachmentDescription(
        format: format,
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )]
    dependencies = @[VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT],
      srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
      dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT],
      dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
    )]
    outputs = @[
      VkAttachmentReference(
        attachment: 0,
        layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      )
    ]

  var subpassesList = [
    VkSubpassDescription(
      flags: VkSubpassDescriptionFlags(0),
      pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
      inputAttachmentCount: 0,
      pInputAttachments: nil,
      colorAttachmentCount: uint32(outputs.len),
      pColorAttachments: outputs.ToCPointer,
      pResolveAttachments: nil,
      pDepthStencilAttachment: nil,
      preserveAttachmentCount: 0,
      pPreserveAttachments: nil,
    )
  ]

  var createInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: uint32(attachments.len),
      pAttachments: attachments.ToCPointer,
      subpassCount: uint32(subpassesList.len),
      pSubpasses: subpassesList.ToCPointer,
      dependencyCount: uint32(dependencies.len),
      pDependencies: dependencies.ToCPointer,
    )
  checkVkResult device.vkCreateRenderPass(addr(createInfo), nil, addr(result))

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
    # var glslExe = currentSourcePath.parentDir.parentDir.parentDir / "tools" / "glslangValidator"
    var glslExe = currentSourcePath.parentDir / "tools" / "glslangValidator"
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
  var descriptorBinding = 0

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
    elif hasCustomPragma(value, ShaderOutput):
      fsOutput.add &"layout(location = " & $fsOutputLocation & ") out " & GlslType(value) & " " & fieldname & ";"
      fsOutputLocation.inc
    elif typeof(value) is Texture:
      samplers.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(value) & " " & fieldname & ";"
      descriptorBinding.inc
    elif typeof(value) is object:
      # TODO
      uniforms.add ""
      descriptorBinding.inc
    elif typeof(value) is array:
      when elementType(value) is Texture:
        let arrayDecl = "[" & $typeof(value).len & "]"
        samplers.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(default(elementType(value))) & " " & fieldname & "" & arrayDecl & ";"
        descriptorBinding.inc
      elif elementType(value) is object:
        # TODO
        let arrayDecl = "[" & $typeof(value).len & "]"
        # uniforms.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(elementType(value)) & " " & fieldname & "" & arrayDecl & ";"
        descriptorBinding.inc
      else:
        {.error: "Unsupported shader field " & fieldname.}
    elif fieldname in ["vertexCode", "fragmentCode"]:
      discard
    else:
      {.error: "Unsupported shader field '" & tt.name(TShader) & "." & fieldname & "' of type " & tt.name(typeof(value)).}

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

proc CompileShader[TShader](device: VkDevice, shader: static TShader): ShaderObject[TShader] =
  const (vertexShaderSource, fragmentShaderSource) = generateShaderSource(shader)

  let vertexBinary = compileGlslToSPIRV(VK_SHADER_STAGE_VERTEX_BIT, vertexShaderSource)
  let fragmentBinary = compileGlslToSPIRV(VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShaderSource)

  var createInfoVertex = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(vertexBinary.len * sizeof(uint32)),
    pCode: vertexBinary.ToCPointer,
  )
  checkVkResult device.vkCreateShaderModule(addr(createInfoVertex), nil, addr(result.vertexShader))
  var createInfoFragment = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(fragmentBinary.len * sizeof(uint32)),
    pCode: fragmentBinary.ToCPointer,
  )
  checkVkResult device.vkCreateShaderModule(addr(createInfoFragment), nil, addr(result.fragmentShader))


proc CreatePipeline*[TShader](
  device: VkDevice,
  renderPass: VkRenderPass,
  shader: ShaderObject[TShader],
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
): Pipeline[TShader] =
  # assumptions/limitations:
  # - we are only using vertex and fragment shaders (2 stages)
  # - we only support one subpass
  # = we only support one Uniform-Block

  # create pipeline
  var layoutbindings: seq[VkDescriptorSetLayoutBinding]
  ForDescriptorFields(default(TShader), descriptorType, descriptorCount, descriptorBindingNumber):
    layoutbindings.add VkDescriptorSetLayoutBinding(
      binding: descriptorBindingNumber,
      descriptorType: descriptorType,
      descriptorCount: descriptorCount,
      stageFlags: VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
      pImmutableSamplers: nil,
    )
  var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount: uint32(layoutbindings.len),
    pBindings: layoutbindings.ToCPointer
  )
  var descriptorSetLayout: VkDescriptorSetLayout
  checkVkResult vkCreateDescriptorSetLayout(device, addr(layoutCreateInfo), nil, addr(descriptorSetLayout))
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
      module: shader.vertexShader,
      pName: "main",
    ),
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_FRAGMENT_BIT,
      module: shader.fragmentShader,
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
    device,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.pipeline)
  )

  # create descriptors, one per frame-in-flight
  let nSamplers = 0'u32
  let nUniformBuffers = 0'u32

  if nSamplers + nUniformBuffers > 0:
    var poolSizes: seq[VkDescriptorPoolSize]
    if nUniformBuffers > 0:
      poolSizes.add VkDescriptorPoolSize(thetype: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, descriptorCount: nSamplers * INFLIGHTFRAMES)
    if nSamplers > 0:
      poolSizes.add VkDescriptorPoolSize(thetype: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount: nUniformBuffers * INFLIGHTFRAMES)
    var poolInfo = VkDescriptorPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
      poolSizeCount: uint32(poolSizes.len),
      pPoolSizes: poolSizes.ToCPointer,
      maxSets: (nUniformBuffers + nSamplers) * INFLIGHTFRAMES * 2, # good formula? no idea...
    )
    var pool: VkDescriptorPool
    checkVkResult vkCreateDescriptorPool(device, addr(poolInfo), nil, addr(pool))

    var layouts = newSeqWith(result.descriptorSets.len, descriptorSetLayout)
    var allocInfo = VkDescriptorSetAllocateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
      descriptorPool: pool,
      descriptorSetCount: uint32(layouts.len),
      pSetLayouts: layouts.ToCPointer,
    )
    checkVkResult vkAllocateDescriptorSets(device, addr(allocInfo), result.descriptorSets.ToCPointer)

proc WriteDescriptors[TShader](device: VkDevice, pipeline: Pipeline[TShader]) =
  var descriptorSetWrites: seq[VkWriteDescriptorSet]
  ForDescriptorFields(default(TShader), descriptorType, descriptorCount, descriptorBindingNumber):
    for frameInFlight in 0 ..< pipeline.descriptorSets.len:
      if descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:
        # TODO
        let bufferInfo = VkDescriptorBufferInfo(
          buffer: VkBuffer(0),
          offset: 0,
          range: 1,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: pipeline.descriptorSets[frameInFlight],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: uint32(0),
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: nil,
          pBufferInfo: addr(bufferInfo),
        )
      elif descriptorType == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
        # TODO
        let imageInfo = VkDescriptorImageInfo(
          sampler: VkSampler(0),
          imageView: VkImageView(0),
          imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: pipeline.descriptorSets[frameInFlight],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: uint32(0),
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: addr(imageInfo),
          pBufferInfo: nil,
        )
  vkUpdateDescriptorSets(device, uint32(descriptorSetWrites.len), descriptorSetWrites.ToCPointer, 0, nil)

proc CreateRenderable[TMesh, TInstance](
  mesh: TMesh,
  instance: TInstance,
  buffers: RenderBuffers,
): Renderable[TMesh, TInstance] =
  result.indexType = None

proc Bind[T](pipeline: Pipeline[T], commandBuffer: VkCommandBuffer, currentFrameInFlight: int) =
  let a = pipeline.descriptorSets
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)
  if a[currentFrameInFlight] != VkDescriptorSet(0):
    commandBuffer.vkCmdBindDescriptorSets(
      VK_PIPELINE_BIND_POINT_GRAPHICS,
      pipeline.layout,
      0,
      1,
      addr pipeline.descriptorSets[currentFrameInFlight],
      0,
      nil,
    )

proc AssertCompatible(TShader, TMesh, TInstance, TGlobals: typedesc) =
  # assert seq-fields of TMesh|TInstance == seq-fields of TShader
  # assert normal fields of TMesh|Globals == normal fields of TShaderDescriptors
  for inputName, inputValue in default(TShader).fieldPairs:
    var foundField = false
    when hasCustomPragma(inputValue, VertexAttribute):
      assert typeof(inputValue) is SupportedGPUType
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert elementType(meshValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but mesh attribute is of type '" & tt.name(elementType(meshValue)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "'"
    elif hasCustomPragma(inputValue, InstanceAttribute):
      assert typeof(inputValue) is SupportedGPUType
      for instanceName, instanceValue in default(TInstance).fieldPairs:
        when instanceName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert elementType(instanceValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but instance attribute is of type '" & tt.name(elementType(instanceValue)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TInstance) & "'"
    elif typeof(inputValue) is Texture or typeof(inputValue) is object:
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(meshValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but mesh attribute is of type '" & tt.name(elementType(meshValue)) & "'"
          foundField = true
      for globalName, globalValue in default(TGlobals).fieldPairs:
        when globalName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(globalValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"
    elif typeof(inputValue) is array:
      when (elementType(inputValue) is Texture or elementType(inputValue) is object):
        for meshName, meshValue in default(TMesh).fieldPairs:
          when meshName == inputName:
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(meshValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but mesh attribute is of type '" & tt.name(elementType(meshValue)) & "'"
            foundField = true
        for globalName, globalValue in default(TGlobals).fieldPairs:
          when globalName == inputName:
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(globalValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue)) & "'"
            foundField = true
        assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"


proc Render[TShader, TMesh, TInstance, TGlobals](
  pipeline: Pipeline[TShader],
  renderable: Renderable[TMesh, TInstance],
  globals: TGlobals,
  commandBuffer: VkCommandBuffer,
) =
  static: AssertCompatible(TShader, TMesh, TInstance, TGlobals)
  if renderable.vertexBuffers.len > 0:
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
  import semicongine/platform/window
  import semicongine/vulkan/instance
  import semicongine/vulkan/device
  import semicongine/vulkan/physicaldevice
  import std/options

  type
    MaterialA = object
      reflection: float32
      baseColor: Vec3f
    ShaderSettings = object
      brightness: float32
    MeshA = object
      position: seq[Vec3f]
      transparency: float
      material: array[3, MaterialA]
      materialTextures: array[3, Texture]
    InstanceA = object
      transform: seq[Mat4]
      position: seq[Vec3f]
    Globals = object
      fontAtlas: Texture
      settings: ShaderSettings

    ShaderA = object
      # vertex input
      position {.VertexAttribute.}: Vec3f
      transform {.InstanceAttribute.}: Mat4
      # intermediate
      test {.Pass.}: float32
      test1 {.PassFlat.}: Vec3f
      # output
      color {.ShaderOutput.}: Vec4f
      # uniforms
      material: array[3, MaterialA]
      settings: ShaderSettings
      # textures
      fontAtlas: Texture
      materialTextures: array[3, Texture]
      # code
      vertexCode: string = "void main() {}"
      fragmentCode: string = "void main() {}"

  let w = CreateWindow("test2")
  putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")
  let i = w.CreateInstance(
    vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions = @[],
    layers = @["VK_LAYER_KHRONOS_validation"],
  )


  let selectedPhysicalDevice = i.GetPhysicalDevices().FilterBestGraphics()
  let dev = i.CreateDevice(
    selectedPhysicalDevice,
    enabledExtensions = @[],
    selectedPhysicalDevice.FilterForGraphicsPresentationQueues()
  )
  let frameWidth = 100'u32
  let frameHeight = 100'u32

  var myRenderable: Renderable[MeshA, InstanceA]
  var myGlobals: Globals

  # setup for rendering (TODO: swapchain & framebuffers)

  # renderpass
  let renderpass = dev.vk.CreateRenderPass(dev.physicalDevice.GetSurfaceFormats().FilterSurfaceFormat().format)

  # shaders
  const shader = ShaderA()
  let shaderObject = dev.vk.CompileShader(shader)
  var pipeline1 = CreatePipeline(dev.vk, renderPass = renderpass, shaderObject)

  # TODO: probably here: allocate renderables, uniform buffers & textures

  # descriptors
  WriteDescriptors(dev.vk, pipeline1)

  # command buffer
  var
    commandBufferPool: VkCommandPool
    cmdBuffers: array[INFLIGHTFRAMES.int, VkCommandBuffer]
    createInfo = VkCommandPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
      queueFamilyIndex: dev.FirstGraphicsQueue().get().family.index,
    )
  checkVkResult vkCreateCommandPool(dev.vk, addr createInfo, nil, addr commandBufferPool)
  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: commandBufferPool,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: INFLIGHTFRAMES,
  )
  checkVkResult vkAllocateCommandBuffers(dev.vk, addr allocInfo, cmdBuffers.ToCPointer)

  # start command buffer
  block:
    let
      currentFramebuffer = VkFramebuffer(0) # TODO
      currentFrameInFlight = 1
      cmd = cmdBuffers[currentFrameInFlight]
      beginInfo = VkCommandBufferBeginInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
      )
    checkVkResult cmd.vkResetCommandBuffer(VkCommandBufferResetFlags(0))
    checkVkResult cmd.vkBeginCommandBuffer(addr(beginInfo))

    # start renderpass
    block:
      var
        clearColors = [VkClearValue(color: VkClearColorValue(float32: [0, 0, 0, 0]))]
        renderPassInfo = VkRenderPassBeginInfo(
          sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
          renderPass: renderpass,
          framebuffer: currentFramebuffer,
          renderArea: VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: VkExtent2D(width: frameWidth, height: frameHeight),
          ),
          clearValueCount: uint32(clearColors.len),
          pClearValues: clearColors.ToCPointer(),
        )
        viewport = VkViewport(
          x: 0.0,
          y: 0.0,
          width: frameWidth.float32,
          height: frameHeight.float32,
          minDepth: 0.0,
          maxDepth: 1.0,
        )
        scissor = VkRect2D(
          offset: VkOffset2D(x: 0, y: 0),
          extent: VkExtent2D(width: frameWidth, height: frameHeight)
        )
      vkCmdBeginRenderPass(cmd, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

      # setup viewport
      vkCmdSetViewport(cmd, firstViewport = 0, viewportCount = 1, addr(viewport))
      vkCmdSetScissor(cmd, firstScissor = 0, scissorCount = 1, addr(scissor))

      # bind pipeline, will be loop
      block:
        Bind(pipeline1, cmd, currentFrameInFlight = currentFrameInFlight)

        # render object, will be loop
        block:
          Render(pipeline1, myRenderable, myGlobals, cmd)

      vkCmdEndRenderPass(cmd)
    checkVkResult cmd.vkEndCommandBuffer()
