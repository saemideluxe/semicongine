import std/sequtils
import std/options
import std/random

import ../semiconginev2

proc test_01_triangle(nFrames: int, swapchain: var Swapchain) =
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
    pipeline = CreatePipeline[TrianglShader](renderPass = swapchain.renderPass)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)


proc test_02_triangle_quad_instanced(nFrames: int, swapchain: var Swapchain) =
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

  var pipeline = CreatePipeline[SomeShader](renderPass = swapchain.renderPass)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
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

proc test_03_simple_descriptorset(nFrames: int, swapchain: var Swapchain) =
  var renderdata = InitRenderData()

  type
    Material = object
      baseColor: Vec3f

    Uniforms = object
      material: GPUValue[Material, UniformBuffer]
      texture1: Image[TVec4[uint8]]

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
        texture1: Image[TVec4[uint8]](width: 3, height: 3, data: @[R, G, B, G, B, R, B, R, G], interpolation: VK_FILTER_NEAREST),
      )
    )
    uniforms2 = asDescriptorSet(
      Uniforms(
        material: asGPUValue(Material(baseColor: NewVec3f(0.5, 0.5, 0.5)), UniformBuffer),
        texture1: Image[TVec4[uint8]](width: 2, height: 2, data: @[R, G, B, W]),
    )
    )

  AssignBuffers(renderdata, quad)
  AssignBuffers(renderdata, uniforms1)
  AssignBuffers(renderdata, uniforms2)
  UploadImages(renderdata, uniforms1)
  UploadImages(renderdata, uniforms2)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[QuadShader](renderPass = swapchain.renderPass)

  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms2)

  var c = 0
  while UpdateInputs() and c < nFrames:
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
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

proc test_04_multiple_descriptorsets(nFrames: int, swapchain: var Swapchain) =
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
      texture1: array[2, Image[TVec1[uint8]]]
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
      Image[TVec1[uint8]](width: 2, height: 2, data: @[W, G, G, W], interpolation: VK_FILTER_NEAREST),
      Image[TVec1[uint8]](width: 3, height: 3, data: @[W, G, W, G, W, G, W, G, W], interpolation: VK_FILTER_NEAREST),
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
  UploadImages(renderdata, mainset)
  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[QuadShader](renderPass = swapchain.renderPass)

  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], constset)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[1], mainset)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset1)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset2)

  var c = 0
  while UpdateInputs() and c < nFrames:
    TimeAndLog:
      WithNextFrame(swapchain, framebuffer, commandbuffer):
        WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
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

proc test_05_cube(nFrames: int, swapchain: var Swapchain) =
  type

    UniformData = object
      m: Mat4
    Uniforms = object
      data: GPUValue[UniformData, UniformBufferMapped]
    CubeShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec4f
      fragmentColor {.Pass.}: Vec4f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSets.}: (Uniforms, )
      # code
      vertexCode = """void main() {
    fragmentColor = color;
    gl_Position = data.m * vec4(position, 1);
}"""
      fragmentCode = """void main() {
      outColor = fragmentColor;
}"""
    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      normals: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]

  let quad = @[
    NewVec3f(-0.5, -0.5), NewVec3f(-0.5, +0.5), NewVec3f(+0.5, +0.5),
    NewVec3f(+0.5, +0.5), NewVec3f(+0.5, -0.5), NewVec3f(-0.5, -0.5),
  ]
  proc transf(data: seq[Vec3f], m: Mat4): seq[Vec3f] =
    for v in data:
      result.add m * v

  var
    vertices: seq[Vec3f]
    colors: seq[Vec4f]
    normals: seq[Vec3f]

  # front, red
  vertices.add quad.transf(Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(1, 0, 0, 1))
  normals.add newSeqWith(6, NewVec3f(0, 0, -1))

  # back, cyan
  vertices.add quad.transf(Rotate(PI, Y) * Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(0, 1, 1, 1))
  normals.add newSeqWith(6, NewVec3f(0, 0, 1))

  # right, green
  vertices.add quad.transf(Rotate(PI / 2, Y) * Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(0, 1, 0, 1))
  normals.add newSeqWith(6, NewVec3f(-1, 0, 0))

  # left, magenta
  vertices.add quad.transf(Rotate(-PI / 2, Y) * Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(1, 0, 1, 1))
  normals.add newSeqWith(6, NewVec3f(1, 0, 0))

  # bottom, blue
  vertices.add quad.transf(Rotate(PI / 2, X) * Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(0, 0, 1, 1))
  normals.add newSeqWith(6, NewVec3f(0, -1, 0))

  # top, yellow
  vertices.add quad.transf(Rotate(-PI / 2, X) * Translate(0, 0, -0.5))
  colors.add newSeqWith(6, NewVec4f(1, 1, 0, 1))
  normals.add newSeqWith(6, NewVec3f(0, 1, 0))

  var renderdata = InitRenderData()

  var mesh = Mesh(
    position: asGPUArray(vertices, VertexBuffer),
    color: asGPUArray(colors, VertexBuffer),
    normals: asGPUArray(normals, VertexBuffer),
  )
  AssignBuffers(renderdata, mesh)

  var floor = Mesh(
    position: asGPUArray(quad.transf(Scale(10, 10, 10) * Rotate(-PI / 2, X) * Translate(0, 0, 0.05)), VertexBuffer),
    color: asGPUArray(newSeqWith(6, NewVec4f(0.1, 0.1, 0.1, 1)), VertexBuffer),
    normals: asGPUArray(newSeqWith(6, Y), VertexBuffer),
  )
  AssignBuffers(renderdata, floor)

  var uniforms1 = asDescriptorSet(
    Uniforms(
      data: asGPUValue(UniformData(m: Unit4), UniformBufferMapped)
    )
  )
  AssignBuffers(renderdata, uniforms1)

  renderdata.FlushAllMemory()

  var pipeline = CreatePipeline[CubeShader](renderPass = swapchain.renderPass)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)

  var c = 0
  while UpdateInputs() and c < nFrames:

    uniforms1.data.data.data.m = Translate(0, 0, -2) * Rotate(PI * 2 * c.float32 / nFrames.float32, Y) * Rotate(-PI / 4, X) * Perspective(-PI / 2, GetAspectRatio(swapchain), 0.01, 100)
    UpdateGPUBuffer(uniforms1.data.data, flush = true)
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          WithBind(commandbuffer, (uniforms1, ), pipeline, swapchain.currentFiF):
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)
            Render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = floor)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

