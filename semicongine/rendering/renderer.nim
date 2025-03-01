import std/typetraits
import std/strformat
import std/macros
import std/logging

import ../core
import ./vulkan_wrappers
from ./memory import allocateNewMemoryBlock, size

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
    anisotropyEnable: engine().vulkan.anisotropy > 0,
    maxAnisotropy: engine().vulkan.anisotropy,
    borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
    unnormalizedCoordinates: VK_FALSE,
    compareEnable: VK_FALSE,
    compareOp: VK_COMPARE_OP_ALWAYS,
    mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
    mipLodBias: 0,
    minLod: 0,
    maxLod: 0,
  )
  checkVkResult vkCreateSampler(
    engine().vulkan.device, addr(samplerInfo), nil, addr(result)
  )

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
      engine().vulkan.physicalDevice, addr formatInfo, addr formatProperties
    )
    if formatCheck == VK_SUCCESS: # found suitable format
      return format
    elif formatCheck == VK_ERROR_FORMAT_NOT_SUPPORTED: # nope, try to find other format
      continue
    else: # raise error
      checkVkResult formatCheck

  assert false, "Unable to find format for textures"

proc createVulkanImage(renderData: var RenderData, image: var ImageObject) =
  assert image.vk == VkImage(0), "Image has already been created"
  var imgUsage = @[VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_IMAGE_USAGE_SAMPLED_BIT]
  if image.isRenderTarget:
    imgUsage.add VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
  let format =
    getVkFormat(grayscale = elementType(image.data) is Gray, usage = imgUsage)

  image.vk = svkCreate2DImage(
    image.width, image.height, format, imgUsage, image.samples, image.nLayers
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
    engine().vulkan.device,
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
    fixedVertexCount = high(uint32),
    fixedInstanceCount = high(uint32),
) =
  debug("render ", name(TShader))
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
          debug("  vertex attr: ", shaderAttributeName)
          assert meshValue.buffer.vk.Valid,
            "Mesh vertex-attribute '{TMesh}.{shaderAttributeName}' has no valid buffer (encountered while rendering with '{TShader}')"
          vertexBuffers.add meshValue.buffer.vk
          vertexBuffersOffsets.add meshValue.offset
          if elementCount == 0:
            elementCount = meshValue.data.len.uint32
          else:
            assert meshValue.data.len.uint32 == elementCount,
              "Mesh attribute '" & $(TMesh) & "." & meshName & "' has length " &
                $(meshValue.data.len) & " but previous attributes had length " &
                $elementCount
    elif hasCustomPragma(shaderAttribute, InstanceAttribute):
      for instanceName, instanceValue in instances.fieldPairs:
        when instanceName == shaderAttributeName:
          debug("  instnc attr: ", shaderAttributeName)
          vertexBuffers.add instanceValue.buffer.vk
          vertexBuffersOffsets.add instanceValue.offset
          if instanceCount == 1:
            instanceCount = instanceValue.data.len.uint32
          else:
            assert instanceValue.data.len.uint32 == instanceCount,
              "Mesh instance attribute '" & $(TMesh) & "." & instanceName &
                "' has length " & $(instanceValue.data.len) &
                " but previous attributes had length " & $instanceCount

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
    debug "  indexed (", elementCount, ")"
    vkCmdBindIndexBuffer(commandBuffer, indexBuffer, indexBufferOffset, indexType)
    let instanceCount =
      if fixedInstanceCount == high(uint32): instanceCount else: fixedInstanceCount
    if instanceCount > 1:
      debug "  ", instanceCount, " instances"
    vkCmdDrawIndexed(
      commandBuffer = commandBuffer,
      indexCount = elementCount,
      instanceCount = instanceCount,
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0,
    )
  else:
    debug "  non-indexed (",
      if fixedVertexCount == high(uint32): elementCount else: fixedVertexCount, ")"
    let instanceCount =
      if fixedInstanceCount == high(uint32): instanceCount else: fixedInstanceCount
    if instanceCount > 1:
      debug "  ", instanceCount, " instances"
    vkCmdDraw(
      commandBuffer = commandBuffer,
      vertexCount =
        if fixedVertexCount == high(uint32): elementCount else: fixedVertexCount,
      instanceCount = instanceCount,
      firstVertex = 0,
      firstInstance = 0,
    )

proc render*[TShader, TMesh](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    fixedVertexCount = high(uint32),
    fixedInstanceCount = high(uint32),
) =
  render(commandBuffer, pipeline, mesh, EMPTY(), fixedVertexCount, fixedInstanceCount)

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
    fixedVertexCount = high(uint32),
    fixedInstanceCount = high(uint32),
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
  render(commandBuffer, pipeline, mesh, instances, fixedVertexCount, fixedInstanceCount)

proc renderWithPushConstant*[TShader, TMesh, TPushConstant](
    commandBuffer: VkCommandBuffer,
    pipeline: Pipeline[TShader],
    mesh: TMesh,
    pushConstant: TPushConstant,
    fixedVertexCount = high(uint32),
    fixedInstanceCount = high(uint32),
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
  render(commandBuffer, pipeline, mesh, EMPTY(), fixedVertexCount, fixedInstanceCount)

proc asDescriptorSetData*[T](data: sink T): auto =
  DescriptorSetData[T](data: data)
