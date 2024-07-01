import std/os
import std/enumerate
import std/hashes
import std/macros
import std/strformat
import std/strutils
import std/sequtils
import std/typetraits as tt

import semicongine/core/utils
import semicongine/core/imagetypes
import semicongine/core/vector
import semicongine/core/matrix
import semicongine/core/vulkanapi
import semicongine/vulkan/buffer

template VertexAttribute* {.pragma.}
template InstanceAttribute* {.pragma.}
template Pass* {.pragma.}
template PassFlat* {.pragma.}
template ShaderOutput* {.pragma.}
template VertexIndices*{.pragma.}

const INFLIGHTFRAMES = 2'u32
const MEMORY_ALIGNMENT = 65536'u64 # Align buffers inside memory along this alignment
const BUFFER_ALIGNMENT = 64'u64 # align offsets inside buffers along this alignment

type
  SupportedGPUType* = float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] | TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] | TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] | TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] | TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] | TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[float32] | TMat43[float64] | TMat4[float32] | TMat4[float64]
  ShaderObject*[TShader] = object
    vertexShader: VkShaderModule
    fragmentShader: VkShaderModule

func alignedTo[T: SomeInteger](value: T, alignment: T) =
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

template ForVertexDataFields*(inputData: typed, fieldname, valuename, isinstancename, body: untyped): untyped =
  for theFieldname, value in fieldPairs(inputData):
    when hasCustomPragma(value, VertexAttribute) or hasCustomPragma(value, InstanceAttribute):
      when not typeof(value) is seq:
        {.error: "field '" & theFieldname & "' needs to be a seq".}
      when not typeof(value) is SupportedGPUType:
        {.error: "field '" & theFieldname & "' is not a supported GPU type".}
      block:
        let `fieldname` {.inject.} = theFieldname
        let `valuename` {.inject.} = value
        let `isinstancename` {.inject.} = hasCustomPragma(value, InstanceAttribute)
        body

