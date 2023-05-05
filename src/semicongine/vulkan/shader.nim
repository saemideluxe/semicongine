import std/typetraits
import std/os
import std/enumerate
import std/logging
import std/hashes
import std/strformat
import std/strutils
import std/compilesettings

import ./api
import ./device
import ./utils

import ../gpu_data

const DEFAULT_SHADER_VERSION = 450
const DEFAULT_SHADER_ENTRYPOINT = "main"

let logger = newConsoleLogger()
addHandler(logger)

type
  ShaderCode* = object # compiled shader code with some meta data
    stage: VkShaderStageFlagBits
    entrypoint: string
    binary: seq[uint32]
    inputs*: seq[ShaderAttribute]
    uniforms*: seq[ShaderAttribute]
    samplers*: seq[ShaderAttribute]
    outputs*: seq[ShaderAttribute]
  Shader* = object
    device: Device
    vk*: VkShaderModule
    stage*: VkShaderStageFlagBits
    entrypoint*: string
    inputs*: seq[ShaderAttribute]
    uniforms*: seq[ShaderAttribute]
    samplers*: seq[ShaderAttribute]
    outputs*: seq[ShaderAttribute]


proc compileGlslToSPIRV(stage: VkShaderStageFlagBits, shaderSource: string, entrypoint: string): seq[uint32] {.compileTime.} =
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
    # cross compilation for windows workaround, sorry computer
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"
    projectPath = querySetting(projectPath)

  echo "shader of type ", stage, ", entrypoint ", entrypoint
  for i, line in enumerate(shaderSource.splitlines()):
    echo "  ", i + 1, " ", line
  let command = &"{projectPath}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}"

  discard staticExecChecked(
      command = command,
      input = shaderSource
  )

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


proc compileGlslShader*(
  stage: VkShaderStageFlagBits,
  inputs: seq[ShaderAttribute]= @[],
  uniforms: seq[ShaderAttribute]= @[],
  samplers: seq[ShaderAttribute]= @[],
  outputs: seq[ShaderAttribute]= @[],
  version=DEFAULT_SHADER_VERSION ,
  entrypoint=DEFAULT_SHADER_ENTRYPOINT ,
  main: seq[string]
): ShaderCode {.compileTime.} =

  var code = @[&"#version {version}", ""] &
  # var code = @[&"#version {version}", "layout(row_major) uniform;", ""] &
    (if inputs.len > 0: inputs.glslInput() & @[""] else: @[]) &
    (if uniforms.len > 0: uniforms.glslUniforms(binding=0) & @[""] else: @[]) &
    (if samplers.len > 0: samplers.glslSamplers(basebinding=1) & @[""] else: @[]) &
    (if outputs.len > 0: outputs.glslOutput() & @[""] else: @[]) &
    @[&"void {entrypoint}(){{"] &
    main &
    @[&"}}"]
  result.inputs = inputs
  result.uniforms = uniforms
  result.samplers = samplers
  result.outputs = outputs
  result.entrypoint = entrypoint
  result.stage = stage
  result.binary = compileGlslToSPIRV(stage, code.join("\n"), entrypoint)


proc compileGlslShader*(
  stage: VkShaderStageFlagBits,
  inputs: seq[ShaderAttribute]= @[],
  uniforms: seq[ShaderAttribute]= @[],
  samplers: seq[ShaderAttribute]= @[],
  outputs: seq[ShaderAttribute]= @[],
  version=DEFAULT_SHADER_VERSION ,
  entrypoint=DEFAULT_SHADER_ENTRYPOINT ,
  main: string
): ShaderCode {.compileTime.} =
  return compileGlslShader(stage, inputs, uniforms, samplers, outputs, version, entrypoint, @[main])


proc createShaderModule*(
  device: Device,
  shaderCode: ShaderCode,
): Shader =
  assert device.vk.valid
  assert len(shaderCode.binary) > 0

  result.device = device
  result.inputs = shaderCode.inputs
  result.uniforms = shaderCode.uniforms
  result.samplers = shaderCode.samplers
  result.outputs = shaderCode.outputs
  result.entrypoint = shaderCode.entrypoint
  result.stage = shaderCode.stage
  var bin = shaderCode.binary
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(bin.len * sizeof(uint32)),
    pCode: addr(bin[0]),
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfo), nil, addr(result.vk))

proc getVertexInputInfo*(
  shader: Shader,
  bindings: var seq[VkVertexInputBindingDescription],
  attributes: var seq[VkVertexInputAttributeDescription],
  baseBinding=0'u32
): VkPipelineVertexInputStateCreateInfo =
  var location = 0'u32
  var binding = baseBinding

  for attribute in shader.inputs:
    bindings.add VkVertexInputBindingDescription(
      binding: binding,
      stride: attribute.size,
      inputRate: if attribute.perInstance: VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    for i in 0 ..< attribute.thetype.numberOfVertexInputAttributeDescriptors:
      attributes.add VkVertexInputAttributeDescription(
        binding: binding,
        location: location,
        format: attribute.thetype.getVkFormat,
        offset: i * attribute.size(perDescriptor=true),
      )
      location += attribute.thetype.nLocationSlots
    inc binding

  return VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount: uint32(bindings.len),
    pVertexBindingDescriptions: bindings.toCPointer,
    vertexAttributeDescriptionCount: uint32(attributes.len),
    pVertexAttributeDescriptions: attributes.toCPointer,
  )


proc getPipelineInfo*(shader: Shader): VkPipelineShaderStageCreateInfo =
  VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: shader.stage,
    module: shader.vk,
    pName: cstring(shader.entrypoint),
  )

proc destroy*(shader: var Shader) =
  assert shader.device.vk.valid
  assert shader.vk.valid
  shader.device.vk.vkDestroyShaderModule(shader.vk, nil)
  shader.vk.reset
