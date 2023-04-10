import std/typetraits
import std/strformat
import std/tables

import ./vulkan/api
import ./math

type
  GPUType* = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]
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
  DataValue* = object
    case thetype*: DataType
    of Float32: float32: float32
    of Float64: float64: float64
    of Int8: int8: int8
    of Int16: int16: int16
    of Int32: int32: int32
    of Int64: int64: int64
    of UInt8: uint8: uint8
    of UInt16: uint16: uint16
    of UInt32: uint32: uint32
    of UInt64: uint64: uint64
    of Vec2I32: vec2i32: TVec2[int32]
    of Vec2I64: vec2i64: TVec2[int64]
    of Vec3I32: vec3i32: TVec3[int32]
    of Vec3I64: vec3i64: TVec3[int64]
    of Vec4I32: vec4i32: TVec4[int32]
    of Vec4I64: vec4i64: TVec4[int64]
    of Vec2U32: vec2u32: TVec2[uint32]
    of Vec2U64: vec2u64: TVec2[uint64]
    of Vec3U32: vec3u32: TVec3[uint32]
    of Vec3U64: vec3u64: TVec3[uint64]
    of Vec4U32: vec4u32: TVec4[uint32]
    of Vec4U64: vec4u64: TVec4[uint64]
    of Vec2F32: vec2f32: TVec2[float32]
    of Vec2F64: vec2f64: TVec2[float64]
    of Vec3F32: vec3f32: TVec3[float32]
    of Vec3F64: vec3f64: TVec3[float64]
    of Vec4F32: vec4f32: TVec4[float32]
    of Vec4F64: vec4f64: TVec4[float64]
    of Mat2F32: mat2f32: TMat2[float32]
    of Mat2F64: mat2f64: TMat2[float64]
    of Mat23F32: mat23f32: TMat23[float32]
    of Mat23F64: mat23f64: TMat23[float64]
    of Mat32F32: mat32f32: TMat32[float32]
    of Mat32F64: mat32f64: TMat32[float64]
    of Mat3F32: mat3f32: TMat3[float32]
    of Mat3F64: mat3f64: TMat3[float64]
    of Mat34F32: mat34f32: TMat34[float32]
    of Mat34F64: mat34f64: TMat34[float64]
    of Mat43F32: mat43f32: TMat43[float32]
    of Mat43F64: mat43f64: TMat43[float64]
    of Mat4F32: mat4f32: TMat4[float32]
    of Mat4F64: mat4f64: TMat4[float64]
  DataList* = object
    len*: uint32
    case thetype*: DataType
    of Float32: float32: seq[float32]
    of Float64: float64: seq[float64]
    of Int8: int8: seq[int8]
    of Int16: int16: seq[int16]
    of Int32: int32: seq[int32]
    of Int64: int64: seq[int64]
    of UInt8: uint8: seq[uint8]
    of UInt16: uint16: seq[uint16]
    of UInt32: uint32: seq[uint32]
    of UInt64: uint64: seq[uint64]
    of Vec2I32: vec2i32: seq[TVec2[int32]]
    of Vec2I64: vec2i64: seq[TVec2[int64]]
    of Vec3I32: vec3i32: seq[TVec3[int32]]
    of Vec3I64: vec3i64: seq[TVec3[int64]]
    of Vec4I32: vec4i32: seq[TVec4[int32]]
    of Vec4I64: vec4i64: seq[TVec4[int64]]
    of Vec2U32: vec2u32: seq[TVec2[uint32]]
    of Vec2U64: vec2u64: seq[TVec2[uint64]]
    of Vec3U32: vec3u32: seq[TVec3[uint32]]
    of Vec3U64: vec3u64: seq[TVec3[uint64]]
    of Vec4U32: vec4u32: seq[TVec4[uint32]]
    of Vec4U64: vec4u64: seq[TVec4[uint64]]
    of Vec2F32: vec2f32: seq[TVec2[float32]]
    of Vec2F64: vec2f64: seq[TVec2[float64]]
    of Vec3F32: vec3f32: seq[TVec3[float32]]
    of Vec3F64: vec3f64: seq[TVec3[float64]]
    of Vec4F32: vec4f32: seq[TVec4[float32]]
    of Vec4F64: vec4f64: seq[TVec4[float64]]
    of Mat2F32: mat2f32: seq[TMat2[float32]]
    of Mat2F64: mat2f64: seq[TMat2[float64]]
    of Mat23F32: mat23f32: seq[TMat23[float32]]
    of Mat23F64: mat23f64: seq[TMat23[float64]]
    of Mat32F32: mat32f32: seq[TMat32[float32]]
    of Mat32F64: mat32f64: seq[TMat32[float64]]
    of Mat3F32: mat3f32: seq[TMat3[float32]]
    of Mat3F64: mat3f64: seq[TMat3[float64]]
    of Mat34F32: mat34f32: seq[TMat34[float32]]
    of Mat34F64: mat34f64: seq[TMat34[float64]]
    of Mat43F32: mat43f32: seq[TMat43[float32]]
    of Mat43F64: mat43f64: seq[TMat43[float64]]
    of Mat4F32: mat4f32: seq[TMat4[float32]]
    of Mat4F64: mat4f64: seq[TMat4[float64]]
  MemoryLocation* = enum
    VRAM, VRAMVisible, RAM # VRAM is fastest, VRAMVisible allows updating memory directly, may be slower
  ShaderAttribute* = object
    name*: string
    thetype*: DataType
    perInstance*: bool
    memoryLocation*: MemoryLocation

