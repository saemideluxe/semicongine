import std/osproc
import std/strformat
import std/strutils
import std/tables

import ./vulkan_helpers
import ./vulkan
import ./vertex

type
  ShaderProgram* = object
    entryPoint*: string
    programType*: VkShaderStageFlagBits
    shader*: VkPipelineShaderStageCreateInfo

func stage2string(stage: VkShaderStageFlagBits): string =
  case stage
  of VK_SHADER_STAGE_VERTEX_BIT: "vert"
  of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
  of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
  of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
  of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
  of VK_SHADER_STAGE_ALL_GRAPHICS: ""
  of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
  of VK_SHADER_STAGE_ALL: ""

proc compileGLSLToSPIRV(stage: VkShaderStageFlagBits, shaderSource: string, entrypoint: string): seq[uint32] =
  let stagename = stage2string(stage)
  let (output, exitCode) = execCmdEx(command=fmt"./glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename}", input=shaderSource)
  if exitCode != 0:
    raise newException(Exception, output)
  let shaderbinary = readFile fmt"{stagename}.spv"
  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl  0) or
      (uint32(shaderbinary[i + 1]) shl  8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc initShaderProgram*(device: VkDevice, programType: VkShaderStageFlagBits, shader: string, entryPoint: string="main"): ShaderProgram =
  result.entryPoint = entryPoint
  result.programType = programType

  var code = compileGLSLToSPIRV(result.programType, shader, result.entryPoint)
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(code.len * sizeof(uint32)),
    pCode: if code.len > 0: addr(code[0]) else: nil,
  )
  var shaderModule: VkShaderModule
  checkVkResult vkCreateShaderModule(device, addr(createInfo), nil, addr(shaderModule))

  result.shader = VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: programType,
    module: shaderModule,
    pName: cstring(result.entryPoint), # entry point for shader
  )

func generateVertexShaderCode*[T](entryPoint, positionAttrName, colorAttrName: static string): string =
  var lines: seq[string]
  lines.add "#version 450"
  lines.add generateGLSLDeclarations[T]()
  lines.add "layout(location = 0) out vec3 fragColor;"
  lines.add "void " & entryPoint & "() {"

  for name, value in T().fieldPairs:
    when typeof(value) is VertexAttribute and name == positionAttrName:
      lines.add "    gl_Position = vec4(" & name & ", 0.0, 1.0);"
    when typeof(value) is VertexAttribute and name == colorAttrName:
      lines.add "    fragColor = " & name & ";"
  lines.add "}"
  return lines.join("\n")

func generateFragmentShaderCode*[T](entryPoint: static string): string =
  var lines: seq[string]
  lines.add "#version 450"
  lines.add "layout(location = 0) in vec3 fragColor;"
  lines.add "layout(location = 0) out vec4 outColor;"
  lines.add "void " & entryPoint & "() {"
  lines.add "    outColor = vec4(fragColor, 1.0);"
  lines.add "}"

  return lines.join("\n")
