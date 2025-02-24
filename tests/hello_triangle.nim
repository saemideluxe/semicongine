import ../semicongine
import ../semicongine/rendering
import ../semicongine/input

# required
initEngine("Hello triangle")

# set up a simple render pass to render the displayed frame
var renderpass = createDirectPresentationRenderPass(
  depthBuffer = false, samples = VK_SAMPLE_COUNT_1_BIT
)

# the swapchain, needs to be attached to the main renderpass
setupSwapchain(renderpass = renderpass)

# render data is used for memory management on the GPU
var renderdata = initRenderData()

type
  # define a push constant, to have something moving
  PushConstant = object
    scale: float32

  # This is how we define shaders: the interface needs to be "typed"
  # but the shader code itself can freely be written in glsl
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

  # And we also need to define our Mesh, which does describe the vertex layout
  TriangleMesh = object
    position: GPUArray[Vec3f, VertexBuffer]
    color: GPUArray[Vec3f, VertexBuffer]

# instantiate the mesh and fill with data
var mesh = TriangleMesh(
  position: asGPUArray([vec3(-0.5, -0.5), vec3(0, 0.5), vec3(0.5, -0.5)], VertexBuffer),
  color: asGPUArray([vec3(0, 0, 1), vec3(0, 1, 0), vec3(1, 0, 0)], VertexBuffer),
)

# this allocates GPU data, uploads the data to the GPU and flushes any thing that is host-cached
# this is a shortcut version, more fine-grained control is possible
assignBuffers(renderdata, mesh)
renderdata.flushAllMemory()

# Now we need to instantiate the shader as a pipeline object that is attached to a renderpass
var pipeline = createPipeline(Shader(), renderPass = renderPass)

# the main render-loop will exit if we get a kill-signal from the OS
while updateInputs():
  # starts the drawing for the next frame and provides us necesseary framebuffer and commandbuffer objects in this scope
  withNextFrame(framebuffer, commandbuffer):
    # start the main (and only) renderpass we have, needs to know the target framebuffer and a commandbuffer
    withRenderPass(
      renderPass,
      framebuffer,
      commandbuffer,
      frameWidth(),
      frameHeight(),
      vec4(0, 0, 0, 0),
    ):
      # now activate our shader-pipeline
      withPipeline(commandbuffer, pipeline):
        # and finally, draw the mesh and set a single parameter
        # more complicated setups with descriptors/uniforms are of course possible
        renderWithPushConstant(
          commandbuffer = commandbuffer,
          pipeline = pipeline,
          mesh = mesh,
          pushConstant = PushConstant(scale: 0.3),
        )

# cleanup
checkVkResult vkDeviceWaitIdle(engine().vulkan.device)
destroyPipeline(pipeline)
destroyRenderData(renderdata)
destroyRenderPass(renderpass)
destroyVulkan()