proc test_06_triangle_2pass(nFrames: int, depthBuffer: bool, samples: VkSampleCountFlagBits) =
  var
    (offscreenRP, presentRP) = CreateIndirectPresentationRenderPass(depthBuffer = depthBuffer, samples = samples)
    swapchain = InitSwapchain(renderpass = presentRP).get()

  var renderdata = InitRenderData()

  type
    Uniforms = object
      frameTexture: Image[TVec4[uint8]]
    TriangleShader = object
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
    PresentShader = object
      position {.VertexAttribute.}: Vec2f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSets.}: (Uniforms, )
      # code
      vertexCode: string = """void main() {
      uv = ((position + 1) * 0.5) * vec2(1, -1);
      gl_Position = vec4(position, 0, 1);}"""
      fragmentCode: string = """void main() {
      vec2 uv1 = uv + vec2(0.001, 0.001);
      vec2 uv2 = uv + vec2(0.001, -0.001);
      vec2 uv3 = uv + vec2(-0.001, 0.001);
      vec2 uv4 = uv + vec2(-0.001, -0.001);
      outColor = (
        texture(frameTexture, uv1) +
        texture(frameTexture, uv2) +
        texture(frameTexture, uv3) +
        texture(frameTexture, uv4)
      ) / 4;
      }"""
    TriangleMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]
    QuadMesh = object
      position: GPUArray[Vec2f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]
  var mesh = TriangleMesh(
    position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(0, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
    color: asGPUArray([NewVec3f(0, 0, 1), NewVec3f(0, 1, 0), NewVec3f(1, 0, 0)], VertexBuffer),
  )
  var quad = QuadMesh(
    position: asGPUArray([NewVec2f(-1, -1), NewVec2f(-1, 1), NewVec2f(1, 1), NewVec2f(1, -1)], VertexBuffer),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
  )
  var uniforms1 = asDescriptorSet(
    Uniforms(
      frameTexture: Image[TVec4[uint8]](width: swapchain.width, height: swapchain.height, isRenderTarget: true),
    )
  )
  AssignBuffers(renderdata, mesh)
  AssignBuffers(renderdata, quad)
  UploadImages(renderdata, uniforms1)
  renderdata.FlushAllMemory()

  var
    drawPipeline = CreatePipeline[TriangleShader](renderPass = offscreenRP)
    presentPipeline = CreatePipeline[PresentShader](renderPass = presentRP)

  InitDescriptorSet(renderdata, presentPipeline.descriptorSetLayouts[0], uniforms1)

  # create depth buffer images (will not use the one in the swapchain
  var
    depthImage: VkImage
    depthImageView: VkImageView
    depthMemory: VkDeviceMemory
  if offscreenRP.depthBuffer:
    depthImage = svkCreate2DImage(
      width = swapchain.width,
      height = swapchain.height,
      format = DEPTH_FORMAT,
      usage = [VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT],
      samples = offscreenRP.samples,
    )
    let requirements = svkGetImageMemoryRequirements(depthImage)
    depthMemory = svkAllocateMemory(
      requirements.size,
      BestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(
      vulkan.device,
      depthImage,
      depthMemory,
      0,
    )
    depthImageView = svkCreate2DImageView(
      image = depthImage,
      format = DEPTH_FORMAT,
      aspect = VK_IMAGE_ASPECT_DEPTH_BIT
    )

  # create msaa images (will not use the one in the swapchain
  var
    msaaImage: VkImage
    msaaImageView: VkImageView
    msaaMemory: VkDeviceMemory
  if offscreenRP.samples != VK_SAMPLE_COUNT_1_BIT:
    msaaImage = svkCreate2DImage(
      width = swapchain.width,
      height = swapchain.height,
      format = SURFACE_FORMAT,
      usage = [VK_IMAGE_USAGE_SAMPLED_BIT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
      samples = offscreenRP.samples,
    )
    let requirements = svkGetImageMemoryRequirements(msaaImage)
    msaaMemory = svkAllocateMemory(
      requirements.size,
      BestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(
      vulkan.device,
      msaaImage,
      msaaMemory,
      0,
    )
    msaaImageView = svkCreate2DImageView(image = msaaImage, format = SURFACE_FORMAT)

  var attachments: seq[VkImageView]
  if offscreenRP.samples == VK_SAMPLE_COUNT_1_BIT:
    if offscreenRP.depthBuffer:
      attachments = @[uniforms1.data.frameTexture.imageview, depthImageView]
    else:
      attachments = @[uniforms1.data.frameTexture.imageview]
  else:
    if offscreenRP.depthBuffer:
      attachments = @[msaaImageView, depthImageView, uniforms1.data.frameTexture.imageview]
    else:
      attachments = @[msaaImageView, uniforms1.data.frameTexture.imageview]
  echo attachments
  var offscreenFB = svkCreateFramebuffer(
    offscreenRP.vk,
    swapchain.width,
    swapchain.height,
    attachments
  )

  var c = 0
  while UpdateInputs() and c < nFrames:

    TimeAndLog:
      WithNextFrame(swapchain, framebuffer, commandbuffer):

        WithRenderPass(offscreenRP, offscreenFB, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
          WithPipeline(commandbuffer, drawPipeline):
            Render(commandbuffer = commandbuffer, pipeline = drawPipeline, mesh = mesh)

        WithRenderPass(presentRP, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
          WithPipeline(commandbuffer, presentPipeline):
            WithBind(commandbuffer, (uniforms1, ), presentPipeline, swapchain.currentFiF):
              Render(commandbuffer = commandbuffer, pipeline = presentPipeline, mesh = quad)
    inc c

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(presentPipeline)
  DestroyPipeline(drawPipeline)
  DestroyRenderData(renderdata)
  if depthImage.Valid:
    vkDestroyImageView(vulkan.device, depthImageView, nil)
    vkDestroyImage(vulkan.device, depthImage, nil)
    vkFreeMemory(vulkan.device, depthMemory, nil)
  if msaaImage.Valid:
    vkDestroyImageView(vulkan.device, msaaImageView, nil)
    vkDestroyImage(vulkan.device, msaaImage, nil)
    vkFreeMemory(vulkan.device, msaaMemory, nil)
  vkDestroyRenderPass(vulkan.device, offscreenRP.vk, nil)
  vkDestroyRenderPass(vulkan.device, presentRP.vk, nil)
  vkDestroyFramebuffer(vulkan.device, offscreenFB, nil)
  DestroySwapchain(swapchain)

when isMainModule:
  var nFrames = 3000
  InitVulkan()

  var mainRenderpass: RenderPass
  var renderPasses = [
    # (depthBuffer: false, samples: VK_SAMPLE_COUNT_1_BIT),
      # (depthBuffer: false, samples: VK_SAMPLE_COUNT_4_BIT),
    (depthBuffer: true, samples: VK_SAMPLE_COUNT_1_BIT),
    # (depthBuffer: true, samples: VK_SAMPLE_COUNT_4_BIT),
  ]

  # test normal
  for i, (depthBuffer, samples) in renderPasses:
    var renderpass = CreateDirectPresentationRenderPass(depthBuffer = depthBuffer, samples = samples)
    var swapchain = InitSwapchain(renderpass = renderpass).get()

    #[
    # tests a simple triangle with minimalistic shader and vertex format
    test_01_triangle(nFrames, swapchain)

    # tests instanced triangles and quads, mixing meshes and instances
    test_02_triangle_quad_instanced(nFrames, swapchain)

    # teste descriptor sets
    test_03_simple_descriptorset(nFrames, swapchain)

    # tests multiple descriptor sets and arrays
    test_04_multiple_descriptorsets(nFrames, swapchain)
    ]#

    # rotating cube
    while true:
      test_05_cube(nFrames, swapchain)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    DestroySwapchain(swapchain)

  # test multiple render passes
  # for i, (depthBuffer, samples) in renderPasses:
    # test_06_triangle_2pass(nFrames, depthBuffer, samples)

  DestroyVulkan()
