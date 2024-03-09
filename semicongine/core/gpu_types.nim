import std/strformat
import std/tables

import ./vulkanapi
import ./vector
import ./matrix
import ./imagetypes

type
  GPUType* = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64] | Texture
  DataType* = enum
    Float32
    Float64
    Int8
    Int16
    Int32
    Int64
    UInt8
    UInt16
    UInt32
    UInt64
    Vec2I32
    Vec2I64
    Vec3I32
    Vec3I64
    Vec4I32
    Vec4I64
    Vec2U32
    Vec2U64
    Vec3U32
    Vec3U64
    Vec4U32
    Vec4U64
    Vec2F32
    Vec2F64
    Vec3F32
    Vec3F64
    Vec4F32
    Vec4F64
    Mat2F32
    Mat2F64
    Mat23F32
    Mat23F64
    Mat32F32
    Mat32F64
    Mat3F32
    Mat3F64
    Mat34F32
    Mat34F64
    Mat43F32
    Mat43F64
    Mat4F32
    Mat4F64
    TextureType
  MemoryPerformanceHint* = enum
    PreferFastRead, PreferFastWrite
  ShaderAttribute* = object
    name*: string
    theType*: DataType
    arrayCount*: int
    perInstance*: bool
    noInterpolation: bool
    memoryPerformanceHint*: MemoryPerformanceHint

proc `$`*(attr: ShaderAttribute): string =
  result = attr.name
  if attr.perInstance:
    result &= "*"
  result &= &"[{attr.theType}"
  if attr.arrayCount > 0:
    result &= &", {attr.arrayCount}"
  result &= "]"

func vertexInputs*(attributes: seq[ShaderAttribute]): seq[ShaderAttribute] =
  for attr in attributes:
    if attr.perInstance == false:
      result.add attr

func instanceInputs*(attributes: seq[ShaderAttribute]): seq[ShaderAttribute] =
  for attr in attributes:
    if attr.perInstance == false:
      result.add attr

func numberOfVertexInputAttributeDescriptors*(theType: DataType): int =
  case theType:
    of Mat2F32, Mat2F64, Mat23F32, Mat23F64: 2
    of Mat32F32, Mat32F64, Mat3F32, Mat3F64, Mat34F32, Mat34F64: 3
    of Mat43F32, Mat43F64, Mat4F32, Mat4F64: 4
    else: 1

func size*(theType: DataType): int =
  case theType:
    of Float32: 4
    of Float64: 8
    of Int8: 1
    of Int16: 2
    of Int32: 4
    of Int64: 8
    of UInt8: 1
    of UInt16: 2
    of UInt32: 4
    of UInt64: 8
    of Vec2I32: 8
    of Vec2I64: 16
    of Vec3I32: 12
    of Vec3I64: 24
    of Vec4I32: 16
    of Vec4I64: 32
    of Vec2U32: 8
    of Vec2U64: 16
    of Vec3U32: 12
    of Vec3U64: 24
    of Vec4U32: 16
    of Vec4U64: 32
    of Vec2F32: 8
    of Vec2F64: 16
    of Vec3F32: 12
    of Vec3F64: 24
    of Vec4F32: 16
    of Vec4F64: 32
    of Mat2F32: 16
    of Mat2F64: 32
    of Mat23F32: 24
    of Mat23F64: 48
    of Mat32F32: 24
    of Mat32F64: 48
    of Mat3F32: 36
    of Mat3F64: 72
    of Mat34F32: 48
    of Mat34F64: 92
    of Mat43F32: 48
    of Mat43F64: 92
    of Mat4F32: 64
    of Mat4F64: 128
    of TextureType: 0

func size*(attribute: ShaderAttribute, perDescriptor = false): int =
  if perDescriptor:
    attribute.theType.size div attribute.theType.numberOfVertexInputAttributeDescriptors
  else:
    if attribute.arrayCount == 0:
      attribute.theType.size
    else:
      attribute.theType.size * attribute.arrayCount

