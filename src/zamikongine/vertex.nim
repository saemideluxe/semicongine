import std/macros
import std/strutils
import std/strformat
import std/typetraits

import ./math/vector
import ./vulkan

type
  VertexAttributeType = SomeNumber|Vec
  VertexAttribute*[T:VertexAttributeType] = object
    data*: seq[T]

template rawAttributeType(v: VertexAttribute): auto = get(genericParams(typeof(v)), 0)

func datasize*(attribute: VertexAttribute): uint64 =
  uint64(sizeof(rawAttributeType(attribute))) * uint64(attribute.data.len)

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots[T: VertexAttributeType](): int =
  when (T is Vec3[float64] or T is Vec3[uint64] or T is Vec4[float64] or T is Vec4[float64]):
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
  elif T is Vec2[uint8]:   VK_FORMAT_R8G8_UINT
  elif T is Vec2[int8]:    VK_FORMAT_R8G8_SINT
  elif T is Vec2[uint16]:  VK_FORMAT_R16G16_UINT
  elif T is Vec2[int16]:   VK_FORMAT_R16G16_SINT
  elif T is Vec2[uint32]:  VK_FORMAT_R32G32_UINT
  elif T is Vec2[int32]:   VK_FORMAT_R32G32_SINT
  elif T is Vec2[uint64]:  VK_FORMAT_R64G64_UINT
  elif T is Vec2[int64]:   VK_FORMAT_R64G64_SINT
  elif T is Vec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is Vec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is Vec3[uint8]:   VK_FORMAT_R8G8B8_UINT
  elif T is Vec3[int8]:    VK_FORMAT_R8G8B8_SINT
  elif T is Vec3[uint16]:  VK_FORMAT_R16G16B16_UINT
  elif T is Vec3[int16]:   VK_FORMAT_R16G16B16_SINT
  elif T is Vec3[uint32]:  VK_FORMAT_R32G32B32_UINT
  elif T is Vec3[int32]:   VK_FORMAT_R32G32B32_SINT
  elif T is Vec3[uint64]:  VK_FORMAT_R64G64B64_UINT
  elif T is Vec3[int64]:   VK_FORMAT_R64G64B64_SINT
  elif T is Vec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is Vec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is Vec4[uint8]:   VK_FORMAT_R8G8B8A8_UINT
  elif T is Vec4[int8]:    VK_FORMAT_R8G8B8A8_SINT
  elif T is Vec4[uint16]:  VK_FORMAT_R16G16B16A16_UINT
  elif T is Vec4[int16]:   VK_FORMAT_R16G16B16A16_SINT
  elif T is Vec4[uint32]:  VK_FORMAT_R32G32B32A32_UINT
  elif T is Vec4[int32]:   VK_FORMAT_R32G32B32A32_SINT
  elif T is Vec4[uint64]:  VK_FORMAT_R64G64B64A64_UINT
  elif T is Vec4[int64]:   VK_FORMAT_R64G64B64A64_SINT
  elif T is Vec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is Vec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT

func getGLSLType[T: VertexAttributeType](): string =
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


func VertexCount*[T](t: T): uint32 =
  for name, value in t.fieldPairs:
    when typeof(value) is VertexAttribute:
      if result == 0:
        result = uint32(value.data.len)
      else:
        assert result == uint32(value.data.len)

func generateGLSLDeclarations*[T](): string =
  var stmtList: seq[string]
  var i = 0
  for name, value in T().fieldPairs:
    when typeof(value) is VertexAttribute:
      let glsltype = getGLSLType[rawAttributeType(value)]()
      let n = name
      stmtList.add(&"layout(location = {i}) in {glsltype} {n};")
      i += nLocationSlots[rawAttributeType(value)]()

  return stmtList.join("\n")

func generateInputVertexBinding*[T](bindingoffset: int = 0, locationoffset: int = 0): seq[VkVertexInputBindingDescription] =
  # packed attribute data, not interleaved (aks "struct of arrays")
  var binding = bindingoffset
  for name, value in T().fieldPairs:
    when typeof(value) is VertexAttribute:
      result.add(
        VkVertexInputBindingDescription(
          binding: uint32(binding),
          stride: uint32(sizeof(rawAttributeType(value))),
          inputRate: VK_VERTEX_INPUT_RATE_VERTEX, # VK_VERTEX_INPUT_RATE_INSTANCE for instances
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
          format: getVkFormat[rawAttributeType(value)](),
          offset: 0,
        )
      )
      location += nLocationSlots[rawAttributeType(value)]()
      binding += 1
