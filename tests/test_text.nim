import std/os
import std/algorithm
import std/strutils
import std/sequtils
import std/monotimes
import std/times
import std/options
import std/random

import ../semicongine

proc test_01_static_label(time: float32) =
  var renderdata = initRenderData()

  var pipeline = createPipeline[DefaultFontShader](renderPass = vulkan.swapchain.renderPass)

  var font = loadFont("Overhaul.ttf", lineHeightPixels = 160)
  var label1 = initTextbox(
    renderdata,
    pipeline.descriptorSetLayouts[0],
    font,
    "Hello semicongine!",
    color = vec4(1, 1, 1, 1),
    scale = 0.0005,
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    label1.refresh()
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, vec4(0, 0, 0, 0)):
        withPipeline(commandbuffer, pipeline):
          render(label1, commandbuffer, pipeline)

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_02_multiple_animated(time: float32) =
  var renderdata = initRenderData()

  var pipeline = createPipeline[DefaultFontShader](renderPass = vulkan.swapchain.renderPass)

  var font1 = loadFont("Overhaul.ttf", lineHeightPixels = 40)
  var font2 = loadFont("Overhaul.ttf", lineHeightPixels = 160)
  var font3 = loadFont("DejaVuSans.ttf", lineHeightPixels = 160)
  var labels = [
    initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font1,
      "  0",
      color = vec4(0, 1, 1, 1),
      scale = 0.004,
      position = vec3(-0.3, 0.5)
    ),
    initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font2,
      "  1",
      color = vec4(1, 0, 1, 1),
      scale = 0.001,
      position = vec3(0, 0)
    ),
    initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font3,
      "  2",
      color = vec4(1, 1, 0, 1),
      scale = 0.001,
      position = vec3(0.3, -0.5)
    )
  ]

  var start = getMonoTime()
  var p = 0
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    for i in 0 ..< labels.len:
      var c = labels[i].color
      c[i] = progress
      labels[i].color = c
      labels[i].scale = labels[i].scale * (1.0 + (i + 1).float * 0.001)
      labels[i].position = labels[i].position + vec3(0.001 * (i.float - 1'f))
      labels[i].text = $(p + i)
      labels[i].refresh()
    inc p
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, vec4(0, 0, 0, 0)):
        withPipeline(commandbuffer, pipeline):
          for label in labels:
            render(label, commandbuffer, pipeline)

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_03_layouting(time: float32) =
  var renderdata = initRenderData()

  var pipeline = createPipeline[DefaultFontShader](renderPass = vulkan.swapchain.renderPass)

  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 40)
  var labels: seq[Textbox]

  for horizontal in HorizontalAlignment:
    labels.add initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font,
      $horizontal & " aligned",
      color = vec4(1, 1, 1, 1),
      scale = 0.001,
      position = vec3(0, 0.9 - (horizontal.float * 0.15)),
      horizontalAlignment = horizontal,
    )
  for vertical in VerticalAlignment:
    labels.add initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font,
      $vertical & " aligned",
      color = vec4(1, 1, 1, 1),
      scale = 0.001,
      position = vec3(-0.35 + (vertical.float * 0.35), 0.3),
      verticalAlignment = vertical,
    )
  labels.add initTextbox(
    renderdata,
    pipeline.descriptorSetLayouts[0],
    font,
    """Paragraph
This is a somewhat longer paragraph with a few newlines and a maximum width of 0.2.

It should display with some space above and have a pleasing appearance overall! :)""",
    maxWidth = 0.6,
    color = vec4(1, 1, 1, 1),
    scale = 0.001,
    position = vec3(-0.9, 0.1),
    verticalAlignment = Top,
    horizontalAlignment = Left,
  )


  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, vec4(0, 0, 0, 0)):
        withPipeline(commandbuffer, pipeline):
          for label in labels:
            render(label, commandbuffer, pipeline)

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_04_lots_of_texts(time: float32) =
  var renderdata = initRenderData()

  var pipeline = createPipeline[DefaultFontShader](renderPass = vulkan.swapchain.renderPass)

  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 160)
  var labels: seq[Textbox]
  for i in 0 ..< 100:
    labels.add initTextbox(
      renderdata,
      pipeline.descriptorSetLayouts[0],
      font,
      $i,
      color = vec4(rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0)),
      scale = rand(0.0002 .. 0.002),
      position = vec3(rand(-0.5 .. 0.5), rand(-0.5 .. 0.5), rand(-0.1 .. 0.1))
    )
  labels = labels.sortedByIt(-it.position.z)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    for l in labels.mitems:
      l.refresh()
    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(vulkan.swapchain.renderPass, framebuffer, commandbuffer, vulkan.swapchain.width, vulkan.swapchain.height, vec4(0, 0, 0, 0)):
        withPipeline(commandbuffer, pipeline):
          for l in labels:
            render(l, commandbuffer, pipeline)

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

when isMainModule:
  var time = 1'f32
  initVulkan()

  for depthBuffer in [true, false]:
    var renderpass = createDirectPresentationRenderPass(depthBuffer = depthBuffer)
    setupSwapchain(renderpass = renderpass)

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_static_label(time)
    test_02_multiple_animated(time)
    test_03_layouting(time)
    test_04_lots_of_texts(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    clearSwapchain()

  destroyVulkan()
