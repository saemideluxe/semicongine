import std/hashes
import std/tables
import std/strformat

import ./gpu_types
import ./vector
import ./matrix
import ./utils
import ./imagetypes

type
  DataList* = object
    len*: int
    case theType*: DataType
    of Float32: float32: ref seq[float32]
    of Float64: float64: ref seq[float64]
    of Int8: int8: ref seq[int8]
    of Int16: int16: ref seq[int16]
    of Int32: int32: ref seq[int32]
    of Int64: int64: ref seq[int64]
    of UInt8: uint8: ref seq[uint8]
    of UInt16: uint16: ref seq[uint16]
    of UInt32: uint32: ref seq[uint32]
    of UInt64: uint64: ref seq[uint64]
    of Vec2I32: vec2i32: ref seq[TVec2[int32]]
    of Vec2I64: vec2i64: ref seq[TVec2[int64]]
    of Vec3I32: vec3i32: ref seq[TVec3[int32]]
    of Vec3I64: vec3i64: ref seq[TVec3[int64]]
    of Vec4I32: vec4i32: ref seq[TVec4[int32]]
    of Vec4I64: vec4i64: ref seq[TVec4[int64]]
    of Vec2U32: vec2u32: ref seq[TVec2[uint32]]
    of Vec2U64: vec2u64: ref seq[TVec2[uint64]]
    of Vec3U32: vec3u32: ref seq[TVec3[uint32]]
    of Vec3U64: vec3u64: ref seq[TVec3[uint64]]
    of Vec4U32: vec4u32: ref seq[TVec4[uint32]]
    of Vec4U64: vec4u64: ref seq[TVec4[uint64]]
    of Vec2F32: vec2f32: ref seq[TVec2[float32]]
    of Vec2F64: vec2f64: ref seq[TVec2[float64]]
    of Vec3F32: vec3f32: ref seq[TVec3[float32]]
    of Vec3F64: vec3f64: ref seq[TVec3[float64]]
    of Vec4F32: vec4f32: ref seq[TVec4[float32]]
    of Vec4F64: vec4f64: ref seq[TVec4[float64]]
    of Mat2F32: mat2f32: ref seq[TMat2[float32]]
    of Mat2F64: mat2f64: ref seq[TMat2[float64]]
    of Mat23F32: mat23f32: ref seq[TMat23[float32]]
    of Mat23F64: mat23f64: ref seq[TMat23[float64]]
    of Mat32F32: mat32f32: ref seq[TMat32[float32]]
    of Mat32F64: mat32f64: ref seq[TMat32[float64]]
    of Mat3F32: mat3f32: ref seq[TMat3[float32]]
    of Mat3F64: mat3f64: ref seq[TMat3[float64]]
    of Mat34F32: mat34f32: ref seq[TMat34[float32]]
    of Mat34F64: mat34f64: ref seq[TMat34[float64]]
    of Mat43F32: mat43f32: ref seq[TMat43[float32]]
    of Mat43F64: mat43f64: ref seq[TMat43[float64]]
    of Mat4F32: mat4f32: ref seq[TMat4[float32]]
    of Mat4F64: mat4f64: ref seq[TMat4[float64]]
    of TextureType: texture: ref seq[Texture]

func size*(value: DataList): uint64 =
  value.theType.size * value.len.uint64

func hash*(value: DataList): Hash =
  case value.theType
    of Float32: hash(value.float32)
    of Float64: hash(value.float64)
    of Int8: hash(value.int8)
    of Int16: hash(value.int16)
    of Int32: hash(value.int32)
    of Int64: hash(value.int64)
    of UInt8: hash(value.uint8)
    of UInt16: hash(value.uint16)
    of UInt32: hash(value.uint32)
    of UInt64: hash(value.uint64)
    of Vec2I32: hash(value.vec2i32)
    of Vec2I64: hash(value.vec2i64)
    of Vec3I32: hash(value.vec3i32)
    of Vec3I64: hash(value.vec3i64)
    of Vec4I32: hash(value.vec4i32)
    of Vec4I64: hash(value.vec4i64)
    of Vec2U32: hash(value.vec2u32)
    of Vec2U64: hash(value.vec2u64)
    of Vec3U32: hash(value.vec3u32)
    of Vec3U64: hash(value.vec3u64)
    of Vec4U32: hash(value.vec4u32)
    of Vec4U64: hash(value.vec4u64)
    of Vec2F32: hash(value.vec2f32)
    of Vec2F64: hash(value.vec2f64)
    of Vec3F32: hash(value.vec3f32)
    of Vec3F64: hash(value.vec3f64)
    of Vec4F32: hash(value.vec4f32)
    of Vec4F64: hash(value.vec4f64)
    of Mat2F32: hash(value.mat2f32)
    of Mat2F64: hash(value.mat2f64)
    of Mat23F32: hash(value.mat23f32)
    of Mat23F64: hash(value.mat23f64)
    of Mat32F32: hash(value.mat32f32)
    of Mat32F64: hash(value.mat32f64)
    of Mat3F32: hash(value.mat3f32)
    of Mat3F64: hash(value.mat3f64)
    of Mat34F32: hash(value.mat34f32)
    of Mat34F64: hash(value.mat34f64)
    of Mat43F32: hash(value.mat43f32)
    of Mat43F64: hash(value.mat43f64)
    of Mat4F32: hash(value.mat4f32)
    of Mat4F64: hash(value.mat4f64)
    of TextureType: hash(value.texture)

