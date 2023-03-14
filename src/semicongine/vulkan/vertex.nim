import std/tables
import std/macros

import ../math
import ./api
import ./utils
import ./shader


# add pragma to fields of the VertexType that represent per instance attributes
template PerInstance*() {.pragma.}

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots[T](value: T): uint32 =
  when (T is TVec3[float64] or T is TVec3[uint64] or T is TVec4[float64] or T is TVec4[float64]):
    return 2
  elif T is SomeNumber or T is TVec:
    return 1
  else:
    raise newException(Exception, "Unsupported vertex attribute type")

# return the type into which larger types are divided
func compositeAttribute[T](value: T): auto =
  when T is TMat33[float32]:
    Vec3()
  elif T is TMat44[float32]:
    Vec4()
  else:
    value

# return the number of elements into which larger types are divided
func compositeAttributesNumber[T](value: T): int =
  when T is TMat33[float32]:
    3
  elif T is TMat44[float32]:
    4
  else:
    1

func getVkFormat[T](value: T): VkFormat =
  when T is uint8: VK_FORMAT_R8_UINT
  elif T is int8: VK_FORMAT_R8_SINT
  elif T is uint16: VK_FORMAT_R16_UINT
  elif T is int16: VK_FORMAT_R16_SINT
  elif T is uint32: VK_FORMAT_R32_UINT
  elif T is int32: VK_FORMAT_R32_SINT
  elif T is uint64: VK_FORMAT_R64_UINT
  elif T is int64: VK_FORMAT_R64_SINT
  elif T is float32: VK_FORMAT_R32_SFLOAT
  elif T is float64: VK_FORMAT_R64_SFLOAT
  elif T is TVec2[uint8]: VK_FORMAT_R8G8_UINT
  elif T is TVec2[int8]: VK_FORMAT_R8G8_SINT
  elif T is TVec2[uint16]: VK_FORMAT_R16G16_UINT
  elif T is TVec2[int16]: VK_FORMAT_R16G16_SINT
  elif T is TVec2[uint32]: VK_FORMAT_R32G32_UINT
  elif T is TVec2[int32]: VK_FORMAT_R32G32_SINT
  elif T is TVec2[uint64]: VK_FORMAT_R64G64_UINT
  elif T is TVec2[int64]: VK_FORMAT_R64G64_SINT
  elif T is TVec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TVec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TVec3[uint8]: VK_FORMAT_R8G8B8_UINT
  elif T is TVec3[int8]: VK_FORMAT_R8G8B8_SINT
  elif T is TVec3[uint16]: VK_FORMAT_R16G16B16_UINT
  elif T is TVec3[int16]: VK_FORMAT_R16G16B16_SINT
  elif T is TVec3[uint32]: VK_FORMAT_R32G32B32_UINT
  elif T is TVec3[int32]: VK_FORMAT_R32G32B32_SINT
  elif T is TVec3[uint64]: VK_FORMAT_R64G64B64_UINT
  elif T is TVec3[int64]: VK_FORMAT_R64G64B64_SINT
  elif T is TVec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TVec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TVec4[uint8]: VK_FORMAT_R8G8B8A8_UINT
  elif T is TVec4[int8]: VK_FORMAT_R8G8B8A8_SINT
  elif T is TVec4[uint16]: VK_FORMAT_R16G16B16A16_UINT
  elif T is TVec4[int16]: VK_FORMAT_R16G16B16A16_SINT
  elif T is TVec4[uint32]: VK_FORMAT_R32G32B32A32_UINT
  elif T is TVec4[int32]: VK_FORMAT_R32G32B32A32_SINT
  elif T is TVec4[uint64]: VK_FORMAT_R64G64B64A64_UINT
  elif T is TVec4[int64]: VK_FORMAT_R64G64B64A64_SINT
  elif T is TVec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TVec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  else: {.error: "Unsupported vertex attribute type".}

proc getVertexBindings*(shader: VertexShader): VkPipelineVertexInputStateCreateInfo =
  var location = 0'u32
  var binding = 0'u32
  var offset = 0'u32
  var bindings: seq[VkVertexInputBindingDescription]
  var attributes: seq[VkVertexInputAttributeDescription]

  for name, value in shader.vertexType.fieldPairs:
    bindings.add VkVertexInputBindingDescription(
      binding: binding,
      stride: uint32(sizeof(value)),
      inputRate: if value.hasCustomPragma(PerInstance): VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    for i in 0 ..< compositeAttributesNumber(value):
      attributes.add VkVertexInputAttributeDescription(
        binding: binding,
        location: location,
        format: getVkFormat(compositeAttribute(value)),
        offset: uint32(i * sizeof(compositeAttribute(value))),
      )
      location += nLocationSlots(compositeAttribute(value))
    inc binding

  return VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount: uint32(bindings.len),
    pVertexBindingDescriptions: bindings.toCPointer,
    vertexAttributeDescriptionCount: uint32(attributes.len),
    pVertexAttributeDescriptions: attributes.toCPointer,
  )
