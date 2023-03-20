import std/macros
import std/os
import std/enumerate
import std/logging
import std/hashes
import std/strformat
import std/strutils
import std/compilesettings

import ../math
import ./api
import ./device
import ./vertex
import ./glsl
import ./utils

let logger = newConsoleLogger()
addHandler(logger)

type
  Shader*[Inputs, Uniforms, Outputs] = object
    device: Device
    stage*: VkShaderStageFlagBits
    vk*: VkShaderModule
    entrypoint*: string


proc compileGLSLToSPIRV*(stage: VkShaderStageFlagBits, shaderSource: string, entrypoint: string): seq[uint32] {.compileTime.} =

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


proc shaderCode*[Inputs, Uniforms, Outputs](stage: VkShaderStageFlagBits, version: int, entrypoint: string, body: seq[string]): seq[uint32] {.compileTime.} =
  var code = @[&"#version {version}", ""] &
    glslInput[Inputs]() & @[""] &
    glslUniforms[Uniforms]() & @[""] &
    glslOutput[Outputs]() & @[""] &
    @[&"void {entrypoint}(){{"] &
    body &
    @[&"}}"]
  compileGLSLToSPIRV(stage, code.join("\n"), entrypoint)


proc shaderCode*[Inputs, Uniforms, Outputs](stage: VkShaderStageFlagBits, version: int, entrypoint: string, body: string): seq[uint32] {.compileTime.} =
  return shaderCode[Inputs, Uniforms, Outputs](stage, version, entrypoint, @[body])


proc createShader*[Inputs, Uniforms, Outputs](device: Device, stage: VkShaderStageFlagBits, entrypoint: string, binary: seq[uint32]): Shader[Inputs, Uniforms, Outputs] =
  assert device.vk.valid
  assert len(binary) > 0

  result.device = device
  result.entrypoint = entrypoint
  result.stage = stage
  var bin = binary
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(bin.len * sizeof(uint32)),
    pCode: addr(bin[0]),
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfo), nil, addr(result.vk))

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


func getVkFormat[T](value: T): VkFormat =
  when T is uint8: VK_FORMAT_R8_UINT
  elif T is int8: VK_FORMAT_R8_SINT
  elif T is uint16: VK_FORMAT_R16_UINT
  elif T is int16: VK_FORMAT_R16_SINT
  elif T is uint32: VK_FORMAT_R32_UINT
  elif T is int32: VK_FORMAT_R32_SINT
  elif T is uint64: VK_FORMAT_R64_UINT
  elif T is int64: VK_FORMAT_R64_SINT
  elif T is float32: VK_FORMAT_R32_SFLOAT
  elif T is float64: VK_FORMAT_R64_SFLOAT
  elif T is TVec2[uint8]: VK_FORMAT_R8G8_UINT
  elif T is TVec2[int8]: VK_FORMAT_R8G8_SINT
  elif T is TVec2[uint16]: VK_FORMAT_R16G16_UINT
  elif T is TVec2[int16]: VK_FORMAT_R16G16_SINT
  elif T is TVec2[uint32]: VK_FORMAT_R32G32_UINT
  elif T is TVec2[int32]: VK_FORMAT_R32G32_SINT
  elif T is TVec2[uint64]: VK_FORMAT_R64G64_UINT
  elif T is TVec2[int64]: VK_FORMAT_R64G64_SINT
  elif T is TVec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TVec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TVec3[uint8]: VK_FORMAT_R8G8B8_UINT
  elif T is TVec3[int8]: VK_FORMAT_R8G8B8_SINT
  elif T is TVec3[uint16]: VK_FORMAT_R16G16B16_UINT
  elif T is TVec3[int16]: VK_FORMAT_R16G16B16_SINT
  elif T is TVec3[uint32]: VK_FORMAT_R32G32B32_UINT
  elif T is TVec3[int32]: VK_FORMAT_R32G32B32_SINT
  elif T is TVec3[uint64]: VK_FORMAT_R64G64B64_UINT
  elif T is TVec3[int64]: VK_FORMAT_R64G64B64_SINT
  elif T is TVec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TVec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TVec4[uint8]: VK_FORMAT_R8G8B8A8_UINT
  elif T is TVec4[int8]: VK_FORMAT_R8G8B8A8_SINT
  elif T is TVec4[uint16]: VK_FORMAT_R16G16B16A16_UINT
  elif T is TVec4[int16]: VK_FORMAT_R16G16B16A16_SINT
  elif T is TVec4[uint32]: VK_FORMAT_R32G32B32A32_UINT
  elif T is TVec4[int32]: VK_FORMAT_R32G32B32A32_SINT
  elif T is TVec4[uint64]: VK_FORMAT_R64G64B64A64_UINT
  elif T is TVec4[int64]: VK_FORMAT_R64G64B64A64_SINT
  elif T is TVec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TVec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  else: {.error: "Unsupported vertex attribute type".}


proc getVertexInputInfo*[Input, Uniforms, Output](
  shader: Shader[Input, Uniforms, Output],
  bindings: var seq[VkVertexInputBindingDescription],
  attributes: var seq[VkVertexInputAttributeDescription],
): VkPipelineVertexInputStateCreateInfo =
  var location = 0'u32
  var binding = 0'u32

  for name, value in default(Input).fieldPairs:
    bindings.add VkVertexInputBindingDescription(
      binding: binding,
      stride: uint32(sizeof(value)),
      inputRate: if value.hasCustomPragma(PerInstance): VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    for i in 0 ..< compositeAttributesNumber(value):
      attributes.add VkVertexInputAttributeDescription(
        binding: binding,
        location: location,
        format: getVkFormat(compositeAttribute(value)),
        offset: uint32(i * sizeof(compositeAttribute(value))),
      )
      location += nLocationSlots(compositeAttribute(value))
    inc binding

  return VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount: uint32(bindings.len),
    pVertexBindingDescriptions: bindings.toCPointer,
    vertexAttributeDescriptionCount: uint32(attributes.len),
    pVertexAttributeDescriptions: attributes.toCPointer,
  )
