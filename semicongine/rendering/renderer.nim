func pointerAddOffset[T: SomeInteger](p: pointer, offset: T): pointer =
  cast[pointer](cast[T](p) + offset)

func usage(bType: BufferType): seq[VkBufferUsageFlagBits] =
  case bType
  of VertexBuffer:
    @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
  of VertexBufferMapped:
    @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT]
  of IndexBuffer:
    @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
  of IndexBufferMapped:
    @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT]
  of UniformBuffer:
    @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT]
  of UniformBufferMapped:
    @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT]

proc getVkFormat(grayscale: bool, usage: openArray[VkImageUsageFlagBits]): VkFormat =
  let formats =
    if grayscale:
      [VK_FORMAT_R8_SRGB, VK_FORMAT_R8_UNORM]
    else:
      [VK_FORMAT_B8G8R8A8_SRGB, VK_FORMAT_B8G8R8A8_UNORM]

  var formatProperties =
    VkImageFormatProperties2(sType: VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2)
  for format in formats:
    var formatInfo = VkPhysicalDeviceImageFormatInfo2(
      sType: VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
      format: format,
      thetype: VK_IMAGE_TYPE_2D,
      tiling: VK_IMAGE_TILING_OPTIMAL,
      usage: usage.toBits,
    )
    let formatCheck = vkGetPhysicalDeviceImageFormatProperties2(
      vulkan.physicalDevice, addr formatInfo, addr formatProperties
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

template bufferType(gpuData: GPUData): untyped =
  typeof(gpuData).TBuffer

func needsMapping(bType: BufferType): bool =
  bType in [VertexBufferMapped, IndexBufferMapped, UniformBufferMapped]
template needsMapping(gpuData: GPUData): untyped =
  gpuData.bufferType.needsMapping

template size(gpuArray: GPUArray, count = 0'u64): uint64 =
  (if count == 0: gpuArray.data.len.uint64 else: count).uint64 *
    sizeof(elementType(gpuArray.data)).uint64

template size(gpuValue: GPUValue): uint64 =
  sizeof(gpuValue.data).uint64

func size(image: ImageObject): uint64 =
  image.data.len.uint64 * sizeof(elementType(image.data)).uint64

template rawPointer(gpuArray: GPUArray): pointer =
  addr(gpuArray.data[0])

template rawPointer(gpuValue: GPUValue): pointer =
  addr(gpuValue.data)

proc isMappable(memoryTypeIndex: uint32): bool =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(vulkan.physicalDevice, addr(physicalProperties))
  let flags = toEnums(physicalProperties.memoryTypes[memoryTypeIndex].propertyFlags)
  return VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in flags

proc initDescriptorSet*(
    renderData: RenderData,
    layout: VkDescriptorSetLayout,
    descriptorSet: DescriptorSetData,
) =
  # santization checks
  for theName, value in descriptorSet.data.fieldPairs:
    when typeof(value) is GPUValue:
      assert value.buffer.vk.Valid
    elif typeof(value) is ImageObject:
      assert value.vk.Valid
      assert value.imageview.Valid
      assert value.sampler.Valid
    elif typeof(value) is array:
      when elementType(value) is ImageObject:
        for t in value.litems:
          assert t.vk.Valid
          assert t.imageview.Valid
          assert t.sampler.Valid
      elif elementType(value) is GPUValue:
        for t in value.litems:
          assert t.buffer.vk.Valid
      else:
        {.error: "Unsupported descriptor set field: '" & theName & "'".}
    else:
      {.error: "Unsupported descriptor set field: '" & theName & "'".}

  # allocate
  var layouts = newSeqWith(descriptorSet.vk.len, layout)
  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: renderData.descriptorPool,
    descriptorSetCount: uint32(layouts.len),
    pSetLayouts: layouts.ToCPointer,
  )
  checkVkResult vkAllocateDescriptorSets(
    vulkan.device, addr(allocInfo), descriptorSet.vk.ToCPointer
  )

  # allocate seq with high cap to prevent realocation while adding to set
  # (which invalidates pointers that are passed to the vulkan api call)
  var descriptorSetWrites = newSeqOfCap[VkWriteDescriptorSet](1024)
  var imageWrites = newSeqOfCap[VkDescriptorImageInfo](1024)
  var bufferWrites = newSeqOfCap[VkDescriptorBufferInfo](1024)

  forDescriptorFields(
    descriptorSet.data, fieldValue, descriptorType, descriptorCount,
    descriptorBindingNumber,
  ):
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
      elif typeof(fieldValue) is ImageObject:
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
        when elementType(fieldValue) is ImageObject:
          for image in fieldValue.litems:
            imageWrites.add VkDescriptorImageInfo(
              sampler: image.sampler,
              imageView: image.imageView,
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
        elif elementType(fieldValue) is GPUValue:
          for entry in fieldValue.litems:
            bufferWrites.add VkDescriptorBufferInfo(
              buffer: entry.buffer.vk, offset: entry.offset, range: entry.size
            )
          descriptorSetWrites.add VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            dstSet: descriptorSet.vk[i],
            dstBinding: descriptorBindingNumber,
            dstArrayElement: 0,
            descriptorType: descriptorType,
            descriptorCount: descriptorCount,
            pImageInfo: nil,
            pBufferInfo: addr(bufferWrites[^descriptorCount.int]),
          )
        else:
          {.
            error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldValue))
          .}
      else:
        {.
          error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldValue))
        .}

  vkUpdateDescriptorSets(
    device = vulkan.device,
    descriptorWriteCount = descriptorSetWrites.len.uint32,
    pDescriptorWrites = descriptorSetWrites.ToCPointer,
    descriptorCopyCount = 0,
    pDescriptorCopies = nil,
  )

