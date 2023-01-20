import std/macros
import std/strutils
import std/strformat
import std/typetraits

import ./math/vector
import ./math/matrix
import ./vulkan
import ./glsl_helpers

type
  VertexAttributeType = SomeNumber|TVec
  AttributePurpose* = enum
    Unknown, Position Color
  GenericAttribute*[T:VertexAttributeType] = object
    data*: seq[T]
  PositionAttribute*[T:TVec] = object
    data*: seq[T]
  ColorAttribute*[T:TVec] = object
    data*: seq[T]
  InstanceAttribute*[T:TVec] = object
    data*: seq[T]
  VertexAttribute* = GenericAttribute|PositionAttribute|ColorAttribute|InstanceAttribute

template getAttributeType*(v: VertexAttribute): auto = get(genericParams(typeof(v)), 0)

func datasize*(attribute: VertexAttribute): uint64 =
  uint64(sizeof(getAttributeType(attribute))) * uint64(attribute.data.len)

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots[T: VertexAttributeType](): int =
  when (T is Mat44[float64]):
    8
  elif (T is Mat44[float32]):
    4
  elif (T is TVec3[float64] or T is TVec3[uint64] or T is TVec4[float64] or T is TVec4[float64]):
    2
  else:
    1

# numbers
func getVkFormat[T: VertexAttributeType](): VkFormat =
  when T is uint8:         VK_FORMAT_R8_UINT
  elif T is int8:          VK_FORMAT_R8_SINT
  elif T is uint16:        VK_FORMAT_R16_UINT
  elif T is int16:         VK_FORMAT_R16_SINT
  elif T is uint32:        VK_FORMAT_R32_UINT
  elif T is int32:         VK_FORMAT_R32_SINT
  elif T is uint64:        VK_FORMAT_R64_UINT
  elif T is int64:         VK_FORMAT_R64_SINT
  elif T is float32:       VK_FORMAT_R32_SFLOAT
  elif T is float64:       VK_FORMAT_R64_SFLOAT
  elif T is TVec2[uint8]:   VK_FORMAT_R8G8_UINT
  elif T is TVec2[int8]:    VK_FORMAT_R8G8_SINT
  elif T is TVec2[uint16]:  VK_FORMAT_R16G16_UINT
  elif T is TVec2[int16]:   VK_FORMAT_R16G16_SINT
  elif T is TVec2[uint32]:  VK_FORMAT_R32G32_UINT
  elif T is TVec2[int32]:   VK_FORMAT_R32G32_SINT
  elif T is TVec2[uint64]:  VK_FORMAT_R64G64_UINT
  elif T is TVec2[int64]:   VK_FORMAT_R64G64_SINT
  elif T is TVec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TVec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TVec3[uint8]:   VK_FORMAT_R8G8B8_UINT
  elif T is TVec3[int8]:    VK_FORMAT_R8G8B8_SINT
  elif T is TVec3[uint16]:  VK_FORMAT_R16G16B16_UINT
  elif T is TVec3[int16]:   VK_FORMAT_R16G16B16_SINT
  elif T is TVec3[uint32]:  VK_FORMAT_R32G32B32_UINT
  elif T is TVec3[int32]:   VK_FORMAT_R32G32B32_SINT
  elif T is TVec3[uint64]:  VK_FORMAT_R64G64B64_UINT
  elif T is TVec3[int64]:   VK_FORMAT_R64G64B64_SINT
  elif T is TVec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TVec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TVec4[uint8]:   VK_FORMAT_R8G8B8A8_UINT
  elif T is TVec4[int8]:    VK_FORMAT_R8G8B8A8_SINT
  elif T is TVec4[uint16]:  VK_FORMAT_R16G16B16A16_UINT
  elif T is TVec4[int16]:   VK_FORMAT_R16G16B16A16_SINT
  elif T is TVec4[uint32]:  VK_FORMAT_R32G32B32A32_UINT
  elif T is TVec4[int32]:   VK_FORMAT_R32G32B32A32_SINT
  elif T is TVec4[uint64]:  VK_FORMAT_R64G64B64A64_UINT
  elif T is TVec4[int64]:   VK_FORMAT_R64G64B64A64_SINT
  elif T is TVec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TVec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT



func VertexCount*[T](t: T): uint32 =
  for name, value in t.fieldPairs:
    when typeof(value) is VertexAttribute and not (typeof(value) is InstanceAttribute):
      if result == 0:
        result = uint32(value.data.len)
      else:
        assert result == uint32(value.data.len)

func generateGLSLVertexDeclarations*[T](): string =
  var stmtList: seq[string]
  var i = 0
  for name, value in T().fieldPairs:
    when typeof(value) is VertexAttribute:
      let glsltype = getGLSLType[getAttributeType(value)]()
      let n = name
      stmtList.add(&"layout(location = {i}) in {glsltype} {n};")
      i += nLocationSlots[getAttributeType(value)]()

  return stmtList.join("\n")

func generateInputVertexBinding*[T](bindingoffset: int = 0, locationoffset: int = 0): seq[VkVertexInputBindingDescription] =
  # packed attribute data, not interleaved (aks "struct of arrays")
  var binding = bindingoffset
  for name, value in T().fieldPairs:
    when typeof(value) is InstanceAttribute:
      result.add(
        VkVertexInputBindingDescription(
          binding: uint32(binding),
          stride: uint32(sizeof(getAttributeType(value))),
          inputRate: VK_VERTEX_INPUT_RATE_INSTANCE,
        )
      )
      binding += 1
    elif typeof(value) is VertexAttribute:
      result.add(
        VkVertexInputBindingDescription(
          binding: uint32(binding),
          stride: uint32(sizeof(getAttributeType(value))),
          inputRate: VK_VERTEX_INPUT_RATE_VERTEX,
        )
      )
      binding += 1

func generateInputAttributeBinding*[T](bindingoffset: int = 0, locationoffset: int = 0): seq[VkVertexInputAttributeDescription] =
  # packed attribute data, not interleaved (aks "struct of arrays")
  var location = 0
  var binding = bindingoffset
  for name, value in T().fieldPairs:
    when typeof(value) is VertexAttribute:
      result.add(
        VkVertexInputAttributeDescription(
          binding: uint32(binding),
          location: uint32(location),
          format: getVkFormat[getAttributeType(value)](),
          offset: 0,
        )
      )
      location += nLocationSlots[getAttributeType(value)]()
      binding += 1
