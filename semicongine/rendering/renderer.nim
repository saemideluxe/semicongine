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

proc IsMappable(memoryTypeIndex: uint32): bool =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(vulkan.physicalDevice, addr(physicalProperties))
  let flags = toEnums(physicalProperties.memoryTypes[memoryTypeIndex].propertyFlags)
  return VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags

proc InitDescriptorSet*(
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
          {.error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldValue)).}
      else:
        {.error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldValue)).}

  vkUpdateDescriptorSets(
    device = vulkan.device,
    descriptorWriteCount = descriptorSetWrites.len.uint32,
    pDescriptorWrites = descriptorSetWrites.ToCPointer,
    descriptorCopyCount = 0,
    pDescriptorCopies = nil,
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

proc FlushAllMemory*(renderData: RenderData) =
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

proc AssignBuffers*[T](renderdata: var RenderData, data: var T) =
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
proc AssignBuffers*(renderdata: var RenderData, descriptorSet: var DescriptorSet) =
  AssignBuffers(renderdata, descriptorSet.data)

proc UpdateGPUBuffer(gpuData: GPUData) =
  if gpuData.size == 0:
    return
  when NeedsMapping(gpuData):
    copyMem(pointerAddOffset(gpuData.buffer.rawPointer, gpuData.offset), gpuData.rawPointer, gpuData.size)
  else:
    WithStagingBuffer((gpuData.buffer.vk, gpuData.offset), gpuData.size, stagingPtr):
      copyMem(stagingPtr, gpuData.rawPointer, gpuData.size)

proc UpdateAllGPUBuffers*[T](value: T) =
  for name, fieldvalue in value.fieldPairs():
    when typeof(fieldvalue) is GPUData:
      UpdateGPUBuffer(fieldvalue)


proc InitRenderData*(descriptorPoolLimit = 1024'u32): RenderData =
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

proc DestroyRenderData*(renderData: RenderData) =
  vkDestroyDescriptorPool(vulkan.device, renderData.descriptorPool, nil)

  for buffers in renderData.buffers:
    for buffer in buffers:
      vkDestroyBuffer(vulkan.device, buffer.vk, nil)

  for imageView in renderData.imageViews:
    vkDestroyImageView(vulkan.device, imageView, nil)

  for sampler in renderData.samplers:
    vkDestroySampler(vulkan.device, sampler, nil)

  for image in renderData.images:
    vkDestroyImage(vulkan.device, image, nil)

  for memoryBlocks in renderData.memory:
    for memory in memoryBlocks:
      vkFreeMemory(vulkan.device, memory.vk, nil)

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
  renderData.images.add texture.vk
  texture.sampler = createSampler()
  renderData.samplers.add texture.sampler

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
  texture.imageview = svkCreate2DImageView(texture.vk, format)
  renderData.imageViews.add texture.imageview

  # data transfer and layout transition
  TransitionImageLayout(texture.vk, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
  WithStagingBuffer(
    (texture.vk, texture.width, texture.height),
    memoryRequirements.size,
    stagingPtr
  ):
    copyMem(stagingPtr, texture.data.ToCPointer, texture.size)
  TransitionImageLayout(texture.vk, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)


proc UploadTextures*(renderdata: var RenderData, descriptorSet: var DescriptorSet) =
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

proc AssertCompatible(TShader, TMesh, TInstance, TGlobals, TMaterial: typedesc) =
  var descriptorSetCount = 0

  for shaderAttributeName, shaderAttribute in default(TShader).fieldPairs:
    var foundField = false

    # Vertex input data
    when hasCustomPragma(shaderAttribute, VertexAttribute):
      assert typeof(shaderAttribute) is SupportedGPUType
      for meshName, meshValue in default(TMesh).fieldPairs:
        when meshName == shaderAttributeName:
          assert meshValue is GPUArray, "Mesh attribute '" & meshName & "' must be of type 'GPUArray' but is of type " & typetraits.name(typeof(meshValue))
          assert foundField == false, "Shader input '" & typetraits.name(TShader) & "." & shaderAttributeName & "' has been found more than once"
          assert elementType(meshValue.data) is typeof(shaderAttribute), "Shader input " & typetraits.name(TShader) & "." & shaderAttributeName & " is of type '" & typetraits.name(typeof(shaderAttribute)) & "' but mesh attribute is of type '" & typetraits.name(elementType(meshValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & typetraits.name(TShader) & "." & shaderAttributeName & ": " & typetraits.name(typeof(shaderAttribute)) & "' not found in '" & typetraits.name(TMesh) & "'"

    # Instance input data
    elif hasCustomPragma(shaderAttribute, InstanceAttribute):
      assert typeof(shaderAttribute) is SupportedGPUType
      for instanceName, instanceValue in default(TInstance).fieldPairs:
        when instanceName == shaderAttributeName:
          assert instanceValue is GPUArray, "Instance attribute '" & instanceName & "' must be of type 'GPUArray' but is of type " & typetraits.name(typeof(instanceName))
          assert foundField == false, "Shader input '" & typetraits.name(TShader) & "." & shaderAttributeName & "' has been found more than once"
          assert elementType(instanceValue.data) is typeof(shaderAttribute), "Shader input " & typetraits.name(TShader) & "." & shaderAttributeName & " is of type '" & typetraits.name(typeof(shaderAttribute)) & "' but instance attribute is of type '" & typetraits.name(elementType(instanceValue.data)) & "'"
          foundField = true
      assert foundField, "Shader input '" & typetraits.name(TShader) & "." & shaderAttributeName & ": " & typetraits.name(typeof(shaderAttribute)) & "' not found in '" & typetraits.name(TInstance) & "'"

    # descriptors
    elif typeof(shaderAttribute) is DescriptorSet:
      assert descriptorSetCount <= DescriptorSetType.high.int, typetraits.name(TShader) & ": maximum " & $DescriptorSetType.high & " allowed"
      descriptorSetCount.inc


      when shaderAttribute.sType == GlobalSet:
        assert shaderAttribute.sType == default(TGlobals).sType, "Shader has global descriptor set of type '" & $shaderAttribute.sType & "' but matching provided type is '" & $default(TGlobals).sType & "'"
        assert typeof(shaderAttribute) is TGlobals, "Shader has global descriptor set type '" & typetraits.name(get(genericParams(typeof(shaderAttribute)), 0)) & "' but provided type is " & typetraits.name(TGlobals)
      elif shaderAttribute.sType == MaterialSet:
        assert shaderAttribute.sType == default(TMaterial).sType, "Shader has material descriptor set of type '" & $shaderAttribute.sType & "' but matching provided type is '" & $default(TMaterial).sType & "'"
        assert typeof(shaderAttribute) is TMaterial, "Shader has materialdescriptor type '" & typetraits.name(get(genericParams(typeof(shaderAttribute)), 0)) & "' but provided type is " & typetraits.name(TMaterial)



template WithBind*[A, B](commandBuffer: VkCommandBuffer, globalDescriptorSet: DescriptorSet[A, GlobalSet], materialDescriptorSet: DescriptorSet[B, MaterialSet], pipeline: Pipeline, currentFiF: int, body: untyped): untyped =
  block:
    let sets = [globalDescriptorSet.vk[currentFiF], materialDescriptorSet.vk[currentFiF]]
    vkCmdBindDescriptorSets(
      commandBuffer = commandBuffer,
      pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
      layout = pipeline.layout,
      firstSet = 0,
      descriptorSetCount = sets.len.uint32,
      pDescriptorSets = sets.ToCPointer,
      dynamicOffsetCount = 0,
      pDynamicOffsets = nil
    )
    body

proc Render*[TShader, TGlobals, TMaterial, TMesh, TInstance](
  commandBuffer: VkCommandBuffer,
  pipeline: Pipeline[TShader],
  globalSet: TGlobals,
  materialSet: TMaterial,
  mesh: TMesh,
  instances: TInstance,
) =
  when not defined(release):
    static: AssertCompatible(TShader, TMesh, TInstance, TGlobals, TMaterial)

  var vertexBuffers: seq[VkBuffer]
  var vertexBuffersOffsets: seq[uint64]
  var elementCount = 0'u32
  var instanceCount = 1'u32

  for shaderAttributeName, shaderAttribute in default(TShader).fieldPairs:
    when hasCustomPragma(shaderAttribute, VertexAttribute):
      for meshName, meshValue in mesh.fieldPairs:
        when meshName == shaderAttributeName:
          vertexBuffers.add meshValue.buffer.vk
          vertexBuffersOffsets.add meshValue.offset
          elementCount = meshValue.data.len.uint32
    elif hasCustomPragma(shaderAttribute, InstanceAttribute):
      for instanceName, instanceValue in instances.fieldPairs:
        when instanceName == shaderAttributeName:
          vertexBuffers.add instanceValue.buffer.vk
          vertexBuffersOffsets.add instanceValue.offset
          instanceCount = instanceValue.data.len.uint32

  if vertexBuffers.len > 0:
    vkCmdBindVertexBuffers(
      commandBuffer = commandBuffer,
      firstBinding = 0'u32,
      bindingCount = uint32(vertexBuffers.len),
      pBuffers = vertexBuffers.ToCPointer(),
      pOffsets = vertexBuffersOffsets.ToCPointer()
    )

  var indexBuffer: VkBuffer
  var indexBufferOffset: uint64
  var indexType = VK_INDEX_TYPE_NONE_KHR

  for meshName, meshValue in mesh.fieldPairs:
    when typeof(meshValue) is GPUArray[uint8, IndexBuffer]:
      indexBuffer = meshValue.buffer.vk
      indexBufferOffset = meshValue.offset
      indexType = VK_INDEX_TYPE_UINT8_EXT
      elementCount = meshValue.data.len.uint32
    elif typeof(meshValue) is GPUArray[uint16, IndexBuffer]:
      indexBuffer = meshValue.buffer.vk
      indexBufferOffset = meshValue.offset
      indexType = VK_INDEX_TYPE_UINT16
      elementCount = meshValue.data.len.uint32
    elif typeof(meshValue) is GPUArray[uint32, IndexBuffer]:
      indexBuffer = meshValue.buffer.vk
      indexBufferOffset = meshValue.offset
      indexType = VK_INDEX_TYPE_UINT32
      elementCount = meshValue.data.len.uint32

  assert elementCount > 0

  if indexType != VK_INDEX_TYPE_NONE_KHR:
    vkCmdBindIndexBuffer(
      commandBuffer,
      indexBuffer,
      indexBufferOffset,
      indexType,
    )
    vkCmdDrawIndexed(
      commandBuffer = commandBuffer,
      indexCount = elementCount,
      instanceCount = instanceCount,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0
    )
  else:
    vkCmdDraw(
      commandBuffer = commandBuffer,
      vertexCount = elementCount,
      instanceCount = instanceCount,
      firstVertex = 0,
      firstInstance = 0
    )

type EMPTY = object

proc Render*[TShader, TGlobals, TMaterial, TMesh](
  commandBuffer: VkCommandBuffer,
  pipeline: Pipeline[TShader],
  globalSet: TGlobals,
  materialSet: TMaterial,
  mesh: TMesh,
) =
  Render(commandBuffer, pipeline, globalSet, materialSet, mesh, EMPTY())
