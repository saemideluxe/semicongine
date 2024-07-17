proc CreateDirectPresentationRenderPass*(samples = VK_SAMPLE_COUNT_1_BIT): VkRenderPass =
  assert vulkan.instance.Valid, "Vulkan not initialized"

  let format = DefaultSurfaceFormat()
  var attachments = @[VkAttachmentDescription(
    format: format,
    samples: samples,
    loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
    storeOp: VK_ATTACHMENT_STORE_OP_STORE,
    stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
    stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    finalLayout: if samples == VK_SAMPLE_COUNT_1_BIT: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR else: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
  )]
  if samples != VK_SAMPLE_COUNT_1_BIT:
    attachments.add VkAttachmentDescription(
      format: format,
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
        srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
      )
    ]
    colorAttachment = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    resolveAttachment = VkAttachmentReference(
      attachment: 1,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )

  if samples == VK_SAMPLE_COUNT_1_BIT:
    return svkCreateRenderPass(attachments, [colorAttachment], [], dependencies)
  else:
    return svkCreateRenderPass(attachments, [colorAttachment], [resolveAttachment], dependencies)

proc CreateIndirectPresentationRenderPass*(): (VkRenderPass, VkRenderPass) =
  assert vulkan.instance.Valid, "Vulkan not initialized"

  # first renderpass, drawing
  let format = DefaultSurfaceFormat()
  var
    attachments = @[VkAttachmentDescription(
      format: format,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    )]

    dependencies = @[
      VkSubpassDependency(
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
        srcAccessMask: VkAccessFlags(0),
        dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT],
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

  # second renderpass, presentation
  var
    presentAttachments = @[VkAttachmentDescription(
      format: format,
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

  result = (
    svkCreateRenderPass(attachments, [colorAttachment], [], dependencies),
    svkCreateRenderPass(presentAttachments, [presentColorAttachment], [], presentDependencies)
  )

template WithRenderPass*(
  theRenderpass: VkRenderPass,
  theFramebuffer: VkFramebuffer,
  commandbuffer: VkCommandBuffer,
  renderWidth: uint32,
  renderHeight: uint32,
  clearColor: Vec4f,
  body: untyped
): untyped =
  var
    clearColors = [VkClearValue(color: VkClearColorValue(float32: clearColor))]
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: theRenderpass,
      framebuffer: theFramebuffer,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: renderWidth, height: renderHeight),
      ),
      clearValueCount: uint32(clearColors.len),
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