proc allocateNewMemoryBlock(size: uint64, mType: uint32): MemoryBlock =
  result = MemoryBlock(
    vk: svkAllocateMemory(size, mType), size: size, rawPointer: nil, offsetNextFree: 0
  )
  if mType.isMappable():
    checkVkResult vkMapMemory(
      device = vulkan.device,
      memory = result.vk,
      offset = 0'u64,
      size = result.size,
      flags = VkMemoryMapFlags(0),
      ppData = addr(result.rawPointer),
    )

proc flushBuffer*(buffer: Buffer) =
  var flushRegion = VkMappedMemoryRange(
    sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
    memory: buffer.memory,
    offset: buffer.memoryOffset,
    size: buffer.size,
  )
  checkVkResult vkFlushMappedMemoryRanges(vulkan.device, 1, addr(flushRegion))

proc flushAllMemory*(renderData: RenderData) =
  var flushRegions = newSeq[VkMappedMemoryRange]()
  for memoryBlocks in renderData.memory.litems:
    for memoryBlock in memoryBlocks:
      if memoryBlock.rawPointer != nil and memoryBlock.offsetNextFree > 0:
        flushRegions.add VkMappedMemoryRange(
          sType: VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
          memory: memoryBlock.vk,
          size: alignedTo(
            memoryBlock.offsetNextFree,
            svkGetPhysicalDeviceProperties().limits.nonCoherentAtomSize,
          ),
        )
  if flushRegions.len > 0:
    checkVkResult vkFlushMappedMemoryRanges(
      vulkan.device, flushRegions.len.uint32, flushRegions.ToCPointer()
    )

