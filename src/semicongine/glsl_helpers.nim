import ./math/vector
import ./math/matrix

func getGLSLType*[T](): string =
  # todo: likely not correct as we would need to enable some 
  # extensions somewhere (Vulkan/GLSL compiler?) to have 
  # everything work as intended. Or maybe the GPU driver does
  # some automagic conversion stuf..
  when T is uint8:         "uint"
  elif T is int8:          "int"
  elif T is uint16:        "uint"
  elif T is int16:         "int"
  elif T is uint32:        "uint"
  elif T is int32:         "int"
  elif T is uint64:        "uint"
  elif T is int64:         "int"
  elif T is float32:       "float"
  elif T is float64:       "double"

  elif T is Vec2[uint8]:   "uvec2"
  elif T is Vec2[int8]:    "ivec2"
  elif T is Vec2[uint16]:  "uvec2"
  elif T is Vec2[int16]:   "ivec2"
  elif T is Vec2[uint32]:  "uvec2"
  elif T is Vec2[int32]:   "ivec2"
  elif T is Vec2[uint64]:  "uvec2"
  elif T is Vec2[int64]:   "ivec2"
  elif T is Vec2[float32]: "vec2"
  elif T is Vec2[float64]: "dvec2"

  elif T is Vec3[uint8]:   "uvec3"
  elif T is Vec3[int8]:    "ivec3"
  elif T is Vec3[uint16]:  "uvec3"
  elif T is Vec3[int16]:   "ivec3"
  elif T is Vec3[uint32]:  "uvec3"
  elif T is Vec3[int32]:   "ivec3"
  elif T is Vec3[uint64]:  "uvec3"
  elif T is Vec3[int64]:   "ivec3"
  elif T is Vec3[float32]: "vec3"
  elif T is Vec3[float64]: "dvec3"

  elif T is Vec4[uint8]:   "uvec4"
  elif T is Vec4[int8]:    "ivec4"
  elif T is Vec4[uint16]:  "uvec4"
  elif T is Vec4[int16]:   "ivec4"
  elif T is Vec4[uint32]:  "uvec4"
  elif T is Vec4[int32]:   "ivec4"
  elif T is Vec4[uint64]:  "uvec4"
  elif T is Vec4[int64]:   "ivec4"
  elif T is Vec4[float32]: "vec4"
  elif T is Vec4[float64]: "dvec4"

  elif T is Mat22[float32]: "mat2"
  elif T is Mat23[float32]: "mat32"
  elif T is Mat32[float32]: "mat23"
  elif T is Mat33[float32]: "mat3"
  elif T is Mat34[float32]: "mat43"
  elif T is Mat43[float32]: "mat34"
  elif T is Mat44[float32]: "mat4"

  elif T is Mat22[float64]: "dmat2"
  elif T is Mat23[float64]: "dmat32"
  elif T is Mat32[float64]: "dmat23"
  elif T is Mat33[float64]: "dmat3"
  elif T is Mat34[float64]: "dmat43"
  elif T is Mat43[float64]: "dmat34"
  elif T is Mat44[float64]: "dmat4"
