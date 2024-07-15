import std/options
import std/random

import ../semicongine

var
  mainRenderpass: VkRenderPass
  swapchain: Swapchain

proc test_01_triangle(nFrames: int) =
  var renderdata = InitRenderData()

  type
    TrianglShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string = """void main() {
      fragmentColor = color;
      gl_Position = vec4(position, 1);}"""
      fragmentCode: string = """void main() {
      outColor = vec4(fragmentColor, 1);}"""
    TriangleMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]
  var mesh = TriangleMesh(
    position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(0, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
    color: asGPUArray([NewVec3f(0, 0, 1), NewVec3f(0, 1, 0), NewVec3f(1, 0, 0)], VertexBuffer),
  )
  AssignBuffers(renderdata, mesh)
  renderdata.FlushAllMemory()

  var
    pipeline = CreatePipeline[TrianglShader](renderPass = mainRenderpass, samples = swapchain.samples)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)


proc test_02_triangle_quad_instanced(nFrames: int) =
  var renderdata = InitRenderData()

  type
    SomeShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      pos {.InstanceAttribute.}: Vec3f
      scale {.InstanceAttribute.}: float32
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string = """void main() {
      fragmentColor = color;
      gl_Position = vec4((position * scale) + pos, 1);}"""
      fragmentCode: string = """void main() {
      outColor = vec4(fragmentColor, 1);}"""
    TriangleMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]
    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]
    Instances = object
      pos: GPUArray[Vec3f, VertexBuffer]
      scale: GPUArray[float32, VertexBuffer]
  var tri = TriangleMesh(
    position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(0, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
    color: asGPUArray([NewVec3f(0, 0, 1), NewVec3f(0, 1, 0), NewVec3f(1, 0, 0)], VertexBuffer),
  )
  var quad = QuadMesh(
    position: asGPUArray([NewVec3f(-0.3, -0.3), NewVec3f(-0.3, 0.3), NewVec3f(0.3, 0.3), NewVec3f(0.3, -0.3)], VertexBuffer),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
    color: asGPUArray([NewVec3f(1, 1, 1), NewVec3f(1, 1, 1), NewVec3f(1, 1, 1), NewVec3f(1, 1, 1)], VertexBuffer),
  )

  var instancesA: Instances
  for n in 1..100:
    instancesA.pos.data.add NewVec3f(rand(-0.8'f32 .. 0.8'f32), rand(-0.8'f32 .. 0'f32))
    instancesA.scale.data.add rand(0.3'f32 .. 0.4'f32)
  var instancesB: Instances
  for n in 1..100:
    instancesB.pos.data.add NewVec3f(rand(-0.8'f32 .. 0.8'f32), rand(0'f32 .. 0.8'f32))
    instancesB.scale.data.add rand(0.1'f32 .. 0.2'f32)

  AssignBuffers(renderdata, tri)
  AssignBuffers(renderdata, quad)
  AssignBuffers(renderdata, instancesA)
  AssignBuffers(renderdata, instancesB)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[SomeShader](renderPass = mainRenderpass, samples = swapchain.samples)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad, instances = instancesA)
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad, instances = instancesB)
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = tri, instances = instancesA)
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = tri, instances = instancesB)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

proc test_03_global_descriptorset(nFrames: int) =
  var renderdata = InitRenderData()

  type
    RenderSettings = object
      gamma: float32
    FirstDS = object
      settings: GPUValue[RenderSettings, UniformBuffer]
    QuadShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      firstDS: DescriptorSet[FirstDS, First]
      # code
      vertexCode: string = """void main() {
      fragmentColor = vec3(pow(color.r, settings.gamma), pow(color.g, settings.gamma), pow(color.b, settings.gamma));
      gl_Position = vec4(position, 1);}"""
      fragmentCode: string = """void main() {
      outColor = vec4(fragmentColor, 1);}"""
    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]

  var quad = QuadMesh(
    position: asGPUArray([NewVec3f(-0.3, -0.3), NewVec3f(-0.3, 0.3), NewVec3f(0.3, 0.3), NewVec3f(0.3, -0.3)], VertexBuffer),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
    color: asGPUArray([NewVec3f(1, 1, 1), NewVec3f(1, 1, 1), NewVec3f(1, 1, 1), NewVec3f(1, 1, 1)], VertexBuffer),
  )
  var firstDs = DescriptorSet[FirstDS, First](
    data: FirstDS(
      settings: asGPUValue(RenderSettings(
          gamma: 1.0'f32
    ), UniformBuffer)
  )
  )
  AssignBuffers(renderdata, quad)
  AssignBuffers(renderdata, firstDs)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[QuadShader](renderPass = mainRenderpass, samples = swapchain.samples)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithBind(commandbuffer, firstDs, pipeline, swapchain.currentFiF):
        WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
          WithPipeline(commandbuffer, pipeline):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, firstSet = firstDs, mesh = quad)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

when isMainModule:
  var nFrames = 100
  InitVulkan()

  # test normal
  block:
    mainRenderpass = CreatePresentationRenderPass()
    swapchain = InitSwapchain(renderpass = mainRenderpass).get()

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_triangle(nFrames)

    # tests instanced triangles and quads, mixing meshes and instances
    test_02_triangle_quad_instanced(nFrames)

    # tests
    test_03_global_descriptorset(nFrames)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
    DestroySwapchain(swapchain)

  # test MSAA
  block:
    mainRenderpass = CreatePresentationRenderPass(samples = VK_SAMPLE_COUNT_4_BIT)
    swapchain = InitSwapchain(renderpass = mainRenderpass, samples = VK_SAMPLE_COUNT_4_BIT).get()

    test_01_triangle(nFrames)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
    DestroySwapchain(swapchain)

  DestroyVulkan()
