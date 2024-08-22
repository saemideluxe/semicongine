import std/os
import std/sequtils
import std/math
import std/monotimes
import std/times
import std/options
import std/random

import ../semicongine

proc test_01_triangle(time: float32) =
  var renderdata = initRenderData()

  type
    PushConstant = object
      scale: float32

    Shader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      pushConstant {.PushConstant.}: PushConstant
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string =
        """void main() {
      fragmentColor = color;
      gl_Position = vec4(position * pushConstant.scale, 1);}"""
      fragmentCode: string =
        """void main() {
      outColor = vec4(fragmentColor, 1);}"""

    TriangleMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]

  var mesh = TriangleMesh(
    position: asGPUArray(
      [vec3(-0.5, -0.5, 0), vec3(0, 0.5, 0), vec3(0.5, -0.5, 0)], VertexBuffer
    ),
    color: asGPUArray([vec3(0, 0, 1), vec3(0, 1, 0), vec3(1, 0, 0)], VertexBuffer),
  )
  assignBuffers(renderdata, mesh)
  renderdata.flushAllMemory()

  var pipeline = createPipeline[Shader](renderPass = vulkan.swapchain.renderPass)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          renderWithPushConstant(
            commandbuffer = commandbuffer,
            pipeline = pipeline,
            mesh = mesh,
            pushConstant = PushConstant(
              scale: 0.3 + ((getMonoTime() - start).inMilliseconds().int / 1000)
            ),
          )

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_02_triangle_quad_instanced(time: float32) =
  var renderdata = initRenderData()

  type
    SomeShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      pos {.InstanceAttribute.}: Vec3f
      scale {.InstanceAttribute.}: float32
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string =
        """void main() {
      fragmentColor = color;
      gl_Position = vec4((position * scale) + pos, 1);}"""
      fragmentCode: string =
        """void main() {
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
    position: asGPUArray(
      [vec3(-0.5, -0.5, 0), vec3(0, 0.5, 0), vec3(0.5, -0.5, 0)], VertexBuffer
    ),
    color: asGPUArray([vec3(0, 0, 1), vec3(0, 1, 0), vec3(1, 0, 0)], VertexBuffer),
  )
  var quad = QuadMesh(
    position: asGPUArray(
      [vec3(-0.3, -0.3, 0), vec3(-0.3, 0.3, 0), vec3(0.3, 0.3, 0), vec3(0.3, -0.3, 0)],
      VertexBuffer,
    ),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
    color: asGPUArray(
      [vec3(1, 1, 1), vec3(1, 1, 1), vec3(1, 1, 1), vec3(1, 1, 1)], VertexBuffer
    ),
  )

  var instancesA: Instances
  for n in 1 .. 100:
    instancesA.pos.data.add vec3(rand(-0.8'f32 .. 0.8'f32), rand(-0.8'f32 .. 0'f32), 0)
    instancesA.scale.data.add rand(0.3'f32 .. 0.4'f32)
  var instancesB: Instances
  for n in 1 .. 100:
    instancesB.pos.data.add vec3(rand(-0.8'f32 .. 0.8'f32), rand(0'f32 .. 0.8'f32), 0)
    instancesB.scale.data.add rand(0.1'f32 .. 0.2'f32)

  assignBuffers(renderdata, tri)
  assignBuffers(renderdata, quad)
  assignBuffers(renderdata, instancesA)
  assignBuffers(renderdata, instancesB)
  renderdata.flushAllMemory()

  var pipeline = createPipeline[SomeShader](renderPass = vulkan.swapchain.renderPass)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          render(
            commandbuffer = commandbuffer,
            pipeline = pipeline,
            mesh = quad,
            instances = instancesA,
          )
          render(
            commandbuffer = commandbuffer,
            pipeline = pipeline,
            mesh = quad,
            instances = instancesB,
          )
          render(
            commandbuffer = commandbuffer,
            pipeline = pipeline,
            mesh = tri,
            instances = instancesA,
          )
          render(
            commandbuffer = commandbuffer,
            pipeline = pipeline,
            mesh = tri,
            instances = instancesB,
          )

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_03_simple_descriptorset(time: float32) =
  var renderdata = initRenderData()

  type
    Material = object
      baseColor: Vec3f

    Uniforms = object
      material: GPUValue[Material, UniformBuffer]
      texture1: Image[BGRA]

    QuadShader = object
      position {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSet: 0.}: Uniforms
      # code
      vertexCode: string =
        """void main() {
      fragmentColor = material.baseColor;
      gl_Position = vec4(position, 1);
      gl_Position.x += ((material.baseColor.b - 0.5) * 2) - 0.5;
      uv = position.xy + 0.5;
      }"""
      fragmentCode: string =
        """void main() {
      outColor = vec4(fragmentColor, 1) * texture(texture1, uv);}"""

    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]

  let R = BGRA([255'u8, 0'u8, 0'u8, 255'u8])
  let G = BGRA([0'u8, 255'u8, 0'u8, 255'u8])
  let B = BGRA([0'u8, 0'u8, 255'u8, 255'u8])
  let W = BGRA([255'u8, 255'u8, 255'u8, 255'u8])
  var
    quad = QuadMesh(
      position: asGPUArray(
        [vec3(-0.5, -0.5, 0), vec3(-0.5, 0.5, 0), vec3(0.5, 0.5, 0), vec3(0.5, -0.5, 0)],
        VertexBuffer,
      ),
      indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
    )
    uniforms1 = asDescriptorSetData(
      Uniforms(
        material: asGPUValue(Material(baseColor: vec3(1, 1, 1)), UniformBuffer),
        texture1: Image[BGRA](
          width: 3,
          height: 3,
          data: @[R, G, B, G, B, R, B, R, G],
          minInterpolation: VK_FILTER_NEAREST,
          magInterpolation: VK_FILTER_NEAREST,
        ),
      )
    )
    uniforms2 = asDescriptorSetData(
      Uniforms(
        material: asGPUValue(Material(baseColor: vec3(0.5, 0.5, 0.5)), UniformBuffer),
        texture1: Image[BGRA](width: 2, height: 2, data: @[R, G, B, W]),
      )
    )

  assignBuffers(renderdata, quad)
  assignBuffers(renderdata, uniforms1)
  assignBuffers(renderdata, uniforms2)
  uploadImages(renderdata, uniforms1)
  uploadImages(renderdata, uniforms2)
  renderdata.flushAllMemory()

  var pipeline = createPipeline[QuadShader](renderPass = vulkan.swapchain.renderPass)

  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms2)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, uniforms1, 0, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)

          bindDescriptorSet(commandbuffer, uniforms2, 0, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_04_multiple_descriptorsets(time: float32) =
  var renderdata = initRenderData()

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
      texture1: array[2, Image[Gray]]

    OtherSet = object
      objectSettings: GPUValue[ObjectSettings, UniformBufferMapped]

    QuadShader = object
      position {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets0 {.DescriptorSet: 0.}: ConstSet
      descriptorSets1 {.DescriptorSet: 1.}: MainSet
      descriptorSets2 {.DescriptorSet: 2.}: OtherSet
      # code
      vertexCode: string =
        """void main() {
      fragmentColor = material[objectSettings.materialIndex].baseColor * renderSettings.brigthness;
      gl_Position = vec4(position * objectSettings.scale, 1);
      gl_Position.xy += constants.offset.xy;
      gl_Position.x += material[objectSettings.materialIndex].baseColor.b - 0.5;
      uv = position.xy + 0.5;
      }"""
      fragmentCode: string =
        """void main() {
      outColor = vec4(fragmentColor * texture(texture1[objectSettings.materialIndex], uv).rrr, 1);
      }"""

    QuadMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint16, IndexBuffer]

  var quad = QuadMesh(
    position: asGPUArray(
      [vec3(-0.5, -0.5), vec3(-0.5, 0.5), vec3(0.5, 0.5), vec3(0.5, -0.5)], VertexBuffer
    ),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
  )
  var constset = asDescriptorSetData(
    ConstSet(constants: asGPUValue(Constants(offset: vec2(-0.3, 0.2)), UniformBuffer))
  )
  let G = Gray([50'u8])
  let W = Gray([255'u8])
  var mainset = asDescriptorSetData(
    MainSet(
      renderSettings: asGPUValue(RenderSettings(brigthness: 0), UniformBufferMapped),
      material: [
        asGPUValue(Material(baseColor: vec3(1, 1, 0)), UniformBuffer),
        asGPUValue(Material(baseColor: vec3(1, 0, 1)), UniformBuffer),
      ],
      texture1: [
        Image[Gray](
          width: 2,
          height: 2,
          data: @[W, G, G, W],
          minInterpolation: VK_FILTER_NEAREST,
          magInterpolation: VK_FILTER_NEAREST,
        ),
        Image[Gray](
          width: 3,
          height: 3,
          data: @[W, G, W, G, W, G, W, G, W],
          minInterpolation: VK_FILTER_NEAREST,
          magInterpolation: VK_FILTER_NEAREST,
        ),
      ],
    )
  )
  var otherset1 = asDescriptorSetData(
    OtherSet(
      objectSettings:
        asGPUValue(ObjectSettings(scale: 1.0, materialIndex: 0), UniformBufferMapped)
    )
  )
  var otherset2 = asDescriptorSetData(
    OtherSet(
      objectSettings:
        asGPUValue(ObjectSettings(scale: 1.0, materialIndex: 1), UniformBufferMapped)
    )
  )

  assignBuffers(renderdata, quad)
  assignBuffers(renderdata, constset)
  assignBuffers(renderdata, mainset)
  assignBuffers(renderdata, otherset1)
  assignBuffers(renderdata, otherset2)
  uploadImages(renderdata, mainset)
  renderdata.flushAllMemory()

  var pipeline = createPipeline[QuadShader](renderPass = vulkan.swapchain.renderPass)

  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], constset)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[1], mainset)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset1)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[2], otherset2)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, constset, 0, pipeline)
      bindDescriptorSet(commandbuffer, mainset, 1, pipeline)

      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, otherset1, 2, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)

          bindDescriptorSet(commandbuffer, otherset2, 2, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = quad)

    mainset.data.renderSettings.data.brigthness =
      ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    otherset1.data.objectSettings.data.scale =
      0.5 + ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    updateGPUBuffer(mainset.data.renderSettings)
    updateGPUBuffer(otherset1.data.objectSettings)
    renderdata.flushAllMemory()

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_05_cube(time: float32) =
  type
    UniformData = object
      mvp: Mat4

    Uniforms = object
      data: GPUValue[UniformData, UniformBufferMapped]

    CubeShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec4f
      fragmentColor {.Pass.}: Vec4f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSet: 0.}: Uniforms
      # code
      vertexCode =
        """void main() {
    fragmentColor = color;
    gl_Position = vec4(position, 1) * data.mvp;
}"""
      fragmentCode =
        """void main() {
      outColor = fragmentColor;
}"""

    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      normals: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]

  let quad =
    @[
      vec3(-0.5, -0.5),
      vec3(-0.5, +0.5),
      vec3(+0.5, +0.5),
      vec3(+0.5, +0.5),
      vec3(+0.5, -0.5),
      vec3(-0.5, -0.5),
    ]
  proc transf(data: seq[Vec3f], mat: Mat4): seq[Vec3f] =
    for v in data:
      result.add mat * v

  var
    vertices: seq[Vec3f]
    colors: seq[Vec4f]
    normals: seq[Vec3f]

  # front, red
  vertices.add quad.transf(translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(1, 0, 0, 1))
  normals.add newSeqWith(6, vec3(0, 0, -1))

  # back, cyan
  vertices.add quad.transf(rotate(PI, Y) * translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(0, 1, 1, 1))
  normals.add newSeqWith(6, vec3(0, 0, 1))

  # right, green
  vertices.add quad.transf(rotate(PI / 2, Y) * translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(0, 1, 0, 1))
  normals.add newSeqWith(6, vec3(-1, 0, 0))

  # left, magenta
  vertices.add quad.transf(rotate(-PI / 2, Y) * translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(1, 0, 1, 1))
  normals.add newSeqWith(6, vec3(1, 0, 0))

  # bottom, blue
  vertices.add quad.transf(rotate(PI / 2, X) * translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(0, 0, 1, 1))
  normals.add newSeqWith(6, vec3(0, -1, 0))

  # top, yellow
  vertices.add quad.transf(rotate(-PI / 2, X) * translate(0, 0, -0.5))
  colors.add newSeqWith(6, vec4(1, 1, 0, 1))
  normals.add newSeqWith(6, vec3(0, 1, 0))

  var renderdata = initRenderData()

  var mesh = Mesh(
    position: asGPUArray(vertices, VertexBuffer),
    color: asGPUArray(colors, VertexBuffer),
    normals: asGPUArray(normals, VertexBuffer),
  )
  assignBuffers(renderdata, mesh)

  var floor = Mesh(
    position: asGPUArray(
      quad.transf(scale(10, 10, 10) * rotate(-PI / 2, X) * translate(0, 0, 0.05)),
      VertexBuffer,
    ),
    color: asGPUArray(newSeqWith(6, vec4(0.1, 0.1, 0.1, 1)), VertexBuffer),
    normals: asGPUArray(newSeqWith(6, Y), VertexBuffer),
  )
  assignBuffers(renderdata, floor)

  var uniforms1 = asDescriptorSetData(
    Uniforms(data: asGPUValue(UniformData(mvp: Unit4), UniformBufferMapped))
  )
  assignBuffers(renderdata, uniforms1)

  renderdata.flushAllMemory()

  var pipeline = createPipeline[CubeShader](renderPass = vulkan.swapchain.renderPass)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)

  var tStart = getMonoTime()
  var t = tStart

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let tStartLoop = getMonoTime() - tStart

    uniforms1.data.data.data.mvp = (
      projection(-PI / 2, getAspectRatio(), 0.01, 100) * translate(0, 0, 2) *
      rotate(PI / 4, X) * rotate(
        PI * 0.1 * (tStartLoop.inMicroseconds() / 1_000_000), Y
      )
    )
    updateGPUBuffer(uniforms1.data.data, flush = true)

    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, uniforms1, 0, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = floor)

    let tEndLoop = getMonoTime() - tStart
    let looptime = tEndLoop - tStartLoop
    let waitTime = 16_666 - looptime.inMicroseconds
    if waitTime > 0:
      sleep((waitTime / 1000).int)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_06_different_draw_modes(time: float32) =
  var renderdata = initRenderData()

  type
    Shader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string =
        """void main() {
      gl_PointSize = 100;
      fragmentColor = color;
      gl_Position = vec4(position, 1);}"""
      fragmentCode: string =
        """void main() {
      outColor = vec4(fragmentColor, 1);}"""

    TriangleMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec3f, VertexBuffer]

  var triangle = TriangleMesh(
    position: asGPUArray(
      [vec3(-0.5, -0.5, 0), vec3(0, 0.5, 0), vec3(0.5, -0.5, 0)], VertexBuffer
    ),
    color: asGPUArray([vec3(0, 0, 1), vec3(0, 1, 0), vec3(1, 0, 0)], VertexBuffer),
  )
  var lines = TriangleMesh(
    position: asGPUArray(
      [vec3(-0.9, 0, 0), vec3(-0.05, -0.9, 0), vec3(0.05, -0.9, 0), vec3(0.9, 0, 0)],
      VertexBuffer,
    ),
    color: asGPUArray(
      [vec3(1, 1, 0), vec3(1, 1, 0), vec3(0, 1, 0), vec3(0, 1, 0)], VertexBuffer
    ),
  )
  assignBuffers(renderdata, triangle)
  assignBuffers(renderdata, lines)
  renderdata.flushAllMemory()

  var pipeline1 = createPipeline[Shader](
    renderPass = vulkan.swapchain.renderPass,
    polygonMode = VK_POLYGON_MODE_LINE,
    lineWidth = 20'f32,
  )
  var pipeline2 = createPipeline[Shader](
    renderPass = vulkan.swapchain.renderPass, polygonMode = VK_POLYGON_MODE_POINT
  )
  var pipeline3 = createPipeline[Shader](
    renderPass = vulkan.swapchain.renderPass,
    topology = VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
    lineWidth = 5,
  )
  var pipeline4 = createPipeline[Shader](
    renderPass = vulkan.swapchain.renderPass,
    topology = VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline1):
          render(commandbuffer = commandbuffer, pipeline = pipeline1, mesh = triangle)
        withPipeline(commandbuffer, pipeline2):
          render(commandbuffer = commandbuffer, pipeline = pipeline2, mesh = triangle)
        withPipeline(commandbuffer, pipeline3):
          render(commandbuffer = commandbuffer, pipeline = pipeline3, mesh = lines)
        withPipeline(commandbuffer, pipeline4):
          render(commandbuffer = commandbuffer, pipeline = pipeline4, mesh = lines)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline1)
  destroyPipeline(pipeline2)
  destroyPipeline(pipeline3)
  destroyPipeline(pipeline4)
  destroyRenderData(renderdata)

proc test_07_png_texture(time: float32) =
  var renderdata = initRenderData()

  type
    Uniforms = object
      texture1: Image[BGRA]

    Shader = object
      position {.VertexAttribute.}: Vec3f
      uv {.VertexAttribute.}: Vec2f
      fragmentUv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSet: 0.}: Uniforms
      # code
      vertexCode: string =
        """
