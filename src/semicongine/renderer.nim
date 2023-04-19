import std/options
import std/sequtils
import std/tables
import std/strformat
import std/logging

import ./vulkan/api
import ./vulkan/buffer
import ./vulkan/device
import ./vulkan/drawable
import ./vulkan/pipeline
import ./vulkan/physicaldevice
import ./vulkan/renderpass
import ./vulkan/swapchain
import ./vulkan/syncing

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
    renderPass: RenderPass
    swapchain: Swapchain
    scenedata: Table[Entity, SceneData]


proc initRenderer*(device: Device, renderPass: RenderPass): Renderer =
  assert device.vk.valid
  assert renderPass.vk.valid

  result.device = device
  result.renderPass = renderPass
  result.surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
  # use last renderpass as output for swapchain
  let swapchain = device.createSwapchain(result.renderPass.vk, result.surfaceFormat, device.firstGraphicsQueue().get().family)
  if not swapchain.isSome:
    raise newException(Exception, "Unable to create swapchain")
  result.swapchain = swapchain.get()

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

proc render*(renderer: var Renderer, entity: Entity) =
  var
    commandBufferResult = renderer.swapchain.nextFrame()
    commandBuffer: VkCommandBuffer
    oldSwapchain: Swapchain

  if not commandBufferResult.isSome:
    oldSwapchain = renderer.swapchain
    let res = renderer.swapchain.recreate()
    if res.isSome:
      renderer.swapchain = res.get()
      commandBufferResult = renderer.swapchain.nextFrame()
      assert commandBufferResult.isSome
    else:
      raise newException(Exception, "Unable to recreate swapchain")
  commandBuffer = commandBufferResult.get()

  commandBuffer.beginRenderCommands(renderer.renderPass, renderer.swapchain.currentFramebuffer())

  for i in 0 ..< renderer.renderPass.subpasses.len:
    let subpass = renderer.renderPass.subpasses[i]
    for pipeline in subpass.pipelines:
      var mpipeline = pipeline
      commandBuffer.vkCmdBindPipeline(subpass.pipelineBindPoint, mpipeline.vk)
      commandBuffer.vkCmdBindDescriptorSets(subpass.pipelineBindPoint, mpipeline.layout, 0, 1, addr(mpipeline.descriptorSets[renderer.swapchain.currentInFlight].vk), 0, nil)
      mpipeline.updateUniforms(entity, renderer.swapchain.currentInFlight)

      debug "Scene buffers:"
      for (location, buffer) in renderer.scenedata[entity].vertexBuffers.pairs:
        debug "  ", location, ": ", buffer
      debug "  Index buffer: ", renderer.scenedata[entity].indexBuffer

      for drawable in renderer.scenedata[entity].drawables:
        commandBuffer.draw(drawable, vertexBuffers=renderer.scenedata[entity].vertexBuffers, indexBuffer=renderer.scenedata[entity].indexBuffer)

    if i < renderer.renderPass.subpasses.len - 1:
      commandBuffer.vkCmdNextSubpass(VK_SUBPASS_CONTENTS_INLINE)

  commandBuffer.endRenderCommands()

  if not renderer.swapchain.swap():
    oldSwapchain = renderer.swapchain
    let res = renderer.swapchain.recreate()
    if res.isSome:
      renderer.swapchain = res.get()
    else:
      raise newException(Exception, "Unable to recreate swapchain")

  if oldSwapchain.vk.valid:
    oldSwapchain.queueFinishedFence[oldSwapchain.currentInFlight].wait()
    oldSwapchain.destroy()


func framesRendered*(renderer: Renderer): uint64 =
  renderer.swapchain.framesRendered

proc destroy*(renderer: var Renderer) =
  for data in renderer.scenedata.mvalues:
    for buffer in data.vertexBuffers.mvalues:
      buffer.destroy()
    if data.indexBuffer.vk.valid:
      data.indexBuffer.destroy()
  renderer.renderPass.destroy()
  renderer.swapchain.destroy()
