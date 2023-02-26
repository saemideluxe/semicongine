import std/os
import std/typetraits
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
  AllowedUniformType = SomeNumber|TVec
  UniformSlot *[T: AllowedUniformType] = object
  ShaderProgram*[VertexType, Uniforms] = object
    entryPoint*: string
    programType*: VkShaderStageFlagBits
    shader*: VkPipelineShaderStageCreateInfo
    uniforms*: Uniforms

proc staticExecChecked(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(
      command = command,
      input = input)
  if exitcode != 0:
    raise newException(Exception, output)
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

proc compileGLSLToSPIRV(stage: static VkShaderStageFlagBits,
    shaderSource: static string, entrypoint: string): seq[
    uint32] {.compileTime.} =
  when defined(nimcheck): # will not run if nimcheck is running
    return result
  const
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    # cross compilation for windows workaround, sorry computer
    shaderfile = getTempDir() / fmt"shader_{shaderHash}.{stagename}"
    projectPath = querySetting(projectPath)

  discard staticExecChecked(
      command = fmt"{projectPath}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}",
      input = shaderSource
  )

  when defined(mingw) and defined(linux): # required for crosscompilation, path separators get messed up
    let shaderbinary = staticRead shaderfile.replace("\\", "/")
  else:
    let shaderbinary = staticRead shaderfile
  when defined(linux):
    discard staticExecChecked(command = fmt"rm {shaderfile}")
  elif defined(windows):
    discard staticExecChecked(command = fmt"del {shaderfile}")
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

proc initShaderProgram*[VertexType, Uniforms](device: VkDevice,
    programType: static VkShaderStageFlagBits, shader: static string,
    entryPoint: static string = "main"): ShaderProgram[VertexType, Uniforms] =
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
  lines.add "layout(location = 0) out vec4 fragColor;"
  lines.add "void " & entryPoint & "() {"

  var viewprojection = ""

  var hasPosition = 0
  var hasColor = 0
  for attrname, value in VertexType().fieldPairs:
    when typeof(value) is PositionAttribute:
      let glsltype = getGLSLType[getAttributeType(value)]()
      lines.add &"    {glsltype} in_position = " & attrname & ";"
      if getAttributeType(value) is TVec2:
        lines.add "    vec4 out_position = vec4(in_position, 0.0, 1.0);"
      elif getAttributeType(value) is TVec3:
        lines.add "    vec4 out_position = vec4(in_position, 1.0);"
      elif getAttributeType(value) is TVec4:
        lines.add "    vec4 out_position = in_position;"
      hasPosition += 1
    when typeof(value) is ModelTransformAttribute:
      lines.add &"    out_position = " & attrname & " * out_position;"
    when typeof(value) is ColorAttribute:
      let glsltype = getGLSLType[getAttributeType(value)]()
      lines.add &"    {glsltype} in_color = " & attrname & ";"
      if getAttributeType(value) is TVec3:
        lines.add &"    vec4 out_color = vec4(in_color, 1);";
      elif getAttributeType(value) is TVec4:
        lines.add &"    vec4 out_color = in_color;";
      hasColor += 1
  when not (Uniforms is void):
    let uniformBlockName = name(Uniforms).toLower()
    for attrname, value in Uniforms().fieldPairs:
      when typeof(value) is ViewProjectionTransform:
        lines.add "out_position = " & uniformBlockName & "." & attrname & " * out_position;"

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
  lines.add "layout(location = 0) in vec4 fragColor;"
  lines.add "layout(location = 0) out vec4 outColor;"
  lines.add "void " & entryPoint & "() {"
  lines.add "    vec4 in_color = fragColor;"
  lines.add "    vec4 out_color = in_color;"
  lines.add shaderBody
  lines.add "    outColor = out_color;"
  lines.add "}"

  return lines.join("\n")