func `==`*(a, b: DataList): bool =
  if a.theType != b.theType:
    return false
  case a.theType
    of Float32: return a.float32 == b.float32
    of Float64: return a.float64 == b.float64
    of Int8: return a.int8 == b.int8
    of Int16: return a.int16 == b.int16
    of Int32: return a.int32 == b.int32
    of Int64: return a.int64 == b.int64
    of UInt8: return a.uint8 == b.uint8
    of UInt16: return a.uint16 == b.uint16
    of UInt32: return a.uint32 == b.uint32
    of UInt64: return a.uint64 == b.uint64
    of Vec2I32: return a.vec2i32 == b.vec2i32
    of Vec2I64: return a.vec2i64 == b.vec2i64
    of Vec3I32: return a.vec3i32 == b.vec3i32
    of Vec3I64: return a.vec3i64 == b.vec3i64
    of Vec4I32: return a.vec4i32 == b.vec4i32
    of Vec4I64: return a.vec4i64 == b.vec4i64
    of Vec2U32: return a.vec2u32 == b.vec2u32
    of Vec2U64: return a.vec2u64 == b.vec2u64
    of Vec3U32: return a.vec3u32 == b.vec3u32
    of Vec3U64: return a.vec3u64 == b.vec3u64
    of Vec4U32: return a.vec4u32 == b.vec4u32
    of Vec4U64: return a.vec4u64 == b.vec4u64
    of Vec2F32: return a.vec2f32 == b.vec2f32
    of Vec2F64: return a.vec2f64 == b.vec2f64
    of Vec3F32: return a.vec3f32 == b.vec3f32
    of Vec3F64: return a.vec3f64 == b.vec3f64
    of Vec4F32: return a.vec4f32 == b.vec4f32
    of Vec4F64: return a.vec4f64 == b.vec4f64
    of Mat2F32: return a.mat2f32 == b.mat2f32
    of Mat2F64: return a.mat2f64 == b.mat2f64
    of Mat23F32: return a.mat23f32 == b.mat23f32
    of Mat23F64: return a.mat23f64 == b.mat23f64
    of Mat32F32: return a.mat32f32 == b.mat32f32
    of Mat32F64: return a.mat32f64 == b.mat32f64
    of Mat3F32: return a.mat3f32 == b.mat3f32
    of Mat3F64: return a.mat3f64 == b.mat3f64
    of Mat34F32: return a.mat34f32 == b.mat34f32
    of Mat34F64: return a.mat34f64 == b.mat34f64
    of Mat43F32: return a.mat43f32 == b.mat43f32
    of Mat43F64: return a.mat43f64 == b.mat43f64
    of Mat4F32: return a.mat4f32 == b.mat4f32
    of Mat4F64: return a.mat4f64 == b.mat4f64
    of TextureType: a.texture == b.texture

