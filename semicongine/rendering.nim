# in this file:
# - const defintions for rendering
# - custom pragma defintions for rendering
# - type defintions for rendering
# - some utils code that is used in mutiple rendering files
# - inclusion of all rendering files


# const definitions
const INFLIGHTFRAMES = 2'u32
const BUFFER_ALIGNMENT = 64'u64 # align offsets inside buffers along this alignment
const MEMORY_BLOCK_ALLOCATION_SIZE = 100_000_000'u64 # ca. 100mb per block, seems reasonable
const BUFFER_ALLOCATION_SIZE = 9_000_000'u64 # ca. 9mb per block, seems reasonable, can put 10 buffers into one memory block

# custom pragmas to classify shader attributes
template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}
template Pass* {.pragma.}
template PassFlat* {.pragma.}
template ShaderOutput* {.pragma.}

type
  # type aliases
  SupportedGPUType = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]
  TextureType = TVec1[uint8] | TVec2[uint8] | TVec3[uint8] | TVec4[uint8]

  IndexType = enum
    None, UInt8, UInt16, UInt32

  # shader related types
  DescriptorSetType* = enum
    GlobalSet
    MaterialSet
  DescriptorSet*[T: object, sType: static DescriptorSetType] = object
    data*: T
    vk: array[INFLIGHTFRAMES.int, VkDescriptorSet]
  Pipeline*[TShader] = object
    vk: VkPipeline
    layout: VkPipelineLayout
    descriptorSetLayouts: array[DescriptorSetType, VkDescriptorSetLayout]

  # memory/buffer related types
  MemoryBlock* = object
    vk: VkDeviceMemory
    size: uint64
    rawPointer: pointer # if not nil, this is mapped memory
    offsetNextFree: uint64
  BufferType* = enum
    VertexBuffer
    VertexBufferMapped
    IndexBuffer
    IndexBufferMapped
    UniformBuffer
    UniformBufferMapped
  Buffer* = object
    vk: VkBuffer
    size: uint64
    rawPointer: pointer # if not nil, buffer is using mapped memory
    offsetNextFree: uint64
  Texture*[T: TextureType] = object
    vk: VkImage
    imageview: VkImageView
    sampler: VkSampler
    width*: uint32
    height*: uint32
    data*: seq[T]
  GPUArray*[T: SupportedGPUType, TBuffer: static BufferType] = object
    data*: seq[T]
    buffer: Buffer
    offset: uint64
  GPUValue*[T: object|array, TBuffer: static BufferType] = object
    data*: T
    buffer: Buffer
    offset: uint64
  GPUData = GPUArray | GPUValue

  RenderData* = object
    descriptorPool: VkDescriptorPool
    memory: array[VK_MAX_MEMORY_TYPES.int, seq[MemoryBlock]]
    buffers: array[BufferType, seq[Buffer]]

template ForDescriptorFields(shader: typed, fieldname, valuename, typename, countname, bindingNumber, body: untyped): untyped =
  var `bindingNumber` {.inject.} = 1'u32
  for theFieldname, value in fieldPairs(shader):
    when typeof(value) is Texture:
      block:
        const `fieldname` {.inject.} = theFieldname
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        const `countname` {.inject.} = 1'u32
        let `valuename` {.inject.} = value
        body
        `bindingNumber`.inc
    elif typeof(value) is object:
      block:
        const `fieldname` {.inject.} = theFieldname
        const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        const `countname` {.inject.} = 1'u32
        let `valuename` {.inject.} = value
        body
        `bindingNumber`.inc
    elif typeof(value) is array:
      when elementType(value) is Texture:
        block:
          const `fieldname` {.inject.} = theFieldname
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
          const `countname` {.inject.} = uint32(typeof(value).len)
          let `valuename` {.inject.} = value
          body
          `bindingNumber`.inc
      elif elementType(value) is object:
        block:
          const `fieldname` {.inject.} = theFieldname
          const `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
          const `countname` {.inject.} = uint32(typeof(value).len)
          let `valuename` {.inject.} = value
          body
          `bindingNumber`.inc
      else:
        {.error: "Unsupported descriptor type: " & typetraits.name(typeof(value)).}

include ./rendering/vulkan_wrappers
include ./rendering/shaders
include ./rendering/renderer
