import std/os
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
    objPosition {.InstanceAttribute.}: Vec3f
    rotation {.InstanceAttribute.}: Vec4f
    # intermediate
    test {.Pass.}: float32
    test1 {.PassFlat.}: Vec3f
    # output
    color {.ShaderOutput.}: Vec4f
    # descriptor sets
    globals: DescriptorSet[GlobalsA, GlobalSet]
    uniforms: DescriptorSet[UniformsA, MaterialSet]
    # code
    vertexCode: string = "void main() {}"
    fragmentCode: string = "void main() {}"

let frameWidth = 100'u32
let frameHeight = 100'u32

var myMesh1 = MeshA(
  position: GPUArray[Vec3f, VertexBuffer](data: @[NewVec3f(0, 0, ), NewVec3f(0, 0, ), NewVec3f(0, 0, )]),
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

let renderpass = CreatePresentationRenderPass()
var swapchainResult = InitSwapchain(renderpass = renderpass)
assert swapchainResult.isSome()
var swapchain = swapchainResult.get()

# shaders
var pipeline1 = CreatePipeline[ShaderA](renderPass = renderpass)

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


# start command buffer
while true:
  RecordRenderingCommands(swapchain, framebuffer, commandbuffer):
    var
      clearColors = [VkClearValue(color: VkClearColorValue(float32: [0, 0, 0, 0]))]
      renderPassInfo = VkRenderPassBeginInfo(
        sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        renderPass: renderpass,
        framebuffer: framebuffer,
        renderArea: VkRect2D(
          offset: VkOffset2D(x: 0, y: 0),
          extent: VkExtent2D(width: frameWidth, height: frameHeight),
        ),
        clearValueCount: uint32(clearColors.len),
        pClearValues: clearColors.ToCPointer(),
      )
      viewport = VkViewport(
        x: 0.0,
        y: 0.0,
        width: frameWidth.float32,
        height: frameHeight.float32,
        minDepth: 0.0,
        maxDepth: 1.0,
      )
      scissor = VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: frameWidth, height: frameHeight)
      )
    vkCmdBeginRenderPass(commandbuffer, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

    # setup viewport
    vkCmdSetViewport(commandbuffer, firstViewport = 0, viewportCount = 1, addr(viewport))
    vkCmdSetScissor(commandbuffer, firstScissor = 0, scissorCount = 1, addr(scissor))

    # bind pipeline, will be loop
    # block:
      # Bind(pipeline1, commandbuffer, currentFrameInFlight = currentFrameInFlight)

      # render object, will be loop
      # block:
        # Render(commandbuffer, pipeline1, myGlobals, uniforms1, myMesh1, instances1)

    vkCmdEndRenderPass(commandbuffer)