proc setLen*(value: var DataList, len: int) =
  value.len = len
  case value.theType
    of Float32: value.float32[].setLen(len)
    of Float64: value.float64[].setLen(len)
    of Int8: value.int8[].setLen(len)
    of Int16: value.int16[].setLen(len)
    of Int32: value.int32[].setLen(len)
    of Int64: value.int64[].setLen(len)
    of UInt8: value.uint8[].setLen(len)
    of UInt16: value.uint16[].setLen(len)
    of UInt32: value.uint32[].setLen(len)
    of UInt64: value.uint64[].setLen(len)
    of Vec2I32: value.vec2i32[].setLen(len)
    of Vec2I64: value.vec2i64[].setLen(len)
    of Vec3I32: value.vec3i32[].setLen(len)
    of Vec3I64: value.vec3i64[].setLen(len)
    of Vec4I32: value.vec4i32[].setLen(len)
    of Vec4I64: value.vec4i64[].setLen(len)
    of Vec2U32: value.vec2u32[].setLen(len)
    of Vec2U64: value.vec2u64[].setLen(len)
    of Vec3U32: value.vec3u32[].setLen(len)
    of Vec3U64: value.vec3u64[].setLen(len)
    of Vec4U32: value.vec4u32[].setLen(len)
    of Vec4U64: value.vec4u64[].setLen(len)
    of Vec2F32: value.vec2f32[].setLen(len)
    of Vec2F64: value.vec2f64[].setLen(len)
    of Vec3F32: value.vec3f32[].setLen(len)
    of Vec3F64: value.vec3f64[].setLen(len)
    of Vec4F32: value.vec4f32[].setLen(len)
    of Vec4F64: value.vec4f64[].setLen(len)
    of Mat2F32: value.mat2f32[].setLen(len)
    of Mat2F64: value.mat2f64[].setLen(len)
    of Mat23F32: value.mat23f32[].setLen(len)
    of Mat23F64: value.mat23f64[].setLen(len)
    of Mat32F32: value.mat32f32[].setLen(len)
    of Mat32F64: value.mat32f64[].setLen(len)
    of Mat3F32: value.mat3f32[].setLen(len)
    of Mat3F64: value.mat3f64[].setLen(len)
    of Mat34F32: value.mat34f32[].setLen(len)
    of Mat34F64: value.mat34f64[].setLen(len)
    of Mat43F32: value.mat43f32[].setLen(len)
    of Mat43F64: value.mat43f64[].setLen(len)
    of Mat4F32: value.mat4f32[].setLen(len)
    of Mat4F64: value.mat4f64[].setLen(len)
    of TextureType: discard


proc setValues[T: GPUType|int|uint|float](value: var DataList, data: openArray[T]) =
  value.setLen(data.len)
  when T is float32: value.float32[] = @data
  elif T is float64: value.float64[] = @data
  elif T is int8: value.int8[] = @data
  elif T is int16: value.int16[] = @data
  elif T is int32: value.int32[] = @data
  elif T is int64: value.int64[] = @data
  elif T is uint8: value.uint8[] = @data
  elif T is uint16: value.uint16[] = @data
  elif T is uint32: value.uint32[] = @data
  elif T is uint64: value.uint64[] = @data
  elif T is int and sizeof(int) == sizeof(int32): value.int32[] = @data
  elif T is int and sizeof(int) == sizeof(int64): value.int64[] = @data
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32[] = @data
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64[] = @data
  elif T is float and sizeof(float) == sizeof(float32): value.float32[] = @data
  elif T is float and sizeof(float) == sizeof(float64): value.float64[] = @data
  elif T is TVec2[int32]: value.vec2i32[] = @data
  elif T is TVec2[int64]: value.vec2i64[] = @data
  elif T is TVec3[int32]: value.vec3i32[] = @data
  elif T is TVec3[int64]: value.vec3i64[] = @data
  elif T is TVec4[int32]: value.vec4i32[] = @data
  elif T is TVec4[int64]: value.vec4i64[] = @data
  elif T is TVec2[uint32]: value.vec2u32[] = @data
  elif T is TVec2[uint64]: value.vec2u64[] = @data
  elif T is TVec3[uint32]: value.vec3u32[] = @data
  elif T is TVec3[uint64]: value.vec3u64[] = @data
  elif T is TVec4[uint32]: value.vec4u32[] = @data
  elif T is TVec4[uint64]: value.vec4u64[] = @data
  elif T is TVec2[float32]: value.vec2f32[] = @data
  elif T is TVec2[float64]: value.vec2f64[] = @data
  elif T is TVec3[float32]: value.vec3f32[] = @data
  elif T is TVec3[float64]: value.vec3f64[] = @data
  elif T is TVec4[float32]: value.vec4f32[] = @data
  elif T is TVec4[float64]: value.vec4f64[] = @data
  elif T is TMat2[float32]: value.mat2f32[] = @data
  elif T is TMat2[float64]: value.mat2f64[] = @data
  elif T is TMat23[float32]: value.mat23f32[] = @data
  elif T is TMat23[float64]: value.mat23f64[] = @data
  elif T is TMat32[float32]: value.mat32f32[] = @data
  elif T is TMat32[float64]: value.mat32f64[] = @data
  elif T is TMat3[float32]: value.mat3f32[] = @data
  elif T is TMat3[float64]: value.mat3f64[] = @data
  elif T is TMat34[float32]: value.mat34f32[] = @data
  elif T is TMat34[float64]: value.mat34f64[] = @data
  elif T is TMat43[float32]: value.mat43f32[] = @data
  elif T is TMat43[float64]: value.mat43f64[] = @data
  elif T is TMat4[float32]: value.mat4f32[] = @data
  elif T is TMat4[float64]: value.mat4f64[] = @data
  elif T is Texture: value.texture[] = @data
  else: {.error: "Virtual datatype has no values".}