func vertexInputs*(attributes: seq[ShaderAttribute]): seq[ShaderAttribute] =
  for attr in attributes:
    if attr.perInstance == false:
      result.add attr

func instanceInputs*(attributes: seq[ShaderAttribute]): seq[ShaderAttribute] =
  for attr in attributes:
    if attr.perInstance == false:
      result.add attr


func numberOfVertexInputAttributeDescriptors*(thetype: DataType): uint32 =
  case thetype:
    of Mat2F32, Mat2F64, Mat23F32, Mat23F64: 2
    of Mat32F32, Mat32F64, Mat3F32, Mat3F64, Mat34F32, Mat34F64: 3
    of Mat43F32, Mat43F64, Mat4F32, Mat4F64: 4
    else: 1

func size*(thetype: DataType): uint32 =
  case thetype:
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

func size*(attribute: ShaderAttribute, perDescriptor=false): uint32 =
  if perDescriptor: attribute.thetype.size div attribute.thetype.numberOfVertexInputAttributeDescriptors
  else:      attribute.thetype.size

func size*(thetype: seq[ShaderAttribute]): uint32 =
  for attribute in thetype:
    result += attribute.size

func size*(value: DataValue): uint32 =
  value.thetype.size

func size*(value: DataList): uint32 =
  value.thetype.size * value.len

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
  else:
    static:
      raise newException(Exception, &"Unsupported data type for GPU data: {name(T)}" )

func attr*[T: GPUType](
  name: string,
  perInstance=false,
  memoryLocation=VRAMVisible,
): auto =
  ShaderAttribute(
    name: name,
    thetype: getDataType[T](),
    perInstance: perInstance,
    memoryLocation: memoryLocation,
  )