func size*(theType: seq[ShaderAttribute]): int =
  for attribute in theType:
    result += attribute.size

func getDataType*[T: GPUType|int|uint|float](): DataType =
  when T is float32: Float32
  elif T is float64: Float64
  elif T is int8: Int8
  elif T is int16: Int16
  elif T is int32: Int32
  elif T is int64: Int64
  elif T is uint8: UInt8
  elif T is uint16: UInt16
  elif T is uint32: UInt32
  elif T is uint64: UInt64
  elif T is int and sizeof(int) == sizeof(int64): Int64
  elif T is int and sizeof(int) == sizeof(int32): Int32
  elif T is uint and sizeof(uint) == sizeof(uint64): UInt64
  elif T is uint and sizeof(uint) == sizeof(uint32): UInt32
  elif T is float and sizeof(float) == sizeof(float32): Float32
  elif T is float and sizeof(float) == sizeof(float64): Float64
  elif T is TVec2[int32]: Vec2I32
  elif T is TVec2[int64]: Vec2I64
  elif T is TVec3[int32]: Vec3I32
  elif T is TVec3[int64]: Vec3I64
  elif T is TVec4[int32]: Vec4I32
  elif T is TVec4[int64]: Vec4I64
  elif T is TVec2[uint32]: Vec2U32
  elif T is TVec2[uint64]: Vec2U64
  elif T is TVec3[uint32]: Vec3U32
  elif T is TVec3[uint64]: Vec3U64
  elif T is TVec4[uint32]: Vec4U32
  elif T is TVec4[uint64]: Vec4U64
  elif T is TVec2[float32]: Vec2F32
  elif T is TVec2[float64]: Vec2F64
  elif T is TVec3[float32]: Vec3F32
  elif T is TVec3[float64]: Vec3F64
  elif T is TVec4[float32]: Vec4F32
  elif T is TVec4[float64]: Vec4F64
  elif T is TMat2[float32]: Mat2F32
  elif T is TMat2[float64]: Mat2F64
  elif T is TMat23[float32]: Mat23F32
  elif T is TMat23[float64]: Mat23F64
  elif T is TMat32[float32]: Mat32F32
  elif T is TMat32[float64]: Mat32F64
  elif T is TMat3[float32]: Mat3F32
  elif T is TMat3[float64]: Mat3F64
  elif T is TMat34[float32]: Mat34F32
  elif T is TMat34[float64]: Mat34F64
  elif T is TMat43[float32]: Mat43F32
  elif T is TMat43[float64]: Mat43F64
  elif T is TMat4[float32]: Mat4F32
  elif T is TMat4[float64]: Mat4F64
  elif T is Texture: TextureType
  else:
    static:
      raise newException(Exception, &"Unsupported data type for GPU data: {name(T)}")

func attr*[T: GPUType](
  name: string,
  perInstance = false,
  arrayCount = 0,
  noInterpolation = false,
  memoryPerformanceHint = PreferFastRead,
): auto =
  ShaderAttribute(
    name: name,
    theType: getDataType[T](),
    perInstance: perInstance,
    arrayCount: arrayCount,
    noInterpolation: noInterpolation,
    memoryPerformanceHint: memoryPerformanceHint,
  )

