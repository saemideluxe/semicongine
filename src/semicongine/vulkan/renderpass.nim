import std/options
import std/logging

import ./api
import ./utils
import ./device
import ./physicaldevice
import ./pipeline
import ./shader
import ./framebuffer

import ../math

type
  Subpass* = object
    clearColor*: Vec4f
    pipelineBindPoint*: VkPipelineBindPoint
    flags: VkSubpassDescriptionFlags
    inputs: seq[VkAttachmentReference]
    outputs: seq[VkAttachmentReference]
    resolvers: seq[VkAttachmentReference]
    depthStencil: Option[VkAttachmentReference]
    preserves: seq[uint32]
    pipelines*: seq[Pipeline]
  RenderPass* = object
    vk*: VkRenderPass
    device*: Device
    subpasses*: seq[Subpass]

proc createRenderPass*(
  device: Device,
  attachments: seq[VkAttachmentDescription],
  subpasses: seq[Subpass],
  dependencies: seq[VkSubpassDependency],
): RenderPass =
  assert device.vk.valid
  var pAttachments = attachments
  var pSubpasses = subpasses
  var pDependencies = dependencies

  var subpassesList: seq[VkSubpassDescription]
  for subpass in pSubpasses.mitems:
    subpassesList.add VkSubpassDescription(
      flags: subpass.flags,
      pipelineBindPoint: subpass.pipelineBindPoint,
      inputAttachmentCount: uint32(subpass.inputs.len),
      pInputAttachments: subpass.inputs.toCPointer,
      colorAttachmentCount: uint32(subpass.outputs.len),
      pColorAttachments: subpass.outputs.toCPointer,
      pResolveAttachments: subpass.resolvers.toCPointer,
      pDepthStencilAttachment: if subpass.depthStencil.isSome: addr(subpass.depthStencil.get) else: nil,
      preserveAttachmentCount: uint32(subpass.preserves.len),
      pPreserveAttachments: subpass.preserves.toCPointer,
    )

  var createInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: uint32(pAttachments.len),
      pAttachments: pAttachments.toCPointer,
      subpassCount: uint32(subpassesList.len),
      pSubpasses: subpassesList.toCPointer,
      dependencyCount: uint32(pDependencies.len),
      pDependencies: pDependencies.toCPointer,
    )
  result.device = device
  result.subpasses = pSubpasses
  checkVkResult device.vk.vkCreateRenderPass(addr(createInfo), nil, addr(result.vk))

proc simpleForwardRenderPass*(
  device: Device,
  vertexCode: ShaderCode,
  fragmentCode: ShaderCode,
  inFlightFrames=2,
  format=VK_FORMAT_UNDEFINED ,
  clearColor=Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32])
): RenderPass =
  assert device.vk.valid
  assert fragmentCode.outputs.len == 1
  var theformat = format
  if theformat == VK_FORMAT_UNDEFINED:
    theformat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat().format
  var
    attachments = @[VkAttachmentDescription(
        format: theformat,
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )]
    subpasses = @[
      Subpass(
        pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
        outputs: @[VkAttachmentReference(attachment: 0, layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)],
        clearColor: clearColor
      )
    ]
    # dependencies seems to be optional, TODO: benchmark difference
    dependencies = @[VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
      srcAccessMask: VkAccessFlags(0),
      dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
      dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
    )]
  result = device.createRenderPass(attachments=attachments, subpasses=subpasses, dependencies=dependencies)
  result.subpasses[0].pipelines.add device.createPipeline(result.vk, vertexCode, fragmentCode, inFlightFrames, 0)

proc beginRenderCommands*(commandBuffer: VkCommandBuffer, renderpass: RenderPass, framebuffer: Framebuffer) =
  assert commandBuffer.valid
  assert renderpass.vk.valid
  assert framebuffer.vk.valid
  let
    w = framebuffer.dimension.x
    h = framebuffer.dimension.y

  var clearColors: seq[VkClearValue]
  for subpass in renderpass.subpasses:
    clearColors.add(VkClearValue(color: VkClearColorValue(float32: subpass.clearColor)))
  var
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pInheritanceInfo: nil,
    )
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: renderPass.vk,
      framebuffer: framebuffer.vk,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: w, height: h),
      ),
      clearValueCount: uint32(clearColors.len),
      pClearValues: clearColors.toCPointer(),
    )
    viewport = VkViewport(
      x: 0.0,
      y: 0.0,
      width: (float)w,
      height: (float)h,
      minDepth: 0.0,
      maxDepth: 1.0,
    )
    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: VkExtent2D(width: w, height: h)
    )
  checkVkResult commandBuffer.vkResetCommandBuffer(VkCommandBufferResetFlags(0))
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))
  commandBuffer.vkCmdBeginRenderPass(addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)
  commandBuffer.vkCmdSetViewport(firstViewport=0, viewportCount=1, addr(viewport))
  commandBuffer.vkCmdSetScissor(firstScissor=0, scissorCount=1, addr(scissor))

proc endRenderCommands*(commandBuffer: VkCommandBuffer) =
  commandBuffer.vkCmdEndRenderPass()
  checkVkResult commandBuffer.vkEndCommandBuffer()


proc destroy*(renderPass: var RenderPass) =
  assert renderPass.device.vk.valid
  assert renderPass.vk.valid
  renderPass.device.vk.vkDestroyRenderPass(renderPass.vk, nil)
  renderPass.vk.reset
  for subpass in renderPass.subpasses.mitems:
    for pipeline in subpass.pipelines.mitems:
      pipeline.destroy()
  renderPass.subpasses = @[]