func get*[T: GPUType|int|uint|float](value: DataValue): T =
  when T is float32: value.float32
  elif T is float64: value.float64
  elif T is int8: value.int8
  elif T is int16: value.int16
  elif T is int32: value.int32
  elif T is int64: value.int64
  elif T is uint8: value.uint8
  elif T is uint16: value.uint16
  elif T is uint32: value.uint32
  elif T is uint64: value.uint64
  elif T is int and sizeof(int) == sizeof(int32): value.int32
  elif T is int and sizeof(int) == sizeof(int64): value.int64
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64
  elif T is float and sizeof(float) == sizeof(float32): value.float32
  elif T is float and sizeof(float) == sizeof(float64): value.float64
  elif T is TVec2[int32]: value.vec2i32
  elif T is TVec2[int64]: value.vec2i64
  elif T is TVec3[int32]: value.vec3i32
  elif T is TVec3[int64]: value.vec3i64
  elif T is TVec4[int32]: value.vec4i32
  elif T is TVec4[int64]: value.vec4i64
  elif T is TVec2[uint32]: value.vec2u32
  elif T is TVec2[uint64]: value.vec2u64
  elif T is TVec3[uint32]: value.vec3u32
  elif T is TVec3[uint64]: value.vec3u64
  elif T is TVec4[uint32]: value.vec4u32
  elif T is TVec4[uint64]: value.vec4u64
  elif T is TVec2[float32]: value.vec2f32
  elif T is TVec2[float64]: value.vec2f64
  elif T is TVec3[float32]: value.vec3f32
  elif T is TVec3[float64]: value.vec3f64
  elif T is TVec4[float32]: value.vec4f32
  elif T is TVec4[float64]: value.vec4f64
  elif T is TMat2[float32]: value.mat2f32
  elif T is TMat2[float64]: value.mat2f64
  elif T is TMat23[float32]: value.mat23f
  elif T is TMat23[float64]: value.mat23f64
  elif T is TMat32[float32]: value.mat32f32
  elif T is TMat32[float64]: value.mat32f64
  elif T is TMat3[float32]: value.mat3f32
  elif T is TMat3[float64]: value.mat3f64
  elif T is TMat34[float32]: value.mat34f32
  elif T is TMat34[float64]: value.mat34f64
  elif T is TMat43[float32]: value.mat43f32
  elif T is TMat43[float64]: value.mat43f64
  elif T is TMat4[float32]: value.mat4f32
  elif T is TMat4[float64]: value.mat4f64

func get*[T: GPUType|int|uint|float](value: DataList): seq[T] =
  when T is float32: value.float32
  elif T is float64: value.float64
  elif T is int8: value.int8
  elif T is int16: value.int16
  elif T is int32: value.int32
  elif T is int64: value.int64
  elif T is uint8: value.uint8
  elif T is uint16: value.uint16
  elif T is uint32: value.uint32
  elif T is uint64: value.uint64
  elif T is int and sizeof(int) == sizeof(int32): value.int32
  elif T is int and sizeof(int) == sizeof(int64): value.int64
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64
  elif T is float and sizeof(float) == sizeof(float32): value.float32
  elif T is float and sizeof(float) == sizeof(float64): value.float64
  elif T is TVec2[int32]: value.vec2i32
  elif T is TVec2[int64]: value.vec2i64
  elif T is TVec3[int32]: value.vec3i32
  elif T is TVec3[int64]: value.vec3i64
  elif T is TVec4[int32]: value.vec4i32
  elif T is TVec4[int64]: value.vec4i64
  elif T is TVec2[uint32]: value.vec2u32
  elif T is TVec2[uint64]: value.vec2u64
  elif T is TVec3[uint32]: value.vec3u32
  elif T is TVec3[uint64]: value.vec3u64
  elif T is TVec4[uint32]: value.vec4u32
  elif T is TVec4[uint64]: value.vec4u64
  elif T is TVec2[float32]: value.vec2f32
  elif T is TVec2[float64]: value.vec2f64
  elif T is TVec3[float32]: value.vec3f32
  elif T is TVec3[float64]: value.vec3f64
  elif T is TVec4[float32]: value.vec4f32
  elif T is TVec4[float64]: value.vec4f64
  elif T is TMat2[float32]: value.mat2f32
  elif T is TMat2[float64]: value.mat2f64
  elif T is TMat23[float32]: value.mat23f
  elif T is TMat23[float64]: value.mat23f64
  elif T is TMat32[float32]: value.mat32f32
  elif T is TMat32[float64]: value.mat32f64
  elif T is TMat3[float32]: value.mat3f32
  elif T is TMat3[float64]: value.mat3f64
  elif T is TMat34[float32]: value.mat34f32
  elif T is TMat34[float64]: value.mat34f64
  elif T is TMat43[float32]: value.mat43f32
  elif T is TMat43[float64]: value.mat43f64
  elif T is TMat4[float32]: value.mat4f32
  elif T is TMat4[float64]: value.mat4f64

