import std/options

import ./api
import ./utils
import ./device
import ./descriptor

import ../scene

type
  Pipeline* = object
    device*: Device
    vk*: VkPipeline
    layout*: VkPipelineLayout
    descriptorSetLayout*: DescriptorSetLayout
    descriptorPool*: DescriptorPool
    descriptorSets*: seq[DescriptorSet]

proc run*(pipeline: Pipeline, commandBuffer: VkCommandBuffer, inFlightFrame: int, scene: Scene) =
  var varPipeline = pipeline
  commandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.vk)
  commandBuffer.vkCmdBindDescriptorSets(VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.layout, 0, 1, addr(varPipeline.descriptorSets[inFlightFrame].vk), 0, nil)
  for drawable in scene.getDrawables():
    var buffers: seq[VkBuffer]
    var offsets: seq[VkDeviceSize]
    for buffer in drawable.buffers:
      buffers.add buffer.vk
      offsets.add VkDeviceSize(0)
    commandBuffer.vkCmdBindVertexBuffers(
      firstBinding=0'u32,
      bindingCount=uint32(buffers.len),
      pBuffers=buffers.toCPointer(),
      pOffsets=offsets.toCPointer()
    )
    if drawable.indexed:
      commandBuffer.vkCmdBindIndexBuffer(drawable.indexBuffer.vk, VkDeviceSize(0), drawable.indexType)
      commandBuffer.vkCmdDrawIndexed(
        indexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstIndex=0,
        vertexOffset=0,
        firstInstance=0
      )
    else:
      commandBuffer.vkCmdDraw(
        vertexCount=drawable.elementCount,
        instanceCount=drawable.instanceCount,
        firstVertex=0,
        firstInstance=0
      )

proc destroy*(pipeline: var Pipeline) =
  assert pipeline.device.vk.valid
  assert pipeline.vk.valid
  assert pipeline.layout.valid
  assert pipeline.descriptorSetLayout.vk.valid
  
  if pipeline.descriptorPool.vk.valid:
    pipeline.descriptorPool.destroy()
  pipeline.descriptorSetLayout.destroy()
  pipeline.device.vk.vkDestroyPipelineLayout(pipeline.layout, nil)
  pipeline.device.vk.vkDestroyPipeline(pipeline.vk, nil)
  pipeline.descriptorSetLayout.reset()
  pipeline.layout.reset()
  pipeline.vk.reset()
