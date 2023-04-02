import std/options

import ./api
import ./utils
import ./device
import ./pipeline
import ./shader

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
    inFlightFrames*: int
    subpasses*: seq[Subpass]

proc createRenderPass*(
  device: Device,
  attachments: seq[VkAttachmentDescription],
  subpasses: seq[Subpass],
  dependencies: seq[VkSubpassDependency],
  inFlightFrames: int,
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
  result.inFlightFrames = inFlightFrames
  result.subpasses = pSubpasses
  checkVkResult device.vk.vkCreateRenderPass(addr(createInfo), nil, addr(result.vk))

proc simpleForwardRenderPass*(device: Device, format: VkFormat, vertexShader: Shader, fragmentShader: Shader, inFlightFrames: int, clearColor=Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32])): RenderPass =
  assert device.vk.valid
  var
    attachments = @[VkAttachmentDescription(
        format: format,
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
  result = device.createRenderPass(attachments=attachments, subpasses=subpasses, dependencies=dependencies, inFlightFrames=inFlightFrames)
  result.subpasses[0].pipelines.add device.createPipeline(result.vk, vertexShader, fragmentShader, inFlightFrames, 0)

proc destroy*(renderPass: var RenderPass) =
  assert renderPass.device.vk.valid
  assert renderPass.vk.valid
  renderPass.device.vk.vkDestroyRenderPass(renderPass.vk, nil)
  renderPass.vk.reset
  for subpass in renderPass.subpasses.mitems:
    for pipeline in subpass.pipelines.mitems:
      pipeline.destroy()
  renderPass.subpasses = @[]
