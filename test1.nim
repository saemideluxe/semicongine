import std/os
import std/monotimes
import std/times
import std/options

import semicongine

type
  MeshA = object
    position: GPUArray[Vec3f, VertexBuffer]
    indices: GPUArray[uint16, IndexBuffer]
  InstanceA = object
    rotation: GPUArray[Vec4f, VertexBuffer]
    objPosition: GPUArray[Vec3f, VertexBuffer]
  MaterialA = object
    reflection: float32
    baseColor: Vec3f
  UniformsA = object
    defaultTexture: Texture[TVec4[uint8]]
    defaultMaterial: GPUValue[MaterialA, UniformBuffer]
    materials: GPUValue[array[3, MaterialA], UniformBuffer]
    materialTextures: array[3, Texture[TVec4[uint8]]]
  ShaderSettings = object
    gamma: float32
  GlobalsA = object
    fontAtlas: Texture[TVec4[uint8]]
    settings: GPUValue[ShaderSettings, UniformBuffer]

  ShaderA = object
    # vertex input
    position {.VertexAttribute.}: Vec3f
    # objPosition {.InstanceAttribute.}: Vec3f
    # rotation {.InstanceAttribute.}: Vec4f
    # intermediate
    test {.Pass.}: float32
    test1 {.PassFlat.}: Vec3f
    # output
    color {.ShaderOutput.}: Vec4f
    # descriptor sets
    globals: DescriptorSet[GlobalsA, GlobalSet]
    uniforms: DescriptorSet[UniformsA, MaterialSet]
    # code
    vertexCode: string = """void main() {
    gl_Position = vec4(position, 1);
}"""
    fragmentCode: string = """void main() {
    color = vec4(1, 0, 0, 1);
}"""

var myMesh1 = MeshA(
  position: GPUArray[Vec3f, VertexBuffer](data: @[NewVec3f(-0.5, 0.5, ), NewVec3f(0, -0.5, ), NewVec3f(0.5, 0.5, )]),
  indices: GPUArray[uint16, IndexBuffer](data: @[0'u16, 1'u16, 2'u16])
)
var uniforms1 = DescriptorSet[UniformsA, MaterialSet](
  data: UniformsA(
    defaultTexture: Texture[TVec4[uint8]](width: 1, height: 1, data: @[TVec4[uint8]([0'u8, 0'u8, 0'u8, 1'u8])]),
    materials: GPUValue[array[3, MaterialA], UniformBuffer](data: [
      MaterialA(reflection: 0, baseColor: NewVec3f(1, 0, 0)),
      MaterialA(reflection: 0.1, baseColor: NewVec3f(0, 1, 0)),
      MaterialA(reflection: 0.5, baseColor: NewVec3f(0, 0, 1)),
  ]),
  materialTextures: [
    Texture[TVec4[uint8]](width: 1, height: 1, data: @[TVec4[uint8]([0'u8, 0'u8, 0'u8, 1'u8])]),
    Texture[TVec4[uint8]](width: 1, height: 1, data: @[TVec4[uint8]([0'u8, 0'u8, 0'u8, 1'u8])]),
    Texture[TVec4[uint8]](width: 1, height: 1, data: @[TVec4[uint8]([0'u8, 0'u8, 0'u8, 1'u8])]),
  ]
)
)
var instances1 = InstanceA(
  rotation: GPUArray[Vec4f, VertexBuffer](data: @[NewVec4f(1, 0, 0, 0.1), NewVec4f(0, 1, 0, 0.1)]),
  objPosition: GPUArray[Vec3f, VertexBuffer](data: @[NewVec3f(0, 0, 0), NewVec3f(1, 1, 1)]),
)
var myGlobals = DescriptorSet[GlobalsA, GlobalSet](
  data: GlobalsA(
    fontAtlas: Texture[TVec4[uint8]](width: 1, height: 1, data: @[TVec4[uint8]([0'u8, 0'u8, 0'u8, 1'u8])]),
    settings: GPUValue[ShaderSettings, UniformBuffer](data: ShaderSettings(gamma: 1.0))
  )
)

let mainRenderpass = CreatePresentationRenderPass()
var swapchain = InitSwapchain(renderpass = mainRenderpass).get()
var pipeline1 = CreatePipeline[ShaderA](renderPass = mainRenderpass)

var renderdata = InitRenderData()

# buffer assignment
echo "Assigning buffers to GPUData fields"

AssignBuffers(renderdata, myMesh1)
AssignBuffers(renderdata, instances1)
AssignBuffers(renderdata, myGlobals)
AssignBuffers(renderdata, uniforms1)

renderdata.UploadTextures(myGlobals)
renderdata.UploadTextures(uniforms1)

# copy everything to GPU
echo "Copying all data to GPU memory"
UpdateAllGPUBuffers(myMesh1)
UpdateAllGPUBuffers(instances1)
UpdateAllGPUBuffers(uniforms1)
UpdateAllGPUBuffers(myGlobals)
renderdata.FlushAllMemory()

# descriptors
echo "Writing descriptors"
InitDescriptorSet(renderdata, pipeline1.GetLayoutFor(GlobalSet), myGlobals)
InitDescriptorSet(renderdata, pipeline1.GetLayoutFor(MaterialSet), uniforms1)


# main loop
var t = getMonoTime()
while UpdateInputs():
  WithNextFrame(swapchain, framebuffer, commandbuffer):
    WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
      WithPipeline(commandbuffer, pipeline1):
        WithBind(commandBuffer, myGlobals, uniforms1, pipeline1, swapchain.currentFiF.int):
          Render(
            commandbuffer = commandbuffer,
            pipeline = pipeline1,
            globalSet = myGlobals,
            materialSet = uniforms1,
            mesh = myMesh1,
            # instances = instances1,
          )
  echo (getMonoTime() - t).inMicroseconds.float / 1000.0
  t = getMonoTime()

# cleanup
checkVkResult vkDeviceWaitIdle(vulkan.device)
DestroyPipeline(pipeline1)
vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
DestroyRenderData(renderdata)
DestroySwapchain(swapchain)
DestroyVulkan()
