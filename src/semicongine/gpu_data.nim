import std/strformat
import std/tables

import ./vulkan/api

type
  CountType = 1'u32 .. 4'u32
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
  Attribute* = object
    name*: string
    thetype*: DataType
    components*: CountType # how many components the vectors has (1 means scalar)
    rows*: CountType # used to split matrices into rows of vectors
    perInstance*: bool
  AttributeGroup* = object
    attributes*: seq[Attribute]

func attr*(name: string, thetype: DataType, components=CountType(1), rows=CountType(1), perInstance=false): auto =
  Attribute(name: name, thetype: thetype, components: components, rows: rows, perInstance: perInstance)

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
  
func size*(attribute: Attribute, perRow=false): uint32 =
  if perRow:
    attribute.thetype.size * attribute.components
  else:
    attribute.thetype.size * attribute.components * attribute.rows

func size*(thetype: AttributeGroup): uint32 =
  for attribute in thetype.attributes:
    result += attribute.size

const TYPEMAP = {
  CountType(1): {
    UInt8: VK_FORMAT_R8_UINT,
    Int8: VK_FORMAT_R8_SINT,
    UInt16: VK_FORMAT_R16_UINT,
    Int16: VK_FORMAT_R16_SINT,
    UInt32: VK_FORMAT_R32_UINT,
    Int32: VK_FORMAT_R32_SINT,
    UInt64: VK_FORMAT_R64_UINT,
    Int64: VK_FORMAT_R64_SINT,
    Float32: VK_FORMAT_R32_SFLOAT,
    Float64: VK_FORMAT_R64_SFLOAT,
  }.toTable,
  CountType(2): {
    UInt8: VK_FORMAT_R8G8_UINT,
    Int8: VK_FORMAT_R8G8_SINT,
    UInt16: VK_FORMAT_R16G16_UINT,
    Int16: VK_FORMAT_R16G16_SINT,
    UInt32: VK_FORMAT_R32G32_UINT,
    Int32: VK_FORMAT_R32G32_SINT,
    UInt64: VK_FORMAT_R64G64_UINT,
    Int64: VK_FORMAT_R64G64_SINT,
    Float32: VK_FORMAT_R32G32_SFLOAT,
    Float64: VK_FORMAT_R64G64_SFLOAT,
  }.toTable,
  CountType(3): {
    UInt8: VK_FORMAT_R8G8B8_UINT,
    Int8: VK_FORMAT_R8G8B8_SINT,
    UInt16: VK_FORMAT_R16G16B16_UINT,
    Int16: VK_FORMAT_R16G16B16_SINT,
    UInt32: VK_FORMAT_R32G32B32_UINT,
    Int32: VK_FORMAT_R32G32B32_SINT,
    UInt64: VK_FORMAT_R64G64B64_UINT,
    Int64: VK_FORMAT_R64G64B64_SINT,
    Float32: VK_FORMAT_R32G32B32_SFLOAT,
    Float64: VK_FORMAT_R64G64B64_SFLOAT,
  }.toTable,
  CountType(4): {
    UInt8: VK_FORMAT_R8G8B8A8_UINT,
    Int8: VK_FORMAT_R8G8B8A8_SINT,
    UInt16: VK_FORMAT_R16G16B16A16_UINT,
    Int16: VK_FORMAT_R16G16B16A16_SINT,
    UInt32: VK_FORMAT_R32G32B32A32_UINT,
    Int32: VK_FORMAT_R32G32B32A32_SINT,
    UInt64: VK_FORMAT_R64G64B64A64_UINT,
    Int64: VK_FORMAT_R64G64B64A64_SINT,
    Float32: VK_FORMAT_R32G32B32A32_SFLOAT,
    Float64: VK_FORMAT_R64G64B64A64_SFLOAT,
  }.toTable,
}.toTable

func getVkFormat*(value: Attribute): VkFormat =
  TYPEMAP[value.components][value.thetype]

# from https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap15.html
func nLocationSlots*(attribute: Attribute): uint32 =
  #[
  single location:
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  case attribute.thetype:
    of Float32: 1
    of Float64: (if attribute.components < 3: 1 else: 2)
    of Int8: 1
    of Int16: 1
    of Int32: 1
    of Int64: (if attribute.components < 3: 1 else: 2)
    of UInt8: 1
    of UInt16: 1
    of UInt32: 1
    of UInt64: (if attribute.components < 3: 1 else: 2)

func glslType*(attribute: Attribute): string =
  # todo: likely not correct as we would need to enable some 
  # extensions somewhere (Vulkan/GLSL compiler?) to have 
  # everything work as intended. Or maybe the GPU driver does
  # some automagic conversion stuf..
  
  # used to ensure square matrix get only one number for side instead of two,  e.g. mat2 instead of mat22
  let matrixColumns = if attribute.components == attribute.rows: "" else: $attribute.components
  case attribute.rows:
    of 1:
      case attribute.components:
        of 1: # scalars
          case attribute.thetype:
            of Float32: "float"
            of Float64: "double"
            of Int8, Int16, Int32, Int64: "int"
            of UInt8, UInt16, UInt32, UInt64: "uint"
        else: # vectors
          case attribute.thetype:
            of Float32: &"vec{attribute.components}"
            of Float64: &"dvec{attribute.components}"
            of Int8, Int16, Int32, Int64: &"ivec{attribute.components}"
            of UInt8, UInt16, UInt32, UInt64: &"uvec{attribute.components}"
    else:
      case attribute.components:
        of 1: raise newException(Exception, &"Unsupported matrix-column-count: {attribute.components}")
        else:
          case attribute.thetype:
            of Float32: &"mat{attribute.rows}{matrixColumns}"
            of Float64: &"dmat{attribute.rows}{matrixColumns}"
            else: raise newException(Exception, &"Unsupported matrix-component type: {attribute.thetype}")

func glslInput*(group: AttributeGroup): seq[string] =
  if group.attributes.len == 0:
    return @[]
  var i = 0'u32
  for attribute in group.attributes:
    result.add &"layout(location = {i}) in {attribute.glslType} {attribute.name};"
    for j in 0 ..< attribute.rows:
      i += attribute.nLocationSlots

func glslUniforms*(group: AttributeGroup, blockName="Uniforms", binding=0): seq[string] =
  if group.attributes.len == 0:
    return @[]
  # currently only a single uniform block supported, therefore binding = 0
  result.add(&"layout(binding = {binding}) uniform T{blockName} {{")
  for attribute in group.attributes:
    result.add(&"    {attribute.glslType} {attribute.name};")
  result.add(&"}} {blockName};")

func glslOutput*(group: AttributeGroup): seq[string] =
  if group.attributes.len == 0:
    return @[]
  var i = 0'u32
  for attribute in group.attributes:
    result.add &"layout(location = {i}) out {attribute.glslType} {attribute.name};"
    i += 1
