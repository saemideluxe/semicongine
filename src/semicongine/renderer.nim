import std/options
import std/tables
import std/strformat
import std/strutils
import std/logging

import ./core
import ./vulkan/buffer
import ./vulkan/device
import ./vulkan/drawable
import ./vulkan/pipeline
import ./vulkan/physicaldevice
import ./vulkan/renderpass
import ./vulkan/swapchain
import ./vulkan/descriptor
import ./vulkan/image

import ./scene
import ./mesh

type
  SceneData = object
    drawables*: OrderedTable[Mesh, Drawable]
    vertexBuffers*: Table[MemoryPerformanceHint, Buffer]
    indexBuffer*: Buffer
    uniformBuffers*: Table[VkPipeline, seq[Buffer]] # one per frame-in-flight
    textures*: Table[string, seq[VulkanTexture]] # per frame-in-flight
    attributeLocation*: Table[string, MemoryPerformanceHint]
    attributeBindingNumber*: Table[string, int]
    transformAttribute: string # name of attribute that is used for per-instance mesh transformation
    entityTransformationCache: Table[Mesh, Mat4] # remembers last transformation, avoid to send GPU-updates if no changes
    descriptorPool*: DescriptorPool
    descriptorSets*: Table[VkPipeline, seq[DescriptorSet]]
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

