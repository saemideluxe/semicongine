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
      color {.VertexAttribute.}: Vec4f
      uv {.VertexAttribute.}: Vec2f
      fragmentColor {.Pass.}: Vec4f
      fragmentUv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptors {.DescriptorSets.}: (MainDescriptors, )
      # code
      vertexCode: string = """
void main() {
  fragmentColor = color;
  fragmentUv = uv;
  gl_Position = vec4(position, 1);
}"""
      fragmentCode: string = """void main() { outColor = fragmentColor;}"""
    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]
      uv: GPUArray[Vec2f, VertexBuffer]

  let gltfMesh = LoadMeshes[Mesh, Material](
    "town.glb",
    MeshAttributeNames(
      POSITION: "position",
      COLOR: @["color"],
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
  var mesh = gltfMesh.meshes[0][0]
  renderdata.AssignBuffers(mesh)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[Shader](renderPass = vulkan.swapchain.renderPass)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:

    WithNextFrame(framebuffer, commandbuffer):

      WithRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, NewVec4f(0, 0, 0, 0)):

        WithPipeline(commandbuffer, pipeline):

          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)
when isMainModule:
  var time = 1'f32
  InitVulkan()

  var renderpass = CreateDirectPresentationRenderPass(depthBuffer = true, samples = VK_SAMPLE_COUNT_4_BIT)
  SetupSwapchain(renderpass = renderpass)

  # tests a simple triangle with minimalistic shader and vertex format
  test_gltf(time)

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
  ClearSwapchain()

  DestroyVulkan()
