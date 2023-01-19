import std/os
import std/hashes
import std/strformat
import std/strutils
import std/tables
import std/compilesettings

import ./vulkan_helpers
import ./glsl_helpers
import ./vulkan
import ./vertex
import ./descriptor
import ./math/vector

type
  AllowedUniformType = SomeNumber|Vec
  UniformSlot *[T:AllowedUniformType] = object
  ShaderProgram*[VertexType, Uniforms] = object
    entryPoint*: string
    programType*: VkShaderStageFlagBits
    shader*: VkPipelineShaderStageCreateInfo
    uniforms*: Uniforms

func stage2string(stage: VkShaderStageFlagBits): string {.compileTime.} =
  case stage
  of VK_SHADER_STAGE_VERTEX_BIT: "vert"
  of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
  of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
  of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
  of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
  of VK_SHADER_STAGE_ALL_GRAPHICS: ""
  of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
  of VK_SHADER_STAGE_ALL: ""

proc compileGLSLToSPIRV(stage: static VkShaderStageFlagBits, shaderSource: static string, entrypoint: string): seq[uint32] {.compileTime.} =
  when defined(nimcheck): # will not run if nimcheck is running
    return result
  const
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    # cross compilation for windows workaround, sorry computer
    shaderfile = getTempDir() / fmt"shader_{shaderHash}.{stagename}"
    projectPath = querySetting(projectPath)

  let (output, exitCode_glsl) = gorgeEx(command=fmt"{projectPath}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}", input=shaderSource)
  if exitCode_glsl != 0:
    raise newException(Exception, output)
  let shaderbinary = staticRead shaderfile
  # removeFile(shaderfile) TODO: remove file at compile time?

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl  0) or
      (uint32(shaderbinary[i + 1]) shl  8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc initShaderProgram*[VertexType, Uniforms](device: VkDevice, programType: static VkShaderStageFlagBits, shader: static string, entryPoint: static string="main"): ShaderProgram[VertexType, Uniforms] =
  result.entryPoint = entryPoint
  result.programType = programType

  const constcode = compileGLSLToSPIRV(programType, shader, entryPoint)
  var code = constcode
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

func generateVertexShaderCode*[VertexType, Uniforms](
  shaderBody: static string = "",
  entryPoint: static string = "main",
  glslVersion: static string = "450"
): string {.compileTime.} =
  var lines: seq[string]
  lines.add "#version " & glslVersion
  lines.add "layout(row_major) uniform;"
  lines.add generateGLSLUniformDeclarations[Uniforms]()
  lines.add generateGLSLVertexDeclarations[VertexType]()
  lines.add "layout(location = 0) out vec3 fragColor;"
  lines.add "void " & entryPoint & "() {"

  var hasPosition = 0
  var hasColor = 0
  for name, value in VertexType().fieldPairs:
    when typeof(value) is PositionAttribute:
      let glsltype = getGLSLType[getAttributeType(value)]()
      lines.add &"    {glsltype} in_position = " & name & ";"
      if getAttributeType(value) is Vec2:
        lines.add "    vec4 out_position = vec4(in_position, 0.0, 1.0);"
      elif getAttributeType(value) is Vec3:
        lines.add "    vec4 out_position = vec4(in_position, 1.0);"
      elif getAttributeType(value) is Vec4:
        lines.add "    vec4 out_position = in_position;"
      hasPosition += 1
    when typeof(value) is ColorAttribute:
      let glsltype = getGLSLType[getAttributeType(value)]()
      lines.add &"    {glsltype} in_color = " & name & ";"
      lines.add &"    {glsltype} out_color = in_color;";
      hasColor += 1

  lines.add shaderBody
  lines.add "    gl_Position = out_position;"
  lines.add "    fragColor = out_color;"
  lines.add "}"
  if hasPosition != 1:
    raise newException(Exception, fmt"VertexType needs to have exactly one attribute of type PositionAttribute (has {hasPosition})")
  if hasColor != 1:
    raise newException(Exception, fmt"VertexType needs to have exactly one attribute of type ColorAttribute (has {hasColor})")
  return lines.join("\n")

func generateFragmentShaderCode*[VertexType](
  shaderBody: static string = "",
  entryPoint: static string = "main",
  glslVersion: static string = "450"
): string {.compileTime.} =
  var lines: seq[string]
  lines.add "#version " & glslVersion
  lines.add "layout(row_major) uniform;"
  lines.add "layout(location = 0) in vec3 fragColor;"
  lines.add "layout(location = 0) out vec4 outColor;"
  lines.add "void " & entryPoint & "() {"
  lines.add "    vec3 in_color = fragColor;"
  lines.add "    vec3 out_color = in_color;"
  lines.add shaderBody
  lines.add "    outColor = vec4(out_color, 1.0);"
  lines.add "}"

  return lines.join("\n")
