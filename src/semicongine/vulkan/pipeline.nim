import ./api
import ./device
import ./descriptor

type
  Pipeline* = object
    device*: Device
    vk*: VkPipeline
    layout*: VkPipelineLayout
    descriptorSetLayout*: DescriptorSetLayout
    descriptorPool*: DescriptorPool
    descriptorSets*: seq[DescriptorSet]


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
