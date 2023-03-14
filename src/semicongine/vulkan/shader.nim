import std/os
import std/hashes
import std/strformat
import std/compilesettings

import ./api
import ./device

type
  VertexShader*[VertexType] = object
    device: Device
    vertexType*: VertexType
    module*: VkShaderModule
  FragmentShader* = object
    device: Device
    module*: VkShaderModule

proc staticExecChecked(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(
      command = command,
      input = input)
  if exitcode != 0:
    raise newException(Exception, &"Running '{command}' produced exit code: {exitcode}" & output)
  return output

func stage2string(stage: VkShaderStageFlagBits): string {.compileTime.} =
  case stage
  of VK_SHADER_STAGE_VERTEX_BIT: "vert"
  of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
  of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
  of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
  of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
  of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
  else: ""

proc compileGLSLToSPIRV(stage: static VkShaderStageFlagBits, shaderSource: static string, entrypoint: string): seq[uint32] {.compileTime.} =
  when defined(nimcheck): # will not run if nimcheck is running
    return result
  const
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    # cross compilation for windows workaround, sorry computer
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"
    projectPath = querySetting(projectPath)

  discard staticExecChecked(
      command = &"{projectPath}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}",
      input = shaderSource
  )

  when defined(mingw) and defined(linux): # required for crosscompilation, path separators get messed up
    let shaderbinary = staticRead shaderfile.replace("\\", "/")
  else:
    let shaderbinary = staticRead shaderfile
  when defined(linux):
    discard staticExecChecked(command = fmt"rm {shaderfile}")
  elif defined(windows):
    discard staticExecChecked(command = fmt"cmd.exe /c del {shaderfile}")
  else:
    raise newException(Exception, "Unsupported operating system")

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl 0) or
      (uint32(shaderbinary[i + 1]) shl 8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc createVertexShader*[VertexType](device: Device, shader: static string, vertexType: VertexType, entryPoint: static string = "main"): VertexShader[VertexType] =
  assert device.vk.valid

  const constcode = compileGLSLToSPIRV(VK_SHADER_STAGE_VERTEX_BIT, shader, entryPoint)
  var code = constcode
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(code.len * sizeof(uint32)),
    pCode: if code.len > 0: addr(code[0]) else: nil,
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfo), nil, addr(result.module))

proc createFragmentShader*(device: Device, shader: static string, entryPoint: static string = "main"): FragmentShader =
  assert device.vk.valid

  const constcode = compileGLSLToSPIRV(VK_SHADER_STAGE_FRAGMENT_BIT, shader, entryPoint)
  var code = constcode
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(code.len * sizeof(uint32)),
    pCode: if code.len > 0: addr(code[0]) else: nil,
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfo), nil, addr(result.module))

proc getPipelineInfo*(shader: VertexShader|FragmentShader, entryPoint = "main"): VkPipelineShaderStageCreateInfo =
  VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: VK_SHADER_STAGE_VERTEX_BIT,
    module: shader.module,
    pName: cstring(entryPoint),
  )

proc destroy*(shader: var VertexShader) =
  assert shader.device.vk.valid
  assert shader.module.valid
  shader.device.vk.vkDestroyShaderModule(shader.module, nil)
  shader.module.reset

proc destroy*(shader: var FragmentShader) =
  assert shader.device.vk.valid
  assert shader.module.valid
  shader.device.vk.vkDestroyShaderModule(shader.module, nil)
  shader.module.reset
