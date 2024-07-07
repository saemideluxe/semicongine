import std/algorithm
import std/os
import std/enumerate
import std/hashes
import std/macros
import std/strformat
import std/strutils
import std/sequtils
import std/typetraits as tt

import semicongine/core/utils
import semicongine/core/vector
import semicongine/core/matrix
import semicongine/core/vulkanapi

import ./vulkan_utils

template VertexAttribute {.pragma.}
template InstanceAttribute {.pragma.}
template Pass {.pragma.}
template PassFlat {.pragma.}
template ShaderOutput {.pragma.}

const INFLIGHTFRAMES = 2'u32
const MEMORY_ALIGNMENT = 65536'u64 # Align buffers inside memory along this alignment
const BUFFER_ALIGNMENT = 64'u64 # align offsets inside buffers along this alignment
const MEMORY_BLOCK_ALLOCATION_SIZE = 100_000_000'u64 # ca. 100mb per block, seems reasonable
const BUFFER_ALLOCATION_SIZE = 9_000_000'u64 # ca. 9mb per block, seems reasonable, can put 10 buffers into one memory block

# some globals that will (likely?) never change during the life time of the engine
type
  SupportedGPUType = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]
  TextureType = TVec1[uint8] | TVec2[uint8] | TVec3[uint8] | TVec4[uint8]

  ShaderObject[TShader] = object
    vertexShader: VkShaderModule
    fragmentShader: VkShaderModule

  IndexType = enum
    None, UInt8, UInt16, UInt32

  MemoryBlock = object
    vk: VkDeviceMemory
    size: uint64
    rawPointer: pointer # if not nil, this is mapped memory
    offsetNextFree: uint64

  BufferType = enum
    VertexBuffer
    VertexBufferMapped
    IndexBuffer
    IndexBufferMapped
    UniformBuffer
    UniformBufferMapped
  Buffer = object
    vk: VkBuffer
    size: uint64
    rawPointer: pointer # if not nil, buffer is using mapped memory
    offsetNextFree: uint64

  Texture[T: TextureType] = object
    vk: VkImage
    imageview: VkImageView
    sampler: VkSampler
    # offset: uint64
    # size: uint64
    width: uint32
    height: uint32
    data: seq[T]

  GPUArray[T: SupportedGPUType, TBuffer: static BufferType] = object
    data: seq[T]
    buffer: Buffer
    offset: uint64
  GPUValue[T: object|array, TBuffer: static BufferType] = object
    data: T
    buffer: Buffer
    offset: uint64
  GPUData = GPUArray | GPUValue

  DescriptorSetType = enum
    GlobalSet
    MaterialSet
  DescriptorSet[T: object, sType: static DescriptorSetType] = object
    data: T
    vk: array[INFLIGHTFRAMES.int, VkDescriptorSet]

  Pipeline[TShader] = object
    vk: VkPipeline
    layout: VkPipelineLayout
    descriptorSetLayouts: array[DescriptorSetType, VkDescriptorSetLayout]
  RenderData = object
    descriptorPool: VkDescriptorPool
    memory: array[VK_MAX_MEMORY_TYPES.int, seq[MemoryBlock]]
    buffers: array[BufferType, seq[Buffer]]

func depth(texture: Texture): int =
  default(elementType(texture.data)).len

func pointerAddOffset[T: SomeInteger](p: pointer, offset: T): pointer =
  cast[pointer](cast[T](p) + offset)

func usage(bType: BufferType): seq[VkBufferUsageFlagBits] =
  case bType:
    of VertexBuffer: @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of VertexBufferMapped: @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of IndexBuffer: @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of IndexBufferMapped: @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of UniformBuffer: @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of UniformBufferMapped: @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]

proc GetVkFormat(depth: int, usage: openArray[VkImageUsageFlagBits]): VkFormat =
  const DEPTH_FORMAT_MAP = [
    0: [VK_FORMAT_UNDEFINED, VK_FORMAT_UNDEFINED],
    1: [VK_FORMAT_R8_SRGB, VK_FORMAT_R8_UNORM],
    2: [VK_FORMAT_R8G8_SRGB, VK_FORMAT_R8G8_UNORM],
    3: [VK_FORMAT_R8G8B8_SRGB, VK_FORMAT_R8G8B8_UNORM],
    4: [VK_FORMAT_R8G8B8A8_SRGB, VK_FORMAT_R8G8B8A8_UNORM],
  ]

  var formatProperties = VkImageFormatProperties2(sType: VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2)
  for format in DEPTH_FORMAT_MAP[depth]:
    var formatInfo = VkPhysicalDeviceImageFormatInfo2(
      sType: VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
      format: format,
      thetype: VK_IMAGE_TYPE_2D,
      tiling: VK_IMAGE_TILING_OPTIMAL,
      usage: usage.toBits,
    )
    let formatCheck = vkGetPhysicalDeviceImageFormatProperties2(
      vulkan.physicalDevice,
      addr formatInfo,
      addr formatProperties,
    )
    if formatCheck == VK_SUCCESS: # found suitable format
      return format
    elif formatCheck == VK_ERROR_FORMAT_NOT_SUPPORTED: # nope, try to find other format
      continue
    else: # raise error
      checkVkResult formatCheck

  assert false, "Unable to find format for textures"


func alignedTo[T: SomeInteger](value: T, alignment: T): T =
  let remainder = value mod alignment
  if remainder == 0:
    return value
  else:
    return value + alignment - remainder