void main() {
    fragmentUv = uv;
    gl_Position = vec4(position, 1);
}"""
      fragmentCode: string =
        """
void main() {
    outColor = texture(texture1, fragmentUv);
}"""

    Quad = object
      position: GPUArray[Vec3f, VertexBuffer]
      uv: GPUArray[Vec2f, VertexBuffer]

  var mesh = Quad(
    position: asGPUArray(
      [
        vec3(-0.8, -0.5),
        vec3(-0.8, 0.5),
        vec3(0.8, 0.5),
        vec3(0.8, 0.5),
        vec3(0.8, -0.5),
        vec3(-0.8, -0.5),
      ],
      VertexBuffer,
    ),
    uv: asGPUArray(
      [vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 0), vec2(1, 1), vec2(0, 1)],
      VertexBuffer,
    ),
  )
  assignBuffers(renderdata, mesh)
  renderdata.flushAllMemory()

  var pipeline = createPipeline[Shader](renderPass = vulkan.swapchain.renderPass)
  var uniforms1 = asDescriptorSetData(Uniforms(texture1: loadImage[BGRA]("art.png")))
  uploadImages(renderdata, uniforms1)
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], uniforms1)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, uniforms1, 0, pipeline)
          render(commandbuffer = commandbuffer, pipeline = pipeline, mesh = mesh)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_08_triangle_2pass(
    time: float32, depthBuffer: bool, samples: VkSampleCountFlagBits
) =
  var (offscreenRP, presentRP) =
    createIndirectPresentationRenderPass(depthBuffer = depthBuffer, samples = samples)

  setupSwapchain(renderpass = presentRP)

  var renderdata = initRenderData()

  type
    Uniforms = object
      frameTexture: Image[BGRA]

    TriangleShader = object
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec3f
      fragmentColor {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      # code
      vertexCode: string =
        """void main() {
      fragmentColor = color;
      gl_Position = vec4(position, 1);}"""
      fragmentCode: string =
        """void main() {
      outColor = vec4(fragmentColor, 1);}"""

    PresentShader = object
      position {.VertexAttribute.}: Vec2f
      uv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptorSets {.DescriptorSet: 0.}: Uniforms
      # code
      vertexCode: string =
        """void main() {
      uv = ((position + 1) * 0.5) * vec2(1, -1);
      gl_Position = vec4(position, 0, 1);}"""
      fragmentCode: string =
        """void main() {
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
    position:
      asGPUArray([vec3(-0.5, -0.5), vec3(0, 0.5), vec3(0.5, -0.5)], VertexBuffer),
    color: asGPUArray([vec3(0, 0, 1), vec3(0, 1, 0), vec3(1, 0, 0)], VertexBuffer),
  )
  var quad = QuadMesh(
    position:
      asGPUArray([vec2(-1, -1), vec2(-1, 1), vec2(1, 1), vec2(1, -1)], VertexBuffer),
    indices: asGPUArray([0'u16, 1'u16, 2'u16, 2'u16, 3'u16, 0'u16], IndexBuffer),
  )
  var uniforms1 = asDescriptorSetData(
    Uniforms(
      frameTexture: Image[BGRA](
        width: vulkan.swapchain.width,
        height: vulkan.swapchain.height,
        isRenderTarget: true,
      )
    )
  )
  assignBuffers(renderdata, mesh)
  assignBuffers(renderdata, quad)
  uploadImages(renderdata, uniforms1)
  renderdata.flushAllMemory()

  var
    drawPipeline = createPipeline[TriangleShader](renderPass = offscreenRP)
    presentPipeline = createPipeline[PresentShader](renderPass = presentRP)

  initDescriptorSet(renderdata, presentPipeline.descriptorSetLayouts[0], uniforms1)

  # create depth buffer images (will not use the one in the swapchain
  var
    depthImage: VkImage
    depthImageView: VkImageView
    depthMemory: VkDeviceMemory
  if offscreenRP.depthBuffer:
    depthImage = svkCreate2DImage(
      width = vulkan.swapchain.width,
      height = vulkan.swapchain.height,
      format = DEPTH_FORMAT,
      usage = [VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT],
      samples = offscreenRP.samples,
    )
    let requirements = svkGetImageMemoryRequirements(depthImage)
    depthMemory = svkAllocateMemory(
      requirements.size, bestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(vulkan.device, depthImage, depthMemory, 0)
    depthImageView = svkCreate2DImageView(
      image = depthImage, format = DEPTH_FORMAT, aspect = VK_IMAGE_ASPECT_DEPTH_BIT
    )

  # create msaa images (will not use the one in the swapchain
  var
    msaaImage: VkImage
    msaaImageView: VkImageView
    msaaMemory: VkDeviceMemory
  if offscreenRP.samples != VK_SAMPLE_COUNT_1_BIT:
    msaaImage = svkCreate2DImage(
      width = vulkan.swapchain.width,
      height = vulkan.swapchain.height,
      format = SURFACE_FORMAT,
      usage = [VK_IMAGE_USAGE_SAMPLED_BIT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT],
      samples = offscreenRP.samples,
    )
    let requirements = svkGetImageMemoryRequirements(msaaImage)
    msaaMemory = svkAllocateMemory(
      requirements.size, bestMemory(mappable = false, filter = requirements.memoryTypes)
    )
    checkVkResult vkBindImageMemory(vulkan.device, msaaImage, msaaMemory, 0)
    msaaImageView = svkCreate2DImageView(image = msaaImage, format = SURFACE_FORMAT)

  var attachments: seq[VkImageView]
  if offscreenRP.samples == VK_SAMPLE_COUNT_1_BIT:
    if offscreenRP.depthBuffer:
      attachments = @[uniforms1.data.frameTexture.imageview, depthImageView]
    else:
      attachments = @[uniforms1.data.frameTexture.imageview]
  else:
    if offscreenRP.depthBuffer:
      attachments =
        @[msaaImageView, depthImageView, uniforms1.data.frameTexture.imageview]
    else:
      attachments = @[msaaImageView, uniforms1.data.frameTexture.imageview]
  var offscreenFB = svkCreateFramebuffer(
    offscreenRP.vk, vulkan.swapchain.width, vulkan.swapchain.height, attachments
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        offscreenRP,
        offscreenFB,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, drawPipeline):
          render(commandbuffer = commandbuffer, pipeline = drawPipeline, mesh = mesh)

      withRenderPass(
        presentRP,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, presentPipeline):
          bindDescriptorSet(commandbuffer, uniforms1, 0, presentPipeline)
          render(commandbuffer = commandbuffer, pipeline = presentPipeline, mesh = quad)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(presentPipeline)
  destroyPipeline(drawPipeline)
  destroyRenderData(renderdata)
  if depthImage.Valid:
    vkDestroyImageView(vulkan.device, depthImageView, nil)
    vkDestroyImage(vulkan.device, depthImage, nil)
    vkFreeMemory(vulkan.device, depthMemory, nil)
  if msaaImage.Valid:
    vkDestroyImageView(vulkan.device, msaaImageView, nil)
    vkDestroyImage(vulkan.device, msaaImage, nil)
    vkFreeMemory(vulkan.device, msaaMemory, nil)
  destroyRenderPass(offscreenRP)
  destroyRenderPass(presentRP)
  vkDestroyFramebuffer(vulkan.device, offscreenFB, nil)
  clearSwapchain()

when isMainModule:
  var time = 1'f32
  initVulkan()

  var mainRenderpass: RenderPass
  var renderPasses = [
    (depthBuffer: false, samples: VK_SAMPLE_COUNT_1_BIT),
    (depthBuffer: false, samples: VK_SAMPLE_COUNT_4_BIT),
    (depthBuffer: true, samples: VK_SAMPLE_COUNT_1_BIT),
    (depthBuffer: true, samples: VK_SAMPLE_COUNT_4_BIT),
  ]

  # test normal
  for i, (depthBuffer, samples) in renderPasses:
    var renderpass =
      createDirectPresentationRenderPass(depthBuffer = depthBuffer, samples = samples)
    setupSwapchain(renderpass = renderpass)

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_triangle(time)

    # tests instanced triangles and quads, mixing meshes and instances
    test_02_triangle_quad_instanced(time)

    # teste descriptor sets
    test_03_simple_descriptorset(time)

    # tests multiple descriptor sets and arrays
    test_04_multiple_descriptorsets(time)

    # rotating cube
    test_05_cube(time)

    # different draw modes (lines, points, and topologies)
    test_06_different_draw_modes(time)

    # load PNG texture
    test_07_png_texture(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    destroyRenderPass(renderpass)
    clearSwapchain()

  # test multiple render passes
  for i, (depthBuffer, samples) in renderPasses:
    test_08_triangle_2pass(time, depthBuffer, samples)

  destroyVulkan()