proc setValue[T: GPUType|int|uint|float](value: var DataList, i: int, data: T) =
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
  elif T is Texture: value.texture[i] = data
  else: {.error: "Virtual datatype has no values".}

proc initDataList*(theType: DataType, len = 0): DataList =
  result = DataList(theType: theType)
  case result.theType
    of Float32: result.float32 = new seq[float32]
    of Float64: result.float64 = new seq[float64]
    of Int8: result.int8 = new seq[int8]
    of Int16: result.int16 = new seq[int16]
    of Int32: result.int32 = new seq[int32]
    of Int64: result.int64 = new seq[int64]
    of UInt8: result.uint8 = new seq[uint8]
    of UInt16: result.uint16 = new seq[uint16]
    of UInt32: result.uint32 = new seq[uint32]
    of UInt64: result.uint64 = new seq[uint64]
    of Vec2I32: result.vec2i32 = new seq[TVec2[int32]]
    of Vec2I64: result.vec2i64 = new seq[TVec2[int64]]
    of Vec3I32: result.vec3i32 = new seq[TVec3[int32]]
    of Vec3I64: result.vec3i64 = new seq[TVec3[int64]]
    of Vec4I32: result.vec4i32 = new seq[TVec4[int32]]
    of Vec4I64: result.vec4i64 = new seq[TVec4[int64]]
    of Vec2U32: result.vec2u32 = new seq[TVec2[uint32]]
    of Vec2U64: result.vec2u64 = new seq[TVec2[uint64]]
    of Vec3U32: result.vec3u32 = new seq[TVec3[uint32]]
    of Vec3U64: result.vec3u64 = new seq[TVec3[uint64]]
    of Vec4U32: result.vec4u32 = new seq[TVec4[uint32]]
    of Vec4U64: result.vec4u64 = new seq[TVec4[uint64]]
    of Vec2F32: result.vec2f32 = new seq[TVec2[float32]]
    of Vec2F64: result.vec2f64 = new seq[TVec2[float64]]
    of Vec3F32: result.vec3f32 = new seq[TVec3[float32]]
    of Vec3F64: result.vec3f64 = new seq[TVec3[float64]]
    of Vec4F32: result.vec4f32 = new seq[TVec4[float32]]
    of Vec4F64: result.vec4f64 = new seq[TVec4[float64]]
    of Mat2F32: result.mat2f32 = new seq[TMat2[float32]]
    of Mat2F64: result.mat2f64 = new seq[TMat2[float64]]
    of Mat23F32: result.mat23f32 = new seq[TMat23[float32]]
    of Mat23F64: result.mat23f64 = new seq[TMat23[float64]]
    of Mat32F32: result.mat32f32 = new seq[TMat32[float32]]
    of Mat32F64: result.mat32f64 = new seq[TMat32[float64]]
    of Mat3F32: result.mat3f32 = new seq[TMat3[float32]]
    of Mat3F64: result.mat3f64 = new seq[TMat3[float64]]
    of Mat34F32: result.mat34f32 = new seq[TMat34[float32]]
    of Mat34F64: result.mat34f64 = new seq[TMat34[float64]]
    of Mat43F32: result.mat43f32 = new seq[TMat43[float32]]
    of Mat43F64: result.mat43f64 = new seq[TMat43[float64]]
    of Mat4F32: result.mat4f32 = new seq[TMat4[float32]]
    of Mat4F64: result.mat4f64 = new seq[TMat4[float64]]
    of TextureType: result.texture = new seq[Texture]
  result.setLen(len)

proc initDataList*[T: GPUType](len = 1): DataList =
  result = initDataList(getDataType[T]())
  result.setLen(len)

proc initDataList*[T: GPUType](data: openArray[T]): DataList =
  result = initDataList(getDataType[T]())
  result.setValues(@data)

func getValues[T: GPUType|int|uint|float](value: DataList): ref seq[T] =
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
  elif T is Texture: value.texture
  else: {.error: "Virtual datatype has no values".}