const TYPEMAP = {
    Float32: VK_FORMAT_R32_SFLOAT,
    Float64: VK_FORMAT_R64_SFLOAT,
    Int8: VK_FORMAT_R8_SINT,
    Int16: VK_FORMAT_R16_SINT,
    Int32: VK_FORMAT_R32_SINT,
    Int64: VK_FORMAT_R64_SINT,
    UInt8: VK_FORMAT_R8_UINT,
    UInt16: VK_FORMAT_R16_UINT,
    UInt32: VK_FORMAT_R32_UINT,
    UInt64: VK_FORMAT_R64_UINT,
    Vec2I32: VK_FORMAT_R32G32_SINT,
    Vec2I64: VK_FORMAT_R64G64_SINT,
    Vec3I32: VK_FORMAT_R32G32B32_SINT,
    Vec3I64: VK_FORMAT_R64G64B64_SINT,
    Vec4I32: VK_FORMAT_R32G32B32A32_SINT,
    Vec4I64: VK_FORMAT_R64G64B64A64_SINT,
    Vec2U32: VK_FORMAT_R32G32_UINT,
    Vec2U64: VK_FORMAT_R64G64_UINT,
    Vec3U32: VK_FORMAT_R32G32B32_UINT,
    Vec3U64: VK_FORMAT_R64G64B64_UINT,
    Vec4U32: VK_FORMAT_R32G32B32A32_UINT,
    Vec4U64: VK_FORMAT_R64G64B64A64_UINT,
    Vec2F32: VK_FORMAT_R32G32_SFLOAT,
    Vec2F64: VK_FORMAT_R64G64_SFLOAT,
    Vec3F32: VK_FORMAT_R32G32B32_SFLOAT,
    Vec3F64: VK_FORMAT_R64G64B64_SFLOAT,
    Vec4F32: VK_FORMAT_R32G32B32A32_SFLOAT,
    Vec4F64: VK_FORMAT_R64G64B64A64_SFLOAT,
    Mat2F32: VK_FORMAT_R32G32_SFLOAT,
    Mat2F64: VK_FORMAT_R64G64_SFLOAT,
    Mat23F32: VK_FORMAT_R32G32B32_SFLOAT,
    Mat23F64: VK_FORMAT_R64G64B64_SFLOAT,
    Mat32F32: VK_FORMAT_R32G32_SFLOAT,
    Mat32F64: VK_FORMAT_R64G64_SFLOAT,
    Mat3F32: VK_FORMAT_R32G32B32_SFLOAT,
    Mat3F64: VK_FORMAT_R64G64B64_SFLOAT,
    Mat34F32: VK_FORMAT_R32G32B32A32_SFLOAT,
    Mat34F64: VK_FORMAT_R64G64B64A64_SFLOAT,
    Mat43F32: VK_FORMAT_R32G32B32_SFLOAT,
    Mat43F64: VK_FORMAT_R64G64B64_SFLOAT,
    Mat4F32: VK_FORMAT_R32G32B32A32_SFLOAT,
    Mat4F64: VK_FORMAT_R64G64B64A64_SFLOAT,
}.toTable

func getVkFormat*(theType: DataType): VkFormat =
  TYPEMAP[theType]

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots*(theType: DataType): int =
  #[
  single location:
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  case theType:
    of Float32: 1
    of Float64: 1
    of Int8: 1
    of Int16: 1
    of Int32: 1
    of Int64: 1
    of UInt8: 1
    of UInt16: 1
    of UInt32: 1
    of UInt64: 1
    of Vec2I32: 1
    of Vec2I64: 1
    of Vec3I32: 1
    of Vec3I64: 2
    of Vec4I32: 1
    of Vec4I64: 2
    of Vec2U32: 1
    of Vec2U64: 1
    of Vec3U32: 1
    of Vec3U64: 2
    of Vec4U32: 1
    of Vec4U64: 2
    of Vec2F32: 1
    of Vec2F64: 1
    of Vec3F32: 1
    of Vec3F64: 2
    of Vec4F32: 1
    of Vec4F64: 2
    of Mat2F32: 1
    of Mat2F64: 1
    of Mat23F32: 1
    of Mat23F64: 2
    of Mat32F32: 1
    of Mat32F64: 1
    of Mat3F32: 1
    of Mat3F64: 2
    of Mat34F32: 1
    of Mat34F64: 2
    of Mat43F32: 1
    of Mat43F64: 2
    of Mat4F32: 1
    of Mat4F64: 2
    of TextureType: 1

