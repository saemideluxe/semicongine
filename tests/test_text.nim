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

type EMPTY = object

const N_GLYPHS = 200
proc test_01_static_label_new(time: float32) =
  var font = loadFont("Overhaul.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()
  var pipeline =
    createPipeline[GlyphShader[N_GLYPHS]](renderPass = vulkan.swapchain.renderPass)
  var (ds, glyphtable) = glyphDescriptorSet(font, N_GLYPHS)
  var glyphs = Glyphs(
    position: asGPUArray([vec3(), vec3()], VertexBufferMapped),
    scale: asGPUArray([1'f32, 1'f32], VertexBufferMapped),
    color: asGPUArray([vec4(1, 1, 1, 1), vec4(1, 1, 1, 1)], VertexBufferMapped),
    glyphIndex:
      asGPUArray([glyphtable[Rune('Q')], glyphtable[Rune('H')]], VertexBufferMapped),
  )

  assignBuffers(renderdata, glyphs)
  assignBuffers(renderdata, ds)
  uploadImages(renderdata, ds)
  initDescriptorSet(renderdata, pipeline.layout(0), ds)

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
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
          render(commandbuffer, pipeline, EMPTY(), glyphs, fixedVertexCount = 6)

        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_01_static_label(time: float32) =
  var font = loadFont("Overhaul.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()
  var pipeline =
    createPipeline[DefaultFontShader[FontDS]](renderPass = vulkan.swapchain.renderPass)

  var ds = asDescriptorSetData(FontDS(fontAtlas: font.fontAtlas.copy()))
  uploadImages(renderdata, ds)
  initDescriptorSet(renderdata, pipeline.layout(0), ds)

  var label1 =
    initTextbox(renderdata, pipeline.layout(0), font, 0.0005, "Hello semicongine!")

  var start = getMonoTime()
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    label1.refresh()
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
          render(commandbuffer, pipeline, label1, vec3(), vec4(1, 1, 1, 1))
        # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_02_multiple_animated(time: float32) =
  var font1 = loadFont("Overhaul.ttf", lineHeightPixels = 40)
  var font2 = loadFont("Overhaul.ttf", lineHeightPixels = 160)
  var font3 = loadFont("DejaVuSans.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()

  var pipeline =
    createPipeline[DefaultFontShader[FontDS]](renderPass = vulkan.swapchain.renderPass)

  var ds1 = asDescriptorSetData(FontDS(fontAtlas: font1.fontAtlas.copy()))
  uploadImages(renderdata, ds1)
  initDescriptorSet(renderdata, pipeline.layout(0), ds1)

  var ds2 = asDescriptorSetData(FontDS(fontAtlas: font2.fontAtlas.copy()))
  uploadImages(renderdata, ds2)
  initDescriptorSet(renderdata, pipeline.layout(0), ds2)

  var ds3 = asDescriptorSetData(FontDS(fontAtlas: font3.fontAtlas.copy()))
  uploadImages(renderdata, ds3)
  initDescriptorSet(renderdata, pipeline.layout(0), ds3)

  var labels = [
    initTextbox(renderdata, pipeline.layout(0), font1, 0.004, "  0"),
    initTextbox(renderdata, pipeline.layout(0), font2, 0.001, "  1"),
    initTextbox(renderdata, pipeline.layout(0), font3, 0.001, "  2"),
  ]

  var start = getMonoTime()
  var p = 0
  while ((getMonoTime() - start).inMilliseconds().int / 1000) < time:
    let progress = ((getMonoTime() - start).inMilliseconds().int / 1000) / time
    for i in 0 ..< labels.len:
      labels[i].text = $(p + i)
      labels[i].refresh()
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
          bindDescriptorSet(commandbuffer, ds1, 0, pipeline)
          render(
            commandbuffer,
            pipeline,
            labels[0],
            position = vec3(0 / labels.len, 0.1 + progress * 0.5),
            color = vec4(1, 1, 1, 1),
          )
          bindDescriptorSet(commandbuffer, ds2, 0, pipeline)
          render(
            commandbuffer,
            pipeline,
            labels[1],
            position = vec3(1 / labels.len, 0.1 + progress * 0.5),
            color = vec4(1, 1, 1, 1),
          )
          bindDescriptorSet(commandbuffer, ds3, 0, pipeline)
          render(
            commandbuffer,
            pipeline,
            labels[2],
            position = vec3(2 / labels.len, 0.1 + progress * 0.5),
            color = vec4(1, 1, 1, 1),
          )

      # cleanup
  checkVkResult vkDeviceWaitIdle(vulkan.device)
  destroyPipeline(pipeline)
  destroyRenderData(renderdata)

proc test_03_layouting(time: float32) =
  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 40)
  var renderdata = initRenderData()

  var pipeline =
    createPipeline[DefaultFontShader[FontDS]](renderPass = vulkan.swapchain.renderPass)

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
  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 160)
  var renderdata = initRenderData()

  var pipeline =
    createPipeline[DefaultFontShader[FontDS]](renderPass = vulkan.swapchain.renderPass)

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

when isMainModule:
  var time = 1000'f32
  initVulkan()

  for depthBuffer in [true, false]:
    var renderpass = createDirectPresentationRenderPass(depthBuffer = depthBuffer)
    setupSwapchain(renderpass = renderpass)

    # tests a simple triangle with minimalistic shader and vertex format
    test_01_static_label_new(time)
    # test_01_static_label(time)
    # test_02_multiple_animated(time)
    # test_03_layouting(time)
    # test_04_lots_of_texts(time)

    checkVkResult vkDeviceWaitIdle(vulkan.device)
    vkDestroyRenderPass(vulkan.device, renderpass.vk, nil)
    clearSwapchain()

  destroyVulkan()
