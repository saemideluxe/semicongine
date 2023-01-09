type

  # EShLanguage counterpart
  glslang_stage_t* {.size: sizeof(cint).} = enum
    GLSLANG_STAGE_VERTEX
    GLSLANG_STAGE_TESSCONTROL
    GLSLANG_STAGE_TESSEVALUATION
    GLSLANG_STAGE_GEOMETRY
    GLSLANG_STAGE_FRAGMENT
    GLSLANG_STAGE_COMPUTE
    GLSLANG_STAGE_RAYGEN
    GLSLANG_STAGE_INTERSECT
    GLSLANG_STAGE_ANYHIT
    GLSLANG_STAGE_CLOSESTHIT
    GLSLANG_STAGE_MISS
    GLSLANG_STAGE_CALLABLE
    GLSLANG_STAGE_TASK
    GLSLANG_STAGE_MESH
    GLSLANG_STAGE_COUNT

  # EShLanguageMask counterpart
  glslang_stage_mask_t* {.size: sizeof(cint).} = enum
    GLSLANG_STAGE_VERTEX_MASK = (1 shl ord(GLSLANG_STAGE_VERTEX))
    GLSLANG_STAGE_TESSCONTROL_MASK = (1 shl ord(GLSLANG_STAGE_TESSCONTROL))
    GLSLANG_STAGE_TESSEVALUATION_MASK = (1 shl ord(GLSLANG_STAGE_TESSEVALUATION))
    GLSLANG_STAGE_GEOMETRY_MASK = (1 shl ord(GLSLANG_STAGE_GEOMETRY))
    GLSLANG_STAGE_FRAGMENT_MASK = (1 shl ord(GLSLANG_STAGE_FRAGMENT))
    GLSLANG_STAGE_COMPUTE_MASK = (1 shl ord(GLSLANG_STAGE_COMPUTE))
    GLSLANG_STAGE_RAYGEN_MASK = (1 shl ord(GLSLANG_STAGE_RAYGEN))
    GLSLANG_STAGE_INTERSECT_MASK = (1 shl ord(GLSLANG_STAGE_INTERSECT))
    GLSLANG_STAGE_ANYHIT_MASK = (1 shl ord(GLSLANG_STAGE_ANYHIT))
    GLSLANG_STAGE_CLOSESTHIT_MASK = (1 shl ord(GLSLANG_STAGE_CLOSESTHIT))
    GLSLANG_STAGE_MISS_MASK = (1 shl ord(GLSLANG_STAGE_MISS))
    GLSLANG_STAGE_CALLABLE_MASK = (1 shl ord(GLSLANG_STAGE_CALLABLE))
    GLSLANG_STAGE_TASK_MASK = (1 shl ord(GLSLANG_STAGE_TASK))
    GLSLANG_STAGE_MESH_MASK = (1 shl ord(GLSLANG_STAGE_MESH))
    GLSLANG_STAGE_MASK_COUNT

  # EShSource counterpart
  glslang_source_t* {.size: sizeof(cint).} = enum
    GLSLANG_SOURCE_NONE
    GLSLANG_SOURCE_GLSL
    GLSLANG_SOURCE_HLSL
    GLSLANG_SOURCE_COUNT

  # EShClient counterpart
  glslang_client_t* {.size: sizeof(cint).} = enum
    GLSLANG_CLIENT_NONE
    GLSLANG_CLIENT_VULKAN
    GLSLANG_CLIENT_OPENGL
    GLSLANG_CLIENT_COUNT

  # EShTargetLanguage counterpart
  glslang_target_language_t* {.size: sizeof(cint).} = enum
    GLSLANG_TARGET_NONE
    GLSLANG_TARGET_SPV
    GLSLANG_TARGET_COUNT

  # SH_TARGET_ClientVersion counterpart
  glslang_target_client_version_t* {.size: sizeof(cint).} = enum
    GLSLANG_TARGET_CLIENT_VERSION_COUNT = 5
    GLSLANG_TARGET_OPENGL_450 = 450
    GLSLANG_TARGET_VULKAN_1_0 = (1 shl 22)
    GLSLANG_TARGET_VULKAN_1_1 = (1 shl 22) or (1 shl 12)
    GLSLANG_TARGET_VULKAN_1_2 = (1 shl 22) or (2 shl 12)
    GLSLANG_TARGET_VULKAN_1_3 = (1 shl 22) or (3 shl 12)

  # SH_TARGET_LanguageVersion counterpart
  glslang_target_language_version_t* {.size: sizeof(cint).} = enum
      GLSLANG_TARGET_LANGUAGE_VERSION_COUNT = 7
      GLSLANG_TARGET_SPV_1_0 = (1 shl 16)
      GLSLANG_TARGET_SPV_1_1 = (1 shl 16) or (1 shl 8)
      GLSLANG_TARGET_SPV_1_2 = (1 shl 16) or (2 shl 8)
      GLSLANG_TARGET_SPV_1_3 = (1 shl 16) or (3 shl 8)
      GLSLANG_TARGET_SPV_1_4 = (1 shl 16) or (4 shl 8)
      GLSLANG_TARGET_SPV_1_5 = (1 shl 16) or (5 shl 8)
      GLSLANG_TARGET_SPV_1_6 = (1 shl 16) or (6 shl 8)

  # EShExecutable counterpart
  glslang_executable_t* {.size: sizeof(cint).} = enum
    GLSLANG_EX_VERTEX_FRAGMENT
    GLSLANG_EX_FRAGMENT

  # EShOptimizationLevel counterpart
  # This enum is not used in the current C interface, but could be added at a later date.
  # GLSLANG_OPT_NONE is the current default.
  glslang_optimization_level_t* {.size: sizeof(cint).} = enum
    GLSLANG_OPT_NO_GENERATION
    GLSLANG_OPT_NONE
    GLSLANG_OPT_SIMPLE
    GLSLANG_OPT_FULL
    GLSLANG_OPT_LEVEL_COUNT

  # EShTextureSamplerTransformMode counterpart
  glslang_texture_sampler_transform_mode_t* {.size: sizeof(cint).} = enum
    GLSLANG_TEX_SAMP_TRANS_KEEP
    GLSLANG_TEX_SAMP_TRANS_UPGRADE_TEXTURE_REMOVE_SAMPLER
    GLSLANG_TEX_SAMP_TRANS_COUNT

  # EShMessages counterpart
  glslang_messages_t* {.size: sizeof(cint).} = enum
    GLSLANG_MSG_DEFAULT_BIT = 0
    GLSLANG_MSG_RELAXED_ERRORS_BIT = (1 shl 0)
    GLSLANG_MSG_SUPPRESS_WARNINGS_BIT = (1 shl 1)
    GLSLANG_MSG_AST_BIT = (1 shl 2)
    GLSLANG_MSG_SPV_RULES_BIT = (1 shl 3)
    GLSLANG_MSG_VULKAN_RULES_BIT = (1 shl 4)
    GLSLANG_MSG_ONLY_PREPROCESSOR_BIT = (1 shl 5)
    GLSLANG_MSG_READ_HLSL_BIT = (1 shl 6)
    GLSLANG_MSG_CASCADING_ERRORS_BIT = (1 shl 7)
    GLSLANG_MSG_KEEP_UNCALLED_BIT = (1 shl 8)
    GLSLANG_MSG_HLSL_OFFSETS_BIT = (1 shl 9)
    GLSLANG_MSG_DEBUG_INFO_BIT = (1 shl 10)
    GLSLANG_MSG_HLSL_ENABLE_16BIT_TYPES_BIT = (1 shl 11)
    GLSLANG_MSG_HLSL_LEGALIZATION_BIT = (1 shl 12)
    GLSLANG_MSG_HLSL_DX9_COMPATIBLE_BIT = (1 shl 13)
    GLSLANG_MSG_BUILTIN_SYMBOL_TABLE_BIT = (1 shl 14)
    GLSLANG_MSG_ENHANCED = (1 shl 15)
    GLSLANG_MSG_COUNT

  # EShReflectionOptions counterpart
  glslang_reflection_options_t* {.size: sizeof(cint).} = enum
    GLSLANG_REFLECTION_DEFAULT_BIT = 0
    GLSLANG_REFLECTION_STRICT_ARRAY_SUFFIX_BIT = (1 shl 0)
    GLSLANG_REFLECTION_BASIC_ARRAY_SUFFIX_BIT = (1 shl 1)
    GLSLANG_REFLECTION_INTERMEDIATE_IOO_BIT = (1 shl 2)
    GLSLANG_REFLECTION_SEPARATE_BUFFERS_BIT = (1 shl 3)
    GLSLANG_REFLECTION_ALL_BLOCK_VARIABLES_BIT = (1 shl 4)
    GLSLANG_REFLECTION_UNWRAP_IO_BLOCKS_BIT = (1 shl 5)
    GLSLANG_REFLECTION_ALL_IO_VARIABLES_BIT = (1 shl 6)
    GLSLANG_REFLECTION_SHARED_STD140_SSBO_BIT = (1 shl 7)
    GLSLANG_REFLECTION_SHARED_STD140_UBO_BIT = (1 shl 8)
    GLSLANG_REFLECTION_COUNT

  # EProfile counterpart (from Versions.h)
  glslang_profile_t* {.size: sizeof(cint).} = enum
    GLSLANG_BAD_PROFILE = 0
    GLSLANG_NO_PROFILE = (1 shl 0)
    GLSLANG_CORE_PROFILE = (1 shl 1)
    GLSLANG_COMPATIBILITY_PROFILE = (1 shl 2)
    GLSLANG_ES_PROFILE = (1 shl 3)
    GLSLANG_PROFILE_COUNT

  # Shader options
  glslang_shader_options_t* {.size: sizeof(cint).} = enum
    GLSLANG_SHADER_DEFAULT_BIT = 0
    GLSLANG_SHADER_AUTO_MAP_BINDINGS = (1 shl 0)
    GLSLANG_SHADER_AUTO_MAP_LOCATIONS = (1 shl 1)
    GLSLANG_SHADER_VULKAN_RULES_RELAXED = (1 shl 2)
    GLSLANG_SHADER_COUNT

  # TResourceType counterpart
  glslang_resource_type_t* {.size: sizeof(cint).} = enum
    GLSLANG_RESOURCE_TYPE_SAMPLER
    GLSLANG_RESOURCE_TYPE_TEXTURE
    GLSLANG_RESOURCE_TYPE_IMAGE
    GLSLANG_RESOURCE_TYPE_UBO
    GLSLANG_RESOURCE_TYPE_SSBO
    GLSLANG_RESOURCE_TYPE_UAV
    GLSLANG_RESOURCE_TYPE_COUNT

