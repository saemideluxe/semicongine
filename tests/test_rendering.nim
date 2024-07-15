import std/options
import ../semicongine

var
  mainRenderpass: VkRenderPass
  swapchain: Swapchain

proc test_01_gl_triangle() =
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
    Empty = object
  var mesh = TriangleMesh(
    position: asGPUArray([NewVec3f(-0.5, -0.5), NewVec3f(-0.5, 0.5), NewVec3f(0.5, -0.5)], VertexBuffer),
    color: asGPUArray([NewVec3f(0, 0, 1), NewVec3f(0, 1, 0), NewVec3f(1, 0, 0)], VertexBuffer),
  )

  var
    pipeline = CreatePipeline[TrianglShader](renderPass = mainRenderpass)
    a, b: Empty

  while UpdateInputs():
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(mainRenderpass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          # WithBind(commandBuffer, a, b, pipeline, swapchain.currentFiF.int):
            Render(
              commandbuffer = commandbuffer,
              pipeline = pipeline,
              globalSet = a,
              materialSet = b,
              mesh = mesh,
            )

  # cleanup
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)


when isMainModule:
  mainRenderpass = CreatePresentationRenderPass()
  swapchain = InitSwapchain(renderpass = mainRenderpass).get()

  test_01_gl_triangle()

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, mainRenderpass, nil)
  DestroySwapchain(swapchain)
  DestroyVulkan()
