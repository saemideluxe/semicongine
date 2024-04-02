import std/typetraits
import std/os
import std/enumerate
import std/logging
import std/hashes
import std/strformat
import std/strutils

import ../core
import ./device

const DEFAULT_SHADER_VERSION = 450
const DEFAULT_SHADER_ENTRYPOINT = "main"

let logger = newConsoleLogger()
addHandler(logger)

type
  ShaderModule* = object
    device: Device
    vk*: VkShaderModule
    stage*: VkShaderStageFlagBits
    configuration*: ShaderConfiguration
  ShaderConfiguration* = object
    vertexBinary: seq[uint32]
    fragmentBinary: seq[uint32]
    entrypoint: string
    inputs*: seq[ShaderAttribute]
    intermediates*: seq[ShaderAttribute]
    outputs*: seq[ShaderAttribute]
    uniforms*: seq[ShaderAttribute]
    samplers*: seq[ShaderAttribute]

proc `$`*(shader: ShaderConfiguration): string =
  &"Inputs: {shader.inputs}, Uniforms: {shader.uniforms}, Samplers: {shader.samplers}"

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
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"


  if not shaderfile.fileExists:
    echo "shader of type ", stage, ", entrypoint ", entrypoint
    for i, line in enumerate(shaderSource.splitlines()):
      echo "  ", i + 1, " ", line
    var glslExe = currentSourcePath.parentDir.parentDir.parentDir / "tools" / "glslangValidator"
    when defined(windows):
      glslExe = glslExe & "." & ExeExt
    let command = &"{glslExe} --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}"
    echo "run: ", command
    discard staticExecChecked(
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

proc compileGlslCode*(
  stage: VkShaderStageFlagBits,
  inputs: openArray[ShaderAttribute] = [],
  uniforms: openArray[ShaderAttribute] = [],
  samplers: openArray[ShaderAttribute] = [],
  outputs: openArray[ShaderAttribute] = [],
  version = DEFAULT_SHADER_VERSION,
  entrypoint = DEFAULT_SHADER_ENTRYPOINT,
  main: string
): seq[uint32] {.compileTime.} =

  let code = @[&"#version {version}", "#extension GL_EXT_scalar_block_layout : require", ""] &
    (if inputs.len > 0: inputs.glslInput() & @[""] else: @[]) &
    (if uniforms.len > 0: uniforms.glslUniforms(binding = 0) & @[""] else: @[]) &
    (if samplers.len > 0: samplers.glslSamplers(basebinding = if uniforms.len > 0: 1 else: 0) & @[""] else: @[]) &
    (if outputs.len > 0: outputs.glslOutput() & @[""] else: @[]) &
    @[&"void {entrypoint}(){{"] &
    main &
    @[&"}}"]
  compileGlslToSPIRV(stage, code.join("\n"), entrypoint)

proc createShaderConfiguration*(
  inputs: openArray[ShaderAttribute] = [],
  intermediates: openArray[ShaderAttribute] = [],
  outputs: openArray[ShaderAttribute] = [],
  uniforms: openArray[ShaderAttribute] = [],
  samplers: openArray[ShaderAttribute] = [],
  version = DEFAULT_SHADER_VERSION,
  entrypoint = DEFAULT_SHADER_ENTRYPOINT,
  vertexCode: string,
  fragmentCode: string,
): ShaderConfiguration {.compileTime.} =
  ShaderConfiguration(
    vertexBinary: compileGlslCode(
      stage = VK_SHADER_STAGE_VERTEX_BIT,
      inputs = inputs,
      outputs = intermediates,
      uniforms = uniforms,
      samplers = samplers,
      main = vertexCode,
    ),
    fragmentBinary: compileGlslCode(
      stage = VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs = intermediates,
      outputs = outputs,
      uniforms = uniforms,
      samplers = samplers,
      main = fragmentCode,
    ),
    entrypoint: entrypoint,
    inputs: @inputs,
    intermediates: @intermediates,
    outputs: @outputs,
    uniforms: @uniforms,
    samplers: @samplers,
  )


proc createShaderModules*(
  device: Device,
  shaderConfiguration: ShaderConfiguration,
): (ShaderModule, ShaderModule) =
  assert device.vk.valid
  assert len(shaderConfiguration.vertexBinary) > 0
  assert len(shaderConfiguration.fragmentBinary) > 0

  result[0].device = device
  result[1].device = device
  result[0].configuration = shaderConfiguration
  result[1].configuration = shaderConfiguration
  result[0].stage = VK_SHADER_STAGE_VERTEX_BIT
  result[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT

  var createInfoVertex = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(shaderConfiguration.vertexBinary.len * sizeof(uint32)),
    pCode: addr(shaderConfiguration.vertexBinary[0]),
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfoVertex), nil, addr(result[0].vk))
  var createInfoFragment = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(shaderConfiguration.fragmentBinary.len * sizeof(uint32)),
    pCode: addr(shaderConfiguration.fragmentBinary[0]),
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfoFragment), nil, addr(result[1].vk))

proc getVertexInputInfo*(
  shaderConfiguration: ShaderConfiguration,
  bindings: var seq[VkVertexInputBindingDescription],
  attributes: var seq[VkVertexInputAttributeDescription],
  baseBinding = 0'u32
): VkPipelineVertexInputStateCreateInfo =
  var location = 0'u32
  var binding = baseBinding

  for attribute in shaderConfiguration.inputs:
    bindings.add VkVertexInputBindingDescription(
      binding: binding,
      stride: uint32(attribute.size),
      inputRate: if attribute.perInstance: VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    for i in 0 ..< attribute.thetype.numberOfVertexInputAttributeDescriptors:
      attributes.add VkVertexInputAttributeDescription(
        binding: binding,
        location: location,
        format: attribute.thetype.getVkFormat,
        offset: uint32(i * attribute.size(perDescriptor = true)),
      )
      location += uint32(attribute.thetype.nLocationSlots)
    inc binding

  return VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount: uint32(bindings.len),
    pVertexBindingDescriptions: bindings.toCPointer,
    vertexAttributeDescriptionCount: uint32(attributes.len),
    pVertexAttributeDescriptions: attributes.toCPointer,
  )


proc getPipelineInfo*(shader: ShaderModule): VkPipelineShaderStageCreateInfo =
  VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: shader.stage,
    module: shader.vk,
    pName: cstring(shader.configuration.entrypoint),
  )

proc destroy*(shader: var ShaderModule) =
  assert shader.device.vk.valid
  assert shader.vk.valid
  shader.device.vk.vkDestroyShaderModule(shader.vk, nil)
  shader.vk.reset
