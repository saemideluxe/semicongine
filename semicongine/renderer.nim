import std/options
import std/tables
import std/strformat
import std/sequtils
import std/strutils
import std/logging

import ./core
import ./vulkan/commandbuffer
import ./vulkan/buffer
import ./vulkan/device
import ./vulkan/drawable
import ./vulkan/physicaldevice
import ./vulkan/pipeline
import ./vulkan/renderpass
import ./vulkan/swapchain
import ./vulkan/shader
import ./vulkan/descriptor
import ./vulkan/image

import ./scene
import ./mesh
import ./material

const VERTEX_ATTRIB_ALIGNMENT = 4 # used for buffer alignment

type
  ShaderData = ref object
    descriptorPool: DescriptorPool
    descriptorSets: seq[DescriptorSet] # len = n swapchain images
    uniformBuffers: seq[Buffer]
    textures: Table[string, seq[VulkanTexture]]

  SceneData = ref object
    drawables: seq[tuple[drawable: Drawable, mesh: Mesh]]
    vertexBuffers: Table[MemoryPerformanceHint, Buffer]
    indexBuffer: Buffer
    attributeLocation: Table[string, MemoryPerformanceHint]
    vertexBufferOffsets: Table[(Mesh, string), uint64]
    materials: Table[MaterialType, seq[MaterialData]]
    shaderData: Table[VkPipeline, ShaderData]
  Renderer* = object
    device: Device
    renderPass: RenderPass
    swapchain: Swapchain
    scenedata: Table[Scene, SceneData]
    emptyTexture: VulkanTexture
    queue: Queue
    commandBufferPool: CommandBufferPool
    nextFrameReady: bool = false

proc currentFrameCommandBuffer(renderer: Renderer): VkCommandBuffer =
  renderer.commandBufferPool.buffers[renderer.swapchain.currentInFlight]

proc hasScene*(renderer: Renderer, scene: Scene): bool =
  scene in renderer.scenedata

proc initRenderer*(
  device: Device,
  shaders: openArray[(MaterialType, ShaderConfiguration)],
  clearColor = newVec4f(0, 0, 0, 0),
  backFaceCulling = true,
  vSync = false,
  inFlightFrames = 2,
): Renderer =
  assert device.vk.valid

  result.device = device
  result.renderPass = device.createRenderPass(shaders, clearColor = clearColor, backFaceCulling = backFaceCulling)
  let swapchain = device.createSwapchain(
    result.renderPass.vk,
    device.physicalDevice.getSurfaceFormats().filterSurfaceFormat(),
    vSync = vSync,
    inFlightFrames = inFlightFrames,
  )
  if not swapchain.isSome:
    raise newException(Exception, "Unable to create swapchain")

  result.queue = device.firstGraphicsQueue().get()
  result.commandBufferPool = device.createCommandBufferPool(result.queue.family, swapchain.get().inFlightFrames)
  result.swapchain = swapchain.get()
  result.emptyTexture = device.uploadTexture(result.queue, EMPTY_TEXTURE)

func shadersForScene(renderer: Renderer, scene: Scene): seq[(MaterialType, ShaderPipeline)] =
  for (materialType, shaderPipeline) in renderer.renderPass.shaderPipelines:
    if scene.usesMaterial(materialType):
      result.add (materialType, shaderPipeline)

func vertexInputsForScene(renderer: Renderer, scene: Scene): seq[ShaderAttribute] =
  var found: Table[string, ShaderAttribute]
  for (materialType, shaderPipeline) in renderer.shadersForScene(scene):
    for input in shaderPipeline.inputs:
      if found.contains(input.name):
        assert input.name == found[input.name].name, &"{input.name}: {input.name} != {found[input.name].name}"
        assert input.theType == found[input.name].theType, &"{input.name}: {input.theType} != {found[input.name].theType}"
        assert input.arrayCount == found[input.name].arrayCount, &"{input.name}: {input.arrayCount} != {found[input.name].arrayCount}"
        assert input.memoryPerformanceHint == found[input.name].memoryPerformanceHint, &"{input.name}: {input.memoryPerformanceHint} != {found[input.name].memoryPerformanceHint}"
      else:
        result.add input
        found[input.name] = input

