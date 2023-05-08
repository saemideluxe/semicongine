import ../core
import ./device
import ./utils
import ./image


type
  Framebuffer* = object
    device*: Device
    vk*: VkFramebuffer
    dimension*: Vec2I

proc createFramebuffer*(device: Device, renderpass: VkRenderPass, attachments: openArray[ImageView], dimension: Vec2I): Framebuffer =
  assert device.vk.valid
  assert renderpass.valid

  result.device = device
  result.dimension = dimension

  var theattachments: seq[VkImageView]
  for a in attachments:
    assert a.vk.valid
    theattachments.add a.vk
  var framebufferInfo = VkFramebufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    renderPass: renderpass,
    attachmentCount: uint32(theattachments.len),
    pAttachments: theattachments.toCPointer,
    width: dimension[0],
    height: dimension[1],
    layers: 1,
  )
  checkVkResult device.vk.vkCreateFramebuffer(addr(framebufferInfo), nil, addr(result.vk))

proc destroy*(framebuffer: var Framebuffer) =
  assert framebuffer.device.vk.valid
  assert framebuffer.vk.valid
  framebuffer.device.vk.vkDestroyFramebuffer(framebuffer.vk, nil)
  framebuffer.vk.reset
