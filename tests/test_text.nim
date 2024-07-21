import std/os
import std/strutils
import std/sequtils
import std/monotimes
import std/times
import std/options
import std/random

import ../semiconginev2

proc test_01_static_label(time: float32, swapchain: var Swapchain) =
  var renderdata = InitRenderData()

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

proc test_02_multiple_animated(time: float32, swapchain: var Swapchain) =
  var renderdata = InitRenderData()

  var pipeline = CreatePipeline[DefaultFontShader](renderPass = swapchain.renderPass)

  var font1 = LoadFont("Overhaul.ttf", lineHeightPixels = 40)
  var font2 = LoadFont("Overhaul.ttf", lineHeightPixels = 160)
  var font3 = LoadFont("DejaVuSans.ttf", lineHeightPixels = 160)
  var labels = [
    InitTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font1,
      "  0",
      color = NewVec4f(0, 1, 1, 1),
      scale = 0.004,
      position = NewVec3f(-0.3, 0.5)
    ),
    InitTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font2,
      "  1",
      color = NewVec4f(1, 0, 1, 1),
      scale = 0.001,
      position = NewVec3f(0, 0)
    ),
    InitTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font3,
      "  2",
      color = NewVec4f(1, 1, 0, 1),
      scale = 0.001,
      position = NewVec3f(0.3, -0.5)
    )
  ]

  var start = getMonoTime()
  var p = 0
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    for i in 0 ..< labels.len:
      var c = labels[i].Color
      c[i] = progress
      labels[i].Color = c
      labels[i].Scale = labels[i].Scale * (1.0 + (i + 1).float * 0.001)
      labels[i].Position = labels[i].Position + NewVec3f(0.001 * (i.float - 1'f))
      labels[i].text = $(p + i)
      labels[i].Refresh(swapchain.GetAspectRatio())
    inc p
    WithNextFrame(swapchain, framebuffer, commandbuffer):
      WithRenderPass(swapchain.renderPass, framebuffer, commandbuffer, swapchain.width, swapchain.height, NewVec4f(0, 0, 0, 0)):
        WithPipeline(commandbuffer, pipeline):
          for label in labels:
            Render(label, commandbuffer, pipeline, swapchain.currentFiF)

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  DestroyPipeline(pipeline)
  DestroyRenderData(renderdata)

proc test_03_layouting(time: float32, swapchain: var Swapchain) =
  discard # TODO
proc test_04_lots_of_texts(time: float32, swapchain: var Swapchain) =
  discard # TODO

when isMainModule:
  var time = 10'f32
  InitVulkan()

  var renderpass = CreateDirectPresentationRenderPass(depthBuffer = true)
  var swapchain = InitSwapchain(renderpass = renderpass).get()

  # tests a simple triangle with minimalistic shader and vertex format
  # test_01_static_label(time, swapchain)
  test_02_multiple_animated(time, swapchain)

  checkVkResult vkDeviceWaitIdle(vulkan.device)
  vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
  DestroySwapchain(swapchain)

  DestroyVulkan()
