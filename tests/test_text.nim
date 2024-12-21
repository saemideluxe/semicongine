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
  assignBuffers(renderdata, font.descriptorSet)
  uploadImages(renderdata, font.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font.descriptorSet)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let t = getMonoTime()
    textbuffer.reset()
    textbuffer.add("Hello semicongine!", vec3(0.5, 0.5), anchor = vec2(0.5, 0.5))
    textbuffer.updateAllGPUBuffers(flush = true)

    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, font.descriptorSet, 0, pipeline)
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

  assignBuffers(renderdata, font1.descriptorSet)
  assignBuffers(renderdata, font2.descriptorSet)
  assignBuffers(renderdata, font3.descriptorSet)
  uploadImages(renderdata, font1.descriptorSet)
  uploadImages(renderdata, font2.descriptorSet)
  uploadImages(renderdata, font3.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font1.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font2.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font3.descriptorSet)

  var textbuffer1 = font1.initTextBuffer(10, baseScale = 0.1)
  var textbuffer2 = font2.initTextBuffer(10, baseScale = 0.1)
  var textbuffer3 = font3.initTextBuffer(10, baseScale = 0.1)

  assignBuffers(renderdata, textbuffer1)
  assignBuffers(renderdata, textbuffer2)
  assignBuffers(renderdata, textbuffer3)

  var labels = ["  0", "  1", "  2"]

  var start = getMonoTime()
  var p = 0
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    textbuffer1.reset()
    textbuffer2.reset()
    textbuffer3.reset()

    textbuffer1.add($(p + 0), vec3(0.3, 0.5))
    textbuffer2.add($(p + 1), vec3(0.5, 0.5))
    textbuffer3.add($(p + 2), vec3(0.7, 0.5))

    textbuffer1.updateAllGPUBuffers(flush = true)
    textbuffer2.updateAllGPUBuffers(flush = true)
    textbuffer3.updateAllGPUBuffers(flush = true)

    inc p
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
          bindDescriptorSet(commandbuffer, font1.descriptorSet, 0, pipeline)
          renderTextBuffer(commandbuffer, pipeline, textbuffer1)
          bindDescriptorSet(commandbuffer, font2.descriptorSet, 0, pipeline)
          renderTextBuffer(commandbuffer, pipeline, textbuffer2)
          bindDescriptorSet(commandbuffer, font3.descriptorSet, 0, pipeline)
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

  assignBuffers(renderdata, font.descriptorSet)
  uploadImages(renderdata, font.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font.descriptorSet)

  var textbuffer = font.initTextBuffer(1000, baseScale = 0.1)
  assignBuffers(renderdata, textbuffer)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time

    textbuffer.reset()
    textbuffer.add("Anchor at center", vec3(0, 0), anchor = vec2(0, 0))
    textbuffer.add("Anchor at top left`", vec3(-1, 1), anchor = vec2(-1, 1))
    textbuffer.add("Anchor at top right", vec3(1, 1), anchor = vec2(1, 1))
    textbuffer.add("Anchor at bottom left", vec3(-1, -1), anchor = vec2(-1, -1))
    textbuffer.add("Anchor at bottom right", vec3(1, -1), anchor = vec2(1, -1))

    textbuffer.add(
      "Mutiline text\nLeft aligned\nCool!", vec3(-0.5, -0.5), alignment = Left
    )
    textbuffer.add(
      "Mutiline text\nCenter aligned\nCool!!", vec3(0, -0.5), alignment = Center
    )
    textbuffer.add(
      "Mutiline text\nRight aligned\nCool!!!", vec3(0.5, -0.5), alignment = Right
    )

    textbuffer.updateAllGPUBuffers(flush = true)

    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, font.descriptorSet, 0, pipeline)
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

  assignBuffers(renderdata, font.descriptorSet)
  uploadImages(renderdata, font.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font.descriptorSet)

  var textbuffer = font.initTextBuffer(1000, baseScale = 0.1)
  assignBuffers(renderdata, textbuffer)

  var labels: seq[Textbox]
  var positions = newSeq[Vec3f](100)
  var colors = newSeq[Vec4f](100)
  var scales = newSeq[Vec2f](100)
  for i in 0 ..< 100:
    positions[i] = vec3(rand(-0.5 .. 0.5), rand(-0.5 .. 0.5), rand(-0.1 .. 0.1))
    colors[i] =
      vec4(rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0), rand(0.5 .. 1.0))
    scales[i] = vec2(rand(0.5'f32 .. 1.5'f32), rand(0.5'f32 .. 1.5'f32))
    labels.add initTextbox(renderdata, pipeline.layout(0), font, 0.001, $i)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    textbuffer.reset()
    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, font.descriptorSet, 0, pipeline)
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
  var time = 100'f32
  initVulkan()

  for depthBuffer in [true, false]:
    var renderpass = createDirectPresentationRenderPass(depthBuffer = depthBuffer)
    setupSwapchain(renderpass = renderpass)

    # tests a simple triangle with minimalistic shader and vertex format
    # test_01_static_label(time)
    # test_02_multi_counter(time)
    test_03_layouting(time)
    # test_04_lots_of_texts(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    clearSwapchain()

  destroyVulkan()
