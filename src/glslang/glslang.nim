# required to link the GLSL compiler
{.passl: "-Lthirdparty/glslang/lib/" .}
{.passl: "-Lthirdparty/spirv-tools/lib/" .}

{.passl: "-lglslang" .}
{.passl: "-lglslang-default-resource-limits" .}
{.passl: "-lHLSL" .}
{.passl: "-lMachineIndependent" .}
{.passl: "-lGenericCodeGen" .}
{.passl: "-lOSDependent" .}
{.passl: "-lOGLCompiler" .}
{.passl: "-lSPIRV" .}
{.passl: "-lSPIRV-Tools-opt" .}

{.passl: "-lSPIRV-Tools" .}
{.passl: "-lSPIRV-Tools-diff" .}
{.passl: "-lSPIRV-Tools-fuzz" .}
{.passl: "-lSPIRV-Tools-link" .}
{.passl: "-lSPIRV-Tools-lint" .}
{.passl: "-lSPIRV-Tools-opt" .}
{.passl: "-lSPIRV-Tools-reduce" .}

{.passl: "-lstdc++" .}
{.passl: "-lm" .}

import glslang_c_interface
import glslang_c_shader_types


proc compileShaderToSPIRV_Vulkan*(stage: glslang_stage_t , shaderSource: string, fileName: string): seq[uint32] =
    var input = glslang_input_t(
        language: GLSLANG_SOURCE_GLSL,
        stage: stage,
        client: GLSLANG_CLIENT_VULKAN,
        client_version: GLSLANG_TARGET_VULKAN_1_2,
        target_language: GLSLANG_TARGET_SPV,
        target_language_version: GLSLANG_TARGET_SPV_1_5,
        code: shaderSource,
        default_version: 100,
        default_profile: GLSLANG_NO_PROFILE,
        force_default_version_and_profile: false.cint,
        forward_compatible: false.cint,
        messages: GLSLANG_MSG_DEFAULT_BIT,
        resource: glslang_default_resource(),
    )

    let shader = glslang_shader_create(addr(input))

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

    let program: ptr glslang_program_t = glslang_program_create()
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
