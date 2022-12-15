import glslang_c_interface
import glslang_c_shader_types

export
  glslang_stage_t,
  glslang_initialize_process,
  glslang_finalize_process

type
  ShaderVersion = enum
    ES_VERSION = 100
    DESKTOP_VERSION = 110

proc compileGLSLToSPIRV*(stage: glslang_stage_t, shaderSource: string, fileName: string): seq[uint32] =
  var input = glslang_input_t(
    stage: stage,
    language: GLSLANG_SOURCE_GLSL,
    client: GLSLANG_CLIENT_VULKAN,
    client_version: GLSLANG_TARGET_VULKAN_1_2,
    target_language: GLSLANG_TARGET_SPV,
    target_language_version: GLSLANG_TARGET_SPV_1_5,
    code: cstring(shaderSource),
    default_version: ord(DESKTOP_VERSION),
    default_profile: GLSLANG_CORE_PROFILE,
    force_default_version_and_profile: false.cint,
    forward_compatible: false.cint,
    messages: GLSLANG_MSG_DEBUG_INFO_BIT,
    resource: glslang_default_resource(),
  )

  var shader = glslang_shader_create(addr(input))

  if not bool(glslang_shader_preprocess(shader, addr(input))):
      echo "GLSL preprocessing failed " & fileName
      echo glslang_shader_get_info_log(shader)
      echo glslang_shader_get_info_debug_log(shader)
      echo input.code
      glslang_shader_delete(shader)
      return

  if not bool(glslang_shader_parse(shader, addr(input))):
      echo "GLSL parsing failed " & fileName
      echo glslang_shader_get_info_log(shader)
      echo glslang_shader_get_info_debug_log(shader)
      echo glslang_shader_get_preprocessed_code(shader)
      glslang_shader_delete(shader)
      return

  var program: ptr glslang_program_t = glslang_program_create()
  glslang_program_add_shader(program, shader)

  if not bool(glslang_program_link(program, ord(GLSLANG_MSG_SPV_RULES_BIT) or ord(GLSLANG_MSG_VULKAN_RULES_BIT))):
      echo "GLSL linking failed " & fileName
      echo glslang_program_get_info_log(program)
      echo glslang_program_get_info_debug_log(program)
      glslang_program_delete(program)
      glslang_shader_delete(shader)
      return

  glslang_program_SPIRV_generate(program, stage)

  result = newSeq[uint32](glslang_program_SPIRV_get_size(program))
  glslang_program_SPIRV_get(program, addr(result[0]))

  var spirv_messages: cstring = glslang_program_SPIRV_get_messages(program)
  if spirv_messages != nil:
      echo "(%s) %s\b", fileName, spirv_messages

  glslang_program_delete(program)
  glslang_shader_delete(shader)

template checkGlslangResult*(call: untyped) =
  let value = call
  if value != 1:
    raise newException(Exception, "glgslang error: " & astToStr(call) & " returned " & $value)
