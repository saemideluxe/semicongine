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
    ObjectData = object
      transform: Mat4
    Camera = object
      viewPerspective: Mat4
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
      camera: GPUValue[Camera, UniformBufferMapped]
    Shader = object
      objectData {.PushConstantAttribute.}: ObjectData
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec4f
      # uv {.VertexAttribute.}: Vec2f
      fragmentColor {.Pass.}: Vec4f
      fragmentUv {.Pass.}: Vec2f
      outColor {.ShaderOutput.}: Vec4f
      descriptors {.DescriptorSets.}: (MainDescriptors, )
      # code
      vertexCode: string = """
void main() {
  fragmentColor = color;
  // fragmentUv = uv;
  gl_Position = vec4(position, 1) * camera.viewPerspective;
}"""
      fragmentCode: string = """void main() { outColor = fragmentColor;}"""
    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]
      uv: GPUArray[Vec2f, VertexBuffer]
    DebugMesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]

  var gltfData = LoadMeshes[Mesh, Material](
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
  var descriptors = asDescriptorSet(
    MainDescriptors(
      camera: asGPUValue(Camera(
        viewPerspective: Unit4,
      ), UniformBufferMapped)
    )
  )
  for mesh in mitems(gltfData.meshes):
    for primitive in mitems(mesh):
      primitive[0].color = asGPUArray(newSeqWith(primitive[0].position.data.len, NewVec4f(1, 1, 1, 1)), VertexBuffer)
      renderdata.AssignBuffers(primitive[0])
  renderdata.AssignBuffers(descriptors)

  let O = default(Vec3f)
  let Gray = NewVec4f(0.5, 0.5, 0.5, 1)
  var gridPos = @[O, X, O, Y, O, Z]
  var gridColor = @[R, R, G, G, B, B]
  for i in 0 ..< 10:
    gridPos.add [NewVec3f(-5, -0.001, i.float32 - 5), NewVec3f(5, -0.001, i.float32 - 5)]
    gridPos.add [NewVec3f(i.float32 - 5, -0.001, -5), NewVec3f(i.float32 - 5, -0.001, 5)]
    gridColor.add [Gray, Gray, Gray, Gray]
  var grid = DebugMesh(
    position: asGPUArray(gridPos, VertexBuffer),
    color: asGPUArray(gridColor, VertexBuffer),
  )
  renderdata.AssignBuffers(grid)

  var pipeline = CreatePipeline[Shader](renderPass = vulkan.swapchain.renderPass, cullMode = [])
  var debugpipeline = CreatePipeline[Shader](renderPass = vulkan.swapchain.renderPass, topology = VK_PRIMITIVE_TOPOLOGY_LINE_LIST, lineWidth=10)
  InitDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], descriptors)

  renderdata.FlushAllMemory()

  proc drawNode(commandbuffer: VkCommandBuffer, pipeline: Pipeline, nodeId: int,
      transform: Mat4 = Unit4) =
    let nodeTransform = gltfData.nodes[nodeId].transform * transform
    if gltfData.nodes[nodeId].mesh >= 0:
      for primitive in gltfData.meshes[gltfData.nodes[nodeId].mesh]:
        RenderWithPushConstant(
          commandbuffer = commandbuffer,
          pipeline = pipeline,
          mesh = primitive[0],
          pushConstant = ObjectData(transform: nodeTransform)
        )
    for childNode in gltfData.nodes[nodeId].children:
      drawNode(commandbuffer = commandbuffer, pipeline = pipeline, nodeId = childNode, transform = nodeTransform)

  var camPos: Vec3f
  var camYaw: float32
  var camPitch: float32

  discard UpdateInputs() # clear inputs, otherwise MouseMove will have stuff

  var start = getMonoTime()
  var lastT = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time and UpdateInputs():
    let dt = ((getMonoTime() - lastT).inNanoseconds().int / 1_000_000_000).float32
    lastT = getMonoTime()

    camYaw  -= MouseMove().x / 1000
    camPitch -= MouseMove().y / 1000
    var
      forward = 0'f32
      sideward = 0'f32
    if KeyIsDown(W): forward += 2
    if KeyIsDown(S): forward -= 2
    if KeyIsDown(A): sideward -= 2
    if KeyIsDown(D): sideward += 2

    let camDir = (Rotate(camPitch, X) * Rotate(camYaw, Y)) * Z
    echo camDir
    let camDirSide = (Rotate(camPitch, X) * Rotate(camYaw, Y)) * X
    # echo camDir
    # echo camDirSide
    camPos += camDir * forward * dt
    camPos += camDirSide * sideward * dt

    descriptors.data.camera.data.viewPerspective = (
      Perspective(PI/3, aspect = GetAspectRatio(), zNear = 0.001, zFar = 100) *
      Rotate(-camPitch, X) * Rotate(-camYaw, Y) * Translate(-camPos)
    )

    UpdateGPUBuffer(descriptors.data.camera)

    WithNextFrame(framebuffer, commandbuffer):

      WithRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, NewVec4f(0, 0, 0, 0)):

        WithPipeline(commandbuffer, pipeline):
          WithBind(commandbuffer, (descriptors, ), pipeline):
            for nodeId in gltfData.scenes[0]:
              drawNode(commandbuffer = commandbuffer, pipeline = pipeline, nodeId = nodeId)
        WithBind(commandbuffer, (descriptors, ), pipeline):
          WithPipeline(commandbuffer, debugpipeline):
            Render(commandbuffer = commandbuffer, pipeline = debugpipeline, mesh = grid)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyPipeline(debugpipeline)
  DestroyRenderData(renderdata)
when isMainModule:
  var time = 1000'f32
  InitVulkan()

  var renderpass = CreateDirectPresentationRenderPass(depthBuffer = true, samples = VK_SAMPLE_COUNT_4_BIT)
  SetupSwapchain(renderpass = renderpass)
  LockMouse(true)

  # tests a simple triangle with minimalistic shader and vertex format
  test_gltf(time)

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
  ClearSwapchain()

  DestroyVulkan()
