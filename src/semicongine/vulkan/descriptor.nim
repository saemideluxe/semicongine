import std/enumerate
import std/tables

import ./api
import ./device
import ./buffer
import ./utils
import ./image

type
  DescriptorType* = enum
    Uniform, ImageSampler
  Descriptor* = object # "fields" of a DescriptorSetLayout
    name*: string
    count*: uint32
    stages*: seq[VkShaderStageFlagBits]
    itemsize*: uint32
    case thetype*: DescriptorType
    of Uniform:
      buffer*: Buffer
      offset*: uint64
      size*: uint64
    of ImageSampler:
      imageview*: ImageView
      sampler*: Sampler
  DescriptorSet* = object # "instance" of a DescriptorSetLayout
    vk*: VkDescriptorSet
    layout*: DescriptorSetLayout
  DescriptorSetLayout* = object # "type-description" of a DescriptorSet
    device: Device
    vk*: VkDescriptorSetLayout
    descriptors*: seq[Descriptor]
  DescriptorPool* = object # required for allocation of DescriptorSet
    device: Device
    vk*: VkDescriptorPool
    maxSets*: uint32 # maximum number of allocatable descriptor sets
    counts*: seq[(VkDescriptorType, uint32)] # maximum number for each descriptor type to allocate

const DESCRIPTOR_TYPE_MAP = {
  Uniform: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
  ImageSampler: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
}.toTable

func vkType(descriptor: Descriptor): VkDescriptorType =
  DESCRIPTOR_TYPE_MAP[descriptor.thetype]

proc createDescriptorSetLayout*(device: Device, descriptors: seq[Descriptor]): DescriptorSetLayout =
  assert device.vk.valid

  result.device = device
  result.descriptors = descriptors

  var layoutbindings: seq[VkDescriptorSetLayoutBinding]
  for i, descriptor in enumerate(descriptors):
    layoutbindings.add VkDescriptorSetLayoutBinding(
      binding: uint32(i),
      descriptorType: descriptor.vkType,
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

proc writeDescriptorSet*(descriptorSet: DescriptorSet, bindingBase=0'u32) =
  # assumes descriptors of the descriptorSet are arranged interleaved in buffer
  assert descriptorSet.layout.device.vk.valid
  assert descriptorSet.layout.vk.valid
  assert descriptorSet.vk.valid

  var descriptorSetWrites: seq[VkWriteDescriptorSet]
  var bufferInfos: seq[VkDescriptorBufferInfo]
  var imageInfos: seq[VkDescriptorImageInfo]

  var i = bindingBase
  for descriptor in descriptorSet.layout.descriptors:
    if descriptor.thetype == Uniform:
      assert descriptor.buffer.vk.valid
      bufferInfos.add VkDescriptorBufferInfo(
        buffer: descriptor.buffer.vk,
        offset: descriptor.offset,
        range: descriptor.size,
      )
      descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSet.vk,
          dstBinding: i,
          dstArrayElement: 0,
          descriptorType: descriptor.vkType,
          descriptorCount: descriptor.count,
          pBufferInfo: addr bufferInfos[^1],
        )
    #[ 
    elif descriptor.thetype == ImageSampler:
      assert descriptor.imageview.vk.valid
      assert descriptor.sampler.vk.valid
      imageInfos.add VkDescriptorImageInfo(
        imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        imageView: descriptor.imageview.vk,
        sampler: descriptor.sampler.vk,
      )
      descriptorSetWrites.add VkWriteDescriptorSet(
          sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
          dstSet: descriptorSet.vk,
          dstBinding: i,
          dstArrayElement: 0,
          descriptorType: descriptor.vkType,
          descriptorCount: descriptor.count,
          pImageInfo: addr imageInfos[^1],
        )
    ]#
    inc i
  descriptorSet.layout.device.vk.vkUpdateDescriptorSets(uint32(descriptorSetWrites.len), descriptorSetWrites.toCPointer, 0, nil)
