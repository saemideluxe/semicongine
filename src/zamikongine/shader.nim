import std/strformat
import std/strutils
import std/tables
import std/compilesettings


import ./vulkan_helpers
import ./vulkan
import ./vertex
import ./math/vector

type
  AllowedUniformType = SomeNumber|Vec
  UniformSlot *[T:AllowedUniformType] = object
  ShaderProgram*[Uniforms] = object
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

proc compileGLSLToSPIRV(stage: VkShaderStageFlagBits, shaderSource: string, entrypoint: string): seq[uint32] {.compileTime.} =
  let stagename = stage2string(stage)

  # TODO: compiles only on linux for now (because we don't have compile-time functionality in std/tempfile)
  if not defined(linux):
    raise newException(Exception, "Compilation is currently only supported on linux (need mktemp command), sorry!")
  let (tmpfile, exitCode) = gorgeEx(command=fmt"mktemp --tmpdir shader_XXXXXXX.{stagename}")
  if exitCode != 0:
    raise newException(Exception, tmpfile)

  let (output, exitCode_glsl) = gorgeEx(command=fmt"{querySetting(projectPath)}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {tmpfile}", input=shaderSource)
  if exitCode_glsl != 0:
    raise newException(Exception, output)
  let shaderbinary = staticRead tmpfile

  let (output_rm, exitCode_rm) = gorgeEx(command=fmt"rm {tmpfile}")
  if exitCode_rm != 0:
    raise newException(Exception, output_rm)

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl  0) or
      (uint32(shaderbinary[i + 1]) shl  8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc initShaderProgram*[T](device: VkDevice, programType: static VkShaderStageFlagBits, shader: static string, entryPoint: static string="main"): ShaderProgram[T] =
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

func generateVertexShaderCode*[VertexType](entryPoint, positionAttrName, colorAttrName: static string): string {.compileTime.} =
  var lines: seq[string]
  lines.add "#version 450"
  # lines.add "layout(binding = 0) uniform UniformBufferObject { float dt; } ubo;"
  lines.add generateGLSLDeclarations[VertexType]()
  lines.add "layout(location = 0) out vec3 fragColor;"
  lines.add "void " & entryPoint & "() {"

  for name, value in VertexType().fieldPairs:
    when typeof(value) is VertexAttribute and name == positionAttrName:
      # lines.add "    vec2 tmp = " & name & " * ubo.dt;"
      lines.add "    vec2 tmp = " & name & ";"
      lines.add "    gl_Position = vec4(tmp, 0.0, 1.0);"
    when typeof(value) is VertexAttribute and name == colorAttrName:
      lines.add "    fragColor = " & name & ";"
  lines.add "}"
  return lines.join("\n")

func generateFragmentShaderCode*[VertexType](entryPoint: static string): string {.compileTime.} =
  var lines: seq[string]
  lines.add "#version 450"
  lines.add "layout(location = 0) in vec3 fragColor;"
  lines.add "layout(location = 0) out vec4 outColor;"
  lines.add "void " & entryPoint & "() {"
  lines.add "    outColor = vec4(fragColor, 1.0);"
  lines.add "}"

  return lines.join("\n")