func getValue[T: GPUType|int|uint|float](value: DataList, i: int): T =
  when T is float32: value.float32[i]
  elif T is float64: value.float64[i]
  elif T is int8: value.int8[i]
  elif T is int16: value.int16[i]
  elif T is int32: value.int32[i]
  elif T is int64: value.int64[i]
  elif T is uint8: value.uint8[i]
  elif T is uint16: value.uint16[i]
  elif T is uint32: value.uint32[i]
  elif T is uint64: value.uint64[i]
  elif T is int and sizeof(int) == sizeof(int32): value.int32[i]
  elif T is int and sizeof(int) == sizeof(int64): value.int64[i]
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32[i]
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64[i]
  elif T is float and sizeof(float) == sizeof(float32): value.float32[i]
  elif T is float and sizeof(float) == sizeof(float64): value.float64[i]
  elif T is TVec2[int32]: value.vec2i32[i]
  elif T is TVec2[int64]: value.vec2i64[i]
  elif T is TVec3[int32]: value.vec3i32[i]
  elif T is TVec3[int64]: value.vec3i64[i]
  elif T is TVec4[int32]: value.vec4i32[i]
  elif T is TVec4[int64]: value.vec4i64[i]
  elif T is TVec2[uint32]: value.vec2u32[i]
  elif T is TVec2[uint64]: value.vec2u64[i]
  elif T is TVec3[uint32]: value.vec3u32[i]
  elif T is TVec3[uint64]: value.vec3u64[i]
  elif T is TVec4[uint32]: value.vec4u32[i]
  elif T is TVec4[uint64]: value.vec4u64[i]
  elif T is TVec2[float32]: value.vec2f32[i]
  elif T is TVec2[float64]: value.vec2f64[i]
  elif T is TVec3[float32]: value.vec3f32[i]
  elif T is TVec3[float64]: value.vec3f64[i]
  elif T is TVec4[float32]: value.vec4f32[i]
  elif T is TVec4[float64]: value.vec4f64[i]
  elif T is TMat2[float32]: value.mat2f32[i]
  elif T is TMat2[float64]: value.mat2f64[i]
  elif T is TMat23[float32]: value.mat23f[i]
  elif T is TMat23[float64]: value.mat23f64[i]
  elif T is TMat32[float32]: value.mat32f32[i]
  elif T is TMat32[float64]: value.mat32f64[i]
  elif T is TMat3[float32]: value.mat3f32[i]
  elif T is TMat3[float64]: value.mat3f64[i]
  elif T is TMat34[float32]: value.mat34f32[i]
  elif T is TMat34[float64]: value.mat34f64[i]
  elif T is TMat43[float32]: value.mat43f32[i]
  elif T is TMat43[float64]: value.mat43f64[i]
  elif T is TMat4[float32]: value.mat4f32[i]
  elif T is TMat4[float64]: value.mat4f64[i]
  elif T is Texture: value.texture[i]
  else: {.error: "Virtual datatype has no values".}

template `[]`*(list: DataList, t: typedesc): ref seq[t] =
  getValues[t](list)
template `[]`*(list: DataList, i: int, t: typedesc): untyped =
  getValue[t](list, i)

# since we use this often with tables, add this for an easy assignment
template `[]`*(table: Table[string, DataList], key: string, t: typedesc): ref seq[t] =
  getValues[t](table[key])
template `[]=`*[T](table: var Table[string, DataList], key: string, values: openArray[T]) =
  if table.contains(key):
    table[key].setValues(values)
  else:
    table[key] = initDataList(values)

template `[]=`*[T](list: var DataList, values: openArray[T]) =
  list.setValues(values)
template `[]=`*[T](list: var DataList, i: int, value: T) =
  list.setValue(i, value)

