import std/enumerate

import ./api
import ./device
import ./buffer
import ./utils

type
  Descriptor* = object # "fields" of a DescriptorSetLayout
    thetype*: VkDescriptorType
    count*: uint32
    stages*: seq[VkShaderStageFlagBits]
    itemsize*: uint32
  DescriptorSetLayout* = object # "type-description" of a DescriptorSet
    device: Device
    vk*: VkDescriptorSetLayout
    descriptors*: seq[Descriptor]
  DescriptorSet* = object # "instance" of a DescriptorSetLayout
    vk*: VkDescriptorSet
    layout: DescriptorSetLayout
  DescriptorPool* = object # required for allocation of DescriptorSet
    device: Device
    vk*: VkDescriptorPool
    maxSets*: uint32 # maximum number of allocatable descriptor sets
    counts*: seq[(VkDescriptorType, uint32)] # maximum number for each descriptor type to allocate


proc createDescriptorSetLayout*(device: Device, descriptors: seq[Descriptor]): DescriptorSetLayout =
  assert device.vk.valid

  result.device = device
  result.descriptors = descriptors

  var layoutbindings: seq[VkDescriptorSetLayoutBinding]
  for i, descriptor in enumerate(descriptors):
    layoutbindings.add VkDescriptorSetLayoutBinding(
      binding: uint32(i),
      descriptorType: descriptor.thetype,
      descriptorCount: descriptor.count,
      stageFlags: toBits descriptor.stages,
      pImmutableSamplers: nil,
    )
  var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount: uint32(layoutbindings.len),
    pBindings: layoutbindings.toCPointer
  )
  checkVkResult vkCreateDescriptorSetLayout(device.vk, addr(layoutCreateInfo), nil, addr(result.vk))

proc destroy*(descriptorSetLayout: var DescriptorSetLayout) =
  assert descriptorSetLayout.device.vk.valid
  assert descriptorSetLayout.vk.valid
  descriptorSetLayout.device.vk.vkDestroyDescriptorSetLayout(descriptorSetLayout.vk, nil)
  descriptorSetLayout.vk.reset


proc createDescriptorSetPool*(device: Device, counts: seq[(VkDescriptorType, uint32)], maxSets = 1000'u32): DescriptorPool =
  assert device.vk.valid

  result.device = device
  result.maxSets = maxSets
  result.counts = counts

  var poolSizes: seq[VkDescriptorPoolSize]
  for (thetype, count) in result.counts:
    poolSizes.add VkDescriptorPoolSize(thetype: thetype, descriptorCount: count)
  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount: uint32(poolSizes.len),
    pPoolSizes: poolSizes.toCPointer,
    maxSets: result.maxSets,
  )
  checkVkResult vkCreateDescriptorPool(result.device.vk, addr(poolInfo), nil, addr(result.vk))

proc reset*(pool: DescriptorPool) =
  assert pool.device.vk.valid
  assert pool.vk.valid
  checkVkResult vkResetDescriptorPool(pool.device.vk, pool.vk, VkDescriptorPoolResetFlags(0))

proc destroy*(pool: var DescriptorPool) =
  assert pool.device.vk.valid
  assert pool.vk.valid
  pool.device.vk.vkDestroyDescriptorPool(pool.vk, nil)
  pool.vk.reset

proc allocateDescriptorSet*(pool: DescriptorPool, layout: DescriptorSetLayout, nframes: int): seq[DescriptorSet] =
  assert pool.device.vk.valid
  assert pool.vk.valid
  assert layout.device.vk.valid
  assert layout.vk.valid


  var layouts: seq[VkDescriptorSetLayout]
  var descriptorSets = newSeq[VkDescriptorSet](nframes)
  for i in 0 ..< nframes:
    layouts.add layout.vk
  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: pool.vk,
    descriptorSetCount: uint32(layouts.len),
    pSetLayouts: layouts.toCPointer,
  )

  checkVkResult vkAllocateDescriptorSets(pool.device.vk, addr(allocInfo), descriptorSets.toCPointer)
  for descriptorSet in descriptorSets:
    result.add DescriptorSet(vk: descriptorSet, layout: layout)

proc setDescriptorSet*(descriptorSet: DescriptorSet, buffer: Buffer, bindingBase=0'u32) =
  # assumes descriptors of the descriptorSet are arranged interleaved in buffer
  assert descriptorSet.layout.device.vk.valid
  assert descriptorSet.layout.vk.valid
  assert descriptorSet.vk.valid
  assert buffer.device.vk.valid
  assert buffer.vk.valid

  var descriptorSetWrites: seq[VkWriteDescriptorSet]

  var offset = VkDeviceSize(0)
  var i = bindingBase
  for descriptor in descriptorSet.layout.descriptors:
    let length = VkDeviceSize(descriptor.itemsize * descriptor.count)
    var bufferInfo = VkDescriptorBufferInfo(buffer: buffer.vk, offset: offset, range: length)
    descriptorSetWrites.add VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        dstSet: descriptorSet.vk,
        dstBinding: i,
        dstArrayElement: 0,
        descriptorType: descriptor.thetype,
        descriptorCount: descriptor.count,
        pBufferInfo: addr(bufferInfo),
      )
    offset += length
  descriptorSet.layout.device.vk.vkUpdateDescriptorSets(uint32(descriptorSetWrites.len), descriptorSetWrites.toCPointer, 0, nil)