func glslType*(theType: DataType): string =
  # todo: likely not correct as we would need to enable some
  # extensions somewhere (Vulkan/GLSL compiler?) to have
  # everything work as intended. Or maybe the GPU driver does
  # some automagic conversion stuf..
  case theType:
    of Float32: "float"
    of Float64: "double"
    of Int8, Int16, Int32, Int64: "int"
    of UInt8, UInt16, UInt32, UInt64: "uint"
    of Vec2I32: "ivec2"
    of Vec2I64: "ivec2"
    of Vec3I32: "ivec3"
    of Vec3I64: "ivec3"
    of Vec4I32: "ivec4"
    of Vec4I64: "ivec4"
    of Vec2U32: "uvec2"
    of Vec2U64: "uvec2"
    of Vec3U32: "uvec3"
    of Vec3U64: "uvec3"
    of Vec4U32: "uvec4"
    of Vec4U64: "uvec4"
    of Vec2F32: "vec2"
    of Vec2F64: "dvec2"
    of Vec3F32: "vec3"
    of Vec3F64: "dvec3"
    of Vec4F32: "vec4"
    of Vec4F64: "dvec4"
    of Mat2F32: "mat2"
    of Mat2F64: "dmat2"
    of Mat23F32: "mat23"
    of Mat23F64: "dmat23"
    of Mat32F32: "mat32"
    of Mat32F64: "dmat32"
    of Mat3F32: "mat3"
    of Mat3F64: "dmat3"
    of Mat34F32: "mat34"
    of Mat34F64: "dmat34"
    of Mat43F32: "mat43"
    of Mat43F64: "dmat43"
    of Mat4F32: "mat4"
    of Mat4F64: "dmat4"
    of TextureType: "sampler2D"

func glslInput*(group: openArray[ShaderAttribute]): seq[string] =
  if group.len == 0:
    return @[]
  var i = 0
  for attribute in group:
    assert attribute.arrayCount == 0, "arrays not supported for shader vertex attributes"
    let flat = if attribute.noInterpolation: "flat " else: ""
    result.add &"layout(location = {i}) {flat}in {attribute.theType.glslType} {attribute.name};"
    for j in 0 ..< attribute.theType.numberOfVertexInputAttributeDescriptors:
      i += attribute.theType.nLocationSlots

func glslUniforms*(group: openArray[ShaderAttribute], blockName = "Uniforms", binding: int): seq[string] =
  if group.len == 0:
    return @[]
  # currently only a single uniform block supported, therefore binding = 0
  result.add(&"layout(std430, binding = {binding}) uniform T{blockName} {{")
  var last_size = high(int)
  for attribute in group:
    assert attribute.size <= last_size, &"The attribute '{attribute.name}' is bigger than the attribute before, which is not allowed" # using smaller uniform-types first will lead to problems (I think due to alignment, there is also some stuff on the internet about this ;)
    var arrayDecl = ""
    if attribute.arrayCount > 0:
      arrayDecl = &"[{attribute.arrayCount}]"
    result.add(&"    {attribute.theType.glslType} {attribute.name}{arrayDecl};")
    last_size = attribute.size
  result.add(&"}} {blockName};")

func glslSamplers*(group: openArray[ShaderAttribute], basebinding: int): seq[string] =
  if group.len == 0:
    return @[]
  var thebinding = basebinding
  for attribute in group:
    var arrayDecl = ""
    if attribute.arrayCount > 0:
      arrayDecl = &"[{attribute.arrayCount}]"
    result.add(&"layout(binding = {thebinding}) uniform {attribute.theType.glslType} {attribute.name}{arrayDecl};")
    inc thebinding

func glslOutput*(group: openArray[ShaderAttribute]): seq[string] =
  if group.len == 0:
    return @[]
  var i = 0
  for attribute in group:
    assert attribute.arrayCount == 0, "arrays not supported for outputs"
    let flat = if attribute.noInterpolation: "flat " else: ""
    result.add &"layout(location = {i}) {flat}out {attribute.theType.glslType} {attribute.name};"
    i += 1
