import ./vulkan
import ./vulkan_helpers
import ./math/vector
import ./math/matrix
import ./buffer

type
  DescriptorType = SomeNumber|Vec|Mat
  Descriptor*[T:DescriptorType] = object
    value*: T

proc createUniformDescriptorLayout*(device: VkDevice, shaderStage: VkShaderStageFlags, binding: uint32): VkDescriptorSetLayout =
  var
    layoutbinding = VkDescriptorSetLayoutBinding(
      binding: binding,
      descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
      descriptorCount: 1,
      stageFlags: shaderStage,
      pImmutableSamplers: nil,
    )
    layoutInfo = VkDescriptorSetLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      bindingCount: 1,
      pBindings: addr(layoutbinding)
    )
  checkVkResult device.vkCreateDescriptorSetLayout(addr(layoutInfo), nil, addr(result))

proc createUniformBuffers*[nBuffers: static int, T](device: VkDevice, physicalDevice: VkPhysicalDevice): array[nBuffers, Buffer] =
  let size = sizeof(T)
  for i in 0 ..< nBuffers:
    var buffer = InitBuffer(
      device,
      physicalDevice,
      uint64(size),
      {UniformBuffer},
      {VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT},
      persistentMapping=true,
    )
    result[i] = buffer