proc allocateNewBuffer(
    renderData: var RenderData, size: uint64, bufferType: BufferType
): Buffer =
  result = Buffer(
    vk: svkCreateBuffer(size, bufferType.usage),
    size: size,
    rawPointer: nil,
    offsetNextFree: 0,
  )
  let memoryRequirements = svkGetBufferMemoryRequirements(result.vk)
  let memoryType = bestMemory(
    mappable = bufferType.needsMapping, filter = memoryRequirements.memoryTypes
  )

  # check if there is an existing allocated memory block that is large enough to be used
  var selectedBlockI = -1
  for i in 0 ..< renderData.memory[memoryType].len:
    if renderData.memory[memoryType][i].size -
        alignedTo(
          renderData.memory[memoryType][i].offsetNextFree, memoryRequirements.alignment
        ) >= memoryRequirements.size:
      selectedBlockI = i
      break
  # otherwise, allocate a new block of memory and use that
  if selectedBlockI < 0:
    selectedBlockI = renderData.memory[memoryType].len
    renderData.memory[memoryType].add allocateNewMemoryBlock(
      size = max(memoryRequirements.size, MEMORY_BLOCK_ALLOCATION_SIZE),
      mType = memoryType,
    )

  template selectedBlock(): untyped =
    renderData.memory[memoryType][selectedBlockI]

  # let selectedBlock =
  renderData.memory[memoryType][selectedBlockI].offsetNextFree =
    alignedTo(selectedBlock.offsetNextFree, memoryRequirements.alignment)
  checkVkResult vkBindBufferMemory(
    vulkan.device, result.vk, selectedBlock.vk, selectedBlock.offsetNextFree
  )
  result.memory = selectedBlock.vk
  result.memoryOffset = selectedBlock.offsetNextFree
  result.rawPointer =
    selectedBlock.rawPointer.pointerAddOffset(selectedBlock.offsetNextFree)
  renderData.memory[memoryType][selectedBlockI].offsetNextFree += memoryRequirements.size

proc updateGPUBuffer*(gpuData: GPUData, count = 0'u64, flush = false) =
  if gpuData.size() == 0:
    return

  when needsMapping(gpuData):
    when gpuData is GPUArray:
      copyMem(
        pointerAddOffset(gpuData.buffer.rawPointer, gpuData.offset),
        gpuData.rawPointer,
        gpuData.size(count),
      )
    else:
      copyMem(
        pointerAddOffset(gpuData.buffer.rawPointer, gpuData.offset),
        gpuData.rawPointer,
        gpuData.size(),
      )
    if flush:
      flushBuffer(gpuData.buffer)
  else:
    withStagingBuffer((gpuData.buffer.vk, gpuData.offset), gpuData.size, stagingPtr):
      when gpuData is GPUArray:
        copyMem(stagingPtr, gpuData.rawPointer, gpuData.size(count))
      else:
        copyMem(stagingPtr, gpuData.rawPointer, gpuData.size())

proc updateAllGPUBuffers*[T](value: T, flush = false) =
  for name, fieldvalue in value.fieldPairs():
    when typeof(fieldvalue) is GPUData:
      updateGPUBuffer(fieldvalue, flush = flush)
    when typeof(fieldvalue) is array:
      when elementType(fieldvalue) is GPUData:
        for entry in fieldvalue.litems:
          updateGPUBuffer(entry, flush = flush)

proc allocateGPUData(
    renderdata: var RenderData, bufferType: BufferType, size: uint64
): (Buffer, uint64) =
  # find buffer that has space
  var selectedBufferI = -1

  for i in 0 ..< renderData.buffers[bufferType].len:
    let buffer = renderData.buffers[bufferType][i]
    if buffer.size - alignedTo(buffer.offsetNextFree, BUFFER_ALIGNMENT) >= size:
      selectedBufferI = i

  # otherwise create new buffer
  if selectedBufferI < 0:
    selectedBufferI = renderdata.buffers[bufferType].len
    renderdata.buffers[bufferType].add renderdata.allocateNewBuffer(
      size = max(size, BUFFER_ALLOCATION_SIZE), bufferType = bufferType
    )

  # assigne value
  let selectedBuffer = renderdata.buffers[bufferType][selectedBufferI]
  renderdata.buffers[bufferType][selectedBufferI].offsetNextFree =
    alignedTo(selectedBuffer.offsetNextFree, BUFFER_ALIGNMENT)

  result[0] = selectedBuffer
  result[1] = renderdata.buffers[bufferType][selectedBufferI].offsetNextFree
  renderdata.buffers[bufferType][selectedBufferI].offsetNextFree += size

proc assignBuffers*[T](renderdata: var RenderData, data: var T, uploadData = true) =
  for name, value in fieldPairs(data):
    when typeof(value) is GPUData:
      (value.buffer, value.offset) =
        allocateGPUData(renderdata, value.bufferType, value.size)
    elif typeof(value) is DescriptorSetData:
      assignBuffers(renderdata, value.data, uploadData = uploadData)
    elif typeof(value) is array:
      when elementType(value) is GPUValue:
        for v in value.mitems:
          (v.buffer, v.offset) = allocateGPUData(renderdata, v.bufferType, v.size)

  if uploadData:
    updateAllGPUBuffers(data, flush = true)

proc assignBuffers*(
    renderdata: var RenderData, descriptorSet: var DescriptorSetData, uploadData = true
) =
  assignBuffers(renderdata, descriptorSet.data, uploadData = uploadData)

proc initRenderData*(descriptorPoolLimit = 1024'u32): RenderData =
  result = RenderData()
  # allocate descriptor pools
  var poolSizes = [
    VkDescriptorPoolSize(
      thetype: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
      descriptorCount: descriptorPoolLimit,
    ),
    VkDescriptorPoolSize(
      thetype: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, descriptorCount: descriptorPoolLimit
    ),
  ]
  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount: poolSizes.len.uint32,
    pPoolSizes: poolSizes.ToCPointer,
    maxSets: descriptorPoolLimit,
  )
  checkVkResult vkCreateDescriptorPool(
    vulkan.device, addr(poolInfo), nil, addr(result.descriptorPool)
  )

proc destroyRenderData*(renderData: RenderData) =
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

  for memoryBlocks in renderData.memory.litems:
    for memory in memoryBlocks:
      vkFreeMemory(vulkan.device, memory.vk, nil)

proc transitionImageLayout(
    image: VkImage, oldLayout, newLayout: VkImageLayout, nLayers: uint32
) =
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
        layerCount: nLayers,
      ),
    )
    srcStage: VkPipelineStageFlagBits
    dstStage: VkPipelineStageFlagBits

  if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED and
      newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
    barrier.srcAccessMask = VkAccessFlags(0)
    dstStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.dstAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
  elif oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and
      newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
    srcStage = VK_PIPELINE_STAGE_TRANSFER_BIT
    barrier.srcAccessMask = [VK_ACCESS_TRANSFER_WRITE_BIT].toBits
    dstStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
    barrier.dstAccessMask = [VK_ACCESS_SHADER_READ_BIT].toBits
  else:
    raise newException(Exception, "Unsupported layout transition!")

  withSingleUseCommandBuffer(commandBuffer):
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