proc setupDrawableBuffers*(renderer: var Renderer, scene: var Scene) =
  assert not (scene in renderer.scenedata)

  var scenedata = SceneData()

  # find all material data and group it by material type
  for mesh in scene.meshes:
    assert mesh.material != nil, "Mesh {mesh} has no material assigned"
    if not scenedata.materials.contains(mesh.material.theType):
      scenedata.materials[mesh.material.theType] = @[]
    if not scenedata.materials[mesh.material.theType].contains(mesh.material):
      scenedata.materials[mesh.material.theType].add mesh.material

  # automatically populate material and tranform attributes
  for mesh in scene.meshes:
    if not (TRANSFORM_ATTRIB in mesh[].attributes):
      mesh[].initInstanceAttribute(TRANSFORM_ATTRIB, Unit4)
    if not (MATERIALINDEX_ATTRIBUTE in mesh[].attributes):
      mesh[].initInstanceAttribute(MATERIALINDEX_ATTRIBUTE, uint16(scenedata.materials[mesh.material.theType].find(mesh.material)))

  # create index buffer if necessary
  var indicesBufferSize = 0'u64
  for mesh in scene.meshes:
    if mesh[].indexType != MeshIndexType.None:
      let indexAlignment = case mesh[].indexType
        of MeshIndexType.None: 0'u64
        of Tiny: 1'u64
        of Small: 2'u64
        of Big: 4'u64
      # index value alignment required by Vulkan
      if indicesBufferSize mod indexAlignment != 0:
        indicesBufferSize += indexAlignment - (indicesBufferSize mod indexAlignment)
      indicesBufferSize += mesh[].indexSize
  if indicesBufferSize > 0:
    scenedata.indexBuffer = renderer.device.createBuffer(
      size = indicesBufferSize,
      usage = [VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      requireMappable = false,
      preferVRAM = true,
    )

  # calculcate offsets for attributes in vertex buffers
  # trying to use one buffer per memory type
  var perLocationSizes: Table[MemoryPerformanceHint, uint64]
  for hint in MemoryPerformanceHint:
    perLocationSizes[hint] = 0

  let sceneVertexInputs = renderer.vertexInputsForScene(scene)
  let sceneShaders = renderer.shadersForScene(scene)

  for (materialType, shaderPipeline) in sceneShaders:
    scenedata.shaderData[shaderPipeline.vk] = ShaderData()

  for vertexAttribute in sceneVertexInputs:
    scenedata.attributeLocation[vertexAttribute.name] = vertexAttribute.memoryPerformanceHint
    # setup one buffer per vertexAttribute-location-type
    for mesh in scene.meshes:
      # align size to VERTEX_ATTRIB_ALIGNMENT bytes (the important thing is the correct alignment of the offsets, but
      # we need to expand the buffer size as well, therefore considering alignment already here as well
      if perLocationSizes[vertexAttribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
        perLocationSizes[vertexAttribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationSizes[vertexAttribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)
      perLocationSizes[vertexAttribute.memoryPerformanceHint] += mesh[].attributeSize(vertexAttribute.name)

  # create vertex buffers
  for memoryPerformanceHint, bufferSize in perLocationSizes.pairs:
    if bufferSize > 0:
      scenedata.vertexBuffers[memoryPerformanceHint] = renderer.device.createBuffer(
        size = bufferSize,
        usage = [VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        requireMappable = memoryPerformanceHint == PreferFastWrite,
        preferVRAM = true,
      )

  # calculate offset of each attribute for all meshes
  var perLocationOffsets: Table[MemoryPerformanceHint, uint64]
  var indexBufferOffset = 0'u64
  for hint in MemoryPerformanceHint:
    perLocationOffsets[hint] = 0

  for mesh in scene.meshes:
    for attribute in sceneVertexInputs:
      scenedata.vertexBufferOffsets[(mesh, attribute.name)] = perLocationOffsets[attribute.memoryPerformanceHint]
      if mesh[].attributes.contains(attribute.name):
        perLocationOffsets[attribute.memoryPerformanceHint] += mesh[].attributeSize(attribute.name)
        if perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
          perLocationOffsets[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)

    # fill offsets per shaderPipeline (as sequence corresponds to shader input binding)
    var offsets: Table[VkPipeline, seq[(string, MemoryPerformanceHint, uint64)]]
    for (materialType, shaderPipeline) in sceneShaders:
      offsets[shaderPipeline.vk] = newSeq[(string, MemoryPerformanceHint, uint64)]()
      for attribute in shaderPipeline.inputs:
        offsets[shaderPipeline.vk].add (attribute.name, attribute.memoryPerformanceHint, scenedata.vertexBufferOffsets[(mesh, attribute.name)])

    # create drawables
    let indexed = mesh.indexType != MeshIndexType.None
    var drawable = Drawable(
      name: mesh.name,
      elementCount: if indexed: mesh[].indicesCount else: mesh[].vertexCount,
      bufferOffsets: offsets,
      instanceCount: mesh[].instanceCount,
      indexed: indexed,
    )
    if indexed:
      let indexAlignment = case mesh.indexType
        of MeshIndexType.None: 0'u64
        of Tiny: 1'u64
        of Small: 2'u64
        of Big: 4'u64
      # index value alignment required by Vulkan
      if indexBufferOffset mod indexAlignment != 0:
        indexBufferOffset += indexAlignment - (indexBufferOffset mod indexAlignment)
      drawable.indexBufferOffset = indexBufferOffset
      drawable.indexType = mesh.indexType
      var (pdata, size) = mesh[].getRawIndexData()
      scenedata.indexBuffer.setData(renderer.queue, pdata, size, indexBufferOffset)
      indexBufferOffset += size
    scenedata.drawables.add (drawable, mesh)

  # setup uniforms and textures (anything descriptor)
  var uploadedTextures: Table[Texture, VulkanTexture]
  for (materialType, shaderPipeline) in sceneShaders:
    # gather textures
    for texture in shaderPipeline.samplers:
      scenedata.shaderData[shaderPipeline.vk].textures[texture.name] = newSeq[VulkanTexture]()
      if scene.shaderGlobals.contains(texture.name):
        for textureValue in scene.shaderGlobals[texture.name][Texture][]:
          if not uploadedTextures.contains(textureValue):
            uploadedTextures[textureValue] = renderer.device.uploadTexture(renderer.queue, textureValue)
          scenedata.shaderData[shaderPipeline.vk].textures[texture.name].add uploadedTextures[textureValue]
      else:
        var foundTexture = false
        for material in scene.getMaterials(materialType):
          if material.hasMatchingAttribute(texture):
            foundTexture = true
            let value = material[texture.name, Texture][]
            assert value.len == 1, &"Mesh material attribute '{texture.name}' has texture-array, but only single textures are allowed"
            if not uploadedTextures.contains(value[0]):
              uploadedTextures[value[0]] = renderer.device.uploadTexture(renderer.queue, value[0])
            scenedata.shaderData[shaderPipeline.vk].textures[texture.name].add uploadedTextures[value[0]]
        assert foundTexture, &"No texture found in shaderGlobals or materials for '{texture.name}'"
      let nTextures = scenedata.shaderData[shaderPipeline.vk].textures[texture.name].len.uint32
      assert (texture.arrayCount == 0 and nTextures == 1) or texture.arrayCount >= nTextures, &"Shader assigned to render '{materialType}' expected {texture.arrayCount} textures for '{texture.name}' but got {nTextures}"
      if texture.arrayCount < nTextures:
        warn &"Shader assigned to render '{materialType}' expected {texture.arrayCount} textures for '{texture.name}' but got {nTextures}"

    # gather uniform sizes
    var uniformBufferSize = 0'u64
    for uniform in shaderPipeline.uniforms:
      uniformBufferSize += uniform.size
    if uniformBufferSize > 0:
      for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
        scenedata.shaderData[shaderPipeline.vk].uniformBuffers.add renderer.device.createBuffer(
          size = uniformBufferSize,
          usage = [VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
          requireMappable = true,
          preferVRAM = true,
        )

    # TODO: rework the whole descriptor/pool/layout stuff, a bit unclear
    var poolsizes = @[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, renderer.swapchain.inFlightFrames.uint32)]
    var nTextures = 0'u32
    for descriptor in shaderPipeline.descriptorSetLayout.descriptors:
      if descriptor.thetype == ImageSampler:
        nTextures += descriptor.count
    if nTextures > 0:
      poolsizes.add (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, nTextures * renderer.swapchain.inFlightFrames.uint32)
    scenedata.shaderData[shaderPipeline.vk].descriptorPool = renderer.device.createDescriptorSetPool(poolsizes)

    scenedata.shaderData[shaderPipeline.vk].descriptorSets = shaderPipeline.setupDescriptors(
      scenedata.shaderData[shaderPipeline.vk].descriptorPool,
      scenedata.shaderData[shaderPipeline.vk].uniformBuffers,
      scenedata.shaderData[shaderPipeline.vk].textures,
      inFlightFrames = renderer.swapchain.inFlightFrames,
      emptyTexture = renderer.emptyTexture,
    )
    for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
      scenedata.shaderData[shaderPipeline.vk].descriptorSets[frame_i].writeDescriptorSet()

  renderer.scenedata[scene] = scenedata

proc updateMeshData*(renderer: var Renderer, scene: var Scene, forceAll = false) =
  assert scene in renderer.scenedata

  var addedBarrier = false;
  for (drawable, mesh) in renderer.scenedata[scene].drawables.mitems:
    if mesh[].attributes.contains(TRANSFORM_ATTRIB):
      mesh[].updateInstanceTransforms(TRANSFORM_ATTRIB)
    let attrs = (if forceAll: mesh[].attributes else: mesh[].dirtyAttributes)
    for attribute in attrs:
      # ignore attributes that are not used in this scene
      if attribute in renderer.scenedata[scene].attributeLocation:
        debug &"Update mesh attribute {attribute}"
        let memoryPerformanceHint = renderer.scenedata[scene].attributeLocation[attribute]
        # if we have to do a vkCmdCopyBuffer (not buffer.canMap), then we want to added a barrier to
        # not infer with the current frame that is being renderer (relevant when we have multiple frames in flight)
        # (remark: ...I think..., I am pretty new to this sync stuff)
        if not renderer.scenedata[scene].vertexBuffers[memoryPerformanceHint].canMap and not addedBarrier:
          withSingleUseCommandBuffer(renderer.device, renderer.queue, commandBuffer):
            let barrier = VkMemoryBarrier(
              sType: VK_STRUCTURE_TYPE_MEMORY_BARRIER,
              srcAccessMask: [VK_ACCESS_MEMORY_READ_BIT].toBits,
              dstAccessMask: [VK_ACCESS_MEMORY_WRITE_BIT].toBits,
            )
            commandBuffer.pipelineBarrier(
              srcStages = [VK_PIPELINE_STAGE_VERTEX_INPUT_BIT],
              dstStages = [VK_PIPELINE_STAGE_TRANSFER_BIT],
              memoryBarriers = [barrier]
            )
            addedBarrier = true
        renderer.scenedata[scene].vertexBuffers[memoryPerformanceHint].setData(
          renderer.queue,
          mesh[].getPointer(attribute),
          mesh[].attributeSize(attribute),
          renderer.scenedata[scene].vertexBufferOffsets[(mesh, attribute)]
        )
    mesh[].clearDirtyAttributes()

proc updateUniformData*(renderer: var Renderer, scene: var Scene, forceAll = false) =
  assert scene in renderer.scenedata

  let dirty = scene.dirtyShaderGlobals

  if forceAll:
    debug "Update uniforms because 'forceAll' was given"
  elif dirty.len > 0:
    debug &"Update uniforms because of dirty scene globals: {dirty}"

  # loop over all used shaders/pipelines
  for (materialType, shaderPipeline) in renderer.shadersForScene(scene):
    if renderer.scenedata[scene].shaderData[shaderPipeline.vk].uniformBuffers.len > 0:
      var dirtyMaterialAttribs: seq[string]
      for material in renderer.scenedata[scene].materials[materialType].mitems:
        dirtyMaterialAttribs.add material.dirtyAttributes
        material.clearDirtyAttributes()
      assert renderer.scenedata[scene].shaderData[shaderPipeline.vk].uniformBuffers[renderer.swapchain.currentInFlight].vk.valid
      if forceAll:
        for buffer in renderer.scenedata[scene].shaderData[shaderPipeline.vk].uniformBuffers:
          assert buffer.vk.valid

      var offset = 0'u64
      # loop over all uniforms of the shader-shaderPipeline
      for uniform in shaderPipeline.uniforms:
        if dirty.contains(uniform.name) or dirtyMaterialAttribs.contains(uniform.name) or forceAll: # only update uniforms if necessary
          var value = initDataList(uniform.theType)
          if scene.shaderGlobals.hasKey(uniform.name):
            assert scene.shaderGlobals[uniform.name].thetype == uniform.thetype
            value = scene.shaderGlobals[uniform.name]
          else:
            var foundValue = false
            for material in renderer.scenedata[scene].materials[materialType]:
              if material.hasMatchingAttribute(uniform):
                value.appendValues(material[uniform.name])
                foundValue = true
            assert foundValue, &"Uniform '{uniform.name}' not found in scene shaderGlobals or materials"
          assert (uniform.arrayCount == 0 and value.len == 1) or value.len.uint <= uniform.arrayCount, &"Uniform '{uniform.name}' found has wrong length (shader declares {uniform.arrayCount} but shaderGlobals and materials provide {value.len})"
          if value.len.uint <= uniform.arrayCount:
            debug &"Uniform '{uniform.name}' found has short length (shader declares {uniform.arrayCount} but shaderGlobals and materials provide {value.len})"
          assert value.size <= uniform.size, &"During uniform update: gathered value has size {value.size} but uniform expects size {uniform.size}"
          if value.size < uniform.size:
            debug &"During uniform update: gathered value has size {value.size} but uniform expects size {uniform.size}"
          debug &"  update uniform '{uniform.name}' with value: {value}"
          # TODO: technically we would only need to update the uniform buffer of the current
          # frameInFlight (I think), but we don't track for which frame the shaderglobals are no longer dirty
          # therefore we have to update the uniform values in all buffers, of all inFlightframes (usually 2)
          for buffer in renderer.scenedata[scene].shaderData[shaderPipeline.vk].uniformBuffers:
            buffer.setData(renderer.queue, value.getPointer(), value.size, offset)
        offset += uniform.size
  scene.clearDirtyShaderGlobals()

proc startNewFrame*(renderer: var Renderer) =
  # TODO: chance for an infinity-loop?
  while not renderer.swapchain.acquireNextFrame():
    checkVkResult renderer.device.vk.vkDeviceWaitIdle()
    let res = renderer.swapchain.recreate()
    if not res.isSome:
      raise newException(Exception, "Unable to recreate swapchain")
    var oldSwapchain = renderer.swapchain
    renderer.swapchain = res.get()
    checkVkResult renderer.device.vk.vkDeviceWaitIdle()
    oldSwapchain.destroy()
  renderer.nextFrameReady = true

proc render*(renderer: var Renderer, scene: Scene) =
  assert scene in renderer.scenedata
  assert renderer.nextFrameReady, "startNewFrame() must be called before calling render()"

  # preparation
  renderer.currentFrameCommandBuffer.beginRenderCommands(renderer.renderPass, renderer.swapchain.currentFramebuffer(), oneTimeSubmit = true)

  # debug output
  debug "Scene buffers:"
  for (location, buffer) in renderer.scenedata[scene].vertexBuffers.pairs:
    debug "  ", location, ": ", buffer
  debug "  Index buffer: ", renderer.scenedata[scene].indexBuffer

  # draw all meshes
  for (materialType, shaderPipeline) in renderer.renderPass.shaderPipelines:
    if scene.usesMaterial(materialType):
      debug &"Start shaderPipeline for '{materialType}'"
      renderer.currentFrameCommandBuffer.vkCmdBindPipeline(VK_PIPELINE_BIND_POINT_GRAPHICS, shaderPipeline.vk)
      renderer.currentFrameCommandBuffer.vkCmdBindDescriptorSets(
        VK_PIPELINE_BIND_POINT_GRAPHICS,
        shaderPipeline.layout,
        0,
        1,
        addr(renderer.scenedata[scene].shaderData[shaderPipeline.vk].descriptorSets[renderer.swapchain.currentInFlight].vk),
        0,
        nil
      )
      for (drawable, mesh) in renderer.scenedata[scene].drawables.filterIt(it[1].visible and it[1].material.theType == materialType):
        drawable.draw(renderer.currentFrameCommandBuffer, vertexBuffers = renderer.scenedata[scene].vertexBuffers, indexBuffer = renderer.scenedata[scene].indexBuffer, shaderPipeline.vk)

  # done rendering
  renderer.currentFrameCommandBuffer.endRenderCommands()

  # swap framebuffer
  if not renderer.swapchain.swap(renderer.queue, renderer.currentFrameCommandBuffer):
    let res = renderer.swapchain.recreate()
    if res.isSome:
      var oldSwapchain = renderer.swapchain
      renderer.swapchain = res.get()
      checkVkResult renderer.device.vk.vkDeviceWaitIdle()
      oldSwapchain.destroy()
  renderer.swapchain.currentInFlight = (renderer.swapchain.currentInFlight + 1) mod renderer.swapchain.inFlightFrames
  renderer.nextFrameReady = false

func valid*(renderer: Renderer): bool =
  renderer.device.vk.valid

proc destroy*(renderer: var Renderer, scene: Scene) =
  checkVkResult renderer.device.vk.vkDeviceWaitIdle()
  var scenedata = renderer.scenedata[scene]

  for buffer in scenedata.vertexBuffers.mvalues:
    assert buffer.vk.valid
    buffer.destroy()

  if scenedata.indexBuffer.vk.valid:
    assert scenedata.indexBuffer.vk.valid
    scenedata.indexBuffer.destroy()

  var destroyedTextures: seq[VkImage]

  for (vkPipeline, shaderData) in scenedata.shaderData.mpairs:

    for buffer in shaderData.uniformBuffers.mitems:
      assert buffer.vk.valid
      buffer.destroy()

    for textures in shaderData.textures.mvalues:
      for texture in textures.mitems:
        if not destroyedTextures.contains(texture.image.vk):
          destroyedTextures.add texture.image.vk
          texture.destroy()

    shaderData.descriptorPool.destroy()

  renderer.scenedata.del(scene)

proc destroy*(renderer: var Renderer) =
  for scene in renderer.scenedata.keys.toSeq:
    renderer.destroy(scene)
  assert renderer.scenedata.len == 0
  renderer.emptyTexture.destroy()
  renderer.renderPass.destroy()
  renderer.commandBufferPool.destroy()
  renderer.swapchain.destroy()
