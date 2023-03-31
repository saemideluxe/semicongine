import ./api
import ./device
import ./descriptor
import ./shader

import ../gpu_data

type
  Pipeline* = object
    device*: Device
    vk*: VkPipeline
    layout*: VkPipelineLayout
    shaders*: seq[Shader]
    descriptorSetLayout*: DescriptorSetLayout
    descriptorPool*: DescriptorPool
    descriptorSets*: seq[DescriptorSet]

func inputs*(pipeline: Pipeline): AttributeGroup =
  for shader in pipeline.shaders:
    if shader.stage == VK_SHADER_STAGE_VERTEX_BIT:
      return shader.inputs

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
