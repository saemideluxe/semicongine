import std/os
import std/sequtils
import std/monotimes
import std/times
import std/options
import std/random

import ../semiconginev2

proc test_gltf(time: float32) =
  var renderdata = InitRenderData()

  type
    Material = object
      color: Vec4f = NewVec4f(1, 1, 1, 1)
      colorTexture: int32 = -1
      metallic: float32 = 0
      roughness: float32 = 0
      metallicRoughnessTexture: int32 = -1

      normalTexture: int32 = -1
      occlusionTexture: int32 = -1
      emissive: Vec4f = NewVec4f(0, 0, 0, 0)
      emissiveTexture: int32 = -1
    MainDescriptors = object
      material: GPUValue[Material, UniformBuffer]
    Shader = object
      position {.VertexAttribute.}: Vec3f
      uv {.VertexAttribute.}: Vec2f
      fragmentColor {.Pass.}: Vec4f
      fragmentUv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptors {.DescriptorSets.}: (MainDescriptors, )
      # code
      vertexCode: string = """
void main() {
  fragmentColor = vec4(1, 1, 1, 1);
  fragmentUv = uv;
  gl_Position = vec4(position, 1);
}"""
      fragmentCode: string = """void main() { outColor = fragmentColor;}"""
    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      uv: GPUArray[Vec2f, VertexBuffer]

  var gltfData = LoadMeshes[Mesh, Material](
    "town.glb",
    MeshAttributeNames(
      POSITION: "position",
    TEXCOORD: @["uv"],
  ),
    MaterialAttributeNames(
      baseColorFactor: "color",
      baseColorTexture: "colorTexture",
      metallicFactor: "metallic",
      roughnessFactor: "roughness",
      metallicRoughnessTexture: "metallicRoughnessTexture",
      normalTexture: "normalTexture",
      occlusionTexture: "occlusionTexture",
      emissiveTexture: "emissiveTexture",
      emissiveFactor: "emissive",
    )
  )
  for mesh in mitems(gltfData.meshes):
    for primitive in mitems(mesh):
      renderdata.AssignBuffers(primitive[0])
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[Shader](renderPass = vulkan.swapchain.renderPass)

  proc drawNode(commandbuffer: VkCommandBuffer, pipeline: Pipeline, nodeId: int, transform: Mat4 = Unit4) =
    let nodeTransform = gltfData.nodes[nodeId].transform * transform
    if gltfData.nodes[nodeId].mesh >= 0:
      for primitive in gltfData.meshes[gltfData.nodes[nodeId].mesh]:
        Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = primitive[0])
    for childNode in gltfData.nodes[nodeId].children:
      drawNode(commandbuffer = commandbuffer, pipeline = pipeline, nodeId = childNode, transform = nodeTransform)


  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:

    WithNextFrame(framebuffer, commandbuffer):

      WithRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, NewVec4f(0, 0, 0, 0)):

        WithPipeline(commandbuffer, pipeline):
          for nodeId in gltfData.scenes[0]:
            drawNode(commandbuffer = commandbuffer, pipeline = pipeline, nodeId = nodeId)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)
when isMainModule:
  var time = 5'f32
  InitVulkan()

  var renderpass = CreateDirectPresentationRenderPass(depthBuffer = true, samples = VK_SAMPLE_COUNT_4_BIT)
  SetupSwapchain(renderpass = renderpass)

  # tests a simple triangle with minimalistic shader and vertex format
  test_gltf(time)

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
  ClearSwapchain()

  DestroyVulkan()