func getPointer*(value: var DataList): pointer =
  if value.len == 0:
    result = nil
  case value.theType
    of Float32: result = value.float32[].toCPointer
    of Float64: result = value.float64[].toCPointer
    of Int8: result = value.int8[].toCPointer
    of Int16: result = value.int16[].toCPointer
    of Int32: result = value.int32[].toCPointer
    of Int64: result = value.int64[].toCPointer
    of UInt8: result = value.uint8[].toCPointer
    of UInt16: result = value.uint16[].toCPointer
    of UInt32: result = value.uint32[].toCPointer
    of UInt64: result = value.uint64[].toCPointer
    of Vec2I32: result = value.vec2i32[].toCPointer
    of Vec2I64: result = value.vec2i64[].toCPointer
    of Vec3I32: result = value.vec3i32[].toCPointer
    of Vec3I64: result = value.vec3i64[].toCPointer
    of Vec4I32: result = value.vec4i32[].toCPointer
    of Vec4I64: result = value.vec4i64[].toCPointer
    of Vec2U32: result = value.vec2u32[].toCPointer
    of Vec2U64: result = value.vec2u64[].toCPointer
    of Vec3U32: result = value.vec3u32[].toCPointer
    of Vec3U64: result = value.vec3u64[].toCPointer
    of Vec4U32: result = value.vec4u32[].toCPointer
    of Vec4U64: result = value.vec4u64[].toCPointer
    of Vec2F32: result = value.vec2f32[].toCPointer
    of Vec2F64: result = value.vec2f64[].toCPointer
    of Vec3F32: result = value.vec3f32[].toCPointer
    of Vec3F64: result = value.vec3f64[].toCPointer
    of Vec4F32: result = value.vec4f32[].toCPointer
    of Vec4F64: result = value.vec4f64[].toCPointer
    of Mat2F32: result = value.mat2f32[].toCPointer
    of Mat2F64: result = value.mat2f64[].toCPointer
    of Mat23F32: result = value.mat23f32[].toCPointer
    of Mat23F64: result = value.mat23f64[].toCPointer
    of Mat32F32: result = value.mat32f32[].toCPointer
    of Mat32F64: result = value.mat32f64[].toCPointer
    of Mat3F32: result = value.mat3f32[].toCPointer
    of Mat3F64: result = value.mat3f64[].toCPointer
    of Mat34F32: result = value.mat34f32[].toCPointer
    of Mat34F64: result = value.mat34f64[].toCPointer
    of Mat43F32: result = value.mat43f32[].toCPointer
    of Mat43F64: result = value.mat43f64[].toCPointer
    of Mat4F32: result = value.mat4f32[].toCPointer
    of Mat4F64: result = value.mat4f64[].toCPointer
    of TextureType: nil

proc appendValues*[T: GPUType|int|uint|float](value: var DataList, data: openArray[T]) =
  value.len += data.len
  when T is float32: value.float32[].add @data
  elif T is float64: value.float64[].add @data
  elif T is int8: value.int8[].add @data
  elif T is int16: value.int16[].add @data
  elif T is int32: value.int32[].add @data
  elif T is int64: value.int64[].add @data
  elif T is uint8: value.uint8[].add @data
  elif T is uint16: value.uint16[].add @data
  elif T is uint32: value.uint32[].add @data
  elif T is uint64: value.uint64[].add @data
  elif T is int and sizeof(int) == sizeof(int32): value.int32[].add @data
  elif T is int and sizeof(int) == sizeof(int64): value.int64[].add @data
  elif T is uint and sizeof(uint) == sizeof(uint32): value.uint32[].add @data
  elif T is uint and sizeof(uint) == sizeof(uint64): value.uint64[].add @data
  elif T is float and sizeof(float) == sizeof(float32): value.float32[].add @data
  elif T is float and sizeof(float) == sizeof(float64): value.float64[].add @data
  elif T is TVec2[int32]: value.vec2i32[].add @data
  elif T is TVec2[int64]: value.vec2i64[].add @data
  elif T is TVec3[int32]: value.vec3i32[].add @data
  elif T is TVec3[int64]: value.vec3i64[].add @data
  elif T is TVec4[int32]: value.vec4i32[].add @data
  elif T is TVec4[int64]: value.vec4i64[].add @data
  elif T is TVec2[uint32]: value.vec2u32[].add @data
  elif T is TVec2[uint64]: value.vec2u64[].add @data
  elif T is TVec3[uint32]: value.vec3u32[].add @data
  elif T is TVec3[uint64]: value.vec3u64[].add @data
  elif T is TVec4[uint32]: value.vec4u32[].add @data
  elif T is TVec4[uint64]: value.vec4u64[].add @data
  elif T is TVec2[float32]: value.vec2f32[].add @data
  elif T is TVec2[float64]: value.vec2f64[].add @data
  elif T is TVec3[float32]: value.vec3f32[].add @data
  elif T is TVec3[float64]: value.vec3f64[].add @data
  elif T is TVec4[float32]: value.vec4f32[].add @data
  elif T is TVec4[float64]: value.vec4f64[].add @data
  elif T is TMat2[float32]: value.mat2f32[].add @data
  elif T is TMat2[float64]: value.mat2f64[].add @data
  elif T is TMat23[float32]: value.mat23f32[].add @data
  elif T is TMat23[float64]: value.mat23f64[].add @data
  elif T is TMat32[float32]: value.mat32f32[].add @data
  elif T is TMat32[float64]: value.mat32f64[].add @data
  elif T is TMat3[float32]: value.mat3f32[].add @data
  elif T is TMat3[float64]: value.mat3f64[].add @data
  elif T is TMat34[float32]: value.mat34f32[].add @data
  elif T is TMat34[float64]: value.mat34f64[].add @data
  elif T is TMat43[float32]: value.mat43f32[].add @data
  elif T is TMat43[float64]: value.mat43f64[].add @data
  elif T is TMat4[float32]: value.mat4f32[].add @data
  elif T is TMat4[float64]: value.mat4f64[].add @data
  elif T is Texture: value.texture[].add @data
  else: {.error: "Virtual datatype has no values".}