func getRawData*(value: var DataValue): (pointer, uint32) =
  result[1] = value.thetype.size
  case value.thetype
    of Float32: result[0] = addr value.float32
    of Float64: result[0] = addr value.float64
    of Int8: result[0] = addr value.int8
    of Int16: result[0] = addr value.int16
    of Int32: result[0] = addr value.int32
    of Int64: result[0] = addr value.int64
    of UInt8: result[0] = addr value.uint8
    of UInt16: result[0] = addr value.uint16
    of UInt32: result[0] = addr value.uint32
    of UInt64: result[0] = addr value.uint64
    of Vec2I32: result[0] = addr value.vec2i32
    of Vec2I64: result[0] = addr value.vec2i64
    of Vec3I32: result[0] = addr value.vec3i32
    of Vec3I64: result[0] = addr value.vec3i64
    of Vec4I32: result[0] = addr value.vec4i32
    of Vec4I64: result[0] = addr value.vec4i64
    of Vec2U32: result[0] = addr value.vec2u32
    of Vec2U64: result[0] = addr value.vec2u64
    of Vec3U32: result[0] = addr value.vec3u32
    of Vec3U64: result[0] = addr value.vec3u64
    of Vec4U32: result[0] = addr value.vec4u32
    of Vec4U64: result[0] = addr value.vec4u64
    of Vec2F32: result[0] = addr value.vec2f32
    of Vec2F64: result[0] = addr value.vec2f64
    of Vec3F32: result[0] = addr value.vec3f32
    of Vec3F64: result[0] = addr value.vec3f64
    of Vec4F32: result[0] = addr value.vec4f32
    of Vec4F64: result[0] = addr value.vec4f64
    of Mat2F32: result[0] = addr value.mat2f32
    of Mat2F64: result[0] = addr value.mat2f64
    of Mat23F32: result[0] = addr value.mat23f32
    of Mat23F64: result[0] = addr value.mat23f64
    of Mat32F32: result[0] = addr value.mat32f32
    of Mat32F64: result[0] = addr value.mat32f64
    of Mat3F32: result[0] = addr value.mat3f32
    of Mat3F64: result[0] = addr value.mat3f64
    of Mat34F32: result[0] = addr value.mat34f32
    of Mat34F64: result[0] = addr value.mat34f64
    of Mat43F32: result[0] = addr value.mat43f32
    of Mat43F64: result[0] = addr value.mat43f64
    of Mat4F32: result[0] = addr value.mat4f32
    of Mat4F64: result[0] = addr value.mat4f64

func getRawData*(value: var DataList): (pointer, uint32) =
  result[1] = value.thetype.size * value.len
  case value.thetype
    of Float32: result[0] = addr value.float32[0]
    of Float64: result[0] = addr value.float64[0]
    of Int8: result[0] = addr value.int8[0]
    of Int16: result[0] = addr value.int16[0]
    of Int32: result[0] = addr value.int32[0]
    of Int64: result[0] = addr value.int64[0]
    of UInt8: result[0] = addr value.uint8[0]
    of UInt16: result[0] = addr value.uint16[0]
    of UInt32: result[0] = addr value.uint32[0]
    of UInt64: result[0] = addr value.uint64[0]
    of Vec2I32: result[0] = addr value.vec2i32[0]
    of Vec2I64: result[0] = addr value.vec2i64[0]
    of Vec3I32: result[0] = addr value.vec3i32[0]
    of Vec3I64: result[0] = addr value.vec3i64[0]
    of Vec4I32: result[0] = addr value.vec4i32[0]
    of Vec4I64: result[0] = addr value.vec4i64[0]
    of Vec2U32: result[0] = addr value.vec2u32[0]
    of Vec2U64: result[0] = addr value.vec2u64[0]
    of Vec3U32: result[0] = addr value.vec3u32[0]
    of Vec3U64: result[0] = addr value.vec3u64[0]
    of Vec4U32: result[0] = addr value.vec4u32[0]
    of Vec4U64: result[0] = addr value.vec4u64[0]
    of Vec2F32: result[0] = addr value.vec2f32[0]
    of Vec2F64: result[0] = addr value.vec2f64[0]
    of Vec3F32: result[0] = addr value.vec3f32[0]
    of Vec3F64: result[0] = addr value.vec3f64[0]
    of Vec4F32: result[0] = addr value.vec4f32[0]
    of Vec4F64: result[0] = addr value.vec4f64[0]
    of Mat2F32: result[0] = addr value.mat2f32[0]
    of Mat2F64: result[0] = addr value.mat2f64[0]
    of Mat23F32: result[0] = addr value.mat23f32[0]
    of Mat23F64: result[0] = addr value.mat23f64[0]
    of Mat32F32: result[0] = addr value.mat32f32[0]
    of Mat32F64: result[0] = addr value.mat32f64[0]
    of Mat3F32: result[0] = addr value.mat3f32[0]
    of Mat3F64: result[0] = addr value.mat3f64[0]
    of Mat34F32: result[0] = addr value.mat34f32[0]
    of Mat34F64: result[0] = addr value.mat34f64[0]
    of Mat43F32: result[0] = addr value.mat43f32[0]
    of Mat43F64: result[0] = addr value.mat43f64[0]
    of Mat4F32: result[0] = addr value.mat4f32[0]
    of Mat4F64: result[0] = addr value.mat4f64[0]

