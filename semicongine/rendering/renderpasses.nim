proc createDirectPresentationRenderPass*(depthBuffer: bool, samples = VK_SAMPLE_COUNT_1_BIT): RenderPass =
  assert vulkan.instance.Valid, "Vulkan not initialized"
  result = RenderPass(depthBuffer: depthBuffer, samples: samples)

  var attachments = @[VkAttachmentDescription(
    format: SURFACE_FORMAT,
    samples: samples,
    loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
    storeOp: VK_ATTACHMENT_STORE_OP_STORE,
    stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
    stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    finalLayout: if samples == VK_SAMPLE_COUNT_1_BIT: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR else: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
  )]
  if depthBuffer:
    attachments.add VkAttachmentDescription(
      format: DEPTH_FORMAT,
      samples: samples,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    )
  if samples != VK_SAMPLE_COUNT_1_BIT:
    attachments.add VkAttachmentDescription(
      format: SURFACE_FORMAT,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )
  var
    dependencies = @[
      VkSubpassDependency(
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT],
        dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT],
        srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
      )
    ]
    colorAttachment = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    depthAttachment = VkAttachmentReference(
      attachment: 1,
      layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    )
    resolveAttachment = VkAttachmentReference(
      attachment: (attachments.len - 1).uint32, # depending on whether depthBuffer is used or not
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )

  result.vk = svkCreateRenderPass(
    attachments = attachments,
    colorAttachments = [colorAttachment],
    depthAttachments = if depthBuffer: @[depthAttachment] else: @[],
    resolveAttachments = if samples > VK_SAMPLE_COUNT_1_BIT: @[resolveAttachment] else: @[],
    dependencies = dependencies,
  )

proc createIndirectPresentationRenderPass*(depthBuffer: bool, samples = VK_SAMPLE_COUNT_1_BIT): (RenderPass, RenderPass) =
  assert vulkan.instance.Valid, "Vulkan not initialized"

  result[0] = RenderPass(depthBuffer: depthBuffer, samples: samples)
  result[1] = RenderPass(depthBuffer: false, samples: VK_SAMPLE_COUNT_1_BIT)

  # first renderpass, drawing
  var
    attachments = @[VkAttachmentDescription(
      format: SURFACE_FORMAT, # not strictly necessary
      samples: samples,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      # finalLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      finalLayout: if samples == VK_SAMPLE_COUNT_1_BIT: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL else: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )]
  if depthBuffer:
    attachments.add VkAttachmentDescription(
      format: DEPTH_FORMAT,
      samples: samples,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    )
  if samples != VK_SAMPLE_COUNT_1_BIT:
    attachments.add VkAttachmentDescription(
      format: SURFACE_FORMAT,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    )

  var
    dependencies = @[
      VkSubpassDependency(
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT],
        dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT],
        srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
      ),
      VkSubpassDependency(
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: toBits [VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT],
        dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        srcAccessMask: toBits [VK_ACCESS_SHADER_READ_BIT],
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
      ),
      VkSubpassDependency(
        srcSubpass: 0,
        dstSubpass: VK_SUBPASS_EXTERNAL,
        srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        dstStageMask: toBits [VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT],
        srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
        dstAccessMask: toBits [VK_ACCESS_SHADER_READ_BIT],
      ),
    ]
    colorAttachment = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    depthAttachment = VkAttachmentReference(
      attachment: 1,
      layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    )
    resolveAttachment = VkAttachmentReference(
      attachment: (attachments.len - 1).uint32, # depending on whether depthBuffer is used or not
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
  result[0].vk = svkCreateRenderPass(
    attachments = attachments,
    colorAttachments = [colorAttachment],
    depthAttachments = if depthBuffer: @[depthAttachment] else: @[],
    resolveAttachments = if samples > VK_SAMPLE_COUNT_1_BIT: @[resolveAttachment] else: @[],
    dependencies = dependencies
  )

  # second renderpass, presentation
  var
    presentAttachments = @[VkAttachmentDescription(
      format: SURFACE_FORMAT,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )]
    presentDependencies = @[VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
      dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
      srcAccessMask: VkAccessFlags(0),
      dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
    )]
    presentColorAttachment = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )

  result[1].vk = svkCreateRenderPass(
    attachments = presentAttachments,
    colorAttachments = [presentColorAttachment],
    depthAttachments = [],
    resolveAttachments = [],
    dependencies = presentDependencies
  )

template withRenderPass*(
  theRenderPass: RenderPass,
  theFramebuffer: VkFramebuffer,
  commandbuffer: VkCommandBuffer,
  renderWidth: uint32,
  renderHeight: uint32,
  clearColor: Vec4f,
  body: untyped
): untyped =
  var
    clearColors = [
      VkClearValue(color: VkClearColorValue(float32: clearColor)),
      VkClearValue(depthStencil: VkClearDepthStencilValue(depth: 1'f32, stencil: 0))
    ]
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: theRenderPass.vk,
      framebuffer: theFramebuffer,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: renderWidth, height: renderHeight),
      ),
      clearValueCount: clearColors.len.uint32,
      pClearValues: clearColors.ToCPointer(),
    )
    viewport = VkViewport(
      x: 0.0,
      y: renderHeight.float32,
      width: renderWidth.float32,
      height: -renderHeight.float32,
      minDepth: 0.0,
      maxDepth: 1.0,
    )
    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: VkExtent2D(width: renderWidth, height: renderHeight)
    )

  vkCmdBeginRenderPass(commandbuffer, addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

  # setup viewport
  vkCmdSetViewport(commandbuffer, firstViewport = 0, viewportCount = 1, addr(viewport))
  vkCmdSetScissor(commandbuffer, firstScissor = 0, scissorCount = 1, addr(scissor))

  block:
    body

  vkCmdEndRenderPass(commandbuffer)
