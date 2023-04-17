import std/options
import std/sequtils
import std/tables
import std/strformat
import std/logging

import ./vulkan/api
import ./vulkan/buffer
import ./vulkan/device
import ./vulkan/drawable
import ./vulkan/framebuffer
import ./vulkan/pipeline
import ./vulkan/physicaldevice
import ./vulkan/renderpass
import ./vulkan/swapchain

import ./entity
import ./mesh
import ./gpu_data

type
  SceneData = object
    drawables*: seq[Drawable]
    vertexBuffers*: Table[MemoryLocation, Buffer]
    indexBuffer*: Buffer
  Renderer* = object
    device: Device
    surfaceFormat: VkSurfaceFormatKHR
    renderPasses: seq[RenderPass]
    swapchain: Swapchain
    scenedata: Table[Entity, SceneData]


proc initRenderer*(device: Device, renderPasses: openArray[RenderPass]): Renderer =
  assert device.vk.valid
  assert renderPasses.len > 0
  for renderPass in renderPasses:
    assert renderPass.vk.valid

  result.device = device
  result.renderPasses = renderPasses.toSeq
  result.surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
  let (swapchain, res) = device.createSwapchain(result.renderPasses[^1], result.surfaceFormat, device.firstGraphicsQueue().get().family, 2)
  if res != VK_SUCCESS:
    raise newException(Exception, "Unable to create swapchain")
  result.swapchain = swapchain

proc setupDrawableBuffers*(renderer: var Renderer, tree: Entity, inputs: seq[ShaderAttribute]) =
  assert not (tree in renderer.scenedata)
  var data = SceneData()

  var allMeshes: seq[Mesh]
  for mesh in allComponentsOfType[Mesh](tree):
    allMeshes.add mesh
    for inputAttr in inputs:
      assert mesh.hasDataFor(inputAttr.name), &"{mesh} missing data for {inputAttr}"
  
  var indicesBufferSize = 0'u64
  for mesh in allMeshes:
    if mesh.indexType != None:
      let indexAlignment = case mesh.indexType
        of None: 0'u64
        of Tiny: 1'u64
        of Small: 2'u64
        of Big: 4'u64
      # index value alignment required by Vulkan
      if indicesBufferSize mod indexAlignment != 0:
        indicesBufferSize += indexAlignment - (indicesBufferSize mod indexAlignment)
      indicesBufferSize += mesh.indexDataSize
  if indicesBufferSize > 0:
    data.indexBuffer = renderer.device.createBuffer(
      size=indicesBufferSize,
      usage=[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      useVRAM=true,
      mappable=false,
    )

  # one vertex data buffer per memory location
  var perLocationOffsets: Table[MemoryLocation, uint64]
  for location, attributes in inputs.groupByMemoryLocation().pairs:
    # setup one buffer per attribute-location-type
    var bufferSize = 0'u64
    for mesh in allMeshes:
      for attribute in attributes:
        bufferSize += mesh.dataSize(attribute.name)
    if bufferSize > 0:
      data.vertexBuffers[location] = renderer.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        useVRAM=location in [VRAM, VRAMVisible],
        mappable=location in [VRAMVisible, RAM],
      )
      perLocationOffsets[location] = 0

  var indexBufferOffset = 0'u64
  for mesh in allMeshes:
    var offsets: Table[MemoryLocation, seq[uint64]]
    for location, attributes in inputs.groupByMemoryLocation().pairs:
      for attribute in attributes:
        if not (location in offsets):
          offsets[location] = @[]
        offsets[location].add perLocationOffsets[location]
        var (pdata, size) = mesh.getRawData(attribute.name)
        data.vertexBuffers[location].setData(pdata, size, perLocationOffsets[location])
        perLocationOffsets[location] += size

    let indexed = mesh.indexType != None
    var drawable = Drawable(
      elementCount: if indexed: mesh.indicesCount else: mesh.vertexCount,
      bufferOffsets: offsets,
      instanceCount: mesh.instanceCount,
      indexed: indexed,
    )
    if indexed:
      let indexAlignment = case mesh.indexType
        of None: 0'u64
        of Tiny: 1'u64
        of Small: 2'u64
        of Big: 4'u64
      # index value alignment required by Vulkan
      if indexBufferOffset mod indexAlignment != 0:
        indexBufferOffset += indexAlignment - (indexBufferOffset mod indexAlignment)
      drawable.indexBufferOffset = indexBufferOffset
      drawable.indexType = mesh.indexType
      var (pdata, size) = mesh.getRawIndexData()
      data.indexBuffer.setData(pdata, size, indexBufferOffset)
      indexBufferOffset += size
    data.drawables.add drawable

  renderer.scenedata[tree] = data

proc render*(renderer: var Renderer, entity: Entity): bool =
  var commandBuffer = renderer.swapchain.nextFrame()

  commandBuffer.beginRenderCommands(renderer.swapchain.renderPass, renderer.swapchain.currentFramebuffer())

  for i in 0 ..< renderer.swapchain.renderPass.subpasses.len:
    let subpass = renderer.swapchain.renderPass.subpasses[i]
    for pipeline in subpass.pipelines:
      var mpipeline = pipeline
      commandBuffer.vkCmdBindPipeline(subpass.pipelineBindPoint, mpipeline.vk)
      commandBuffer.vkCmdBindDescriptorSets(subpass.pipelineBindPoint, mpipeline.layout, 0, 1, addr(mpipeline.descriptorSets[renderer.swapchain.currentInFlight].vk), 0, nil)
      mpipeline.updateUniforms(entity, renderer.swapchain.currentInFlight)

      debug "Scene buffers:"
      for (location, buffer) in renderer.scenedata[entity].vertexBuffers.pairs:
        echo "  ", location, ": ", buffer
      echo "  Index buffer: ", renderer.scenedata[entity].indexBuffer

      for drawable in renderer.scenedata[entity].drawables:
        commandBuffer.draw(drawable, vertexBuffers=renderer.scenedata[entity].vertexBuffers, indexBuffer=renderer.scenedata[entity].indexBuffer)

    if i < renderer.swapchain.renderPass.subpasses.len - 1:
      commandBuffer.vkCmdNextSubpass(VK_SUBPASS_CONTENTS_INLINE)

  commandBuffer.endRenderCommands()

  return renderer.swapchain.swap()

func framesRendered*(renderer: Renderer): uint64 =
  renderer.swapchain.framesRendered

proc destroy*(renderer: var Renderer) =
  for data in renderer.scenedata.mvalues:
    for buffer in data.vertexBuffers.mvalues:
      buffer.destroy()
    if data.indexBuffer.vk.valid:
      data.indexBuffer.destroy()
  for renderpass in renderer.renderPasses.mitems:
    renderpass.destroy()
  renderer.swapchain.destroy()