proc createVulkanImage(renderData: var RenderData, image: var ImageObject) =
  assert image.vk == VkImage(0), "Image has already been created"
  var usage = @[VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_IMAGE_USAGE_SAMPLED_BIT]
  if image.isRenderTarget:
    usage.add VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
  let format = getVkFormat(grayscale = elementType(image.data) is Gray, usage = usage)

  image.vk = svkCreate2DImage(
    image.width, image.height, format, usage, image.samples, image.nLayers
  )
  renderData.images.add image.vk
  image.sampler = createSampler(
    magFilter = image.magInterpolation,
    minFilter = image.minInterpolation,
    addressModeU = image.wrapU,
    addressModeV = image.wrapV,
  )
  renderData.samplers.add image.sampler

  let memoryRequirements = image.vk.svkGetImageMemoryRequirements()
  let memoryType = bestMemory(mappable = false, filter = memoryRequirements.memoryTypes)
  # check if there is an existing allocated memory block that is large enough to be used
  var selectedBlockI = -1
  for i in 0 ..< renderData.memory[memoryType].len:
    if renderData.memory[memoryType][i].size -
        alignedTo(
          renderData.memory[memoryType][i].offsetNextFree, memoryRequirements.alignment
        ) >= memoryRequirements.size:
      selectedBlockI = i
      break
  # otherwise, allocate a new block of memory and use that
  if selectedBlockI < 0:
    selectedBlockI = renderData.memory[memoryType].len
    renderData.memory[memoryType].add allocateNewMemoryBlock(
      size = max(memoryRequirements.size, MEMORY_BLOCK_ALLOCATION_SIZE),
      mType = memoryType,
    )
  template selectedBlock(): untyped =
    renderData.memory[memoryType][selectedBlockI]

  renderData.memory[memoryType][selectedBlockI].offsetNextFree =
    alignedTo(selectedBlock.offsetNextFree, memoryRequirements.alignment)

  checkVkResult vkBindImageMemory(
    vulkan.device,
    image.vk,
    selectedBlock.vk,
    renderData.memory[memoryType][selectedBlockI].offsetNextFree,
  )
  renderData.memory[memoryType][selectedBlockI].offsetNextFree += memoryRequirements.size

  # imageview can only be created after memory is bound
  image.imageview = svkCreate2DImageView(
    image.vk, format, nLayers = image.nLayers, isArray = typeof(image) is ImageArray
  )
  renderData.imageViews.add image.imageview

  # data transfer and layout transition
  transitionImageLayout(
    image.vk, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    image.nLayers,
  )
  if image.data.len > 0:
    withStagingBuffer(
      (image.vk, image.width, image.height, image.nLayers),
      memoryRequirements.size,
      stagingPtr,
    ):
      copyMem(stagingPtr, image.data.ToCPointer, image.size)
  transitionImageLayout(
    image.vk, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, image.nLayers,
  )

