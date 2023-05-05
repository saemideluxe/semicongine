import std/options
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
import ./vulkan/descriptor
import ./vulkan/image

import ./entity
import ./mesh
import ./gpu_data
import ./math

type
  SceneData = object
    drawables*: OrderedTable[Mesh, Drawable]
    vertexBuffers*: Table[MemoryPerformanceHint, Buffer]
    indexBuffer*: Buffer
    uniformBuffers*: seq[Buffer] # one per frame-in-flight
    images*: seq[Image] # used to back texturees
    textures*: seq[Table[string, Texture]] # per frame-in-flight
    attributeLocation*: Table[string, MemoryPerformanceHint]
    attributeBindingNumber*: Table[string, int]
    transformAttribute: string # name of attribute that is used for per-instance mesh transformation
    entityTransformationCache: Table[Mesh, Mat4] # remembers last transformation, avoid to send GPU-updates if no changes
  Renderer* = object
    device: Device
    surfaceFormat: VkSurfaceFormatKHR
    renderPass: RenderPass
    swapchain: Swapchain
    scenedata: Table[Scene, SceneData]


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

proc setupDrawableBuffers*(renderer: var Renderer, scene: Scene, inputs: seq[ShaderAttribute], transformAttribute="") =
  assert not (scene in renderer.scenedata)
  var data = SceneData()

  # when mesh transformation are handled through the scenegraph-transformation, set it up here
  if transformattribute != "":
    var hasTransformAttribute = false
    for input in inputs:
      if input.name == transformattribute:
        assert input.perInstance == true, $input
        assert getDataType[Mat4]() == input.thetype
        hasTransformAttribute = true
    assert hasTransformAttribute
    data.transformAttribute = transformAttribute

  # find all meshes, populate missing attribute values for shader
  var allMeshes: seq[Mesh]
  for mesh in allComponentsOfType[Mesh](scene.root):
    allMeshes.add mesh
    for inputAttr in inputs:
      if not mesh.hasDataFor(inputAttr.name):
        mesh.initData(inputAttr)
  
  # create index buffer if necessary
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
      requireMappable=false,
      preferVRAM=true,
    )

  # create vertex buffers and calculcate offsets
  # trying to use one buffer per memory type
  var
    perLocationOffsets: Table[MemoryPerformanceHint, uint64]
    perLocationSizes: Table[MemoryPerformanceHint, uint64]
    bindingNumber = 0
  for attribute in inputs:
    data.attributeLocation[attribute.name] = attribute.memoryPerformanceHint
    data.attributeBindingNumber[attribute.name] = bindingNumber
    inc bindingNumber
    # setup one buffer per attribute-location-type
    if not (attribute.memoryPerformanceHint in perLocationSizes):
      perLocationSizes[attribute.memoryPerformanceHint] = 0'u64
    for mesh in allMeshes:
      perLocationSizes[attribute.memoryPerformanceHint] += mesh.dataSize(attribute.name)
  for memoryPerformanceHint, bufferSize in perLocationSizes.pairs:
    if bufferSize > 0:
      data.vertexBuffers[memoryPerformanceHint] = renderer.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        requireMappable=memoryPerformanceHint==PreferFastWrite,
        preferVRAM=true,
      )
      perLocationOffsets[memoryPerformanceHint] = 0

  # fill vertex buffers
  var indexBufferOffset = 0'u64
  for mesh in allMeshes:
    var offsets: seq[(string, MemoryPerformanceHint, uint64)]
    for attribute in inputs:
      offsets.add (attribute.name, attribute.memoryPerformanceHint, perLocationOffsets[attribute.memoryPerformanceHint])
      var (pdata, size) = mesh.getRawData(attribute.name)
      data.vertexBuffers[attribute.memoryPerformanceHint].setData(pdata, size, perLocationOffsets[attribute.memoryPerformanceHint])
      perLocationOffsets[attribute.memoryPerformanceHint] += size

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
    data.drawables[mesh] = drawable

  # setup uniforms and textures
  for i in 0 ..< renderer.renderPass.subpasses.len:
    var subpass = renderer.renderPass.subpasses[i]
    for pipeline in subpass.pipelines.mitems:
      var uniformBufferSize = 0'u64
      for uniform in pipeline.uniforms:
        uniformBufferSize += uniform.thetype.size
      if uniformBufferSize > 0:
        for i in 0 ..< renderer.swapchain.inFlightFrames:
          data.uniformBuffers.add renderer.device.createBuffer(
            size=uniformBufferSize,
            usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
            requireMappable=true,
            preferVRAM=true,
          )
      for i in 0 ..< renderer.swapchain.inFlightFrames:
        var textures: Table[string, Texture]
        # todo: get textures from scene, currently only 32 bit images supported
        for name, image in scene.textures.pairs:
          textures[name] = renderer.device.createTexture(image.width, image.height, 4, addr image.imagedata[0][0])
        data.textures.add textures
      # need a separate descriptor for each frame in flight
      pipeline.setupDescriptors(data.uniformBuffers, data.textures, inFlightFrames=renderer.swapchain.inFlightFrames)
      pipeline.descriptorSets[i].writeDescriptorSet()

  renderer.scenedata[scene] = data