func setValue*[T: GPUType|int|uint|float](value: var DataValue, data: T) =
  when T is float32: value.float32 = data
  elif T is float64: value.float64 = data
  elif T is int8: value.int8 = data
  elif T is int16: value.int16 = data
  elif T is int32: value.int32 = data
  elif T is int64: value.int64 = data
  elif T is uint8: value.uint8 = data
  elif T is uint16: value.uint16 = data
  elif T is uint32: value.uint32 = data
  elif T is uint64: value.uint64 = data
  elif T is int and sizeof(int) == sizeof(int32): value.int32 = data
  elif T is int and sizeof(int) == sizeof(int64): value.int64 = data
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32 = data
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64 = data
  elif T is float and sizeof(float) == sizeof(float32): value.float32 = data
  elif T is float and sizeof(float) == sizeof(float64): value.float64 = data
  elif T is TVec2[int32]: value.vec2i32 = data
  elif T is TVec2[int64]: value.vec2i64 = data
  elif T is TVec3[int32]: value.vec3i32 = data
  elif T is TVec3[int64]: value.vec3i64 = data
  elif T is TVec4[int32]: value.vec4i32 = data
  elif T is TVec4[int64]: value.vec4i64 = data
  elif T is TVec2[uint32]: value.vec2u32 = data
  elif T is TVec2[uint64]: value.vec2u64 = data
  elif T is TVec3[uint32]: value.vec3u32 = data
  elif T is TVec3[uint64]: value.vec3u64 = data
  elif T is TVec4[uint32]: value.vec4u32 = data
  elif T is TVec4[uint64]: value.vec4u64 = data
  elif T is TVec2[float32]: value.vec2f32 = data
  elif T is TVec2[float64]: value.vec2f64 = data
  elif T is TVec3[float32]: value.vec3f32 = data
  elif T is TVec3[float64]: value.vec3f64 = data
  elif T is TVec4[float32]: value.vec4f32 = data
  elif T is TVec4[float64]: value.vec4f64 = data
  elif T is TMat2[float32]: value.mat2f32 = data
  elif T is TMat2[float64]: value.mat2f64 = data
  elif T is TMat23[float32]: value.mat23f32 = data
  elif T is TMat23[float64]: value.mat23f64 = data
  elif T is TMat32[float32]: value.mat32f32 = data
  elif T is TMat32[float64]: value.mat32f64 = data
  elif T is TMat3[float32]: value.mat3f32 = data
  elif T is TMat3[float64]: value.mat3f64 = data
  elif T is TMat34[float32]: value.mat34f32 = data
  elif T is TMat34[float64]: value.mat34f64 = data
  elif T is TMat43[float32]: value.mat43f32 = data
  elif T is TMat43[float64]: value.mat43f64 = data
  elif T is TMat4[float32]: value.mat4f32 = data
  elif T is TMat4[float64]: value.mat4f64 = data