proc appendValues*(value: var DataList, data: DataList) =
  assert value.theType == data.theType, &"Expected datalist of type {value.theType} but got {data.theType}"
  value.len += data.len
  case value.theType:
  of Float32: value.float32[].add data.float32[]
  of Float64: value.float64[].add data.float64[]
  of Int8: value.int8[].add data.int8[]
  of Int16: value.int16[].add data.int16[]
  of Int32: value.int32[].add data.int32[]
  of Int64: value.int64[].add data.int64[]
  of UInt8: value.uint8[].add data.uint8[]
  of UInt16: value.uint16[].add data.uint16[]
  of UInt32: value.uint32[].add data.uint32[]
  of UInt64: value.uint64[].add data.uint64[]
  of Vec2I32: value.vec2i32[].add data.vec2i32[]
  of Vec2I64: value.vec2i64[].add data.vec2i64[]
  of Vec3I32: value.vec3i32[].add data.vec3i32[]
  of Vec3I64: value.vec3i64[].add data.vec3i64[]
  of Vec4I32: value.vec4i32[].add data.vec4i32[]
  of Vec4I64: value.vec4i64[].add data.vec4i64[]
  of Vec2U32: value.vec2u32[].add data.vec2u32[]
  of Vec2U64: value.vec2u64[].add data.vec2u64[]
  of Vec3U32: value.vec3u32[].add data.vec3u32[]
  of Vec3U64: value.vec3u64[].add data.vec3u64[]
  of Vec4U32: value.vec4u32[].add data.vec4u32[]
  of Vec4U64: value.vec4u64[].add data.vec4u64[]
  of Vec2F32: value.vec2f32[].add data.vec2f32[]
  of Vec2F64: value.vec2f64[].add data.vec2f64[]
  of Vec3F32: value.vec3f32[].add data.vec3f32[]
  of Vec3F64: value.vec3f64[].add data.vec3f64[]
  of Vec4F32: value.vec4f32[].add data.vec4f32[]
  of Vec4F64: value.vec4f64[].add data.vec4f64[]
  of Mat2F32: value.mat2f32[].add data.mat2f32[]
  of Mat2F64: value.mat2f64[].add data.mat2f64[]
  of Mat23F32: value.mat23f32[].add data.mat23f32[]
  of Mat23F64: value.mat23f64[].add data.mat23f64[]
  of Mat32F32: value.mat32f32[].add data.mat32f32[]
  of Mat32F64: value.mat32f64[].add data.mat32f64[]
  of Mat3F32: value.mat3f32[].add data.mat3f32[]
  of Mat3F64: value.mat3f64[].add data.mat3f64[]
  of Mat34F32: value.mat34f32[].add data.mat34f32[]
  of Mat34F64: value.mat34f64[].add data.mat34f64[]
  of Mat43F32: value.mat43f32[].add data.mat43f32[]
  of Mat43F64: value.mat43f64[].add data.mat43f64[]
  of Mat4F32: value.mat4f32[].add data.mat4f32[]
  of Mat4F64: value.mat4f64[].add data.mat4f64[]
  of TextureType: value.texture[].add data.texture[]