func VkType[T: SupportedGPUType](value: T): VkFormat =
  when T is float32: VK_FORMAT_R32_SFLOAT
  elif T is float64: VK_FORMAT_R64_SFLOAT
  elif T is int8: VK_FORMAT_R8_SINT
  elif T is int16: VK_FORMAT_R16_SINT
  elif T is int32: VK_FORMAT_R32_SINT
  elif T is int64: VK_FORMAT_R64_SINT
  elif T is uint8: VK_FORMAT_R8_UINT
  elif T is uint16: VK_FORMAT_R16_UINT
  elif T is uint32: VK_FORMAT_R32_UINT
  elif T is uint64: VK_FORMAT_R64_UINT
  elif T is TVec2[int32]: VK_FORMAT_R32G32_SINT
  elif T is TVec2[int64]: VK_FORMAT_R64G64_SINT
  elif T is TVec3[int32]: VK_FORMAT_R32G32B32_SINT
  elif T is TVec3[int64]: VK_FORMAT_R64G64B64_SINT
  elif T is TVec4[int32]: VK_FORMAT_R32G32B32A32_SINT
  elif T is TVec4[int64]: VK_FORMAT_R64G64B64A64_SINT
  elif T is TVec2[uint32]: VK_FORMAT_R32G32_UINT
  elif T is TVec2[uint64]: VK_FORMAT_R64G64_UINT
  elif T is TVec3[uint32]: VK_FORMAT_R32G32B32_UINT
  elif T is TVec3[uint64]: VK_FORMAT_R64G64B64_UINT
  elif T is TVec4[uint32]: VK_FORMAT_R32G32B32A32_UINT
  elif T is TVec4[uint64]: VK_FORMAT_R64G64B64A64_UINT
  elif T is TVec2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TVec2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TVec3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TVec3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TVec4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TVec4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  elif T is TMat2[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TMat2[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TMat23[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat23[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat32[float32]: VK_FORMAT_R32G32_SFLOAT
  elif T is TMat32[float64]: VK_FORMAT_R64G64_SFLOAT
  elif T is TMat3[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat3[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat34[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TMat34[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  elif T is TMat43[float32]: VK_FORMAT_R32G32B32_SFLOAT
  elif T is TMat43[float64]: VK_FORMAT_R64G64B64_SFLOAT
  elif T is TMat4[float32]: VK_FORMAT_R32G32B32A32_SFLOAT
  elif T is TMat4[float64]: VK_FORMAT_R64G64B64A64_SFLOAT
  else: {.error: "Unsupported data type on GPU".}

func GlslType[T: SupportedGPUType|Texture](value: T): string =
  when T is float32: "float"
  elif T is float64: "double"
  elif T is int8 or T is int16 or T is int32 or T is int64: "int"
  elif T is uint8 or T is uint16 or T is uint32 or T is uint64: "uint"
  elif T is TVec2[int32]: "ivec2"
  elif T is TVec2[int64]: "ivec2"
  elif T is TVec3[int32]: "ivec3"
  elif T is TVec3[int64]: "ivec3"
  elif T is TVec4[int32]: "ivec4"
  elif T is TVec4[int64]: "ivec4"
  elif T is TVec2[uint32]: "uvec2"
  elif T is TVec2[uint64]: "uvec2"
  elif T is TVec3[uint32]: "uvec3"
  elif T is TVec3[uint64]: "uvec3"
  elif T is TVec4[uint32]: "uvec4"
  elif T is TVec4[uint64]: "uvec4"
  elif T is TVec2[float32]: "vec2"
  elif T is TVec2[float64]: "dvec2"
  elif T is TVec3[float32]: "vec3"
  elif T is TVec3[float64]: "dvec3"
  elif T is TVec4[float32]: "vec4"
  elif T is TVec4[float64]: "dvec4"
  elif T is TMat2[float32]: "mat2"
  elif T is TMat2[float64]: "dmat2"
  elif T is TMat23[float32]: "mat23"
  elif T is TMat23[float64]: "dmat23"
  elif T is TMat32[float32]: "mat32"
  elif T is TMat32[float64]: "dmat32"
  elif T is TMat3[float32]: "mat3"
  elif T is TMat3[float64]: "dmat3"
  elif T is TMat34[float32]: "mat34"
  elif T is TMat34[float64]: "dmat34"
  elif T is TMat43[float32]: "mat43"
  elif T is TMat43[float64]: "dmat43"
  elif T is TMat4[float32]: "mat4"
  elif T is TMat4[float64]: "dmat4"
  elif T is Texture: "sampler2D"
  else: {.error: "Unsupported data type on GPU".}

template ForVertexDataFields(shader: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(shader):
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        const `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = value
        const `isinstancename` {.inject.} = hasCustomPragma(value, InstanceAttribute)
        body

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
        {.error: "Unsupported descriptor type: " & tt.name(typeof(value)).}

func NumberOfVertexInputAttributeDescriptors[T: SupportedGPUType|Texture](value: T): uint32 =
  when T is TMat2[float32] or T is TMat2[float64] or T is TMat23[float32] or T is TMat23[float64]:
    2
  elif T is TMat32[float32] or T is TMat32[float64] or T is TMat3[float32] or T is TMat3[float64] or T is TMat34[float32] or T is TMat34[float64]:
    3
  elif T is TMat43[float32] or T is TMat43[float64] or T is TMat4[float32] or T is TMat4[float64]:
    4
  else:
    1

func NLocationSlots[T: SupportedGPUType|Texture](value: T): uint32 =
  #[
  single location:
    - any scalar
    - any 16-bit vector
    - any 32-bit vector
    - any 64-bit vector that has max. 2 components
    16-bit scalar and vector types, and
    32-bit scalar and vector types, and
    64-bit scalar and 2-component vector types.
  two locations
    64-bit three- and four-component vectors
  ]#
  when T is TVec3[int64] or
    T is TVec4[int64] or
    T is TVec3[uint64] or
    T is TVec4[uint64] or
    T is TVec3[float64] or
    T is TVec4[float64] or
    T is TMat23[float64] or
    T is TMat3[float64] or
    T is TMat34[float64] or
    T is TMat43[float64] or
    T is TMat4[float64]:
    return 2
  else:
    return 1

template sType(descriptorSet: DescriptorSet): untyped =
  get(genericParams(typeof(descriptorSet)), 1)

# template bufferType[T: SupportedGPUType, TBuffer: static BufferType](gpuArray: GPUArray[T, TBuffer]): untyped =
  # TBuffer
# template bufferType[T: SupportedGPUType, TBuffer: static BufferType](gpuValue: GPUValue[T, TBuffer]): untyped =
  # TBuffer

template bufferType(gpuData: GPUData): untyped =
  typeof(gpuData).TBuffer
func NeedsMapping(bType: BufferType): bool =
  bType in [VertexBufferMapped, IndexBufferMapped, UniformBufferMapped]
template NeedsMapping(gpuData: GPUData): untyped =
  gpuData.bufferType.NeedsMapping

template size(gpuArray: GPUArray): uint64 =
  (gpuArray.data.len * sizeof(elementType(gpuArray.data))).uint64
template size(gpuValue: GPUValue): uint64 =
  sizeof(gpuValue.data).uint64
func size(texture: Texture): uint64 =
  texture.data.len.uint64 * sizeof(elementType(texture.data)).uint64

template rawPointer(gpuArray: GPUArray): pointer =
  addr(gpuArray.data[0])
template rawPointer(gpuValue: GPUValue): pointer =
  addr(gpuValue.data)

proc GetPhysicalDevice(instance: VkInstance): VkPhysicalDevice =
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance, addr(nDevices), devices.ToCPointer)

  var score = 0'u32
  for pDevice in devices:
    var props: VkPhysicalDeviceProperties
    # CANNOT use svkGetPhysicalDeviceProperties (not initialized yet)
    vkGetPhysicalDeviceProperties(pDevice, addr(props))
    if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and props.limits.maxImageDimension2D > score:
      score = props.limits.maxImageDimension2D
      result = pDevice

  if score == 0:
    for pDevice in devices:
      var props: VkPhysicalDeviceProperties
      # CANNOT use svkGetPhysicalDeviceProperties (not initialized yet)
      vkGetPhysicalDeviceProperties(pDevice, addr(props))
      if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU and props.limits.maxImageDimension2D > score:
        score = props.limits.maxImageDimension2D
        result = pDevice

  assert score > 0, "Unable to find integrated or discrete GPU"

proc IsMappable(memoryTypeIndex: uint32): bool =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(vulkan.physicalDevice, addr(physicalProperties))
  let flags = toEnums(physicalProperties.memoryTypes[memoryTypeIndex].propertyFlags)
  return VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags

proc GetQueueFamily(pDevice: VkPhysicalDevice, qType: VkQueueFlagBits): uint32 =
  var nQueuefamilies: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(pDevice, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  vkGetPhysicalDeviceQueueFamilyProperties(pDevice, addr nQueuefamilies, queuFamilies.ToCPointer)
  for i in 0'u32 ..< nQueuefamilies:
    if qType in toEnums(queuFamilies[i].queueFlags):
      return i
  assert false, &"Queue of type {qType} not found"

proc GetSurfaceFormat(): VkFormat =
  # EVERY windows driver and almost every linux driver should support this
  VK_FORMAT_B8G8R8A8_SRGB

proc InitDescriptorSet(
  renderData: RenderData,
  layout: VkDescriptorSetLayout,
  descriptorSet: var DescriptorSet,
) =
  # santization checks
  for name, value in descriptorSet.data.fieldPairs:
    when typeof(value) is GPUValue:
      assert value.buffer.vk.Valid
    elif typeof(value) is Texture:
      assert value.vk.Valid
      assert value.imageview.Valid
      assert value.sampler.Valid

  # allocate
  var layouts = newSeqWith(descriptorSet.vk.len, layout)
  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: renderData.descriptorPool,
    descriptorSetCount: uint32(layouts.len),
    pSetLayouts: layouts.ToCPointer,
  )
  checkVkResult vkAllocateDescriptorSets(vulkan.device, addr(allocInfo), descriptorSet.vk.ToCPointer)

  # allocate seq with high cap to prevent realocation while adding to set
  # (which invalidates pointers that are passed to the vulkan api call)
  var descriptorSetWrites = newSeqOfCap[VkWriteDescriptorSet](1024)
  var imageWrites = newSeqOfCap[VkDescriptorImageInfo](1024)
  var bufferWrites = newSeqOfCap[VkDescriptorBufferInfo](1024)

  ForDescriptorFields(descriptorSet.data, fieldName, fieldValue, descriptorType, descriptorCount, descriptorBindingNumber):
    for i in 0 ..< descriptorSet.vk.len:
      when typeof(fieldValue) is GPUValue:
        bufferWrites.add VkDescriptorBufferInfo(
          buffer: fieldValue.buffer.vk,
          offset: fieldValue.offset,
          range: fieldValue.size,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSet.vk[i],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: 0,
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: nil,
          pBufferInfo: addr(bufferWrites[^1]),
        )
      elif typeof(fieldValue) is Texture:
        imageWrites.add VkDescriptorImageInfo(
          sampler: fieldValue.sampler,
          imageView: fieldValue.imageView,
          imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSet.vk[i],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: 0,
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: addr(imageWrites[^1]),
          pBufferInfo: nil,
        )
      elif typeof(fieldValue) is array:
        discard
        when elementType(fieldValue) is Texture:
          for textureIndex in 0 ..< descriptorCount:
            imageWrites.add VkDescriptorImageInfo(
              sampler: fieldValue[textureIndex].sampler,
              imageView: fieldValue[textureIndex].imageView,
              imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            )
          descriptorSetWrites.add VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            dstSet: descriptorSet.vk[i],
            dstBinding: descriptorBindingNumber,
            dstArrayElement: 0,
            descriptorType: descriptorType,
            descriptorCount: descriptorCount,
            pImageInfo: addr(imageWrites[^descriptorCount.int]),
            pBufferInfo: nil,
          )
        else:
          {.error: "Unsupported descriptor type: " & tt.name(typeof(fieldValue)).}
      else:
        {.error: "Unsupported descriptor type: " & tt.name(typeof(fieldValue)).}

  vkUpdateDescriptorSets(
    device = vulkan.device,
    descriptorWriteCount = descriptorSetWrites.len.uint32,
    pDescriptorWrites = descriptorSetWrites.ToCPointer,
    descriptorCopyCount = 0,
    pDescriptorCopies = nil,
  )

converter toVkIndexType(indexType: IndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of UInt8: VK_INDEX_TYPE_UINT8_EXT
    of UInt16: VK_INDEX_TYPE_UINT16
    of UInt32: VK_INDEX_TYPE_UINT32

proc CreateRenderPass(format: VkFormat): VkRenderPass =
  var
    attachments = @[VkAttachmentDescription(
        format: format,
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )]
    dependencies = @[VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT],
      srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
      dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT],
      dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
    )]
    outputs = @[
      VkAttachmentReference(
        attachment: 0,
        layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      )
    ]

  var subpassesList = [
    VkSubpassDescription(
      flags: VkSubpassDescriptionFlags(0),
      pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
      inputAttachmentCount: 0,
      pInputAttachments: nil,
      colorAttachmentCount: uint32(outputs.len),
      pColorAttachments: outputs.ToCPointer,
      pResolveAttachments: nil,
      pDepthStencilAttachment: nil,
      preserveAttachmentCount: 0,
      pPreserveAttachments: nil,
    )
  ]

  var createInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: uint32(attachments.len),
      pAttachments: attachments.ToCPointer,
      subpassCount: uint32(subpassesList.len),
      pSubpasses: subpassesList.ToCPointer,
      dependencyCount: uint32(dependencies.len),
      pDependencies: dependencies.ToCPointer,
    )
  checkVkResult vulkan.device.vkCreateRenderPass(addr(createInfo), nil, addr(result))

proc compileGlslToSPIRV(stage: VkShaderStageFlagBits, shaderSource: string): seq[uint32] {.compileTime.} =
  func stage2string(stage: VkShaderStageFlagBits): string {.compileTime.} =
    case stage
    of VK_SHADER_STAGE_VERTEX_BIT: "vert"
    of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
    of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
    of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
    of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
    of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
    else: ""

  when defined(nimcheck): # will not run if nimcheck is running
    return result

  let
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"

  if not shaderfile.fileExists:
    echo "shader of type ", stage
    for i, line in enumerate(shaderSource.splitlines()):
      echo "  ", i + 1, " ", line
    # var glslExe = currentSourcePath.parentDir.parentDir.parentDir / "tools" / "glslangValidator"
    var glslExe = currentSourcePath.parentDir / "tools" / "glslangValidator"
    when defined(windows):
      glslExe = glslExe & "." & ExeExt
    let command = &"{glslExe} --entry-point main -V --stdin -S {stagename} -o {shaderfile}"
    echo "run: ", command
    discard StaticExecChecked(
        command = command,
        input = shaderSource
    )
  else:
    echo &"shaderfile {shaderfile} is up-to-date"

  when defined(mingw) and defined(linux): # required for crosscompilation, path separators get messed up
    let shaderbinary = staticRead shaderfile.replace("\\", "/")
  else:
    let shaderbinary = staticRead shaderfile

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl 0) or
      (uint32(shaderbinary[i + 1]) shl 8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc generateShaderSource[TShader](shader: TShader): (string, string) {.compileTime.} =
  const GLSL_VERSION = "450"
  var vsInput: seq[string]
  var vsOutput: seq[string]
  var fsInput: seq[string]
  var fsOutput: seq[string]
  var uniforms: seq[string]
  var samplers: seq[string]
  var vsInputLocation = 0'u32
  var passLocation = 0
  var fsOutputLocation = 0

  var descriptorSetCount = 0
  for fieldname, value in fieldPairs(shader):
    # vertex shader inputs
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      assert typeof(value) is SupportedGPUType
      vsInput.add "layout(location = " & $vsInputLocation & ") in " & GlslType(value) & " " & fieldname & ";"
      for j in 0 ..< NumberOfVertexInputAttributeDescriptors(value):
        vsInputLocation += NLocationSlots(value)

    # intermediate values, passed between shaders
    elif hasCustomPragma(value, Pass) or hasCustomPragma(value, PassFlat):
      let flat = if hasCustomPragma(value, PassFlat): "flat " else: ""
      vsOutput.add "layout(location = " & $passLocation & ") " & flat & "out " & GlslType(value) & " " & fieldname & ";"
      fsInput.add "layout(location = " & $passLocation & ") " & flat & "in " & GlslType(value) & " " & fieldname & ";"
      passLocation.inc

    # fragment shader output
    elif hasCustomPragma(value, ShaderOutput):
      fsOutput.add &"layout(location = " & $fsOutputLocation & ") out " & GlslType(value) & " " & fieldname & ";"
      fsOutputLocation.inc

    # descriptor sets
    # need to consider 4 cases: uniform block, texture, uniform block array, texture array
    elif typeof(value) is DescriptorSet:
      assert descriptorSetCount <= DescriptorSetType.high.int, &"{tt.name(TShader)}: maximum {DescriptorSetType.high} allowed"

      var descriptorBinding = 0
      for descriptorName, descriptorValue in fieldPairs(value.data):

        when typeof(descriptorValue) is Texture:
          samplers.add "layout(set=" & $descriptorSetCount & ", binding = " & $descriptorBinding & ") uniform " & GlslType(descriptorValue) & " " & descriptorName & ";"
          descriptorBinding.inc

        elif typeof(descriptorValue) is GPUValue:
          uniforms.add "layout(set=" & $descriptorSetCount & ", binding = " & $descriptorBinding & ") uniform T" & descriptorName & " {"
          when typeof(descriptorValue.data) is object:
            for blockFieldName, blockFieldValue in descriptorValue.data.fieldPairs():
              assert typeof(blockFieldValue) is SupportedGPUType, "uniform block field '" & blockFieldName & "' is not a SupportedGPUType"
              uniforms.add "  " & GlslType(blockFieldValue) & " " & blockFieldName & ";"
            uniforms.add "} " & descriptorName & ";"
          elif typeof(descriptorValue.data) is array:
            for blockFieldName, blockFieldValue in default(elementType(descriptorValue.data)).fieldPairs():
              assert typeof(blockFieldValue) is SupportedGPUType, "uniform block field '" & blockFieldName & "' is not a SupportedGPUType"
              uniforms.add "  " & GlslType(blockFieldValue) & " " & blockFieldName & ";"
            uniforms.add "} " & descriptorName & "[" & $descriptorValue.data.len & "];"
          descriptorBinding.inc
        elif typeof(descriptorValue) is array:
          when elementType(descriptorValue) is Texture:
            let arrayDecl = "[" & $typeof(descriptorValue).len & "]"
            samplers.add "layout(set=" & $descriptorSetCount & ", binding = " & $descriptorBinding & ") uniform " & GlslType(default(elementType(descriptorValue))) & " " & descriptorName & "" & arrayDecl & ";"
            descriptorBinding.inc
          else:
            {.error: "Unsupported shader descriptor field " & descriptorName.}
      descriptorSetCount.inc
    elif fieldname in ["vertexCode", "fragmentCode"]:
      discard
    else:
      {.error: "Unsupported shader field '" & tt.name(TShader) & "." & fieldname & "' of type " & tt.name(typeof(value)).}

  result[0] = (@[&"#version {GLSL_VERSION}", "#extension GL_EXT_scalar_block_layout : require", ""] &
    vsInput &
    uniforms &
    samplers &
    vsOutput &
    @[shader.vertexCode]).join("\n")

  result[1] = (@[&"#version {GLSL_VERSION}", "#extension GL_EXT_scalar_block_layout : require", ""] &
    fsInput &
    uniforms &
    samplers &
    fsOutput &
    @[shader.fragmentCode]).join("\n")

proc CompileShader[TShader](shader: static TShader): ShaderObject[TShader] =
  const (vertexShaderSource, fragmentShaderSource) = generateShaderSource(shader)

  let vertexBinary = compileGlslToSPIRV(VK_SHADER_STAGE_VERTEX_BIT, vertexShaderSource)
  let fragmentBinary = compileGlslToSPIRV(VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShaderSource)

  var createInfoVertex = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(vertexBinary.len * sizeof(uint32)),
    pCode: vertexBinary.ToCPointer,
  )
  checkVkResult vulkan.device.vkCreateShaderModule(addr(createInfoVertex), nil, addr(result.vertexShader))
  var createInfoFragment = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(fragmentBinary.len * sizeof(uint32)),
    pCode: fragmentBinary.ToCPointer,
  )
  checkVkResult vulkan.device.vkCreateShaderModule(addr(createInfoFragment), nil, addr(result.fragmentShader))


proc CreatePipeline[TShader](
  renderPass: VkRenderPass,
  shader: ShaderObject[TShader],
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
  descriptorPoolLimit = 1024
): Pipeline[TShader] =
  # create pipeline

  for theFieldname, value in fieldPairs(default(TShader)):
    when typeof(value) is DescriptorSet:
      var layoutbindings: seq[VkDescriptorSetLayoutBinding]
      ForDescriptorFields(value.data, fieldName, fieldValue, descriptorType, descriptorCount, descriptorBindingNumber):
        layoutbindings.add VkDescriptorSetLayoutBinding(
          binding: descriptorBindingNumber,
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          stageFlags: VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
          pImmutableSamplers: nil,
        )
      var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
        sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        bindingCount: layoutbindings.len.uint32,
        pBindings: layoutbindings.ToCPointer
      )
      checkVkResult vkCreateDescriptorSetLayout(
        vulkan.device,
        addr(layoutCreateInfo),
        nil,
        addr(result.descriptorSetLayouts[value.sType])
      )
  let pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount: result.descriptorSetLayouts.len.uint32,
    pSetLayouts: result.descriptorSetLayouts.ToCPointer,
    # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.ToCPointer,
  )
  checkVkResult vkCreatePipelineLayout(vulkan.device, addr(pipelineLayoutInfo), nil, addr(result.layout))

  let stages = [
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_VERTEX_BIT,
      module: shader.vertexShader,
      pName: "main",
    ),
    VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_FRAGMENT_BIT,
      module: shader.fragmentShader,
      pName: "main",
    ),
  ]
  var
    bindings: seq[VkVertexInputBindingDescription]
    attributes: seq[VkVertexInputAttributeDescription]
  var inputBindingNumber = 0'u32
  var location = 0'u32
  ForVertexDataFields(default(TShader), fieldname, value, isInstanceAttr):
    bindings.add VkVertexInputBindingDescription(
      binding: inputBindingNumber,
      stride: sizeof(value).uint32,
      inputRate: if isInstanceAttr: VK_VERTEX_INPUT_RATE_INSTANCE else: VK_VERTEX_INPUT_RATE_VERTEX,
    )
    # allows to submit larger data structures like Mat44, for most other types will be 1
    let perDescriptorSize = sizeof(value).uint32 div NumberOfVertexInputAttributeDescriptors(value)
    for i in 0'u32 ..< NumberOfVertexInputAttributeDescriptors(value):
      attributes.add VkVertexInputAttributeDescription(
        binding: inputBindingNumber,
        location: location,
        format: VkType(value),
        offset: i * perDescriptorSize,
      )
      location += NLocationSlots(value)
    inc inputBindingNumber

  let
    vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
      vertexBindingDescriptionCount: uint32(bindings.len),
      pVertexBindingDescriptions: bindings.ToCPointer,
      vertexAttributeDescriptionCount: uint32(attributes.len),
      pVertexAttributeDescriptions: attributes.ToCPointer,
    )
    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: topology,
      primitiveRestartEnable: false,
    )
    viewportState = VkPipelineViewportStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
      viewportCount: 1,
      scissorCount: 1,
    )
    rasterizer = VkPipelineRasterizationStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
      depthClampEnable: VK_FALSE,
      rasterizerDiscardEnable: VK_FALSE,
      polygonMode: polygonMode,
      lineWidth: 1.0,
      cullMode: toBits [cullMode],
      frontFace: frontFace,
      depthBiasEnable: VK_FALSE,
      depthBiasConstantFactor: 0.0,
      depthBiasClamp: 0.0,
      depthBiasSlopeFactor: 0.0,
    )
    multisampling = VkPipelineMultisampleStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
      sampleShadingEnable: VK_FALSE,
      rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
      minSampleShading: 1.0,
      pSampleMask: nil,
      alphaToCoverageEnable: VK_FALSE,
      alphaToOneEnable: VK_FALSE,
    )
    colorBlendAttachment = VkPipelineColorBlendAttachmentState(
      colorWriteMask: toBits [VK_COLOR_COMPONENT_R_BIT, VK_COLOR_COMPONENT_G_BIT, VK_COLOR_COMPONENT_B_BIT, VK_COLOR_COMPONENT_A_BIT],
      blendEnable: VK_TRUE,
      srcColorBlendFactor: VK_BLEND_FACTOR_SRC_ALPHA,
      dstColorBlendFactor: VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
      colorBlendOp: VK_BLEND_OP_ADD,
      srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
      dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
      alphaBlendOp: VK_BLEND_OP_ADD,
    )
    colorBlending = VkPipelineColorBlendStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
      logicOpEnable: false,
      attachmentCount: 1,
      pAttachments: addr(colorBlendAttachment),
    )
    dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
    dynamicState = VkPipelineDynamicStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
      dynamicStateCount: dynamicStates.len.uint32,
      pDynamicStates: dynamicStates.ToCPointer,
    )
  let createInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount: 2,
    pStages: stages.ToCPointer,
    pVertexInputState: addr(vertexInputInfo),
    pInputAssemblyState: addr(inputAssembly),
    pViewportState: addr(viewportState),
    pRasterizationState: addr(rasterizer),
    pMultisampleState: addr(multisampling),
    pDepthStencilState: nil,
    pColorBlendState: addr(colorBlending),
    pDynamicState: addr(dynamicState),
    layout: result.layout,
    renderPass: renderPass,
    subpass: 0,
    basePipelineHandle: VkPipeline(0),
    basePipelineIndex: -1,
  )
  checkVkResult vkCreateGraphicsPipelines(
    vulkan.device,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.vk)
  )

proc AllocateNewMemoryBlock(size: uint64, mType: uint32): MemoryBlock =
  result = MemoryBlock(
    vk: svkAllocateMemory(size, mType),
    size: size,
    rawPointer: nil,
    offsetNextFree: 0,
  )
  if mType.IsMappable():
    checkVkResult vkMapMemory(
      device = vulkan.device,
      memory = result.vk,
      offset = 0'u64,
      size = result.size,
      flags = VkMemoryMapFlags(0),
      ppData = addr(result.rawPointer)
    )

proc FlushAllMemory(renderData: RenderData) =
  var flushRegions = newSeq[VkMappedMemoryRange]()
  for memoryBlocks in renderData.memory:
    for memoryBlock in memoryBlocks:
      if memoryBlock.rawPointer != nil and memoryBlock.offsetNextFree > 0:
        flushRegions.add VkMappedMemoryRange(
          sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
          memory: memoryBlock.vk,
          size: alignedTo(memoryBlock.offsetNextFree, svkGetPhysicalDeviceProperties().limits.nonCoherentAtomSize),
        )
  if flushRegions.len > 0:
    checkVkResult vkFlushMappedMemoryRanges(vulkan.device, flushRegions.len.uint32, flushRegions.ToCPointer())

proc AllocateNewBuffer(renderData: var RenderData, size: uint64, bufferType: BufferType): Buffer =
  result = Buffer(
    vk: svkCreateBuffer(size, bufferType.usage),
    size: size,
    rawPointer: nil,
    offsetNextFree: 0,
  )
  let memoryRequirements = svkGetBufferMemoryRequirements(result.vk)
  let memoryType = BestMemory(mappable = bufferType.NeedsMapping, filter = memoryRequirements.memoryTypes)

  # check if there is an existing allocated memory block that is large enough to be used
  var selectedBlockI = -1
  for i in 0 ..< renderData.memory[memoryType].len:
    let memoryBlock = renderData.memory[memoryType][i]
    if memoryBlock.size - alignedTo(memoryBlock.offsetNextFree, memoryRequirements.alignment) >= memoryRequirements.size:
      selectedBlockI = i
      break
  # otherwise, allocate a new block of memory and use that
  if selectedBlockI < 0:
    selectedBlockI = renderData.memory[memoryType].len
    renderData.memory[memoryType].add AllocateNewMemoryBlock(
      size = max(memoryRequirements.size, MEMORY_BLOCK_ALLOCATION_SIZE),
      mType = memoryType
    )

  let selectedBlock = renderData.memory[memoryType][selectedBlockI]
  renderData.memory[memoryType][selectedBlockI].offsetNextFree = alignedTo(
    selectedBlock.offsetNextFree,
    memoryRequirements.alignment,
  )
  checkVkResult vkBindBufferMemory(
    vulkan.device,
    result.vk,
    selectedBlock.vk,
    selectedBlock.offsetNextFree,
  )
  result.rawPointer = selectedBlock.rawPointer.pointerAddOffset(selectedBlock.offsetNextFree)
  renderData.memory[memoryType][selectedBlockI].offsetNextFree += memoryRequirements.size

proc AssignBuffers[T](renderdata: var RenderData, data: var T) =
  for name, value in fieldPairs(data):
    when typeof(value) is GPUData:

      # find buffer that has space
      var selectedBufferI = -1
      for i in 0 ..< renderData.buffers[value.bufferType].len:
        let buffer = renderData.buffers[value.bufferType][i]
        if buffer.size - alignedTo(buffer.offsetNextFree, BUFFER_ALIGNMENT) >= value.size:
          selectedBufferI = i

      # otherwise create new buffer
      if selectedBufferI < 0:
        selectedBufferI = renderdata.buffers[value.bufferType].len
        renderdata.buffers[value.bufferType].add renderdata.AllocateNewBuffer(
          size = max(value.size, BUFFER_ALLOCATION_SIZE),
          bufferType = value.bufferType,
        )

      # assigne value
      let selectedBuffer = renderdata.buffers[value.bufferType][selectedBufferI]
      renderdata.buffers[value.bufferType][selectedBufferI].offsetNextFree = alignedTo(
        selectedBuffer.offsetNextFree,
        BUFFER_ALIGNMENT
      )
      value.buffer = selectedBuffer
      value.offset = renderdata.buffers[value.bufferType][selectedBufferI].offsetNextFree
      renderdata.buffers[value.bufferType][selectedBufferI].offsetNextFree += value.size
proc AssignBuffers(renderdata: var RenderData, descriptorSet: var DescriptorSet) =
  AssignBuffers(renderdata, descriptorSet.data)

proc UpdateGPUBuffer(gpuData: GPUData) =
  if gpuData.size == 0:
    return
  when NeedsMapping(gpuData):
    copyMem(pointerAddOffset(gpuData.buffer.rawPointer, gpuData.offset), gpuData.rawPointer, gpuData.size)
  else:
    WithStagingBuffer((gpuData.buffer.vk, gpuData.offset), gpuData.size, stagingPtr):
      copyMem(stagingPtr, gpuData.rawPointer, gpuData.size)

proc UpdateAllGPUBuffers[T](value: T) =
  for name, fieldvalue in value.fieldPairs():
    when typeof(fieldvalue) is GPUData:
      UpdateGPUBuffer(fieldvalue)


proc InitRenderData(descriptorPoolLimit = 1024'u32): RenderData =
  # allocate descriptor pools
  var poolSizes = [
    VkDescriptorPoolSize(thetype: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, descriptorCount: descriptorPoolLimit),
    VkDescriptorPoolSize(thetype: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount: descriptorPoolLimit),
  ]
  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount: poolSizes.len.uint32,
    pPoolSizes: poolSizes.ToCPointer,
    maxSets: descriptorPoolLimit,
  )
  checkVkResult vkCreateDescriptorPool(vulkan.device, addr(poolInfo), nil, addr(result.descriptorPool))

proc TransitionImageLayout(image: VkImage, oldLayout, newLayout: VkImageLayout) =
  var
    barrier = VkImageMemoryBarrier(
      sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
      oldLayout: oldLayout,
      newLayout: newLayout,
      srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      image: image,
      subresourceRange: VkImageSubresourceRange(
        aspectMask: toBits [VK_IMAGE_ASPECT_COLOR_BIT],
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1,
      ),
    )
    srcStage: VkPipelineStageFlagBits
    dstStage: VkPipelineStageFlagBits

  if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED and newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
    barrier.srcAccessMask = VkAccessFlags(0)
    dstStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.dstAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
  elif oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.srcAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
    dstStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
    barrier.dstAccessMask = [VK_ACCESS_SHADER_READ_BIT].toBits
  else:
    raise newException(Exception, "Unsupported layout transition!")

  WithSingleUseCommandBuffer(commandBuffer):
    vkCmdPipelineBarrier(
      commandBuffer,
      srcStageMask = [srcStage].toBits,
      dstStageMask = [dstStage].toBits,
      dependencyFlags = VkDependencyFlags(0),
      memoryBarrierCount = 0,
      pMemoryBarriers = nil,
      bufferMemoryBarrierCount = 0,
      pBufferMemoryBarriers = nil,
      imageMemoryBarrierCount = 1,
      pImageMemoryBarriers = addr(barrier),
    )

proc createImageView(image: VkImage, format: VkFormat): VkImageView =
  var createInfo = VkImageViewCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    image: image,
    viewType: VK_IMAGE_VIEW_TYPE_2D,
    format: format,
    components: VkComponentMapping(
      r: VK_COMPONENT_SWIZZLE_IDENTITY,
      g: VK_COMPONENT_SWIZZLE_IDENTITY,
      b: VK_COMPONENT_SWIZZLE_IDENTITY,
      a: VK_COMPONENT_SWIZZLE_IDENTITY,
    ),
    subresourceRange: VkImageSubresourceRange(
      aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
      baseMipLevel: 0,
      levelCount: 1,
      baseArrayLayer: 0,
      layerCount: 1,
    ),
  )
  checkVkResult vkCreateImageView(vulkan.device, addr(createInfo), nil, addr(result))

proc createSampler(
  magFilter = VK_FILTER_LINEAR,
  minFilter = VK_FILTER_LINEAR,
  addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT,
  addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT,
): VkSampler =

  let samplerInfo = VkSamplerCreateInfo(
    sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
    magFilter: magFilter,
    minFilter: minFilter,
    addressModeU: addressModeU,
    addressModeV: addressModeV,
    addressModeW: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    anisotropyEnable: vulkan.anisotropy > 0,
    maxAnisotropy: vulkan.anisotropy,
    borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
    unnormalizedCoordinates: VK_FALSE,
    compareEnable: VK_FALSE,
    compareOp: VK_COMPARE_OP_ALWAYS,
    mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
    mipLodBias: 0,
    minLod: 0,
    maxLod: 0,
  )
  checkVkResult vkCreateSampler(vulkan.device, addr(samplerInfo), nil, addr(result))

proc createTextureImage(renderData: var RenderData, texture: var Texture) =
  assert texture.vk == VkImage(0)
  const usage = [VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_IMAGE_USAGE_SAMPLED_BIT]
  let format = GetVkFormat(texture.depth, usage = usage)

  texture.vk = svkCreate2DImage(texture.width, texture.height, format, usage)
  texture.sampler = createSampler()

  let memoryRequirements = texture.vk.svkGetImageMemoryRequirements()
  let memoryType = BestMemory(mappable = false, filter = memoryRequirements.memoryTypes)
  # check if there is an existing allocated memory block that is large enough to be used
  var selectedBlockI = -1
  for i in 0 ..< renderData.memory[memoryType].len:
    let memoryBlock = renderData.memory[memoryType][i]
    if memoryBlock.size - alignedTo(memoryBlock.offsetNextFree, memoryRequirements.alignment) >= memoryRequirements.size:
      selectedBlockI = i
      break
  # otherwise, allocate a new block of memory and use that
  if selectedBlockI < 0:
    selectedBlockI = renderData.memory[memoryType].len
    renderData.memory[memoryType].add AllocateNewMemoryBlock(
      size = max(memoryRequirements.size, MEMORY_BLOCK_ALLOCATION_SIZE),
      mType = memoryType
    )
  let selectedBlock = renderData.memory[memoryType][selectedBlockI]
  renderData.memory[memoryType][selectedBlockI].offsetNextFree = alignedTo(
    selectedBlock.offsetNextFree,
    memoryRequirements.alignment,
  )

  checkVkResult vkBindImageMemory(
    vulkan.device,
    texture.vk,
    selectedBlock.vk,
    renderData.memory[memoryType][selectedBlockI].offsetNextFree,
  )
  renderData.memory[memoryType][selectedBlockI].offsetNextFree += memoryRequirements.size

  # imageview can only be created after memory is bound
  texture.imageview = createImageView(texture.vk, format)

  # data transfer and layout transition
  TransitionImageLayout(texture.vk, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
  WithStagingBuffer(
    (texture.vk, texture.width, texture.height),
    memoryRequirements.size,
    stagingPtr
  ):
    copyMem(stagingPtr, texture.data.ToCPointer, texture.size)
  TransitionImageLayout(texture.vk, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)


proc UploadTextures(renderdata: var RenderData, descriptorSet: var DescriptorSet) =
  for name, value in fieldPairs(descriptorSet.data):
    when typeof(value) is Texture:
      echo "Upload texture '", name, "'"
      renderdata.createTextureImage(value)
    elif typeof(value) is array:
      when elementType(value) is Texture:
        echo "Upload texture ARRAY '", name, "'"
        for texture in value.mitems:
          renderdata.createTextureImage(texture)

proc HasGPUValueField[T](name: static string): bool {.compileTime.} =
  for fieldname, value in default(T).fieldPairs():
    when typeof(value) is GPUValue and fieldname == name: return true
  return false

template WithGPUValueField(obj: object, name: static string, fieldvalue, body: untyped): untyped =
  # HasGPUValueField MUST be used to check if this is supported
  for fieldname, value in obj.fieldPairs():
    when fieldname == name:
      block:
        let `fieldvalue` {.inject.} = value
        body

proc Bind[T](pipeline: Pipeline[T], commandBuffer: VkCommandBuffer, currentFrameInFlight: int) =
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.vk)
  #[
  commandBuffer.vkCmdBindDescriptorSets(
    VK_PIPELINE_BIND_POINT_GRAPHICS,
    pipeline.layout,
    0,
    1,
    addr pipeline.descriptorSets[currentFrameInFlight],
    0,
    nil,
  )
  ]#

proc AssertCompatible(TShader, TMesh, TInstance, TGlobals, TMaterial: typedesc) =
  var descriptorSetCount = 0

  for shaderAttributeName, shaderAttribute in default(TShader).fieldPairs:
    var foundField = false

    # Vertex input data
    when hasCustomPragma(shaderAttribute, VertexAttribute):
      assert typeof(shaderAttribute) is SupportedGPUType
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == shaderAttributeName:
          assert meshValue is GPUArray, "Mesh attribute '" & meshName & "' must be of type 'GPUArray' but is of type " & tt.name(typeof(meshValue))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & shaderAttributeName & "' has been found more than once"
          assert elementType(meshValue.data) is typeof(shaderAttribute), "Shader input " & tt.name(TShader) & "." & shaderAttributeName & " is of type '" & tt.name(typeof(shaderAttribute)) & "' but mesh attribute is of type '" & tt.name(elementType(meshValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & shaderAttributeName & ": " & tt.name(typeof(shaderAttribute)) & "' not found in '" & tt.name(TMesh) & "'"

    # Instance input data
    elif hasCustomPragma(shaderAttribute, InstanceAttribute):
      assert typeof(shaderAttribute) is SupportedGPUType
      for instanceName, instanceValue in default(TInstance).fieldPairs:
        when instanceName == shaderAttributeName:
          assert instanceValue is GPUArray, "Instance attribute '" & instanceName & "' must be of type 'GPUArray' but is of type " & tt.name(typeof(instanceName))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & shaderAttributeName & "' has been found more than once"
          assert elementType(instanceValue.data) is typeof(shaderAttribute), "Shader input " & tt.name(TShader) & "." & shaderAttributeName & " is of type '" & tt.name(typeof(shaderAttribute)) & "' but instance attribute is of type '" & tt.name(elementType(instanceValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & shaderAttributeName & ": " & tt.name(typeof(shaderAttribute)) & "' not found in '" & tt.name(TInstance) & "'"

    # descriptors
    elif typeof(shaderAttribute) is DescriptorSet:
      assert descriptorSetCount <= DescriptorSetType.high.int, &"{tt.name(TShader)}: maximum {DescriptorSetType.high} allowed"
      descriptorSetCount.inc


      when shaderAttribute.sType == GlobalSet:
        assert shaderAttribute.sType == default(TGlobals).sType, "Shader has global descriptor set of type '" & $shaderAttribute.sType & "' but matching provided type is '" & $default(TGlobals).sType & "'"
        assert typeof(shaderAttribute) is TGlobals, "Shader has global descriptor set type '" & tt.name(get(genericParams(typeof(shaderAttribute)), 0)) & "' but provided type is " & tt.name(TGlobals)
      elif shaderAttribute.sType == MaterialSet:
        assert shaderAttribute.sType == default(TMaterial).sType, "Shader has material descriptor set of type '" & $shaderAttribute.sType & "' but matching provided type is '" & $default(TMaterial).sType & "'"
        assert typeof(shaderAttribute) is TMaterial, "Shader has materialdescriptor type '" & tt.name(get(genericParams(typeof(shaderAttribute)), 0)) & "' but provided type is " & tt.name(TMaterial)


proc Render[TShader, TGlobals, TMaterial, TMesh, TInstance](
  commandBuffer: VkCommandBuffer,
  pipeline: Pipeline[TShader],
  globalSet: TGlobals,
  materialSet: TMaterial,
  mesh: TMesh,
  instances: TInstance,
) =
  static: AssertCompatible(TShader, TMesh, TInstance, TGlobals, TMaterial)
  #[
  if renderable.vertexBuffers.len > 0:
    commandBuffer.vkCmdBindVertexBuffers(
      firstBinding = 0'u32,
      bindingCount = uint32(renderable.vertexBuffers.len),
      pBuffers = renderable.vertexBuffers.ToCPointer(),
      pOffsets = renderable.bufferOffsets.ToCPointer()
    )
  if renderable.indexType != None:
    commandBuffer.vkCmdBindIndexBuffer(
      renderable.indexBuffer,
      renderable.indexBufferOffset,
      renderable.indexType,
    )
    commandBuffer.vkCmdDrawIndexed(
      indexCount = renderable.indexCount,
      instanceCount = renderable.instanceCount,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0
    )
  else:
    commandBuffer.vkCmdDraw(
      vertexCount = renderable.vertexCount,
      instanceCount = renderable.instanceCount,
      firstVertex = 0,
      firstInstance = 0
    )
    ]#

when isMainModule:
  import semicongine/platform/window
  import semicongine/vulkan/instance
  import semicongine/vulkan/device
  import semicongine/vulkan/physicaldevice
  import std/options

  type
    MeshA = object
      position: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]
    InstanceA = object
      rotation: GPUArray[Vec4f, VertexBuffer]
      objPosition: GPUArray[Vec3f, VertexBuffer]
    MaterialA = object
      reflection: float32
      baseColor: Vec3f
    UniformsA = object
      defaultTexture: Texture[TVec3[uint8]]
      defaultMaterial: GPUValue[MaterialA, UniformBuffer]
      materials: GPUValue[array[3, MaterialA], UniformBuffer]
      materialTextures: array[3, Texture[TVec3[uint8]]]
    ShaderSettings = object
      gamma: float32
    GlobalsA = object
      fontAtlas: Texture[TVec3[uint8]]
      settings: GPUValue[ShaderSettings, UniformBuffer]

    ShaderA = object
      # vertex input
      position {.VertexAttribute.}: Vec3f
      objPosition {.InstanceAttribute.}: Vec3f
      rotation {.InstanceAttribute.}: Vec4f
      # intermediate
      test {.Pass.}: float32
      test1 {.PassFlat.}: Vec3f
      # output
      color {.ShaderOutput.}: Vec4f
      # descriptor sets
      globals: DescriptorSet[GlobalsA, GlobalSet]
      uniforms: DescriptorSet[UniformsA, MaterialSet]
      # code
      vertexCode: string = "void main() {}"
      fragmentCode: string = "void main() {}"

  let w = CreateWindow("test2")
  putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")

  # TODO: remove those ugly wrappers
  let theInstance = w.CreateInstance(
    vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions = @[],
    layers = @["VK_LAYER_KHRONOS_validation"],
  )

  let dev = theInstance.CreateDevice(
    theInstance.GetPhysicalDevices().FilterBestGraphics(),
    enabledExtensions = @[],
    theInstance.GetPhysicalDevices().FilterBestGraphics().FilterForGraphicsPresentationQueues()
  ).vk
  let frameWidth = 100'u32
  let frameHeight = 100'u32

  # TODO: pack this stuff into a setup method and condense everything a bit
  let pDevice = theInstance.vk.GetPhysicalDevice()
  let qfi = pDevice.GetQueueFamily(VK_QUEUE_GRAPHICS_BIT)
  vulkan = VulkanGlobals(
    instance: theInstance.vk,
    device: dev,
    physicalDevice: pDevice,
    queueFamilyIndex: qfi,
    queue: svkGetDeviceQueue(dev, qfi, VK_QUEUE_GRAPHICS_BIT)
  )

  var myMesh1 = MeshA(
    position: GPUArray[Vec3f, VertexBuffer](data: @[NewVec3f(0, 0, ), NewVec3f(0, 0, ), NewVec3f(0, 0, )]),
  )
  var uniforms1 = DescriptorSet[UniformsA, MaterialSet](
    data: UniformsA(
      defaultTexture: Texture[TVec3[uint8]](width: 1, height: 1, data: @[TVec3[uint8]([0'u8, 0'u8, 0'u8])]),
      materials: GPUValue[array[3, MaterialA], UniformBuffer](data: [
        MaterialA(reflection: 0, baseColor: NewVec3f(1, 0, 0)),
        MaterialA(reflection: 0.1, baseColor: NewVec3f(0, 1, 0)),
        MaterialA(reflection: 0.5, baseColor: NewVec3f(0, 0, 1)),
    ]),
    materialTextures: [
      Texture[TVec3[uint8]](width: 1, height: 1, data: @[TVec3[uint8]([0'u8, 0'u8, 0'u8])]),
      Texture[TVec3[uint8]](width: 1, height: 1, data: @[TVec3[uint8]([0'u8, 0'u8, 0'u8])]),
      Texture[TVec3[uint8]](width: 1, height: 1, data: @[TVec3[uint8]([0'u8, 0'u8, 0'u8])]),
    ]
  )
  )
  var instances1 = InstanceA(
    rotation: GPUArray[Vec4f, VertexBuffer](data: @[NewVec4f(1, 0, 0, 0.1), NewVec4f(0, 1, 0, 0.1)]),
    objPosition: GPUArray[Vec3f, VertexBuffer](data: @[NewVec3f(0, 0, 0), NewVec3f(1, 1, 1)]),
  )
  var myGlobals = DescriptorSet[GlobalsA, GlobalSet](
    data: GlobalsA(
      fontAtlas: Texture[TVec3[uint8]](width: 1, height: 1, data: @[TVec3[uint8]([0'u8, 0'u8, 0'u8])]),
      settings: GPUValue[ShaderSettings, UniformBuffer](data: ShaderSettings(gamma: 1.0))
    )
  )

  # setup for rendering (TODO: swapchain & framebuffers)
  let renderpass = CreateRenderPass(GetSurfaceFormat())

  # shaders
  const shader = ShaderA()
  let shaderObject = CompileShader(shader)
  var pipeline1 = CreatePipeline(renderPass = renderpass, shader = shaderObject)

  var renderdata = InitRenderData()

  # buffer assignment
  echo "Assigning buffers to GPUData fields"

  AssignBuffers(renderdata, myMesh1)
  AssignBuffers(renderdata, instances1)
  AssignBuffers(renderdata, myGlobals)
  AssignBuffers(renderdata, uniforms1)

  renderdata.UploadTextures(myGlobals)
  renderdata.UploadTextures(uniforms1)

  # copy everything to GPU
  echo "Copying all data to GPU memory"
  UpdateAllGPUBuffers(myMesh1)
  UpdateAllGPUBuffers(instances1)
  UpdateAllGPUBuffers(uniforms1)
  UpdateAllGPUBuffers(myGlobals)
  renderdata.FlushAllMemory()


  # descriptors
  echo "Writing descriptors"
  InitDescriptorSet(renderdata, pipeline1.descriptorSetLayouts[GlobalSet], myGlobals)
  InitDescriptorSet(renderdata, pipeline1.descriptorSetLayouts[MaterialSet], uniforms1)


  # command buffer
  var
    commandBufferPool: VkCommandPool
    createInfo = VkCommandPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
      queueFamilyIndex: vulkan.queueFamilyIndex,
    )
  checkVkResult vkCreateCommandPool(vulkan.device, addr createInfo, nil, addr commandBufferPool)
  var
    cmdBuffers: array[INFLIGHTFRAMES.int, VkCommandBuffer]
    allocInfo = VkCommandBufferAllocateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      commandPool: commandBufferPool,
      level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      commandBufferCount: INFLIGHTFRAMES,
    )
  checkVkResult vkAllocateCommandBuffers(vulkan.device, addr allocInfo, cmdBuffers.ToCPointer)

  # start command buffer
  block:
    let
      currentFramebuffer = VkFramebuffer(0) # TODO
      currentFrameInFlight = 1
      cmd = cmdBuffers[currentFrameInFlight]
      beginInfo = VkCommandBufferBeginInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
      )
    checkVkResult cmd.vkResetCommandBuffer(VkCommandBufferResetFlags(0))
    checkVkResult cmd.vkBeginCommandBuffer(addr(beginInfo))

    # start renderpass
    block:
      var
        clearColors = [VkClearValue(color: VkClearColorValue(float32: [0, 0, 0, 0]))]
        renderPassInfo = VkRenderPassBeginInfo(
          sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
          renderPass: renderpass,
          framebuffer: currentFramebuffer, # TODO
          renderArea: VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: VkExtent2D(width: frameWidth, height: frameHeight),
          ),
          clearValueCount: uint32(clearColors.len),
          pClearValues: clearColors.ToCPointer(),
        )
        viewport = VkViewport(
          x: 0.0,
          y: 0.0,
          width: frameWidth.float32,
          height: frameHeight.float32,
          minDepth: 0.0,
          maxDepth: 1.0,
        )
        scissor = VkRect2D(
          offset: VkOffset2D(x: 0, y: 0),
          extent: VkExtent2D(width: frameWidth, height: frameHeight)
        )
      vkCmdBeginRenderPass(cmd, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

      # setup viewport
      vkCmdSetViewport(cmd, firstViewport = 0, viewportCount = 1, addr(viewport))
      vkCmdSetScissor(cmd, firstScissor = 0, scissorCount = 1, addr(scissor))

      # bind pipeline, will be loop
      block:
        Bind(pipeline1, cmd, currentFrameInFlight = currentFrameInFlight)

        # render object, will be loop
        block:
          Render(cmd, pipeline1, myGlobals, uniforms1, myMesh1, instances1)

      vkCmdEndRenderPass(cmd)
    checkVkResult cmd.vkEndCommandBuffer()