proc setupDrawableBuffers*(renderer: var Renderer, scene: Scene, inputs: seq[ShaderAttribute], samplers: seq[ShaderAttribute], transformAttribute="transform") =
  assert not (scene in renderer.scenedata)
  const VERTEX_ATTRIB_ALIGNMENT = 4 # used for buffer alignment
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
      assert mesh.dataType(inputAttr.name) == inputAttr.thetype, &"mesh attribute {inputAttr.name} has type {mesh.dataType(inputAttr.name)} but shader expects {inputAttr.thetype}"
  
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
  for hint in MemoryPerformanceHint:
    perLocationOffsets[hint] = 0
    perLocationSizes[hint] = 0
  for attribute in inputs:
    data.attributeLocation[attribute.name] = attribute.memoryPerformanceHint
    data.attributeBindingNumber[attribute.name] = bindingNumber
    inc bindingNumber
    # setup one buffer per attribute-location-type
    for mesh in allMeshes:
      # align size to VERTEX_ATTRIB_ALIGNMENT bytes (the important thing is the correct alignment of the offsets, bu
      # we need to expand the buffer size as well, therefore considering alignment already here as well
      if perLocationSizes[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
        perLocationSizes[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationSizes[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)
      perLocationSizes[attribute.memoryPerformanceHint] += mesh.dataSize(attribute.name)
  for memoryPerformanceHint, bufferSize in perLocationSizes.pairs:
    if bufferSize > 0:
      data.vertexBuffers[memoryPerformanceHint] = renderer.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        requireMappable=memoryPerformanceHint==PreferFastWrite,
        preferVRAM=true,
      )

  # fill vertex buffers
  var indexBufferOffset = 0'u64
  for mesh in allMeshes:
    var offsets: seq[(string, MemoryPerformanceHint, uint64)]
    for attribute in inputs:
      offsets.add (attribute.name, attribute.memoryPerformanceHint, perLocationOffsets[attribute.memoryPerformanceHint])
      var (pdata, size) = mesh.getRawData(attribute.name)
      if pdata != nil: # no data
        data.vertexBuffers[attribute.memoryPerformanceHint].setData(pdata, size, perLocationOffsets[attribute.memoryPerformanceHint])
        perLocationOffsets[attribute.memoryPerformanceHint] += size
        if perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
          perLocationOffsets[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)

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

  for material in scene.getMaterials():
    for textureName, texture in material.textures.pairs:
      if not data.textures.hasKey(textureName):
        data.textures[textureName] = @[]
      data.textures[textureName].add renderer.device.uploadTexture(texture)

  # setup uniforms and samplers
  for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
    for pipeline in renderer.renderPass.subpasses[subpass_i].pipelines.mitems:
      var uniformBufferSize = 0'u64
      for uniform in pipeline.uniforms:
        uniformBufferSize += uniform.size
      if uniformBufferSize > 0:
        data.uniformBuffers[pipeline.vk] = newSeq[Buffer]()
        for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
          data.uniformBuffers[pipeline.vk].add renderer.device.createBuffer(
            size=uniformBufferSize,
            usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
            requireMappable=true,
            preferVRAM=true,
          )
          
      var poolsizes = @[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, uint32(renderer.swapchain.inFlightFrames))]
      if samplers.len > 0:
        var samplercount = 0'u32
        for sampler in samplers:
          samplercount += (if sampler.arrayCount == 0: 1'u32 else: sampler.arrayCount)
        poolsizes.add (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, uint32(renderer.swapchain.inFlightFrames) * samplercount)
    
      data.descriptorPool = renderer.device.createDescriptorSetPool(poolsizes)
  
      data.descriptorSets[pipeline.vk] = pipeline.setupDescriptors(
        data.descriptorPool,
        data.uniformBuffers.getOrDefault(pipeline.vk, @[]),
        data.textures,
        inFlightFrames=renderer.swapchain.inFlightFrames
      )
      for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
        data.descriptorSets[pipeline.vk][frame_i].writeDescriptorSet()

  renderer.scenedata[scene] = data

proc refreshMeshAttributeData(sceneData: var SceneData, mesh: Mesh, attribute: string) =
  debug &"Refreshing data on mesh {mesh} for {attribute}"
  # ignore attributes that are not used in this shader
  if not (attribute in sceneData.attributeLocation):
    return
  var (pdata, size) = mesh.getRawData(attribute)
  let memoryPerformanceHint = sceneData.attributeLocation[attribute]
  let bindingNumber = sceneData.attributeBindingNumber[attribute]

  sceneData.vertexBuffers[memoryPerformanceHint].setData(pdata, size, sceneData.drawables[mesh].bufferOffsets[bindingNumber][2])

proc updateMeshData*(renderer: var Renderer, scene: Scene) =
  assert scene in renderer.scenedata

  for mesh in allComponentsOfType[Mesh](scene.root):
    # if mesh transformation attribute is enabled, update the model matrix
    if renderer.scenedata[scene].transformAttribute != "":
      let transform = mesh.entity.getModelTransform()
      if not (mesh in renderer.scenedata[scene].entityTransformationCache) or renderer.scenedata[scene].entityTransformationCache[mesh] != transform or mesh.areInstanceTransformsDirty:
        var updatedTransform = newSeq[Mat4](int(mesh.instanceCount))
        for i in 0 ..< mesh.instanceCount:
          updatedTransform[i] = transform * mesh.getInstanceTransform(i)
        mesh.updateInstanceData(renderer.scenedata[scene].transformAttribute, updatedTransform)
        renderer.scenedata[scene].entityTransformationCache[mesh] = transform

    # update any changed mesh attributes
    for attribute in mesh.availableAttributes():
      if mesh.hasDataChanged(attribute):
        renderer.scenedata[scene].refreshMeshAttributeData(mesh, attribute)
    var m = mesh
    m.clearDataChanged()

proc updateUniformData*(renderer: var Renderer, scene: var Scene) =
  assert scene in renderer.scenedata

  for i in 0 ..< renderer.renderPass.subpasses.len:
    for pipeline in renderer.renderPass.subpasses[i].pipelines.mitems:
      if renderer.scenedata[scene].uniformBuffers.hasKey(pipeline.vk) and renderer.scenedata[scene].uniformBuffers[pipeline.vk].len != 0:
        assert renderer.scenedata[scene].uniformBuffers[pipeline.vk][renderer.swapchain.currentInFlight].vk.valid
        var offset = 0'u64
        for uniform in pipeline.uniforms:
          if not scene.shaderGlobals.hasKey(uniform.name):
            raise newException(Exception, &"Uniform '{uniform.name}' not found in scene shaderGlobals")
          if uniform.thetype != scene.shaderGlobals[uniform.name].thetype:
            raise newException(Exception, &"Uniform '{uniform.name}' has wrong type {uniform.thetype}, required is {scene.shaderGlobals[uniform.name].thetype}")
          let (pdata, size) = scene.shaderGlobals[uniform.name].getRawData()
          renderer.scenedata[scene].uniformBuffers[pipeline.vk][renderer.swapchain.currentInFlight].setData(pdata, size, offset)
          offset += size

proc render*(renderer: var Renderer, scene: var Scene) =
  assert scene in renderer.scenedata

  var
    commandBufferResult = renderer.swapchain.nextFrame()
    commandBuffer: VkCommandBuffer

  if not commandBufferResult.isSome:
    let res = renderer.swapchain.recreate()
    if res.isSome:
      var oldSwapchain = renderer.swapchain
      renderer.swapchain = res.get()
      checkVkResult renderer.device.vk.vkDeviceWaitIdle()
      oldSwapchain.destroy()
    return

  commandBuffer = commandBufferResult.get()
  commandBuffer.beginRenderCommands(renderer.renderPass, renderer.swapchain.currentFramebuffer())

  for i in 0 ..< renderer.renderPass.subpasses.len:
    for pipeline in renderer.renderPass.subpasses[i].pipelines.mitems:
      commandBuffer.vkCmdBindPipeline(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.vk)
      commandBuffer.vkCmdBindDescriptorSets(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.layout, 0, 1, addr(renderer.scenedata[scene].descriptorSets[pipeline.vk][renderer.swapchain.currentInFlight].vk), 0, nil)

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
    let res = renderer.swapchain.recreate()
    if res.isSome:
      var oldSwapchain = renderer.swapchain
      renderer.swapchain = res.get()
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
    for pipelineUniforms in data.uniformBuffers.mvalues:
      for buffer in pipelineUniforms.mitems:
        assert buffer.vk.valid
        buffer.destroy()
    for textures in data.textures.mvalues:
      for texture in textures.mitems:
        texture.destroy()
    data.descriptorPool.destroy()
  renderer.renderPass.destroy()
  renderer.swapchain.destroy()
