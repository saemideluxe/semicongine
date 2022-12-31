import std/tables

import ./vulkan_helpers
import ./vulkan
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