func setValues*[T: GPUType|int|uint|float](value: var DataList, data: seq[T]) =
  value.len = uint32(data.len)
  when T is float32: value.float32 = data
  elif T is float64: value.float64 = data
  elif T is int8: value.int8 = data
  elif T is int16: value.int16 = data
  elif T is int32: value.int32 = data
  elif T is int64: value.int64 = data
  elif T is uint8: value.uint8 = data
  elif T is uint16: value.uint16 = data
  elif T is uint32: value.uint32 = data
  elif T is uint64: value.uint64 = data
  elif T is int and sizeof(int) == sizeof(int32): value.int32 = data
  elif T is int and sizeof(int) == sizeof(int64): value.int64 = data
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32 = data
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64 = data
  elif T is float and sizeof(float) == sizeof(float32): value.float32 = data
  elif T is float and sizeof(float) == sizeof(float64): value.float64 = data
  elif T is TVec2[int32]: value.vec2i32 = data
  elif T is TVec2[int64]: value.vec2i64 = data
  elif T is TVec3[int32]: value.vec3i32 = data
  elif T is TVec3[int64]: value.vec3i64 = data
  elif T is TVec4[int32]: value.vec4i32 = data
  elif T is TVec4[int64]: value.vec4i64 = data
  elif T is TVec2[uint32]: value.vec2u32 = data
  elif T is TVec2[uint64]: value.vec2u64 = data
  elif T is TVec3[uint32]: value.vec3u32 = data
  elif T is TVec3[uint64]: value.vec3u64 = data
  elif T is TVec4[uint32]: value.vec4u32 = data
  elif T is TVec4[uint64]: value.vec4u64 = data
  elif T is TVec2[float32]: value.vec2f32 = data
  elif T is TVec2[float64]: value.vec2f64 = data
  elif T is TVec3[float32]: value.vec3f32 = data
  elif T is TVec3[float64]: value.vec3f64 = data
  elif T is TVec4[float32]: value.vec4f32 = data
  elif T is TVec4[float64]: value.vec4f64 = data
  elif T is TMat2[float32]: value.mat2f32 = data
  elif T is TMat2[float64]: value.mat2f64 = data
  elif T is TMat23[float32]: value.mat23f32 = data
  elif T is TMat23[float64]: value.mat23f64 = data
  elif T is TMat32[float32]: value.mat32f32 = data
  elif T is TMat32[float64]: value.mat32f64 = data
  elif T is TMat3[float32]: value.mat3f32 = data
  elif T is TMat3[float64]: value.mat3f64 = data
  elif T is TMat34[float32]: value.mat34f32 = data
  elif T is TMat34[float64]: value.mat34f64 = data
  elif T is TMat43[float32]: value.mat43f32 = data
  elif T is TMat43[float64]: value.mat43f64 = data
  elif T is TMat4[float32]: value.mat4f32 = data
  elif T is TMat4[float64]: value.mat4f64 = data