proc uploadImages*(renderdata: var RenderData, descriptorSet: var DescriptorSetData) =
  for name, value in fieldPairs(descriptorSet.data):
    when typeof(value) is ImageObject:
      renderdata.createVulkanImage(value)
    elif typeof(value) is array:
      when elementType(value) is ImageObject:
        for image in value.mitems:
          renderdata.createVulkanImage(image)

type EMPTY = object # only used for static assertions

proc assertCompatibleDescriptorSet(
    TDescriptorSet, TShader: typedesc, index: static DescriptorSetIndex
) =
  for _, fieldvalue in default(TShader).fieldPairs:
    when fieldvalue.hasCustomPragma(DescriptorSet):
      when fieldvalue.getCustomPragmaVal(DescriptorSet) == index:
        assert TDescriptorSet is typeof(fieldvalue),
          "Incompatible descriptor set types for set number " & $index & " in shader " &
            name(TShader)

proc bindDescriptorSet*[TDescriptorSet](
    commandBuffer: VkCommandBuffer,
    descriptorSet: DescriptorSetData[TDescriptorSet],
    index: static DescriptorSetIndex,
    layout: VkPipelineLayout,
) =
  assert descriptorSet.vk[currentFiF()].Valid,
    "DescriptorSetData not initialized, maybe forgot to call initDescriptorSet"
  svkCmdBindDescriptorSet(commandBuffer, descriptorSet.vk[currentFiF()], index, layout)

proc bindDescriptorSet*[TDescriptorSet, TShader](
    commandBuffer: VkCommandBuffer,
    descriptorSet: DescriptorSetData[TDescriptorSet],
    index: static DescriptorSetIndex,
    pipeline: Pipeline[TShader],
) =
  static:
    assertCompatibleDescriptorSet(TDescriptorSet, TShader, index)
  bindDescriptorSet(commandBuffer, descriptorSet, index, pipeline.layout)

proc assertCanRenderMesh(TShader, TMesh, TInstance: typedesc) =
  for attrName, attrValue in default(TShader).fieldPairs:
    when hasCustomPragma(attrValue, VertexAttribute):
      var foundAttr = false
      for meshAttrName, meshAttrValue in default(TMesh).fieldPairs:
        when attrName == meshAttrName:
          assert typeof(meshAttrValue) is GPUArray,
            "Mesh attribute '" & attrName & "' must be a GPUArray"
          assert typeof(attrValue) is elementType(meshAttrValue.data),
            "Type of shader attribute and mesh attribute '" & attrName &
              "' is not the same (" & typeof(attrValue).name & " and " &
              elementType(meshAttrValue.data).name & ")"
          foundAttr = true
      assert foundAttr,
        "Attribute '" & attrName & "' is not provided in mesh type '" & name(TMesh) & "'"
    elif hasCustomPragma(attrValue, InstanceAttribute):
      var foundAttr = false
      for instAttrName, instAttrValue in default(TInstance).fieldPairs:
        when attrName == instAttrName:
          assert typeof(instAttrValue) is GPUArray,
            "Instance attribute '" & attrName & "' must be a GPUArray"
          assert foundAttr == false,
            "Attribute '" & attrName &
              "' is defined in Mesh and Instance, can only be one"
          assert typeof(attrValue) is elementType(instAttrValue.data),
            "Type of shader attribute and mesh attribute '" & attrName &
              "' is not the same"
          foundAttr = true
      assert foundAttr,
        "Attribute '" & attrName & "' is not provided in instance type '" &
          name(TInstance) & "'"

