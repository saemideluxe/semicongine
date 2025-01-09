import std/typetraits
import std/sequtils

import ../core
import ./vulkan_wrappers

proc `[]`*[T, S](a: GPUArray[T, S], i: SomeInteger): T =
  a.data[i]

proc len*[T, S](a: GPUArray[T, S]): int =
  a.data.len

proc `[]=`*[T, S](a: var GPUArray[T, S], i: SomeInteger, value: T) =
  a.data[i] = value

func getBufferType*[A, B](value: GPUValue[A, B]): BufferType {.compileTime.} =
  B

func getBufferType*[A, B](
    value: openArray[GPUValue[A, B]]
): BufferType {.compileTime.} =
  B

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
    VkDescriptorPoolSize(
      thetype: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount: descriptorPoolLimit
    ),
  ]
  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount: poolSizes.len.uint32,
    pPoolSizes: poolSizes.ToCPointer,
    maxSets: descriptorPoolLimit,
  )
  checkVkResult vkCreateDescriptorPool(
    engine().vulkan.device, addr(poolInfo), nil, addr(result.descriptorPool)
  )

proc destroyRenderData*(renderData: RenderData) =
  vkDestroyDescriptorPool(engine().vulkan.device, renderData.descriptorPool, nil)

  for buffers in renderData.buffers:
    for buffer in buffers:
      vkDestroyBuffer(engine().vulkan.device, buffer.vk, nil)

  for imageView in renderData.imageViews:
    vkDestroyImageView(engine().vulkan.device, imageView, nil)

  for sampler in renderData.samplers:
    vkDestroySampler(engine().vulkan.device, sampler, nil)

  for image in renderData.images:
    vkDestroyImage(engine().vulkan.device, image, nil)

  for memoryBlocks in renderData.memory.litems:
    for memory in memoryBlocks:
      vkFreeMemory(engine().vulkan.device, memory.vk, nil)

func pointerAddOffset[T: SomeInteger](p: pointer, offset: T): pointer =
  cast[pointer](cast[T](p) + offset)

const BUFFER_USAGE: array[BufferType, seq[VkBufferUsageFlagBits]] = [
  VertexBuffer: @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT],
  VertexBufferMapped: @[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
  IndexBuffer: @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT],
  IndexBufferMapped: @[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
  UniformBuffer: @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT],
  UniformBufferMapped: @[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
  StorageBuffer: @[VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_BUFFER_USAGE_TRANSFER_DST_BIT],
  StorageBufferMapped: @[VK_BUFFER_USAGE_STORAGE_BUFFER_BIT],
]

template bufferType(gpuData: GPUData): untyped =
  typeof(gpuData).TBuffer

func needsMapping(bType: BufferType): bool =
  bType in
    [VertexBufferMapped, IndexBufferMapped, UniformBufferMapped, StorageBufferMapped]
template needsMapping(gpuData: GPUData): untyped =
  gpuData.bufferType.needsMapping

template size*(gpuArray: GPUArray, count = 0'u64): uint64 =
  (if count == 0: gpuArray.data.len.uint64 else: count).uint64 *
    sizeof(elementType(gpuArray.data)).uint64

template size*(gpuValue: GPUValue): uint64 =
  sizeof(gpuValue.data).uint64

func size*(image: ImageObject): uint64 =
  image.data.len.uint64 * sizeof(elementType(image.data)).uint64

template rawPointer(gpuArray: GPUArray): pointer =
  addr(gpuArray.data[0])

template rawPointer(gpuValue: GPUValue): pointer =
  addr(gpuValue.data)

proc isMappable(memoryTypeIndex: uint32): bool =
  var physicalProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(
    engine().vulkan.physicalDevice, addr(physicalProperties)
  )
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
      assert value.buffer.vk.Valid,
        "Invalid buffer, did you call 'assignBuffers' for this buffer?"
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
    engine().vulkan.device, addr(allocInfo), descriptorSet.vk.ToCPointer
  )

  # allocate seq with high cap to prevent realocation while adding to set
  # (which invalidates pointers that are passed to the vulkan api call)
  var descriptorSetWrites = newSeqOfCap[VkWriteDescriptorSet](1024)
  var imageWrites = newSeqOfCap[VkDescriptorImageInfo](1024)
  var bufferWrites = newSeqOfCap[VkDescriptorBufferInfo](1024)

  for theFieldname, fieldvalue in fieldPairs(descriptorSet.data):
    const descriptorType = getDescriptorType[typeof(fieldvalue)]()
    const descriptorCount = getDescriptorCount[typeof(fieldvalue)]()
    const descriptorBindingNumber =
      getBindingNumber[typeof(descriptorSet.data)](theFieldname)
    for i in 0 ..< descriptorSet.vk.len:
      when typeof(fieldvalue) is GPUValue:
        bufferWrites.add VkDescriptorBufferInfo(
          buffer: fieldvalue.buffer.vk,
          offset: fieldvalue.offset,
          range: fieldvalue.size,
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
      elif typeof(fieldvalue) is ImageObject:
        imageWrites.add VkDescriptorImageInfo(
          sampler: fieldvalue.sampler,
          imageView: fieldvalue.imageView,
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
      elif typeof(fieldvalue) is array:
        when elementType(fieldvalue) is ImageObject:
          for image in fieldvalue.litems:
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
        elif elementType(fieldvalue) is GPUValue:
          for entry in fieldvalue.litems:
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
            error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldvalue))
          .}
      else:
        {.
          error: "Unsupported descriptor type: " & typetraits.name(typeof(fieldvalue))
        .}

  vkUpdateDescriptorSets(
    device = engine().vulkan.device,
    descriptorWriteCount = descriptorSetWrites.len.uint32,
    pDescriptorWrites = descriptorSetWrites.ToCPointer,
    descriptorCopyCount = 0,
    pDescriptorCopies = nil,
  )

proc allocateNewMemoryBlock*(size: uint64, mType: uint32): MemoryBlock =
  result = MemoryBlock(
    vk: svkAllocateMemory(size, mType), size: size, rawPointer: nil, offsetNextFree: 0
  )
  if mType.isMappable():
    checkVkResult vkMapMemory(
      device = engine().vulkan.device,
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
  checkVkResult vkFlushMappedMemoryRanges(engine().vulkan.device, 1, addr(flushRegion))

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
      engine().vulkan.device, flushRegions.len.uint32, flushRegions.ToCPointer()
    )

proc allocateNewBuffer(
    renderData: var RenderData, size: uint64, bufferType: BufferType
): Buffer =
  result = Buffer(
    vk: svkCreateBuffer(size, BUFFER_USAGE[bufferType]),
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
    engine().vulkan.device, result.vk, selectedBlock.vk, selectedBlock.offsetNextFree
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

proc asGPUArray*[T](data: sink openArray[T], bufferType: static BufferType): auto =
  GPUArray[T, bufferType](data: @data)

proc asGPUValue*[T](data: sink T, bufferType: static BufferType): auto =
  GPUValue[T, bufferType](data: data)
