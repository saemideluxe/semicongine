import
  glslang_c_shader_types

type
  glslang_shader_s = object
  glslang_program_s = object
  glslang_shader_t* = glslang_shader_s
  glslang_program_t* = glslang_program_s

##  TLimits counterpart

type
  glslang_limits_t* {.bycopy.} = object
    non_inductive_for_loops*: bool
    while_loops*: bool
    do_while_loops*: bool
    general_uniform_indexing*: bool
    general_attribute_matrix_vector_indexing*: bool
    general_varying_indexing*: bool
    general_sampler_indexing*: bool
    general_variable_indexing*: bool
    general_constant_matrix_vector_indexing*: bool


##  TBuiltInResource counterpart

type
  glslang_resource_t* {.bycopy.} = object
    max_lights*: cint
    max_clip_planes*: cint
    max_texture_units*: cint
    max_texture_coords*: cint
    max_vertex_attribs*: cint
    max_vertex_uniform_components*: cint
    max_varying_floats*: cint
    max_vertex_texture_image_units*: cint
    max_combined_texture_image_units*: cint
    max_texture_image_units*: cint
    max_fragment_uniform_components*: cint
    max_draw_buffers*: cint
    max_vertex_uniform_vectors*: cint
    max_varying_vectors*: cint
    max_fragment_uniform_vectors*: cint
    max_vertex_output_vectors*: cint
    max_fragment_input_vectors*: cint
    min_program_texel_offset*: cint
    max_program_texel_offset*: cint
    max_clip_distances*: cint
    max_compute_work_group_count_x*: cint
    max_compute_work_group_count_y*: cint
    max_compute_work_group_count_z*: cint
    max_compute_work_group_size_x*: cint
    max_compute_work_group_size_y*: cint
    max_compute_work_group_size_z*: cint
    max_compute_uniform_components*: cint
    max_compute_texture_image_units*: cint
    max_compute_image_uniforms*: cint
    max_compute_atomic_counters*: cint
    max_compute_atomic_counter_buffers*: cint
    max_varying_components*: cint
    max_vertex_output_components*: cint
    max_geometry_input_components*: cint
    max_geometry_output_components*: cint
    max_fragment_input_components*: cint
    max_image_units*: cint
    max_combined_image_units_and_fragment_outputs*: cint
    max_combined_shader_output_resources*: cint
    max_image_samples*: cint
    max_vertex_image_uniforms*: cint
    max_tess_control_image_uniforms*: cint
    max_tess_evaluation_image_uniforms*: cint
    max_geometry_image_uniforms*: cint
    max_fragment_image_uniforms*: cint
    max_combined_image_uniforms*: cint
    max_geometry_texture_image_units*: cint
    max_geometry_output_vertices*: cint
    max_geometry_total_output_components*: cint
    max_geometry_uniform_components*: cint
    max_geometry_varying_components*: cint
    max_tess_control_input_components*: cint
    max_tess_control_output_components*: cint
    max_tess_control_texture_image_units*: cint
    max_tess_control_uniform_components*: cint
    max_tess_control_total_output_components*: cint
    max_tess_evaluation_input_components*: cint
    max_tess_evaluation_output_components*: cint
    max_tess_evaluation_texture_image_units*: cint
    max_tess_evaluation_uniform_components*: cint
    max_tess_patch_components*: cint
    max_patch_vertices*: cint
    max_tess_gen_level*: cint
    max_viewports*: cint
    max_vertex_atomic_counters*: cint
    max_tess_control_atomic_counters*: cint
    max_tess_evaluation_atomic_counters*: cint
    max_geometry_atomic_counters*: cint
    max_fragment_atomic_counters*: cint
    max_combined_atomic_counters*: cint
    max_atomic_counter_bindings*: cint
    max_vertex_atomic_counter_buffers*: cint
    max_tess_control_atomic_counter_buffers*: cint
    max_tess_evaluation_atomic_counter_buffers*: cint
    max_geometry_atomic_counter_buffers*: cint
    max_fragment_atomic_counter_buffers*: cint
    max_combined_atomic_counter_buffers*: cint
    max_atomic_counter_buffer_size*: cint
    max_transform_feedback_buffers*: cint
    max_transform_feedback_interleaved_components*: cint
    max_cull_distances*: cint
    max_combined_clip_and_cull_distances*: cint
    max_samples*: cint
    max_mesh_output_vertices_nv*: cint
    max_mesh_output_primitives_nv*: cint
    max_mesh_work_group_size_x_nv*: cint
    max_mesh_work_group_size_y_nv*: cint
    max_mesh_work_group_size_z_nv*: cint
    max_task_work_group_size_x_nv*: cint
    max_task_work_group_size_y_nv*: cint
    max_task_work_group_size_z_nv*: cint
    max_mesh_view_count_nv*: cint
    max_mesh_output_vertices_ext*: cint
    max_mesh_output_primitives_ext*: cint
    max_mesh_work_group_size_x_ext*: cint
    max_mesh_work_group_size_y_ext*: cint
    max_mesh_work_group_size_z_ext*: cint
    max_task_work_group_size_x_ext*: cint
    max_task_work_group_size_y_ext*: cint
    max_task_work_group_size_z_ext*: cint
    max_mesh_view_count_ext*: cint
    maxDualSourceDrawBuffersEXT*: cint
    limits*: glslang_limits_t

  glslang_input_t* {.bycopy.} = object
    language*: glslang_source_t
    stage*: glslang_stage_t
    client*: glslang_client_t
    client_version*: glslang_target_client_version_t
    target_language*: glslang_target_language_t
    target_language_version*: glslang_target_language_version_t
    ##  Shader source code
    code*: cstring
    default_version*: cint
    default_profile*: glslang_profile_t
    force_default_version_and_profile*: cint
    forward_compatible*: cint
    messages*: glslang_messages_t
    resource*: ptr glslang_resource_t


