import std/options

import ./api
import ./utils
import ./device

type
  Subpass* = object
    flags: VkSubpassDescriptionFlags
    pipelineBindPoint: VkPipelineBindPoint
    inputs: seq[VkAttachmentReference]
    outputs: seq[VkAttachmentReference]
    resolvers: seq[VkAttachmentReference]
    depthStencil: Option[VkAttachmentReference]
    preserves: seq[uint32]
  RenderPass* = object
    vk*: VkRenderPass
    device: Device

proc createRenderPass*(
  device: Device,
  attachments: var seq[VkAttachmentDescription],
  subpasses: var seq[Subpass],
  dependencies: var seq[VkSubpassDependency]
): RenderPass =
  assert device.vk.valid

  var subpassesList = newSeq[VkSubpassDescription](subpasses.len)
  for subpass in subpasses.mitems:
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
      attachmentCount: uint32(attachments.len),
      pAttachments: attachments.toCPointer,
      subpassCount: uint32(subpassesList.len),
      pSubpasses: subpassesList.toCPointer,
      dependencyCount: uint32(dependencies.len),
      pDependencies: dependencies.toCPointer,
    )
  result.device = device
  checkVkResult device.vk.vkCreateRenderPass(addr(createInfo), nil, addr(result.vk))

proc createRenderAttachment(
  format: VkFormat,
  flags = VkAttachmentDescriptionFlags(0),
  samples = VK_SAMPLE_COUNT_1_BIT,
  loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
  storeOp = VK_ATTACHMENT_STORE_OP_STORE,
  stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
  stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
  initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
  finalLayout = VK_IMAGE_LAYOUT_GENERAL,
): auto =
  VkAttachmentDescription(
    format: format,
    flags: flags,
    samples: samples,
    loadOp: loadOp,
    storeOp: storeOp,
    stencilLoadOp: stencilLoadOp,
    stencilStoreOp: stencilStoreOp,
    initialLayout: initialLayout,
    finalLayout: finalLayout,
  )

proc simpleForwardRenderPass*(device: Device, format: VkFormat): RenderPass =
  assert device.vk.valid
  var
    attachments = @[createRenderAttachment(
      format = format,
      samples = VK_SAMPLE_COUNT_1_BIT,
      loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp = VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )]
    subpasses = @[
      Subpass(
        pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
        outputs: @[VkAttachmentReference(attachment: 0, layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)]
      )
    ]
    dependencies = @[
      VkSubpassDependency(
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        srcAccessMask: VkAccessFlags(0),
        dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
      )
    ]
  device.createRenderPass(attachments = attachments, subpasses = subpasses, dependencies = dependencies)

proc destroy*(renderpass: var RenderPass) =
  assert renderpass.device.vk.valid
  assert renderpass.vk.valid
  renderpass.device.vk.vkDestroyRenderPass(renderpass.vk, nil)
  renderpass.vk.reset
