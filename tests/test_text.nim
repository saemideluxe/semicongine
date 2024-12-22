import std/os
import std/algorithm
import std/strutils
import std/sequtils
import std/monotimes
import std/times
import std/tables
import std/options
import std/random
import std/unicode

import ../semicongine

const MAX_CODEPOINTS = 200
const FONTNAME = "Overhaul.ttf"
# const FONTNAME = "DejaVuSans.ttf"

proc test_01_static_label(time: float32) =
  var font = loadFont[MAX_CODEPOINTS](FONTNAME, lineHeightPixels = 200)
  var renderdata = initRenderData()
  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )
  var textbuffer = font.initTextBuffer(1000, baseScale = 0.1)
  assignBuffers(renderdata, textbuffer)

  font.upload(renderdata)
  font.addToPipeline(renderdata, pipeline)

  discard textbuffer.add("Hello semicongine!", vec3())

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let t = getMonoTime()
    if windowWasResized():
      textbuffer.refresh()

    withNextFrame(framebuffer, commandbuffer):
      font.bindTo(pipeline, commandbuffer)
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          renderTextBuffer(commandbuffer, pipeline, textbuffer)

  # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_02_multi_counter(time: float32) =
  var font1 = loadFont[MAX_CODEPOINTS]("Overhaul.ttf", lineHeightPixels = 40)
  var font2 = loadFont[MAX_CODEPOINTS]("Overhaul.ttf", lineHeightPixels = 160)
  var font3 = loadFont[MAX_CODEPOINTS]("DejaVuSans.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()

  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )

  font1.upload(renderdata)
  font2.upload(renderdata)
  font3.upload(renderdata)
  font1.addToPipeline(renderdata, pipeline)
  font2.addToPipeline(renderdata, pipeline)
  font3.addToPipeline(renderdata, pipeline)

  var textbuffer1 = font1.initTextBuffer(10, baseScale = 0.1)
  var textbuffer2 = font2.initTextBuffer(10, baseScale = 0.1)
  var textbuffer3 = font3.initTextBuffer(10, baseScale = 0.1)

  assignBuffers(renderdata, textbuffer1)
  assignBuffers(renderdata, textbuffer2)
  assignBuffers(renderdata, textbuffer3)

  var p = 0
  let l1 = textbuffer1.add($(p + 0), vec3(0.3, 0.5), capacity = 5)
  let l2 = textbuffer2.add($(p + 1), vec3(0.5, 0.5), capacity = 5)
  let l3 = textbuffer3.add($(p + 2), vec3(0.7, 0.5), capacity = 5)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time

    inc p

    textbuffer1.text(l1, $(p + 0))
    textbuffer2.text(l2, $(p + 1))
    textbuffer3.text(l3, $(p + 2))

    textbuffer1.refresh()
    textbuffer2.refresh()
    textbuffer3.refresh()

    withNextFrame(framebuffer, commandbuffer):
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          bindDescriptorSet(commandbuffer, font1.descriptorSet, 3, pipeline)
          renderTextBuffer(commandbuffer, pipeline, textbuffer1)
          bindDescriptorSet(commandbuffer, font2.descriptorSet, 3, pipeline)
          renderTextBuffer(commandbuffer, pipeline, textbuffer2)
          bindDescriptorSet(commandbuffer, font3.descriptorSet, 3, pipeline)
          renderTextBuffer(commandbuffer, pipeline, textbuffer3)

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_03_layouting(time: float32) =
  var font = loadFont[MAX_CODEPOINTS]("DejaVuSans.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()

  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )

  font.upload(renderdata)
  font.addToPipeline(renderdata, pipeline)

  var textbuffer = font.initTextBuffer(1000, baseScale = 0.1)
  assignBuffers(renderdata, textbuffer)

  discard textbuffer.add("Anchor at center", vec3(0, 0), anchor = vec2(0, 0))
  discard textbuffer.add("Anchor at top left`", vec3(-1, 1), anchor = vec2(-1, 1))
  discard textbuffer.add("Anchor at top right", vec3(1, 1), anchor = vec2(1, 1))
  discard textbuffer.add("Anchor at bottom left", vec3(-1, -1), anchor = vec2(-1, -1))
  discard textbuffer.add("Anchor at bottom right", vec3(1, -1), anchor = vec2(1, -1))

  discard textbuffer.add(
    "Mutiline text\nLeft aligned\nCool!", vec3(-0.5, -0.5), alignment = Left
  )
  discard textbuffer.add(
    "Mutiline text\nCenter aligned\nCool!!", vec3(0, -0.5), alignment = Center
  )
  discard textbuffer.add(
    "Mutiline text\nRight aligned\nCool!!!", vec3(0.5, -0.5), alignment = Right
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    if windowWasResized():
      textbuffer.refresh()

    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, font.descriptorSet, 3, pipeline)
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          renderTextBuffer(commandbuffer, pipeline, textbuffer)

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_04_lots_of_texts(time: float32) =
  var font = loadFont[MAX_CODEPOINTS]("DejaVuSans.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()

  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )

  font.upload(renderdata)
  font.addToPipeline(renderdata, pipeline)

  var textbuffer = font.initTextBuffer(3000, baseScale = 0.1)
  assignBuffers(renderdata, textbuffer)

  for i in 0 ..< 1000:
    discard textbuffer.add(
      $i,
      vec3(rand(-0.8 .. 0.8), rand(-0.8 .. 0.8), rand(-0.1 .. 0.1)),
      color =
        vec4(rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0)),
      scale = rand(0.5'f32 .. 1.5'f32),
    )

  var start = getMonoTime()
  var last = start
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let n = getMonoTime()
    echo (n - last).inMicroseconds() / 1000
    last = n
    withNextFrame(framebuffer, commandbuffer):
      if windowWasResized():
        textbuffer.refresh()
      bindDescriptorSet(commandbuffer, font.descriptorSet, 3, pipeline)
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          renderTextBuffer(commandbuffer, pipeline, textbuffer)

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
    test_02_multi_counter(time)
    test_03_layouting(time)
    test_04_lots_of_texts(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    clearSwapchain()

  destroyVulkan()