##  Inclusion result structure allocated by C include_local/include_system callbacks

type
  glsl_include_result_t* {.bycopy.} = object
    ##  Header file name or NULL if inclusion failed
    header_name*: cstring
    ##  Header contents or NULL
    header_data*: cstring
    header_length*: csize_t


##  Callback for local file inclusion

type
  glsl_include_local_func* = proc (ctx: pointer; header_name: cstring;
                                includer_name: cstring; include_depth: csize_t): ptr glsl_include_result_t

##  Callback for system file inclusion

type
  glsl_include_system_func* = proc (ctx: pointer; header_name: cstring;
                                 includer_name: cstring; include_depth: csize_t): ptr glsl_include_result_t

##  Callback for include result destruction

type
  glsl_free_include_result_func* = proc (ctx: pointer;
                                      result: ptr glsl_include_result_t): cint

##  Collection of callbacks for GLSL preprocessor

type
  glsl_include_callbacks_t* {.bycopy.} = object
    include_system*: glsl_include_system_func
    include_local*: glsl_include_local_func
    free_include_result*: glsl_free_include_result_func


##  SpvOptions counterpart

type
  glslang_spv_options_t* {.bycopy.} = object
    generate_debug_info*: bool
    strip_debug_info*: bool
    disable_optimizer*: bool
    optimize_size*: bool
    disassemble*: bool
    validate*: bool
    emit_nonsemantic_shader_debug_info*: bool
    emit_nonsemantic_shader_debug_source*: bool


proc glslang_initialize_process*(): cint {.importc.}
proc glslang_finalize_process*() {.importc.}
proc glslang_shader_create*(input: ptr glslang_input_t): ptr glslang_shader_t {.importc.}
proc glslang_shader_delete*(shader: ptr glslang_shader_t) {.importc.}
proc glslang_shader_set_preamble*(shader: ptr glslang_shader_t; s: cstring) {.importc.}
proc glslang_shader_shift_binding*(shader: ptr glslang_shader_t; res: glslang_resource_type_t; base: cuint) {.importc.}
proc glslang_shader_shift_binding_for_set*(shader: ptr glslang_shader_t; res: glslang_resource_type_t; base: cuint; set: cuint) {.importc.}
proc glslang_shader_set_options*(shader: ptr glslang_shader_t; options: cint) {.importc.}

proc glslang_shader_set_glsl_version*(shader: ptr glslang_shader_t; version: cint) {.importc.}
proc glslang_shader_preprocess*(shader: ptr glslang_shader_t; input: ptr glslang_input_t): cint {.importc.}
proc glslang_shader_parse*(shader: ptr glslang_shader_t; input: ptr glslang_input_t): cint {.importc.}
proc glslang_shader_get_preprocessed_code*(shader: ptr glslang_shader_t): cstring {.importc.}
proc glslang_shader_get_info_log*(shader: ptr glslang_shader_t): cstring {.importc.}
proc glslang_shader_get_info_debug_log*(shader: ptr glslang_shader_t): cstring {.importc.}
proc glslang_program_create*(): ptr glslang_program_t {.importc.}
proc glslang_program_delete*(program: ptr glslang_program_t) {.importc.}
proc glslang_program_add_shader*(program: ptr glslang_program_t; shader: ptr glslang_shader_t) {.importc.}
proc glslang_program_link*(program: ptr glslang_program_t; messages: cint): cint {.importc.}

proc glslang_program_add_source_text*(program: ptr glslang_program_t; stage: glslang_stage_t; text: cstring; len: csize_t) {.importc.}
proc glslang_program_set_source_file*(program: ptr glslang_program_t; stage: glslang_stage_t; file: cstring) {.importc.}
proc glslang_program_map_io*(program: ptr glslang_program_t): cint {.importc.}
proc glslang_program_SPIRV_generate*(program: ptr glslang_program_t; stage: glslang_stage_t) {.importc.}
proc glslang_program_SPIRV_generate_with_options*(program: ptr glslang_program_t; stage: glslang_stage_t; spv_options: ptr glslang_spv_options_t) {.importc.}
proc glslang_program_SPIRV_get_size*(program: ptr glslang_program_t): csize_t {.importc.}
proc glslang_program_SPIRV_get*(program: ptr glslang_program_t; a2: ptr cuint) {.importc.}
proc glslang_program_SPIRV_get_ptr*(program: ptr glslang_program_t): ptr cuint {.importc.}
proc glslang_program_SPIRV_get_messages*(program: ptr glslang_program_t): cstring {.importc.}
proc glslang_program_get_info_log*(program: ptr glslang_program_t): cstring {.importc.}
proc glslang_program_get_info_debug_log*(program: ptr glslang_program_t): cstring {.importc.}

proc glslang_default_resource*(): ptr glslang_resource_t {.importc.}
proc glslang_default_resource_string*(): cstring {.importc.}
proc glslang_decode_resource_limits*(resources: ptr glslang_resource_t , config: cstring) {.importc.}
