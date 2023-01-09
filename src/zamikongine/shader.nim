import std/strutils
import std/tables

import ./vulkan_helpers
import ./vulkan
import ./vertex
import ./glslang/glslang

type
  ShaderProgram* = object
    entryPoint*: string
    programType*: VkShaderStageFlagBits
    shader*: VkPipelineShaderStageCreateInfo

proc initShaderProgram*(device: VkDevice, programType: VkShaderStageFlagBits, shader: string, entryPoint: string="main"): ShaderProgram =
  result.entryPoint = entryPoint
  result.programType = programType

  const VK_GLSL_MAP = {
    VK_SHADER_STAGE_VERTEX_BIT: GLSLANG_STAGE_VERTEX,
    VK_SHADER_STAGE_FRAGMENT_BIT: GLSLANG_STAGE_FRAGMENT,
  }.toTable()
  var code = compileGLSLToSPIRV(VK_GLSL_MAP[result.programType], shader, "<memory-shader>")
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
