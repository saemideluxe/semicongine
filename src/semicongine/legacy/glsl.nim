import std/typetraits
import std/strformat
import ../math/vector
import ../math/matrix


func getGLSLType*[T](t: T): string {.compileTime.} =
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

  elif T is TVec2[uint8]:   "uvec2"
  elif T is TVec2[int8]:    "ivec2"
  elif T is TVec2[uint16]:  "uvec2"
  elif T is TVec2[int16]:   "ivec2"
  elif T is TVec2[uint32]:  "uvec2"
  elif T is TVec2[int32]:   "ivec2"
  elif T is TVec2[uint64]:  "uvec2"
  elif T is TVec2[int64]:   "ivec2"
  elif T is TVec2[float32]: "vec2"
  elif T is TVec2[float64]: "dvec2"

  elif T is TVec3[uint8]:   "uvec3"
  elif T is TVec3[int8]:    "ivec3"
  elif T is TVec3[uint16]:  "uvec3"
  elif T is TVec3[int16]:   "ivec3"
  elif T is TVec3[uint32]:  "uvec3"
  elif T is TVec3[int32]:   "ivec3"
  elif T is TVec3[uint64]:  "uvec3"
  elif T is TVec3[int64]:   "ivec3"
  elif T is TVec3[float32]: "vec3"
  elif T is TVec3[float64]: "dvec3"

  elif T is TVec4[uint8]:   "uvec4"
  elif T is TVec4[int8]:    "ivec4"
  elif T is TVec4[uint16]:  "uvec4"
  elif T is TVec4[int16]:   "ivec4"
  elif T is TVec4[uint32]:  "uvec4"
  elif T is TVec4[int32]:   "ivec4"
  elif T is TVec4[uint64]:  "uvec4"
  elif T is TVec4[int64]:   "ivec4"
  elif T is TVec4[float32]: "vec4"
  elif T is TVec4[float64]: "dvec4"

  elif T is TMat22[float32]: "mat2"
  elif T is TMat23[float32]: "mat32"
  elif T is TMat32[float32]: "mat23"
  elif T is TMat33[float32]: "mat3"
  elif T is TMat34[float32]: "mat43"
  elif T is TMat43[float32]: "mat34"
  elif T is TMat44[float32]: "mat4"

  elif T is TMat22[float64]: "dmat2"
  elif T is TMat23[float64]: "dmat32"
  elif T is TMat32[float64]: "dmat23"
  elif T is TMat33[float64]: "dmat3"
  elif T is TMat34[float64]: "dmat43"
  elif T is TMat43[float64]: "dmat34"
  elif T is TMat44[float64]: "dmat4"


# return the number of elements into which larger types are divided
func compositeAttributesNumber*[T](value: T): int =
  when T is TMat33[float32]:
    3
  elif T is TMat44[float32]:
    4
  else:
    1


# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots*[T](value: T): uint32 =
  when (T is TVec3[float64] or T is TVec3[uint64] or T is TVec4[float64] or T is TVec4[float64]):
    return 2
  elif T is SomeNumber or T is TVec:
    return 1
  else:
    raise newException(Exception, "Unsupported vertex attribute type")


# return the type into which larger types are divided
func compositeAttribute*[T](value: T): auto =
  when T is TMat33[float32]:
    Vec3()
  elif T is TMat44[float32]:
    Vec4()
  else:
    value

func glslInput*[T](): seq[string] {.compileTime.} =
  when not (T is void):
    var i = 0'u32
    for fieldname, value in default(T).fieldPairs:
      let glsltype = getGLSLType(value)
      let thename = fieldname
      result.add &"layout(location = {i}) in {glsltype} {thename};"
      for j in 0 ..< compositeAttributesNumber(value):
        i += nLocationSlots(compositeAttribute(value))

func glslUniforms*[T](): seq[string] {.compileTime.} =
  # currently only a single uniform block supported, therefore binding = 0
  when not (T is void):
    let uniformName = name(T)
    result.add(&"layout(binding = 0) uniform T{uniformName} {{")
    for fieldname, value in default(T).fieldPairs:
      let glsltype = getGLSLType(value)
      let thename = fieldname
      result.add(&"    {glsltype} {thename};")
    result.add(&"}} {uniformName};")

func glslOutput*[T](): seq[string] {.compileTime.} =
  when not (T is void):
    var i = 0'u32
    for fieldname, value in default(T).fieldPairs:
      let glsltype = getGLSLType(value)
      let thename = fieldname
      result.add &"layout(location = {i}) out {glsltype} {thename};"
      i += 1
  else:
    result