func setValue*[T: GPUType|int|uint|float](value: var DataList, i: uint32, data: T) =
  assert i < value.len
  when T is float32: value.float32[i] = data
  elif T is float64: value.float64[i] = data
  elif T is int8: value.int8[i] = data
  elif T is int16: value.int16[i] = data
  elif T is int32: value.int32[i] = data
  elif T is int64: value.int64[i] = data
  elif T is uint8: value.uint8[i] = data
  elif T is uint16: value.uint16[i] = data
  elif T is uint32: value.uint32[i] = data
  elif T is uint64: value.uint64[i] = data
  elif T is int and sizeof(int) == sizeof(int32): value.int32[i] = data
  elif T is int and sizeof(int) == sizeof(int64): value.int64[i] = data
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32[i] = data
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64[i] = data
  elif T is float and sizeof(float) == sizeof(float32): value.float32[i] = data
  elif T is float and sizeof(float) == sizeof(float64): value.float64[i] = data
  elif T is TVec2[int32]: value.vec2i32[i] = data
  elif T is TVec2[int64]: value.vec2i64[i] = data
  elif T is TVec3[int32]: value.vec3i32[i] = data
  elif T is TVec3[int64]: value.vec3i64[i] = data
  elif T is TVec4[int32]: value.vec4i32[i] = data
  elif T is TVec4[int64]: value.vec4i64[i] = data
  elif T is TVec2[uint32]: value.vec2u32[i] = data
  elif T is TVec2[uint64]: value.vec2u64[i] = data
  elif T is TVec3[uint32]: value.vec3u32[i] = data
  elif T is TVec3[uint64]: value.vec3u64[i] = data
  elif T is TVec4[uint32]: value.vec4u32[i] = data
  elif T is TVec4[uint64]: value.vec4u64[i] = data
  elif T is TVec2[float32]: value.vec2f32[i] = data
  elif T is TVec2[float64]: value.vec2f64[i] = data
  elif T is TVec3[float32]: value.vec3f32[i] = data
  elif T is TVec3[float64]: value.vec3f64[i] = data
  elif T is TVec4[float32]: value.vec4f32[i] = data
  elif T is TVec4[float64]: value.vec4f64[i] = data
  elif T is TMat2[float32]: value.mat2f32[i] = data
  elif T is TMat2[float64]: value.mat2f64[i] = data
  elif T is TMat23[float32]: value.mat23f32[i] = data
  elif T is TMat23[float64]: value.mat23f64[i] = data
  elif T is TMat32[float32]: value.mat32f32[i] = data
  elif T is TMat32[float64]: value.mat32f64[i] = data
  elif T is TMat3[float32]: value.mat3f32[i] = data
  elif T is TMat3[float64]: value.mat3f64[i] = data
  elif T is TMat34[float32]: value.mat34f32[i] = data
  elif T is TMat34[float64]: value.mat34f64[i] = data
  elif T is TMat43[float32]: value.mat43f32[i] = data
  elif T is TMat43[float64]: value.mat43f64[i] = data
  elif T is TMat4[float32]: value.mat4f32[i] = data
  elif T is TMat4[float64]: value.mat4f64[i] = data

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

func getVkFormat*(thetype: DataType): VkFormat =
  TYPEMAP[thetype]

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots*(thetype: DataType): uint32 =
  #[
  single location:
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  case thetype:
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

func glslType*(thetype: DataType): string =
  # todo: likely not correct as we would need to enable some 
  # extensions somewhere (Vulkan/GLSL compiler?) to have 
  # everything work as intended. Or maybe the GPU driver does
  # some automagic conversion stuf..
  case thetype:
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

func groupByMemoryLocation*(attributes: openArray[ShaderAttribute]): Table[MemoryLocation, seq[ShaderAttribute]] =
  for attr in attributes:
    if not (attr.memoryLocation in result):
      result[attr.memoryLocation] = @[]
    result[attr.memoryLocation].add attr

func glslInput*(group: seq[ShaderAttribute]): seq[string] =
  if group.len == 0:
    return @[]
  var i = 0'u32
  for attributes in group.groupByMemoryLocation().values:
    for attribute in attributes:
      result.add &"layout(location = {i}) in {attribute.thetype.glslType} {attribute.name};"
      for j in 0 ..< attribute.thetype.numberOfVertexInputAttributeDescriptors:
        i += attribute.thetype.nLocationSlots

func glslUniforms*(group: seq[ShaderAttribute], blockName="Uniforms", binding=0): seq[string] =
  if group.len == 0:
    return @[]
  # currently only a single uniform block supported, therefore binding = 0
  result.add(&"layout(binding = {binding}) uniform T{blockName} {{")
  for attribute in group:
    result.add(&"    {attribute.thetype.glslType} {attribute.name};")
  result.add(&"}} {blockName};")

func glslOutput*(group: seq[ShaderAttribute]): seq[string] =
  if group.len == 0:
    return @[]
  var i = 0'u32
  for attribute in group:
    result.add &"layout(location = {i}) out {attribute.thetype.glslType} {attribute.name};"
    i += 1