proc refreshMeshAttributeData(sceneData: var SceneData, mesh: Mesh, attribute: string) =
  debug &"Refreshing data on mesh {mesh} for {attribute}"
  var (pdata, size) = mesh.getRawData(attribute)
  let memoryPerformanceHint = sceneData.attributeLocation[attribute]
  let bindingNumber = sceneData.attributeBindingNumber[attribute]
  sceneData.vertexBuffers[memoryPerformanceHint].setData(pdata, size, sceneData.drawables[mesh].bufferOffsets[bindingNumber][2])

proc refreshMeshData*(renderer: var Renderer, scene: Scene) =
  assert scene in renderer.scenedata

  for mesh in allComponentsOfType[Mesh](scene.root):
    # if mesh transformation attribute is enabled, update the model matrix
    if renderer.scenedata[scene].transformAttribute != "":
      let transform = mesh.entity.getModelTransform()
      if not (mesh in renderer.scenedata[scene].entityTransformationCache) or renderer.scenedata[scene].entityTransformationCache[mesh] != transform:
        mesh.updateInstanceData(renderer.scenedata[scene].transformAttribute, @[transform])
        renderer.scenedata[scene].entityTransformationCache[mesh] = transform

    # update any changed mesh attributes
    for attribute in mesh.availableAttributes():
      if mesh.hasDataChanged(attribute):
        renderer.scenedata[scene].refreshMeshAttributeData(mesh, attribute)
    var m = mesh
    m.clearDataChanged()

proc updateUniforms(renderer: Renderer, scene: var Scene, currentInFlight: int) =
  assert scene in renderer.scenedata
  var data = renderer.scenedata[scene]
  if data.uniformBuffers.len == 0:
    return
  assert data.uniformBuffers[currentInFlight].vk.valid

  for i in 0 ..< renderer.renderPass.subpasses.len:
    var subpass = renderer.renderPass.subpasses[i]
    for pipeline in subpass.pipelines.mitems:
      var offset = 0'u64
      for uniform in pipeline.uniforms:
        assert uniform.thetype == scene.shaderGlobals[uniform.name].thetype
        let (pdata, size) = scene.shaderGlobals[uniform.name].getRawData()
        data.uniformBuffers[currentInFlight].setData(pdata, size, offset)
        offset += size

proc render*(renderer: var Renderer, scene: var Scene) =
  assert scene in renderer.scenedata

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

  renderer.updateUniforms(scene, renderer.swapchain.currentInFlight)

  for i in 0 ..< renderer.renderPass.subpasses.len:
    let subpass = renderer.renderPass.subpasses[i]
    for pipeline in subpass.pipelines:
      var mpipeline = pipeline
      commandBuffer.vkCmdBindPipeline(subpass.pipelineBindPoint, mpipeline.vk)
      commandBuffer.vkCmdBindDescriptorSets(subpass.pipelineBindPoint, mpipeline.layout, 0, 1, addr(mpipeline.descriptorSets[renderer.swapchain.currentInFlight].vk), 0, nil)

      debug "Scene buffers:"
      for (location, buffer) in renderer.scenedata[scene].vertexBuffers.pairs:
        debug "  ", location, ": ", buffer
      debug "  Index buffer: ", renderer.scenedata[scene].indexBuffer

      for drawable in renderer.scenedata[scene].drawables.values:
        commandBuffer.draw(drawable, vertexBuffers=renderer.scenedata[scene].vertexBuffers, indexBuffer=renderer.scenedata[scene].indexBuffer)

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
    checkVkResult renderer.device.vk.vkDeviceWaitIdle()
    oldSwapchain.destroy()

func framesRendered*(renderer: Renderer): uint64 =
  renderer.swapchain.framesRendered

func valid*(renderer: Renderer): bool =
  renderer.device.vk.valid

proc destroy*(renderer: var Renderer) =
  for data in renderer.scenedata.mvalues:
    for buffer in data.vertexBuffers.mvalues:
      assert buffer.vk.valid
      buffer.destroy()
    if data.indexBuffer.vk.valid:
      assert data.indexBuffer.vk.valid
      data.indexBuffer.destroy()
    for buffer in data.uniformBuffers.mitems:
      assert buffer.vk.valid
      buffer.destroy()
  renderer.renderPass.destroy()
  renderer.swapchain.destroy()
