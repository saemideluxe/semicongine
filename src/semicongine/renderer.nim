import std/options

import ./vulkan/api
import ./vulkan/device
import ./vulkan/physicaldevice
import ./vulkan/renderpass
import ./vulkan/swapchain

type
  Renderer = object
    surfaceFormat: VkSurfaceFormatKHR
    renderPasses: seq[RenderPass]
    swapchain: Swapchain


proc initRenderer(device: Device, renderPasses: seq[RenderPass]): Renderer =
  assert device.vk.valid
  assert renderPasses.len > 0
  for renderPass in renderPasses:
    assert renderPass.vk.valid

  result.renderPasses = renderPasses
  result.surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
  let (swapchain, res) = device.createSwapchain(renderPasses[^1], result.surfaceFormat, device.firstGraphicsQueue().get().family, 2)
  if res != VK_SUCCESS:
    raise newException(Exception, "Unable to create swapchain")
  result.swapchain = swapchain