proc render*[TShader, TMesh, TInstance](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    instances: TInstance,
    fixedVertexCount = -1,
    fixedInstanceCount = -1,
) =
  static:
    assertCanRenderMesh(TShader, TMesh, TInstance)

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
      pOffsets = vertexBuffersOffsets.ToCPointer(),
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

  if indexType != VK_INDEX_TYPE_NONE_KHR:
    vkCmdBindIndexBuffer(commandBuffer, indexBuffer, indexBufferOffset, indexType)
    vkCmdDrawIndexed(
      commandBuffer = commandBuffer,
      indexCount = elementCount,
      instanceCount =
        if fixedInstanceCount == -1: instanceCount else: fixedInstanceCount.uint32,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0,
    )
  else:
    vkCmdDraw(
      commandBuffer = commandBuffer,
      vertexCount = if fixedVertexCount < 0: elementCount else: fixedVertexCount.uint32,
      instanceCount =
        if fixedInstanceCount == -1: instanceCount else: fixedInstanceCount.uint32,
      firstVertex = 0,
      firstInstance = 0,
    )

proc render*[TShader, TMesh](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    fixedVertexCount = -1,
) =
  render(commandBuffer, pipeline, mesh, EMPTY(), fixedVertexCount)

proc assertValidPushConstantType(TShader, TPushConstant: typedesc) =
  assert sizeof(TPushConstant) <= PUSH_CONSTANT_SIZE,
    "Push constant values must be <= 128 bytes"
  var foundPushConstant = false
  for fieldname, fieldvalue in default(TShader).fieldPairs():
    when hasCustomPragma(fieldvalue, PushConstant):
      assert typeof(fieldvalue) is TPushConstant,
        "Provided push constant has not same type as declared in shader"
      assert foundPushConstant == false, "More than on push constant found in shader"
      foundPushConstant = true
  assert foundPushConstant == true, "No push constant found in shader"

proc renderWithPushConstant*[TShader, TMesh, TInstance, TPushConstant](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    instances: TInstance,
    pushConstant: TPushConstant,
    fixedVertexCount = -1,
) =
  static:
    assertValidPushConstantType(TShader, TPushConstant)
  vkCmdPushConstants(
    commandBuffer = commandBuffer,
    layout = pipeline.layout,
    stageFlags = VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
    offset = 0,
    size = alignedTo(sizeof(pushConstant).uint32, 4),
    pValues = addr(pushConstant),
  )
  render(commandBuffer, pipeline, mesh, instances, fixedVertexCount)

proc renderWithPushConstant*[TShader, TMesh, TPushConstant](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    pushConstant: TPushConstant,
    fixedVertexCount = -1,
) =
  static:
    assertValidPushConstantType(TShader, TPushConstant)
  vkCmdPushConstants(
    commandBuffer = commandBuffer,
    layout = pipeline.layout,
    stageFlags = VkShaderStageFlags(VK_SHADER_STAGE_ALL_GRAPHICS),
    offset = 0,
    size = sizeof(pushConstant).uint32,
    pValues = addr(pushConstant),
  )
  render(commandBuffer, pipeline, mesh, EMPTY(), fixedVertexCount)

proc asGPUArray*[T](data: sink openArray[T], bufferType: static BufferType): auto =
  GPUArray[T, bufferType](data: @data)

proc asGPUValue*[T](data: sink T, bufferType: static BufferType): auto =
  GPUValue[T, bufferType](data: data)

proc asDescriptorSetData*[T](data: sink T): auto =
  DescriptorSetData[T](data: data)
