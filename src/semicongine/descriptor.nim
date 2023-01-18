import std/strutils
import std/unicode
import std/strformat
import std/typetraits

import ./vulkan
import ./vulkan_helpers
import ./math/vector
import ./math/matrix
import ./buffer
import ./glsl_helpers

# TODO: check for alignment in uniform blocks
#
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

proc createUniformBuffers*[nBuffers: static int, Uniforms](device: VkDevice, physicalDevice: VkPhysicalDevice): array[nBuffers, Buffer] =
  let size = sizeof(Uniforms)
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

template getDescriptorType*(v: Descriptor): auto = get(genericParams(typeof(v)), 0)

func generateGLSLUniformDeclarations*[Uniforms](binding: int = 0): string {.compileTime.} =
  var stmtList: seq[string]

  when not (Uniforms is void):
    let uniformTypeName = name(Uniforms).toUpper()
    let uniformInstanceName = name(Uniforms).toLower()
    stmtList.add(&"layout(binding = {binding}) uniform {uniformTypeName} {{")
    for fieldname, value in Uniforms().fieldPairs:
      when typeof(value) is Descriptor:
        let glsltype = getGLSLType[getDescriptorType(value)]()
        let n = fieldname
        stmtList.add(&"    {glsltype} {n};")
    stmtList.add(&"}} {uniformInstanceName};")

  return stmtList.join("\n")
