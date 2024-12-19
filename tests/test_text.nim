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

type FontDS = object
  fontAtlas: Image[Gray]

const MAX_CODEPOINTS = 200
const FONTNAME = "Overhaul.ttf"
# const FONTNAME = "DejaVuSans.ttf"

proc test_01_static_label(time: float32) =
  var font = loadFont[MAX_CODEPOINTS](FONTNAME, lineHeightPixels = 200)
  var renderdata = initRenderData()
  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )
  var glyphs = font.initGlyphs(1000, baseScale = 0.1)

  assignBuffers(renderdata, glyphs)
  assignBuffers(renderdata, font.descriptorSet)
  uploadImages(renderdata, font.descriptorSet)
  initDescriptorSet(renderdata, pipeline.layout(0), font.descriptorSet)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let t = getMonoTime()
    glyphs.reset()
    glyphs.add("Hello semicongine!", vec3(0.5, 0.5), anchor = vec2(0.5, 0.5))
    glyphs.updateAllGPUBuffers(flush = true)

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
          renderGlyphs(commandbuffer, pipeline, glyphs)

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

  var glyphs1 = font1.initGlyphs(10, baseScale = 0.1)
  var glyphs2 = font2.initGlyphs(10, baseScale = 0.1)
  var glyphs3 = font3.initGlyphs(10, baseScale = 0.1)

  assignBuffers(renderdata, glyphs1)
  assignBuffers(renderdata, glyphs2)
  assignBuffers(renderdata, glyphs3)

  var labels = ["  0", "  1", "  2"]

  var start = getMonoTime()
  var p = 0
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    glyphs1.reset()
    glyphs2.reset()
    glyphs3.reset()

    glyphs1.add($(p + 0), vec3(0.3, 0.5))
    glyphs2.add($(p + 1), vec3(0.5, 0.5))
    glyphs3.add($(p + 2), vec3(0.7, 0.5))

    glyphs1.updateAllGPUBuffers(flush = true)
    glyphs2.updateAllGPUBuffers(flush = true)
    glyphs3.updateAllGPUBuffers(flush = true)

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
          renderGlyphs(commandbuffer, pipeline, glyphs1)
          bindDescriptorSet(commandbuffer, font2.descriptorSet, 0, pipeline)
          renderGlyphs(commandbuffer, pipeline, glyphs2)
          bindDescriptorSet(commandbuffer, font3.descriptorSet, 0, pipeline)
          renderGlyphs(commandbuffer, pipeline, glyphs3)

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

#[
proc test_03_layouting(time: float32) =
  var font = loadFont[MAX_CODEPOINTS]("DejaVuSans.ttf", lineHeightPixels = 40)
  var renderdata = initRenderData()

  var pipeline = createPipeline[GlyphShader[MAX_CODEPOINTS]](
    renderPass = vulkan.swapchain.renderPass
  )

  var ds = asDescriptorSetData(FontDS(fontAtlas: font.fontAtlas.copy()))
  uploadImages(renderdata, ds)
  initDescriptorSet(renderdata, pipeline.layout(0), ds)

  var labels: seq[Textbox]

  for horizontal in HorizontalAlignment:
    labels.add initTextbox(
      renderdata,
      pipeline.layout(0),
      font,
      0.001,
      $horizontal & " aligned",
      horizontalAlignment = horizontal,
    )
  for vertical in VerticalAlignment:
    labels.add initTextbox(
      renderdata,
      pipeline.layout(0),
      font,
      0.001,
      $vertical & " aligned",
      verticalAlignment = vertical,
    )
  labels.add initTextbox(
    renderdata,
    pipeline.layout(0),
    font,
    0.001,
    """Paragraph
This is a somewhat longer paragraph with a few newlines and a maximum width of 0.2.

It should display with some space above and have a pleasing appearance overall! :)""",
    maxWidth = 0.6,
    verticalAlignment = Top,
    horizontalAlignment = Left,
  )

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, ds, 0, pipeline)
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          for i in 0 ..< labels.len:
            render(
              commandbuffer,
              pipeline,
              labels[i],
              vec3(0.5 - i.float32 * 0.1, 0.5 - i.float32 * 0.1),
              vec4(1, 1, 1, 1),
            )

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

  var ds = asDescriptorSetData(FontDS(fontAtlas: font.fontAtlas.copy()))
  uploadImages(renderdata, ds)
  initDescriptorSet(renderdata, pipeline.layout(0), ds)

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
    for l in labels.mitems:
      l.refresh()
    withNextFrame(framebuffer, commandbuffer):
      bindDescriptorSet(commandbuffer, ds, 0, pipeline)
      withRenderPass(
        vulkan.swapchain.renderPass,
        framebuffer,
        commandbuffer,
        vulkan.swapchain.width,
        vulkan.swapchain.height,
        vec4(0, 0, 0, 0),
      ):
        withPipeline(commandbuffer, pipeline):
          for i in 0 ..< labels.len:
            render(
              commandbuffer, pipeline, labels[i], positions[i], colors[i], scales[i]
            )

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)
]#

when isMainModule:
  var time = 1'f32
  initVulkan()

  for depthBuffer in [true, false]:
    var renderpass = createDirectPresentationRenderPass(depthBuffer = depthBuffer)
    setupSwapchain(renderpass = renderpass)

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_static_label(time)
    test_02_multi_counter(time)
    # test_03_layouting(time)
    # test_04_lots_of_texts(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    clearSwapchain()

  destroyVulkan()