template ForDescriptorFields*(inputData: typed, fieldname, typename, countname, bindingNumber, body: untyped): untyped =
  var `bindingNumber` {.inject.} = 1'u32
  for theFieldname, value in fieldPairs(inputData):
    let `fieldname` {.inject.} = theFieldname
    when typeof(value) is Texture:
      block:
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        let `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(value) is object:
      block:
        let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        let `countname` {.inject.} = 1'u32
        body
        `bindingNumber`.inc
    elif typeof(value) is array:
      when elementType(value) is Texture:
        block:
          let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
          let `countname` {.inject.} = uint32(typeof(value).len)
          body
          `bindingNumber`.inc
      elif elementType(value) is object:
        block:
          let `typename` {.inject.} = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
          let `countname` {.inject.} = uint32(typeof(value).len)
          body
          `bindingNumber`.inc

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

type
  IndexType = enum
    None, UInt8, UInt16, UInt32

  IndirectGPUMemory = object
    vk: VkDeviceMemory
    size: uint64
    needsTransfer: bool # usually true
  DirectGPUMemory = object
    vk: VkDeviceMemory
    size: uint64
    data: pointer
    needsFlush: bool # usually true
  GPUMemory = IndirectGPUMemory | DirectGPUMemory

  Buffer[TMemory: GPUMemory] = object
    memory: TMemory
    vk: VkBuffer
    offset: uint64
    size: uint64

  GPUArray[T: SupportedGPUType, TMemory: GPUMemory] = object
    data: seq[T]
    buffer: Buffer[TMemory]
    offset: uint64
  GPUValue[T: object|array, TMemory: GPUMemory] = object
    data: T
    buffer: Buffer[TMemory]
    offset: uint64
  GPUData = GPUArray | GPUValue

  Pipeline[TShader] = object
    pipeline: VkPipeline
    layout: VkPipelineLayout
    descriptorSetLayout: VkDescriptorSetLayout
  BufferType = enum
    VertexBuffer, IndexBuffer, UniformBuffer
  RenderData = object
    descriptorPool: VkDescriptorPool
    # tuple is memory and offset to next free allocation in that memory
    indirectMemory: seq[tuple[memory: IndirectGPUMemory, nextFree: uint64]]
    directMemory: seq[tuple[memory: DirectGPUMemory, nextFree: uint64]]
    indirectBuffers: seq[tuple[buffer: Buffer[IndirectGPUMemory], btype: BufferType, nextFree: uint64]]
    directBuffers: seq[tuple[buffer: Buffer[DirectGPUMemory], btype: BufferType, nextFree: uint64]]

template UsesIndirectMemory(gpuData: GPUData): untyped =
  get(genericParams(typeof(gpuData)), 1) is IndirectGPUMemory
template UsesDirectMemory(gpuData: GPUData): untyped =
  get(genericParams(typeof(gpuData)), 1) is DirectGPUMemory

template size(gpuArray: GPUArray): uint64 =
  result += (gpuArray.data.len * sizeof(elementType(gpuArray.data))).uint64
template size(gpuValue: GPUValue): uint64 =
  result += sizeof(gpuValue.data).uint64

proc GetPhysicalDevice(): VkPhysicalDevice =
  var nDevices: uint32
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult vkEnumeratePhysicalDevices(instance.vk, addr(nDevices), devices.ToCPointer)

  var score = 0
  for pDevice in devices:
    var props: VkPhysicalDeviceProperties
    vkGetPhysicalDeviceProperties(pDevice, addr(props))
    if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and props.maxImageDimension2D > score:
      score = props.maxImageDimension2D
      result = pDevice

  if score == 0
    for pDevice in devices:
      var props: VkPhysicalDeviceProperties
      vkGetPhysicalDeviceProperties(pDevice, addr(props))
      if props.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU and props.maxImageDimension2D > score:
        score = props.maxImageDimension2D
        result = pDevice

  assert score > 0, "Unable to find integrated or discrete GPU"


proc GetDirectMemoryTypeIndex()
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  checkVkResult vkGetPhysicalDeviceMemoryProperties(GetPhysicalDevice(), addr physicalProperties)

  var biggestHeap: uint64 = 0
  result = high(uint32)
  # try to find host-visible type
  for i in 0 ..< physicalProperties.memoryTypeCount:
    let flags = toEnums(physicalProperties.memoryTypes[i].propertyFlags)
    if VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags:
      let size = physicalProperties.memoryHeaps[physicalProperties.memoryTypes[i].heapIndex].size
      if size > biggestHeap:
        biggestHeap = size
        result = i
  assert result != high(uint32), "There is not host visible memory. This is likely a driver bug."

proc GetQueueFamily(device: VkDevice, qType = VK_QUEUE_GRAPHICS_BIT): VkQueue =
  assert device.vk.Valid
  var nQueuefamilies: uint32
  checkVkResult vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, nil)
  var queuFamilies = newSeq[VkQueueFamilyProperties](nQueuefamilies)
  checkVkResult vkGetPhysicalDeviceQueueFamilyProperties(device.vk, addr nQueuefamilies, queuFamilies.ToCPointer)
  for i in 0 ..< nQueuefamilies:
    if qType in toEnums(queuFamilies[i].queueFlags):
      return i
  assert false, &"Queue of type {qType} not found"

proc GetQueue(device: VkDevice, qType = VK_QUEUE_GRAPHICS_BIT): VkQueue =
  checkVkResult vkGetDeviceQueue(
    device,
    GetQueueFamily(device, qType),
    0,
    addr(result),
  )

#[
TODO: Finish this, allow fore easy access to main format 
proc GetSurfaceFormat*(device: PhysicalDevice): VkFormat =
  var n_formats: uint32
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, device.surface, addr(n_formats), nil)
  result = newSeq[VkSurfaceFormatKHR](n_formats)
  checkVkResult vkGetPhysicalDeviceSurfaceFormatsKHR(device.vk, device.surface, addr(n_formats), result.ToCPointer)
]#

template WithSingleUseCommandBuffer*(device: VkDevice, cmd, body: untyped): untyped =
  # TODO? This is super slow, because we call vkQueueWaitIdle
  block:
    var commandBufferPool: VkCommandPool
        createInfo = VkCommandPoolCreateInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
        queueFamilyIndex: GetQueueFamily(device),
      )
    checkVkResult vkCreateCommandPool(device, addr createInfo, nil, addr(commandBufferPool))
    var
      `cmd` {.inject.}: VkCommandBuffer
      allocInfo = VkCommandBufferAllocateInfo(
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool: commandBufferPool,
        level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount: 1,
      )
    checkVkResult device.vk.vkAllocateCommandBuffers(addr allocInfo, addr(`cmd`))
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      flags: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT),
    )
    checkVkResult `cmd`.vkBeginCommandBuffer(addr beginInfo)

    body

    checkVkResult `cmd`.vkEndCommandBuffer()
    var submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      commandBufferCount: 1,
      pCommandBuffers: addr(`cmd`),
    )
    checkVkResult vkQueueSubmit(GetQueue(), 1, addr submitInfo, VkFence(0))
    checkVkResult vkQueueWaitIdle(GetQueue()) # because we want to destroy the commandbuffer pool
    vkDestroyCommandPool(device, commandBufferPool, nil)


proc UpdateGPUBuffer*(device: VkDevice, gpuData: GPUArray) =
  when UsesDirectMemory(gpuData):
    copyMem(cast[pointer](cast[uint64](gpuData.buffer.memory.data) + gpuData.buffer.offset + gpuData.offset), addr(gpuData.data[0]), gpuData.size)
  else:
    var
      stagingBuffer: VkBuffer
      createInfo = VkBufferCreateInfo(
        sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        flags: VkBufferCreateFlags(0),
        size: gpuData.size,
        usage: toBits([VK_BUFFER_USAGE_TRANSFER_SRC_BIT]),
        sharingMode: VK_SHARING_MODE_EXCLUSIVE,
      )
    checkVkResult vkCreateBuffer(
      device = device,
      pCreateInfo = addr(createInfo),
      pAllocator = nil,
      pBuffer = addr(stagingBuffer),
    )
    var
      stagingMemory: VkDeviceMemory
      stagingPtr: pointer
      memoryAllocationInfo = VkMemoryAllocateInfo(
        sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        allocationSize: gpuData.size,
        memoryTypeIndex: GetDirectMemoryTypeIndex(),
      )
    checkVkResult vkAllocateMemory(
      device,
      addr(memoryAllocationInfo),
      nil,
      addr(stagingMemory),
    )
    checkVkResult vkBindBufferMemory(device, stagingBuffer, stagingMemory, 0)
    checkVkResult vkMapMemory(
      device = device,
      memory = stagingMemory,
      offset = 0'u64,
      size = VK_WHOLE_SIZE,
      flags = VkMemoryMapFlags(0),
      ppData = stagingPtr
    )
    copyMem(stagingPtr, addr(gpuData.data[0]), gpuData.size)
    var stagingRange = VkMappedMemoryRange(
      sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
      memory: stagingMemory,
      size: VK_WHOLE_SIZE,
    )
    checkVkResult vkFlushMappedMemoryRanges(device, 1, addr(stagingRange))

    WithSingleUseCommandBuffer(device, commandBuffer):
      var copyRegion = VkBufferCopy(size: gpuData.size)
      vkCmdCopyBuffer(commandBuffer, stagingBuffer, gpuData.buffer.vk, 1, addr(copyRegion))

    checkVkResult vkDestroyBuffer(device, stagingBuffer, nil)
    checkVkResult vkFreeMemory(device, stagingMemory, nil)

converter toVkIndexType(indexType: IndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of UInt8: VK_INDEX_TYPE_UINT8_EXT
    of UInt16: VK_INDEX_TYPE_UINT16
    of UInt32: VK_INDEX_TYPE_UINT32

proc CreateRenderPass*(
  device: VkDevice,
  format: VkFormat,
): VkRenderPass =

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
  checkVkResult device.vkCreateRenderPass(addr(createInfo), nil, addr(result))

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
  var descriptorBinding = 0

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
    elif hasCustomPragma(value, ShaderOutput):
      fsOutput.add &"layout(location = " & $fsOutputLocation & ") out " & GlslType(value) & " " & fieldname & ";"
      fsOutputLocation.inc
    elif typeof(value) is Texture:
      samplers.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(value) & " " & fieldname & ";"
      descriptorBinding.inc
    elif typeof(value) is object:
      # TODO
      uniforms.add ""
      descriptorBinding.inc
    elif typeof(value) is array:
      when elementType(value) is Texture:
        let arrayDecl = "[" & $typeof(value).len & "]"
        samplers.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(default(elementType(value))) & " " & fieldname & "" & arrayDecl & ";"
        descriptorBinding.inc
      elif elementType(value) is object:
        # TODO
        let arrayDecl = "[" & $typeof(value).len & "]"
        # uniforms.add "layout(binding = " & $descriptorBinding & ") uniform " & GlslType(elementType(value)) & " " & fieldname & "" & arrayDecl & ";"
        descriptorBinding.inc
      else:
        {.error: "Unsupported shader field " & fieldname.}
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

proc CompileShader[TShader](device: VkDevice, shader: static TShader): ShaderObject[TShader] =
  const (vertexShaderSource, fragmentShaderSource) = generateShaderSource(shader)

  let vertexBinary = compileGlslToSPIRV(VK_SHADER_STAGE_VERTEX_BIT, vertexShaderSource)
  let fragmentBinary = compileGlslToSPIRV(VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShaderSource)

  var createInfoVertex = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(vertexBinary.len * sizeof(uint32)),
    pCode: vertexBinary.ToCPointer,
  )
  checkVkResult device.vkCreateShaderModule(addr(createInfoVertex), nil, addr(result.vertexShader))
  var createInfoFragment = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: csize_t(fragmentBinary.len * sizeof(uint32)),
    pCode: fragmentBinary.ToCPointer,
  )
  checkVkResult device.vkCreateShaderModule(addr(createInfoFragment), nil, addr(result.fragmentShader))


proc CreatePipeline*[TShader](
  device: VkDevice,
  renderPass: VkRenderPass,
  shader: ShaderObject[TShader],
  topology: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
  polygonMode: VkPolygonMode = VK_POLYGON_MODE_FILL,
  cullMode: VkCullModeFlagBits = VK_CULL_MODE_BACK_BIT,
  frontFace: VkFrontFace = VK_FRONT_FACE_CLOCKWISE,
  descriptorPoolLimit = 1024
): Pipeline[TShader] =
  # create pipeline
  var layoutbindings: seq[VkDescriptorSetLayoutBinding]
  ForDescriptorFields(default(TShader), fieldName, descriptorType, descriptorCount, descriptorBindingNumber):
    layoutbindings.add VkDescriptorSetLayoutBinding(
      binding: descriptorBindingNumber,
      descriptorType: descriptorType,
      descriptorCount: descriptorCount,
      stageFlags: VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
      pImmutableSamplers: nil,
    )
  var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount: uint32(layoutbindings.len),
    pBindings: layoutbindings.ToCPointer
  )
  checkVkResult vkCreateDescriptorSetLayout(device, addr(layoutCreateInfo), nil, addr(result.descriptorSetLayout))
  let pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount: 1,
    pSetLayouts: addr(result.descriptorSetLayout),
    # pushConstantRangeCount: uint32(pushConstants.len),
      # pPushConstantRanges: pushConstants.ToCPointer,
  )
  checkVkResult vkCreatePipelineLayout(device, addr(pipelineLayoutInfo), nil, addr(result.layout))

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
    device,
    VkPipelineCache(0),
    1,
    addr(createInfo),
    nil,
    addr(result.pipeline)
  )

proc AllocateIndirectMemory(device: VkDevice, pDevice: VkPhysicalDevice, size: uint64): IndirectGPUMemory =
  # chooses biggest memory type that has NOT VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
  result.size = size
  result.needsTransfer = true

  # find a good memory type
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  checkVkResult vkGetPhysicalDeviceMemoryProperties(pDevice, addr physicalProperties)

  var biggestHeap: uint64 = 0
  var memoryTypeIndex = high(uint32)
  # try to find non-host-visible type
  for i in 0'u32 ..< physicalProperties.memoryTypeCount:
    if not (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in toEnums(physicalProperties.memoryTypes[i].propertyFlags)):
      let size = physicalProperties.memoryHeaps[physicalProperties.memoryTypes[i].heapIndex].size
      if size > biggestHeap:
        biggestHeap = size
        memoryTypeIndex = i

  # If we did not found a device-only memory type, let's just take the biggest overall
  if memoryTypeIndex == high(uint32):
    result.needsTransfer = false
    for i in 0'u32 ..< physicalProperties.memoryTypeCount:
      let size = physicalProperties.memoryHeaps[physicalProperties.memoryTypes[i].heapIndex].size
      if size > biggestHeap:
        biggestHeap = size
        memoryTypeIndex = i

  assert memoryTypeIndex != high(uint32), "Unable to find indirect memory type"
  var allocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: result.size,
    memoryTypeIndex: memoryTypeIndex,
  )
  checkVkResult vkAllocateMemory(
    device,
    addr allocationInfo,
    nil,
    addr result.vk
  )

proc AllocateDirectMemory(device: VkDevice, pDevice: VkPhysicalDevice, size: uint64): DirectGPUMemory =
  result.size = size
  result.needsFlush = true

  # find a good memory type
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  checkVkResult vkGetPhysicalDeviceMemoryProperties(pDevice, addr physicalProperties)

  var biggestHeap: uint64 = 0
  var memoryTypeIndex = high(uint32)
  # try to find host-visible type
  for i in 0 ..< physicalProperties.memoryTypeCount:
    let flags = toEnums(physicalProperties.memoryTypes[i].propertyFlags)
    if VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags:
      let size = physicalProperties.memoryHeaps[physicalProperties.memoryTypes[i].heapIndex].size
      if size > biggestHeap:
        biggestHeap = size
        memoryTypeIndex = i
        result.needsFlush = not (VK_MEMORY_PROPERTY_HOST_COHERENT_BIT in flags)

  assert memoryTypeIndex != high(uint32), "Unable to find indirect memory type"
  var allocationInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: result.size,
    memoryTypeIndex: FindDirectMemoryTypeIndex(pDevice),
  )
  checkVkResult vkAllocateMemory(
    device,
    addr allocationInfo,
    nil,
    addr result.vk
  )
  checkVkResult vkMapMemory(
    device = device,
    memory = result.vk,
    offset = 0'u64,
    size = result.size,
    flags = VkMemoryMapFlags(0),
    ppData = addr(result.data)
  )

proc AllocateIndirectBuffer(device: VkDevice, renderData: var RenderData, size: uint64, btype: BufferType) =
  assert size > 0, "Buffer sizes must be larger than 0"
  var buffer = Buffer[IndirectGPUMemory](size: size)

  let usageFlags = case btype:
    of VertexBuffer: [VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of IndexBuffer: [VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of UniformBuffer: [VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]

  # iterate through memory areas to find big enough free space
  for (memory, offset) in renderData.indirectMemory.mitems:
    if memory.size - offset >= size:
      buffer.offset = offset
      # create buffer
      var createInfo = VkBufferCreateInfo(
        sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        flags: VkBufferCreateFlags(0),
        size: buffer.size,
        usage: toBits(usageFlags),
        sharingMode: VK_SHARING_MODE_EXCLUSIVE,
      )
      checkVkResult vkCreateBuffer(
        device = device,
        pCreateInfo = addr createInfo,
        pAllocator = nil,
        pBuffer = addr(buffer.vk)
      )
      checkVkResult vkBindBufferMemory(device, buffer.vk, memory.vk, buffer.offset)
      renderData.indirectBuffers.add (buffer, btype, 0'u64)
      # update memory area offset
      offset = alignedTo(offset + size, MEMORY_ALIGNMENT)
      return

  assert false, "Did not find allocated memory region with enough space"

proc AllocateDirectBuffer(device: VkDevice, renderData: var RenderData, size: uint64, btype: BufferType) =
  assert size > 0, "Buffer sizes must be larger than 0"
  var buffer = Buffer[DirectGPUMemory](size: size)

  let usageFlags = case btype:
    of VertexBuffer: [VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of IndexBuffer: [VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
    of UniformBuffer: [VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]

  # iterate through memory areas to find big enough free space
  for (memory, offset) in renderData.directMemory.mitems:
    if memory.size - offset >= size:
      buffer.offset = offset
      # create buffer
      var createInfo = VkBufferCreateInfo(
        sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        flags: VkBufferCreateFlags(0),
        size: buffer.size,
        usage: toBits(usageFlags),
        sharingMode: VK_SHARING_MODE_EXCLUSIVE,
      )
      checkVkResult vkCreateBuffer(
        device = device,
        pCreateInfo = addr createInfo,
        pAllocator = nil,
        pBuffer = addr(buffer.vk)
      )
      checkVkResult vkBindBufferMemory(device, buffer.vk, memory.vk, buffer.offset)
      renderData.directBuffers.add (buffer, btype, 0'u64)
      # update memory area offset
      offset = alignedTo(offset + size, MEMORY_ALIGNMENT)
      return

  assert false, "Did not find allocated memory region with enough space"

proc InitRenderData(device: VkDevice, pDevice: VkPhysicalDevice, descriptorPoolLimit = 1024'u32): RenderData =
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
  checkVkResult vkCreateDescriptorPool(device, addr(poolInfo), nil, addr(result.descriptorPool))

  # allocate some memory
  var initialAllocationSize = 1_000_000_000'u64 # TODO: make this more dynamic or something
  result.indirectMemory = @[(AllocateIndirectMemory(device, pDevice, size = initialAllocationSize), 0'u64)]
  result.directMemory = @[(AllocateDirectMemory(device, pDevice, size = initialAllocationSize), 0'u64)]

# For the Get*BufferSize:
# BUFFER_ALIGNMENT is just added for a rough estimate, to ensure we have enough space to align when binding
proc GetIndirectBufferSizes[T](data: T): uint64 =
  for name, value in fieldPairs(data):
    when not hasCustomPragma(value, VertexIndices):
      when typeof(value) is GPUData:
        when UsesIndirectMemory(value):
          result += value.size + BUFFER_ALIGNMENT
proc GetDirectBufferSizes[T](data: T): uint64 =
  for name, value in fieldPairs(data):
    when not hasCustomPragma(value, VertexIndices):
      when typeof(value) is GPUData:
        when UsesDirectMemory(value):
          result += value.size + BUFFER_ALIGNMENT
proc GetIndirectIndexBufferSizes[T](data: T): uint64 =
  for name, value in fieldPairs(data):
    when hasCustomPragma(value, VertexIndices):
      static: assert typeof(value) is GPUArray, "Index buffers must be of type GPUArray"
      static: assert elementType(value.data) is uint8 or elementType(value.data) is uint16 or elementType(value.data) is uint32
      when UsesIndirectMemory(value):
        result += value.size + BUFFER_ALIGNMENT
proc GetDirectIndexBufferSizes[T](data: T): uint64 =
  for name, value in fieldPairs(data):
    when hasCustomPragma(value, VertexIndices):
      static: assert typeof(value) is GPUArray, "Index buffers must be of type GPUArray"
      static: assert elementType(value.data) is uint8 or elementType(value.data) is uint16 or elementType(value.data) is uint32
      when UsesDirectMemory(value):
        result += value.size + BUFFER_ALIGNMENT

proc AssignIndirectBuffers[T](data: T, renderdata: var RenderData, btype: BufferType) =
  for name, value in fieldPairs(data):
    when typeof(value) is GPUData:
      when UsesIndirectMemory(value):
        # find next buffer of correct type with enough free space
        var foundBuffer = false
        for (buffer, bt, offset) in renderData.indirectBuffers.mitems:
          if bt == btype and buffer.size - offset >= size:
            assert not value.buffer.vk.Valid, "GPUData-Buffer has already been assigned"
            assert buffer.vk.Valid, "RenderData-Buffer has not yet been created"
            value.buffer = buffer
            value.offset = offset
            offset = alignedTo(offset + value.size, BUFFER_ALIGNMENT)
            foundBuffer = true
            break
        assert foundBuffer, &"Unable to find large enough '{btype}' for '{data}'"
proc AssignDirectBuffers[T](data: T, renderdata: var RenderData, btype: BufferType) =
  for name, value in fieldPairs(data):
    when typeof(value) is GPUData:
      when UsesDirectMemory(value):
        # find next buffer of correct type with enough free space
        var foundBuffer = false
        for (buffer, bt, offset) in renderData.directBuffers.mitems:
          if bt == btype and buffer.size - offset >= size:
            assert not value.buffer.vk.Valid, "GPUData-Buffer has already been assigned"
            assert buffer.vk.Valid, "RenderData-Buffer has not yet been created"
            value.buffer = buffer
            value.offset = offset
            offset = alignedTo(offset + value.size, BUFFER_ALIGNMENT)
            foundBuffer = true
            break
        assert foundBuffer, &"Unable to find large enough '{btype}' for '{data}'"

proc WriteDescriptors[TShader](device: VkDevice, descriptorSets: array[INFLIGHTFRAMES.int, VkDescriptorSet]) =
  var descriptorSetWrites: seq[VkWriteDescriptorSet]
  # map (buffer + offset + range) to descriptor
  # map (texture) to descriptor
  ForDescriptorFields(default(TShader), fieldName, descriptorType, descriptorCount, descriptorBindingNumber):
    for frameInFlight in 0 ..< descriptorSets.len:
      when descriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:
        # TODO
        let bufferInfo = VkDescriptorBufferInfo(
          buffer: VkBuffer(0),
          offset: 0,
          range: 1,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSets[frameInFlight],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: uint32(0),
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: nil,
          pBufferInfo: addr(bufferInfo),
        )
      elif descriptorType == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
        # TODO
        let imageInfo = VkDescriptorImageInfo(
          sampler: VkSampler(0),
          imageView: VkImageView(0),
          imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        )
        descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSets[frameInFlight],
          dstBinding: descriptorBindingNumber,
          dstArrayElement: uint32(0),
          descriptorType: descriptorType,
          descriptorCount: descriptorCount,
          pImageInfo: addr(imageInfo),
          pBufferInfo: nil,
        )
  checkVkResult vkUpdateDescriptorSets(device, uint32(descriptorSetWrites.len), descriptorSetWrites.ToCPointer, 0, nil)

proc Bind[T](pipeline: Pipeline[T], commandBuffer: VkCommandBuffer, currentFrameInFlight: int) =
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)
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

proc AssertCompatible(TShader, TMesh, TInstance, TUniforms, TGlobals: typedesc) =
  # assert seq-fields of TMesh|TInstance == seq-fields of TShader
  # assert normal fields of TMesh|Globals == normal fields of TShaderDescriptors
  for inputName, inputValue in default(TShader).fieldPairs:
    var foundField = false

    # Vertex input data
    when hasCustomPragma(inputValue, VertexAttribute):
      assert typeof(inputValue) is SupportedGPUType
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == inputName:
          assert meshValue is GPUArray, "Mesh attribute '" & meshName & "' must be of type 'GPUArray' but is of type " & tt.name(typeof(meshValue))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert elementType(meshValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but mesh attribute is of type '" & tt.name(elementType(meshValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "'"

    # Instance input data
    elif hasCustomPragma(inputValue, InstanceAttribute):
      assert typeof(inputValue) is SupportedGPUType
      for instanceName, instanceValue in default(TInstance).fieldPairs:
        when instanceName == inputName:
          assert instanceValue is GPUArray, "Instance attribute '" & instanceName & "' must be of type 'GPUArray' but is of type " & tt.name(typeof(instanceName))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert elementType(instanceValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but instance attribute is of type '" & tt.name(elementType(instanceValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TInstance) & "'"

    # Texture
    elif typeof(inputValue) is Texture:
      for uniformName, uniformValue in default(TUniforms).fieldPairs:
        when uniformName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(uniformValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but uniform attribute is of type '" & tt.name(typeof(uniformValue)) & "'"
          foundField = true
      for globalName, globalValue in default(TGlobals).fieldPairs:
        when globalName == inputName:
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(globalValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"

    # Uniform block
    elif typeof(inputValue) is object:
      for uniformName, uniformValue in default(TUniforms).fieldPairs:
        when uniformName == inputName:
          assert uniformValue is GPUValue, "global attribute '" & uniformName & "' must be of type 'GPUValue' but is of type " & tt.name(typeof(uniformValue))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(uniformValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but uniform attribute is of type '" & tt.name(typeof(uniformValue.data)) & "'"
          foundField = true
      for globalName, globalValue in default(TGlobals).fieldPairs:
        when globalName == inputName:
          assert globalValue is GPUValue, "global attribute '" & globalName & "' must be of type 'GPUValue' but is of type " & tt.name(typeof(globalValue))
          assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
          assert typeof(globalValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"

    # array
    elif typeof(inputValue) is array:

      # texture-array
      when elementType(inputValue) is Texture:
        for uniformName, uniformValue in default(TUniforms).fieldPairs:
          when uniformName == inputName:
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(uniformValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but uniform attribute is of type '" & tt.name(typeof(uniformValue)) & "'"
            foundField = true
        for globalName, globalValue in default(TGlobals).fieldPairs:
          when globalName == inputName:
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(globalValue) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue)) & "'"
            foundField = true
        assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"

      # uniform-block array
      elif elementType(inputValue) is object:
        for uniformName, uniformValue in default(TUniforms).fieldPairs:
          when uniformName == inputName:
            assert uniformValue is GPUValue, "global attribute '" & uniformName & "' must be of type 'GPUValue' but is of type " & tt.name(typeof(uniformValue))
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(uniformValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but uniform attribute is of type '" & tt.name(typeof(uniformValue.data)) & "'"
            foundField = true
        for globalName, globalValue in default(TGlobals).fieldPairs:
          when globalName == inputName:
            assert globalValue is GPUValue, "global attribute '" & globalName & "' must be of type 'GPUValue' but is of type " & tt.name(typeof(globalValue))
            assert foundField == false, "Shader input '" & tt.name(TShader) & "." & inputName & "' has been found more than once"
            assert typeof(globalValue.data) is typeof(inputValue), "Shader input " & tt.name(TShader) & "." & inputName & " is of type '" & tt.name(typeof(inputValue)) & "' but global attribute is of type '" & tt.name(typeof(globalValue.data)) & "'"
            foundField = true
        assert foundField, "Shader input '" & tt.name(TShader) & "." & inputName & ": " & tt.name(typeof(inputValue)) & "' not found in '" & tt.name(TMesh) & "|" & tt.name(TGlobals) & "'"


proc Render[TShader, TUniforms, TGlobals, TMesh, TInstance](
  commandBuffer: VkCommandBuffer,
  pipeline: Pipeline[TShader],
  uniforms: TUniforms,
  globals: TGlobals,
  mesh: TMesh,
  instances: TInstance,
) =
  static: AssertCompatible(TShader, TMesh, TInstance, TUniforms, TGlobals)
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
      position: GPUArray[Vec3f, IndirectGPUMemory]
      indices {.VertexIndices.}: GPUArray[uint16, IndirectGPUMemory]
    InstanceA = object
      rotation: GPUArray[Vec4f, IndirectGPUMemory]
      objPosition: GPUArray[Vec3f, IndirectGPUMemory]
    MaterialA = object
      reflection: float32
      baseColor: Vec3f
    UniformsA = object
      materials: GPUValue[array[3, MaterialA], IndirectGPUMemory]
      materialTextures: array[3, Texture]
    ShaderSettings = object
      brightness: float32
    GlobalsA = object
      fontAtlas: Texture
      settings: GPUValue[ShaderSettings, IndirectGPUMemory]

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
      # uniforms
      materials: array[3, MaterialA]
      settings: ShaderSettings
      # textures
      fontAtlas: Texture
      materialTextures: array[3, Texture]
      # code
      vertexCode: string = "void main() {}"
      fragmentCode: string = "void main() {}"

  let w = CreateWindow("test2")
  putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")
  let vulkan = w.CreateInstance(
    vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
    instanceExtensions = @[],
    layers = @["VK_LAYER_KHRONOS_validation"],
  )

  let dev = vulkan.CreateDevice(
    GetPhysicalDevice(),
    enabledExtensions = @[],
    [GetQueueFamily()],
  )
  let frameWidth = 100'u32
  let frameHeight = 100'u32

  var myMesh1 = MeshA(
    position: GPUArray[Vec3f, IndirectGPUMemory](data: @[NewVec3f(0, 0, ), NewVec3f(0, 0, ), NewVec3f(0, 0, )]),
  )
  var uniforms1 = UniformsA(
    materials: GPUValue[array[3, MaterialA], IndirectGPUMemory](data: [
      MaterialA(reflection: 0, baseColor: NewVec3f(1, 0, 0)),
      MaterialA(reflection: 0.1, baseColor: NewVec3f(0, 1, 0)),
      MaterialA(reflection: 0.5, baseColor: NewVec3f(0, 0, 1)),
    ]),
    materialTextures: [
      Texture(isGrayscale: false, colorImage: Image[RGBAPixel](width: 1, height: 1, imagedata: @[[255'u8, 0'u8, 0'u8, 255'u8]])),
      Texture(isGrayscale: false, colorImage: Image[RGBAPixel](width: 1, height: 1, imagedata: @[[0'u8, 255'u8, 0'u8, 255'u8]])),
      Texture(isGrayscale: false, colorImage: Image[RGBAPixel](width: 1, height: 1, imagedata: @[[0'u8, 0'u8, 255'u8, 255'u8]])),
    ]
  )
  var instances1 = InstanceA(
    rotation: GPUArray[Vec4f, IndirectGPUMemory](data: @[NewVec4f(1, 0, 0, 0.1), NewVec4f(0, 1, 0, 0.1)]),
    objPosition: GPUArray[Vec3f, IndirectGPUMemory](data: @[NewVec3f(0, 0, 0), NewVec3f(1, 1, 1)]),
  )
  var myGlobals: GlobalsA

  # setup for rendering (TODO: swapchain & framebuffers)

  # renderpass
  let renderpass = CreateRenderPass(dev.vk, dev.physicalDevice.GetSurfaceFormats().FilterSurfaceFormat().format)

  # shaders
  const shader = ShaderA()
  let shaderObject = dev.vk.CompileShader(shader)
  var pipeline1 = CreatePipeline(device = dev.vk, renderPass = renderpass, shader = shaderObject)

  var renderdata = InitRenderData(dev.vk, dev.physicalDevice.vk)

  # create descriptor sets
  #[
  var descriptorSets: array[INFLIGHTFRAMES.int, VkDescriptorSet]
  var layouts = newSeqWith(descriptorSets.len, pipeline.descriptorSetLayout)
  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: pool,
    descriptorSetCount: uint32(layouts.len),
    pSetLayouts: layouts.ToCPointer,
  )
  checkVkResult vkAllocateDescriptorSets(device, addr(allocInfo), descriptorSets.ToCPointer)
  ]#

  #[
  # TODO:
  #
  # assign indirect buffers to vertex data, can happen through the GPUArray/GPUValue-wrappers, they know buffers
  # assign direct buffers to vertex data
  # assign indirect buffers to uniform data
  # assign direct buffers to uniform data
  #
  # upload all textures
  # write descriptors for textures and uniform buffers
  #
  ]#

  # buffer allocation
  var
    indirectVertexSizes = 0'u64
    directVertexSizes = 0'u64
    indirectIndexSizes = 0'u64
    directIndexSizes = 0'u64
    indirectUniformSizes = 0'u64
    directUniformSizes = 0'u64

  indirectVertexSizes += GetIndirectBufferSizes(myMesh1)
  indirectVertexSizes += GetIndirectBufferSizes(instances1)
  if indirectVertexSizes > 0:
    AllocateIndirectBuffer(dev.vk, renderdata, indirectVertexSizes, VertexBuffer)

  directVertexSizes += GetDirectBufferSizes(myMesh1)
  directVertexSizes += GetDirectBufferSizes(instances1)
  if directVertexSizes > 0:
    AllocateDirectBuffer(dev.vk, renderdata, directVertexSizes, VertexBuffer)

  indirectIndexSizes += GetIndirectIndexBufferSizes(myMesh1)
  if indirectIndexSizes > 0:
    AllocateIndirectBuffer(dev.vk, renderdata, indirectIndexSizes, IndexBuffer)

  directIndexSizes += GetDirectIndexBufferSizes(myMesh1)
  if directIndexSizes > 0:
    AllocateDirectBuffer(dev.vk, renderdata, directIndexSizes, IndexBuffer)

  indirectUniformSizes += GetIndirectBufferSizes(uniforms1)
  indirectUniformSizes += GetIndirectBufferSizes(myGlobals)
  if indirectUniformSizes > 0:
    AllocateIndirectBuffer(dev.vk, renderdata, indirectUniformSizes, UniformBuffer)

  directUniformSizes += GetDirectBufferSizes(uniforms1)
  directUniformSizes += GetDirectBufferSizes(myGlobals)
  if directUniformSizes > 0:
    AllocateDirectBuffer(dev.vk, renderdata, directUniformSizes, UniformBuffer)

  # buffer assignment

  AssignIndirectBuffers(data = myMesh1, renderdata = RenderData, btype = VertexBuffer)
  AssignDirectBuffers(data = myMesh1, renderdata = RenderData, btype = VertexBuffer)
  AssignIndirectBuffers(data = myMesh1, renderdata = RenderData, btype = IndexBuffer)
  AssignDirectBuffers(data = myMesh1, renderdata = RenderData, btype = IndexBuffer)

  AssignIndirectBuffers(data = instances1, renderdata = RenderData, btype = VertexBuffer)
  AssignDirectBuffers(data = instances1, renderdata = RenderData, btype = VertexBuffer)

  AssignIndirectBuffers(data = uniforms1, renderdata = RenderData, btype = UniformBuffer)
  AssignDirectBuffers(data = uniforms1, renderdata = RenderData, btype = UniformBuffer)
  AssignIndirectBuffers(data = myGlobals, renderdata = RenderData, btype = UniformBuffer)
  AssignDirectBuffers(data = myGlobals, renderdata = RenderData, btype = UniformBuffer)
 
  UpdateGPUBuffer()

  # descriptors
  # WriteDescriptors(dev.vk, pipeline1)

  # command buffer
  var
    commandBufferPool: VkCommandPool
    createInfo = VkCommandPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      flags: toBits [VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT],
      queueFamilyIndex: GetQueueFamily(dev.vk),
    )
  checkVkResult vkCreateCommandPool(dev.vk, addr createInfo, nil, addr commandBufferPool)
  var
    cmdBuffers: array[INFLIGHTFRAMES.int, VkCommandBuffer]
    allocInfo = VkCommandBufferAllocateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      commandPool: commandBufferPool,
      level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      commandBufferCount: INFLIGHTFRAMES,
    )
  checkVkResult vkAllocateCommandBuffers(dev.vk, addr allocInfo, cmdBuffers.ToCPointer)

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
      checkVkResult vkCmdBeginRenderPass(cmd, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

      # setup viewport
      vkCmdSetViewport(cmd, firstViewport = 0, viewportCount = 1, addr(viewport))
      vkCmdSetScissor(cmd, firstScissor = 0, scissorCount = 1, addr(scissor))

      # bind pipeline, will be loop
      block:
        Bind(pipeline1, cmd, currentFrameInFlight = currentFrameInFlight)

        # render object, will be loop
        block:
          Render(cmd, pipeline1, uniforms1, myGlobals, myMesh1, instances1)

      vkCmdEndRenderPass(cmd)
    checkVkResult cmd.vkEndCommandBuffer()
