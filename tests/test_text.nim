import std/os
import std/sequtils
import std/monotimes
import std/times
import std/options
import std/random

import ../semiconginev2

proc test_01_static_label(time: float32, swapchain: var Swapchain) =
  var renderdata = InitRenderData()

  # scale: float32 = 1,
  # position: Vec3f = NewVec3f(),
  # color: Vec4f = NewVec4f(0, 0, 0, 1),

  var pipeline = CreatePipeline[DefaultFontShader](renderPass = swapchain.renderPass)

  var font = LoadFont("Overhaul.ttf", lineHeightPixels = 160)
  var label1 = InitTextbox(
    renderdata,
    pipeline.descriptorSetLayouts[0],
    font,
    "Hello semicongine!",
    color = NewVec4f(1, 1, 1, 1),
    scale = 0.0005,
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    label1.Refresh(swapchain.GetAspectRatio())
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          Render(label1, commandbuffer, pipeline, swapchain.currentFiF)

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

when isMainModule:
  var time = 10'f32
  InitVulkan()

  var renderpass = CreateDirectPresentationRenderPass(depthBuffer = true)
  var swapchain = InitSwapchain(renderpass = renderpass).get()

  # tests a simple triangle with minimalistic shader and vertex format
  test_01_static_label(time, swapchain)

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
  DestroySwapchain(swapchain)

  DestroyVulkan()