proc appendFrom*(a: var DataList, i: int, b: DataList, j: int) =
  assert a.theType == b.theType
  case a.theType
    of Float32: a.float32[i] = b.float32[j]
    of Float64: a.float64[i] = b.float64[j]
    of Int8: a.int8[i] = b.int8[j]
    of Int16: a.int16[i] = b.int16[j]
    of Int32: a.int32[i] = b.int32[j]
    of Int64: a.int64[i] = b.int64[j]
    of UInt8: a.uint8[i] = b.uint8[j]
    of UInt16: a.uint16[i] = b.uint16[j]
    of UInt32: a.uint32[i] = b.uint32[j]
    of UInt64: a.uint64[i] = b.uint64[j]
    of Vec2I32: a.vec2i32[i] = b.vec2i32[j]
    of Vec2I64: a.vec2i64[i] = b.vec2i64[j]
    of Vec3I32: a.vec3i32[i] = b.vec3i32[j]
    of Vec3I64: a.vec3i64[i] = b.vec3i64[j]
    of Vec4I32: a.vec4i32[i] = b.vec4i32[j]
    of Vec4I64: a.vec4i64[i] = b.vec4i64[j]
    of Vec2U32: a.vec2u32[i] = b.vec2u32[j]
    of Vec2U64: a.vec2u64[i] = b.vec2u64[j]
    of Vec3U32: a.vec3u32[i] = b.vec3u32[j]
    of Vec3U64: a.vec3u64[i] = b.vec3u64[j]
    of Vec4U32: a.vec4u32[i] = b.vec4u32[j]
    of Vec4U64: a.vec4u64[i] = b.vec4u64[j]
    of Vec2F32: a.vec2f32[i] = b.vec2f32[j]
    of Vec2F64: a.vec2f64[i] = b.vec2f64[j]
    of Vec3F32: a.vec3f32[i] = b.vec3f32[j]
    of Vec3F64: a.vec3f64[i] = b.vec3f64[j]
    of Vec4F32: a.vec4f32[i] = b.vec4f32[j]
    of Vec4F64: a.vec4f64[i] = b.vec4f64[j]
    of Mat2F32: a.mat2f32[i] = b.mat2f32[j]
    of Mat2F64: a.mat2f64[i] = b.mat2f64[j]
    of Mat23F32: a.mat23f32[i] = b.mat23f32[j]
    of Mat23F64: a.mat23f64[i] = b.mat23f64[j]
    of Mat32F32: a.mat32f32[i] = b.mat32f32[j]
    of Mat32F64: a.mat32f64[i] = b.mat32f64[j]
    of Mat3F32: a.mat3f32[i] = b.mat3f32[j]
    of Mat3F64: a.mat3f64[i] = b.mat3f64[j]
    of Mat34F32: a.mat34f32[i] = b.mat34f32[j]
    of Mat34F64: a.mat34f64[i] = b.mat34f64[j]
    of Mat43F32: a.mat43f32[i] = b.mat43f32[j]
    of Mat43F64: a.mat43f64[i] = b.mat43f64[j]
    of Mat4F32: a.mat4f32[i] = b.mat4f32[j]
    of Mat4F64: a.mat4f64[i] = b.mat4f64[j]
    of TextureType: a.texture[i] = b.texture[j]

proc copy*(datalist: DataList): DataList =
  result = initDataList(datalist.theType)
  result.appendValues(datalist)

func `$`*(list: DataList): string =
  case list.theType
    of Float32: $list.float32[]
    of Float64: $list.float64[]
    of Int8: $list.int8[]
    of Int16: $list.int16[]
    of Int32: $list.int32[]
    of Int64: $list.int64[]
    of UInt8: $list.uint8[]
    of UInt16: $list.uint16[]
    of UInt32: $list.uint32[]
    of UInt64: $list.uint64[]
    of Vec2I32: $list.vec2i32[]
    of Vec2I64: $list.vec2i64[]
    of Vec3I32: $list.vec3i32[]
    of Vec3I64: $list.vec3i64[]
    of Vec4I32: $list.vec4i32[]
    of Vec4I64: $list.vec4i64[]
    of Vec2U32: $list.vec2u32[]
    of Vec2U64: $list.vec2u64[]
    of Vec3U32: $list.vec3u32[]
    of Vec3U64: $list.vec3u64[]
    of Vec4U32: $list.vec4u32[]
    of Vec4U64: $list.vec4u64[]
    of Vec2F32: $list.vec2f32[]
    of Vec2F64: $list.vec2f64[]
    of Vec3F32: $list.vec3f32[]
    of Vec3F64: $list.vec3f64[]
    of Vec4F32: $list.vec4f32[]
    of Vec4F64: $list.vec4f64[]
    of Mat2F32: $list.mat2f32[]
    of Mat2F64: $list.mat2f64[]
    of Mat23F32: $list.mat23f32[]
    of Mat23F64: $list.mat23f64[]
    of Mat32F32: $list.mat32f32[]
    of Mat32F64: $list.mat32f64[]
    of Mat3F32: $list.mat3f32[]
    of Mat3F64: $list.mat3f64[]
    of Mat34F32: $list.mat34f32[]
    of Mat34F64: $list.mat34f64[]
    of Mat43F32: $list.mat43f32[]
    of Mat43F64: $list.mat43f64[]
    of Mat4F32: $list.mat4f32[]
    of Mat4F64: $list.mat4f64[]
    of TextureType: $list.texture[]
