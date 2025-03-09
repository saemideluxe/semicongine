import std/math
import std/sequtils
import std/monotimes
import std/times
import std/options

import ../semicongine
import ../semicongine/rendering
import ../semicongine/loaders
import ../semicongine/input
import ../semicongine/gltf

proc test_gltf(time: float32, renderPass: RenderPass) =
  var renderdata = initRenderData()

  type
    ObjectData = object
      transform: Mat4
      materialId: int32

    Camera = object
      view: Mat4
      normal: Mat4
      projection: Mat4

    Material = object
      color: Vec4f = vec4(1, 1, 1, 1)
      # colorTexture: int32 = -1
      metallic: float32 = 0
      roughness: float32 = 0
      # metallicRoughnessTexture: int32 = -1
      # normalTexture: int32 = -1
      # occlusionTexture: int32 = -1
      emissive: Vec4f = vec4(0, 0, 0, 0) # emissiveTexture: int32 = -1

    MainDescriptors = object
      materials: array[50, GPUValue[Material, UniformBuffer]]
      camera: GPUValue[Camera, UniformBufferMapped]

    Shader = object
      objectData {.PushConstant.}: ObjectData
      position {.VertexAttribute.}: Vec3f
      color {.VertexAttribute.}: Vec4f
      normal {.VertexAttribute.}: Vec3f
      fragmentPosition {.Pass.}: Vec3f
      fragmentColor {.Pass.}: Vec4f
      fragmentNormal {.Pass.}: Vec3f
      outColor {.ShaderOutput.}: Vec4f
      descriptors {.DescriptorSet: 0.}: MainDescriptors
      # code
      vertexCode: string =
        """
void main() {
  mat4 modelView = objectData.transform * camera.view;
  mat3 normalMat = mat3(transpose(inverse(objectData.transform)));
  vec4 posTransformed = vec4(position, 1) * modelView;
  fragmentPosition = posTransformed.xyz / posTransformed.w;
  fragmentColor = color * materials[objectData.materialId].color;
  fragmentNormal = normal * normalMat;
  gl_Position = vec4(position, 1) * (modelView * camera.projection);
}"""
      fragmentCode: string =
        """
const vec3 lightPosition = vec3(7, 9, -12);
const float shininess = 40;
const vec3 ambientColor = vec3(0, 0, 0);
const vec3 lightColor = vec3(1, 1, 1);
// const vec3 specColor = vec3(1, 1, 1);
const float lightPower = 20;
void main() {
  // some setup
  vec3 normal = normalize(fragmentNormal);
  vec3 lightDir = lightPosition - fragmentPosition;
  float dist = length(lightDir);
  lightDir = normalize(lightDir);

  float lambertian = max(dot(lightDir, normal), 0);
  float specular = 0;

  // blinn-phong
  if (lambertian > 0) {
    vec3 viewDir = normalize(-fragmentPosition);
    vec3 halfDir = normalize(lightDir + viewDir);
    float specAngle = max(dot(halfDir, normal), 0.0);
    specular = pow(specAngle, shininess);
  }

  vec3 diffuseColor = fragmentColor.rgb;
  vec3 specColor = diffuseColor;
  vec3 color = ambientColor + diffuseColor * lambertian * lightColor * lightPower / dist + specColor * specular * lightColor * lightPower / dist;

  outColor = vec4(color, fragmentColor.a);
}"""

    Mesh = object
      position: GPUArray[Vec3f, VertexBuffer]
      color: GPUArray[Vec4f, VertexBuffer]
      normal: GPUArray[Vec3f, VertexBuffer]
      indices: GPUArray[uint32, IndexBuffer]

  var gltfData = loadMeshes[Mesh, Material](
    "town.glb",
    # "forest.glb",
    MeshAttributeNames(
      POSITION: "position", COLOR: @["color"], NORMAL: "normal", indices: "indices"
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
    ),
  )
  var descriptors = asDescriptorSetData(
    MainDescriptors(
      camera: asGPUValue(
        Camera(view: Unit4, normal: Unit4, projection: Unit4), UniformBufferMapped
      )
    )
  )
  for i in 0 ..< gltfData.materials.len:
    descriptors.data.materials[i] = asGPUValue(gltfData.materials[i], UniformBuffer)
  for mesh in mitems(gltfData.meshes):
    for primitive in mitems(mesh.primitives):
      primitive.data.color = asGPUArray(
        newSeqWith(primitive.data.position.data.len, vec4(1, 1, 1, 1)), VertexBuffer
      )
      renderdata.assignBuffers(primitive.data)
  renderdata.assignBuffers(descriptors)

  var pipeline = createPipeline(Shader(), renderPass = renderPass, cullMode = [])
  initDescriptorSet(renderdata, pipeline.descriptorSetLayouts[0], descriptors)

  renderdata.flushAllMemory()

  proc drawNode(
      commandbuffer: VkCommandBuffer, pipeline: Pipeline, nodeId: int, transform: Mat4
  ) =
    let nodeTransform = gltfData.nodes[nodeId].transform * transform
    if gltfData.nodes[nodeId].mesh >= 0:
      for primitive in gltfData.meshes[gltfData.nodes[nodeId].mesh].primitives:
        renderWithPushConstant(
          commandbuffer = commandbuffer,
          pipeline = pipeline,
          mesh = primitive.data,
          pushConstant =
            ObjectData(transform: nodeTransform, materialId: primitive.material.int32),
        )
    for childNode in gltfData.nodes[nodeId].children:
      drawNode(
        commandbuffer = commandbuffer,
        pipeline = pipeline,
        nodeId = childNode,
        transform = nodeTransform,
      )

  var camPos: Vec3f
  var camYaw: float32
  var camPitch: float32

  discard updateInputs() # clear inputs, otherwise MouseMove will have stuff

  var start = getMonoTime()
  var lastT = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time and updateInputs():
    let dt = ((getMonoTime() - lastT).inNanoseconds().int / 1_000_000_000).float32
    lastT = getMonoTime()

    camYaw += mouseMove().x.float32 / 1000'f32
    camPitch += mouseMove().y.float32 / 1000'f32
    var
      forward = 0'f32
      sideward = 0'f32
    if keyIsDown(W):
      forward += 2
    if keyIsDown(S):
      forward -= 2
    if keyIsDown(A):
      sideward -= 2
    if keyIsDown(D):
      sideward += 2

    let camDir = (rotate(camYaw, Y) * rotate(camPitch, X)) * Z
    let camDirSide = camDir.cross(-Y).normalized
    camPos += camDir * forward * dt
    camPos += camDirSide * sideward * dt

    let view = rotate(-camPitch, X) * rotate(-camYaw, Y) * translate(-camPos)
    descriptors.data.camera.data.view = view
    descriptors.data.camera.data.normal = view
    descriptors.data.camera.data.projection =
      projection(PI / 2, aspect = getAspectRatio(), zNear = 0.01, zFar = 20)

    updateGPUBuffer(descriptors.data.camera)

    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        renderPass,
        framebuffer,
        commandbuffer,
        frameWidth(),
        frameHeight(),
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, descriptors, 0, pipeline)
          for nodeId in gltfData.scenes[0]:
            drawNode(
              commandbuffer = commandbuffer,
              pipeline = pipeline,
              nodeId = nodeId,
              transform = rotate(PI / 2, Z),
            )

  # cleanup
  checkVkResult vkDeviceWaitIdle(engine().vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

when isMainModule:
  var time = 1000'f32
  initEngine("Test glTF")

  var renderpass = createDirectPresentationRenderPass(
    depthBuffer = true, samples = VK_SAMPLE_COUNT_4_BIT
  )
  setupSwapchain(renderpass = renderpass)
  lockMouse(true)
  # showSystemCursor(false)

  # tests a simple triangle with minimalistic shader and vertex format
  test_gltf(time, renderpass)

  checkVkResult vkDeviceWaitIdle(engine().vulkan.device)
  destroyRenderPass(renderpass)
  clearSwapchain()

  destroyVulkan()
