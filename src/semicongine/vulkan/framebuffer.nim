import ./api
import ./device
import ./utils
import ./image
import ./renderpass

import ../math

type
  Framebuffer* = object
    device*: Device
    vk*: VkFramebuffer

proc createFramebuffer*(device: Device, renderPass: RenderPass, attachments: openArray[ImageView], dimension: TVec2[uint32]): Framebuffer =
  assert device.vk.valid
  assert renderpass.vk.valid
  var theattachments: seq[VkImageView]
  for a in attachments:
    assert a.vk.valid
    theattachments.add a.vk
  var framebufferInfo = VkFramebufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    renderPass: renderPass.vk,
    attachmentCount: uint32(theattachments.len),
    pAttachments: theattachments.toCPointer,
    width: dimension[0],
    height: dimension[1],
    layers: 1,
  )
  result.device = device
  checkVkResult device.vk.vkCreateFramebuffer(addr(framebufferInfo), nil, addr(result.vk))

proc destroy*(framebuffer: var Framebuffer) =
  assert framebuffer.device.vk.valid
  assert framebuffer.vk.valid
  framebuffer.device.vk.vkDestroyFramebuffer(framebuffer.vk, nil)
  framebuffer.vk.reset
