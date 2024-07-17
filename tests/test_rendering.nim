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

proc test_03_simple_descriptorset(nFrames: int) =
  var renderdata = InitRenderData()

  type
    Material = object
      baseColor: Vec3f

    Uniforms = object
      material: GPUValue[Material, UniformBuffer]
      texture1: Texture[TVec4[uint8]]

    QuadShader = object
      position {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSets.}: (Uniforms, )
      # code
      vertexCode: string = """void main() {
      fragmentColor = material.baseColor;
      gl_Position = vec4(position, 1);
      gl_Position.x += ((material.baseColor.b - 0.5) * 2) - 0.5;
      uv = position.xy + 0.5;
      }"""
      fragmentCode: string = """void main() {
      outColor = vec4(fragmentColor, 1) * texture(texture1, uv);}"""
    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]

  let R = TVec4[uint8]([255'u8, 0'u8, 0'u8, 255'u8])
  let G = TVec4[uint8]([0'u8, 255'u8, 0'u8, 255'u8])
  let B = TVec4[uint8]([0'u8, 0'u8, 255'u8, 255'u8])
  let W = TVec4[uint8]([255'u8, 255'u8, 255'u8, 255'u8])
  var
    quad = QuadMesh(
      position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(-0.5, 0.5), NewVec3f(0.5, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
      indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
    )
    uniforms1 = asDescriptorSet(
      Uniforms(
        material: asGPUValue(Material(baseColor: NewVec3f(1, 1, 1)), UniformBuffer),
        texture1: Texture[TVec4[uint8]](width: 3, height: 3, data: @[R, G, B, G, B, R, B, R, G], interpolation: VK_FILTER_NEAREST),
      )
    )
    uniforms2 = asDescriptorSet(
      Uniforms(
        material: asGPUValue(Material(baseColor: NewVec3f(0.5, 0.5, 0.5)), UniformBuffer),
        texture1: Texture[TVec4[uint8]](width: 2, height: 2, data: @[R, G, B, W]),
    )
    )

  AssignBuffers(renderdata, quad)
  AssignBuffers(renderdata, uniforms1)
  AssignBuffers(renderdata, uniforms2)
  UploadTextures(renderdata, uniforms1)
  UploadTextures(renderdata, uniforms2)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[QuadShader](renderPass = mainRenderpass, samples = swapchain.samples)

  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms2)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          WithBind(commandbuffer, (uniforms1, ), pipeline, swapchain.currentFiF):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)
          WithBind(commandbuffer, (uniforms2, ), pipeline, swapchain.currentFiF):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

proc test_04_multiple_descriptorsets(nFrames: int) =
  var renderdata = InitRenderData()

  type
    RenderSettings = object
      brigthness: float32
    Material = object
      baseColor: Vec3f
    ObjectSettings = object
      scale: float32
      materialIndex: uint32
    Constants = object
      offset: Vec2f

    ConstSet = object
      constants: GPUValue[Constants, UniformBuffer]
    MainSet = object
      renderSettings: GPUValue[RenderSettings, UniformBufferMapped]
      material: array[2, GPUValue[Material, UniformBuffer]]
      texture1: array[2, Texture[TVec1[uint8]]]
    OtherSet = object
      objectSettings: GPUValue[ObjectSettings, UniformBufferMapped]

    QuadShader = object
      position {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSets.}: (ConstSet, MainSet, OtherSet)
      # code
      vertexCode: string = """void main() {
      fragmentColor = material[objectSettings.materialIndex].baseColor * renderSettings.brigthness;
      gl_Position = vec4(position * objectSettings.scale, 1);
      gl_Position.xy += constants.offset.xy;
      gl_Position.x += material[objectSettings.materialIndex].baseColor.b - 0.5;
      uv = position.xy + 0.5;
      }"""
      fragmentCode: string = """void main() {
      outColor = vec4(fragmentColor * texture(texture1[objectSettings.materialIndex], uv).rrr, 1);
      }"""
    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]

  var quad = QuadMesh(
    position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(-0.5, 0.5), NewVec3f(0.5, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
  )
  var constset = asDescriptorSet(
    ConstSet(
      constants: asGPUValue(Constants(offset: NewVec2f(-0.3, 0.2)), UniformBuffer),
    )
  )
  let G = TVec1[uint8]([50'u8])
  let W = TVec1[uint8]([255'u8])
  var mainset = asDescriptorSet(
    MainSet(
      renderSettings: asGPUValue(RenderSettings(brigthness: 0), UniformBufferMapped),
      material: [
        asGPUValue(Material(baseColor: NewVec3f(1, 1, 0)), UniformBuffer),
        asGPUValue(Material(baseColor: NewVec3f(1, 0, 1)), UniformBuffer),
    ],
    texture1: [
      Texture[TVec1[uint8]](width: 2, height: 2, data: @[W, G, G, W], interpolation: VK_FILTER_NEAREST),
      Texture[TVec1[uint8]](width: 3, height: 3, data: @[W, G, W, G, W, G, W, G, W], interpolation: VK_FILTER_NEAREST),
    ],
  ),
  )
  var otherset1 = asDescriptorSet(
    OtherSet(
      objectSettings: asGPUValue(ObjectSettings(scale: 1.0, materialIndex: 0), UniformBufferMapped),
    )
  )
  var otherset2 = asDescriptorSet(
    OtherSet(
      objectSettings: asGPUValue(ObjectSettings(scale: 1.0, materialIndex: 1), UniformBufferMapped),
    )
  )

  AssignBuffers(renderdata, quad)
  AssignBuffers(renderdata, constset)
  AssignBuffers(renderdata, mainset)
  AssignBuffers(renderdata, otherset1)
  AssignBuffers(renderdata, otherset2)
  UploadTextures(renderdata, mainset)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[QuadShader](renderPass = mainRenderpass, samples = swapchain.samples)

  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], constset)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[1], mainset)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset1)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset2)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          WithBind(commandbuffer, (constset, mainset, otherset1), pipeline, swapchain.currentFiF):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)
          WithBind(commandbuffer, (constset, mainset, otherset2), pipeline, swapchain.currentFiF):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)
    mainset.data.renderSettings.data.brigthness = (c.float32 / nFrames.float32)
    otherset1.data.objectSettings.data.scale = 0.5 + (c.float32 / nFrames.float32)
    UpdateGPUBuffer(mainset.data.renderSettings)
    UpdateGPUBuffer(otherset1.data.objectSettings)
    renderdata.FlushAllMemory()
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

when isMainModule:
  var nFrames = 2000
  InitVulkan()

  # test normal
  block:
    mainRenderpass = CreatePresentationRenderPass()
    swapchain = InitSwapchain(renderpass = mainRenderpass).get()

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_triangle(nFrames)

    # tests instanced triangles and quads, mixing meshes and instances
    test_02_triangle_quad_instanced(nFrames)

    # teste descriptor sets
    test_03_simple_descriptorset(nFrames)

    # tests multiple descriptor sets and arrays
    test_04_multiple_descriptorsets(nFrames)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
    DestroySwapchain(swapchain)

  # test MSAA
  block:
    mainRenderpass = CreatePresentationRenderPass(samples = VK_SAMPLE_COUNT_4_BIT)
    swapchain = InitSwapchain(renderpass = mainRenderpass, samples = VK_SAMPLE_COUNT_4_BIT).get()

    # test_01_triangle(99999999)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
    DestroySwapchain(swapchain)

  DestroyVulkan()
