import std/options
import std/tables
import std/strformat
import std/sequtils
import std/logging
import std/enumerate

import ./core
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

const MATERIALINDEXATTRIBUTE = "materialIndex"
const TRANSFORMATTRIBUTE = "transform"

type
  SceneData = object
    drawables*: seq[tuple[drawable: Drawable, meshIndex: int]]
    vertexBuffers*: Table[MemoryPerformanceHint, Buffer]
    indexBuffer*: Buffer
    uniformBuffers*: Table[VkPipeline, seq[Buffer]] # one per frame-in-flight
    textures*: Table[string, seq[VulkanTexture]] # per frame-in-flight
    attributeLocation*: Table[string, MemoryPerformanceHint]
    vertexBufferOffsets*: Table[(int, string), int]
    descriptorPools*: Table[VkPipeline, DescriptorPool]
    descriptorSets*: Table[VkPipeline, seq[DescriptorSet]]
    materials: seq[Material]
  Renderer* = object
    device: Device
    surfaceFormat: VkSurfaceFormatKHR
    renderPass: RenderPass
    swapchain: Swapchain
    scenedata: Table[Scene, SceneData]
    emptyTexture: VulkanTexture

func usesMaterialType(scene: Scene, materialType: string): bool =
  return scene.meshes.anyIt(it.material.materialType == materialType)

func getPipelineForMaterialtype(renderer: Renderer, materialType: string): Option[Pipeline] =
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for pipelineMaterialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if pipelineMaterialType == materialType:
        return some(pipeline)

proc initRenderer*(device: Device, shaders: Table[string, ShaderConfiguration], clearColor=Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32])): Renderer =
  assert device.vk.valid
  
  result.device = device
  result.renderPass = device.simpleForwardRenderPass(shaders, clearColor=clearColor)
  result.surfaceFormat = device.physicalDevice.getSurfaceFormats().filterSurfaceFormat()
  # use last renderpass as output for swapchain
  let swapchain = device.createSwapchain(result.renderPass.vk, result.surfaceFormat, device.firstGraphicsQueue().get().family)
  if not swapchain.isSome:
    raise newException(Exception, "Unable to create swapchain")

  result.swapchain = swapchain.get()
  result.emptyTexture = device.uploadTexture(EMPTYTEXTURE)

func inputs(renderer: Renderer, scene: Scene): seq[ShaderAttribute] =
  var found: Table[string, ShaderAttribute]
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterialType(materialType):
        for input in pipeline.inputs:
          if found.contains(input.name):
            assert input == found[input.name]
          else:
            result.add input
            found[input.name] = input

func samplers(renderer: Renderer, scene: Scene): seq[ShaderAttribute] =
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterialType(materialType):
        result.add pipeline.samplers

func materialCompatibleWithPipeline(scene: Scene, material: Material, pipeline: Pipeline): (bool, string) =
  for uniform in pipeline.uniforms:
    if scene.shaderGlobals.contains(uniform.name):
      if scene.shaderGlobals[uniform.name].theType != uniform.theType:
        return (false, &"shader uniform needs type {uniform.theType} but scene global is of type {scene.shaderGlobals[uniform.name].theType}")
    else:
      var foundMatch = false
      for name, constant in material.constants.pairs:
        if name == uniform.name and constant.theType == uniform.theType:
          foundMatch = true
          break
      if not foundMatch:
        return (false, "shader uniform '{uniform.name}' was not found in scene globals or scene materials")
  for sampler in pipeline.samplers:
    var foundMatch = false
    for name, value in material.textures:
      if name == sampler.name:
        foundMatch = true
        break
    if not foundMatch:
      return (false, "Required texture for shader sampler '{sampler.name}' was not found in scene materials")

  return (true, "")

func meshCompatibleWithPipeline(scene: Scene, mesh: Mesh, pipeline: Pipeline): (bool, string) =
  for input in pipeline.inputs:
    if not (input.name in mesh.attributes):
      return (false, &"Shader input '{input.name}' is not available for mesh '{mesh}'")
    if input.theType != mesh.attributeType(input.name):
      return (false, &"Shader input '{input.name}' expects type {input.theType}, but mesh '{mesh}' has {mesh.attributeType(input.name)}")
    if input.perInstance != mesh.instanceAttributes.contains(input.name):
      return (false, &"Shader input '{input.name}' expects to be per instance, but mesh '{mesh}' has is not as instance attribute")

  return materialCompatibleWithPipeline(scene, mesh.material, pipeline)

func checkSceneIntegrity(renderer: Renderer, scene: Scene) =
  var foundRenderableObject = false
  var shaderTypes: seq[string]
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      shaderTypes.add materialType
      for mesh in scene.meshes:
        if mesh.material.materialType == materialType:
          foundRenderableObject = true
          let (error, message) = scene.meshCompatibleWithPipeline(mesh, pipeline)
          if error:
            raise newException(Exception, &"Mesh '{mesh}' not compatible with assigned pipeline ({materialType}) because: {message}")

  if not foundRenderableObject:
    var materialTypes: seq[string]
    for mesh in scene.meshes:
      if not materialTypes.contains(mesh.material.materialType):
          materialTypes.add mesh.material.materialType
    raise newException(Exception, &"Scene {scene.name} has been added but materials are not compatible with any registered shader: Materials in scene: {materialTypes}, registered shader-materialtypes: {shaderTypes}")

proc setupDrawableBuffers*(renderer: var Renderer, scene: var Scene) =
  assert not (scene in renderer.scenedata)
  renderer.checkSceneIntegrity(scene)

  const VERTEX_ATTRIB_ALIGNMENT = 4 # used for buffer alignment

  let
    inputs = renderer.inputs(scene)
    samplers = renderer.samplers(scene)
  var scenedata = SceneData()

  for mesh in scene.meshes:
    if not scenedata.materials.contains(mesh.material):
      scenedata.materials.add mesh.material
      for textureName, texture in mesh.material.textures.pairs:
        if not scenedata.textures.hasKey(textureName):
          scenedata.textures[textureName] = @[]
        scenedata.textures[textureName].add renderer.device.uploadTexture(texture)

  # find all meshes, populate missing attribute values for shader
  for mesh in scene.meshes.mitems:
    for inputAttr in inputs:
      if inputAttr.name == TRANSFORMATTRIBUTE:
        mesh.initInstanceAttribute(inputAttr.name, inputAttr.thetype)
      elif inputAttr.name == MATERIALINDEXATTRIBUTE:
        let matIndex = scenedata.materials.find(mesh.material)
        if matIndex < 0:
          raise newException(Exception, &"Required material '{mesh.material}' not available in scene (available are: {scenedata.materials})")
        mesh.initInstanceAttribute(inputAttr.name, uint16(matIndex))
      elif not mesh.attributes.contains(inputAttr.name):
        warn(&"Mesh is missing data for shader attribute {inputAttr.name}, auto-filling with empty values")
        if inputAttr.perInstance:
          mesh.initInstanceAttribute(inputAttr.name, inputAttr.thetype)
        else:
          mesh.initVertexAttribute(inputAttr.name, inputAttr.thetype)
      assert mesh.attributeType(inputAttr.name) == inputAttr.thetype, &"mesh attribute {inputAttr.name} has type {mesh.attributeType(inputAttr.name)} but shader expects {inputAttr.thetype}"
  
  # create index buffer if necessary
  var indicesBufferSize = 0
  for mesh in scene.meshes:
    if mesh.indexType != MeshIndexType.None:
      let indexAlignment = case mesh.indexType
        of MeshIndexType.None: 0
        of Tiny: 1
        of Small: 2
        of Big: 4
      # index value alignment required by Vulkan
      if indicesBufferSize mod indexAlignment != 0:
        indicesBufferSize += indexAlignment - (indicesBufferSize mod indexAlignment)
      indicesBufferSize += mesh.indexSize
  if indicesBufferSize > 0:
    scenedata.indexBuffer = renderer.device.createBuffer(
      size=indicesBufferSize,
      usage=[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      requireMappable=false,
      preferVRAM=true,
    )

  # calculcate offsets for attributes in vertex buffers
  # trying to use one buffer per memory type
  var perLocationSizes: Table[MemoryPerformanceHint, int]
  for hint in MemoryPerformanceHint:
    perLocationSizes[hint] = 0
  for attribute in inputs:
    scenedata.attributeLocation[attribute.name] = attribute.memoryPerformanceHint
    # setup one buffer per attribute-location-type
    for mesh in scene.meshes:
      # align size to VERTEX_ATTRIB_ALIGNMENT bytes (the important thing is the correct alignment of the offsets, but
      # we need to expand the buffer size as well, therefore considering alignment already here as well
      if perLocationSizes[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
        perLocationSizes[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationSizes[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)
      perLocationSizes[attribute.memoryPerformanceHint] += mesh.attributeSize(attribute.name)

  # create vertex buffers
  for memoryPerformanceHint, bufferSize in perLocationSizes.pairs:
    if bufferSize > 0:
      scenedata.vertexBuffers[memoryPerformanceHint] = renderer.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        requireMappable=memoryPerformanceHint==PreferFastWrite,
        preferVRAM=true,
      )

  # calculate offset of each attribute of all meshes
  var perLocationOffsets: Table[MemoryPerformanceHint, int]
  var indexBufferOffset = 0
  for hint in MemoryPerformanceHint:
    perLocationOffsets[hint] = 0

  for (meshIndex, mesh) in enumerate(scene.meshes):
    for attribute in inputs:
      scenedata.vertexBufferOffsets[(meshIndex, attribute.name)] = perLocationOffsets[attribute.memoryPerformanceHint]
      let size = mesh.getRawData(attribute.name)[1]
      perLocationOffsets[attribute.memoryPerformanceHint] += size
      if perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
        perLocationOffsets[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)

    # fill offsets per pipeline (as sequence corresponds to shader input binding)
    var offsets: Table[VkPipeline, seq[(string, MemoryPerformanceHint, int)]]
    for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
      for materialType, pipeline in renderer.renderPass.subpasses[subpass_i].pipelines.pairs:
        if scene.usesMaterialType(materialType):
          offsets[pipeline.vk] = newSeq[(string, MemoryPerformanceHint, int)]()
          for attribute in pipeline.inputs:
            offsets[pipeline.vk].add (attribute.name, attribute.memoryPerformanceHint, scenedata.vertexBufferOffsets[(meshIndex, attribute.name)])

    # create drawables
    let indexed = mesh.indexType != MeshIndexType.None
    var drawable = Drawable(
      elementCount: if indexed: mesh.indicesCount else: mesh.vertexCount,
      bufferOffsets: offsets,
      instanceCount: mesh.instanceCount,
      indexed: indexed,
    )
    if indexed:
      let indexAlignment = case mesh.indexType
        of MeshIndexType.None: 0
        of Tiny: 1
        of Small: 2
        of Big: 4
      # index value alignment required by Vulkan
      if indexBufferOffset mod indexAlignment != 0:
        indexBufferOffset += indexAlignment - (indexBufferOffset mod indexAlignment)
      drawable.indexBufferOffset = indexBufferOffset
      drawable.indexType = mesh.indexType
      var (pdata, size) = mesh.getRawIndexData()
      scenedata.indexBuffer.setData(pdata, size, indexBufferOffset)
      indexBufferOffset += size
    scenedata.drawables.add (drawable, meshIndex)

  # setup uniforms and samplers
  for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[subpass_i].pipelines.pairs:
      if scene.usesMaterialType(materialType):
        var uniformBufferSize = 0
        for uniform in pipeline.uniforms:
          uniformBufferSize += uniform.size
        if uniformBufferSize > 0:
          scenedata.uniformBuffers[pipeline.vk] = newSeq[Buffer]()
          for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
            scenedata.uniformBuffers[pipeline.vk].add renderer.device.createBuffer(
              size=uniformBufferSize,
              usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
              requireMappable=true,
              preferVRAM=true,
            )
            
        var poolsizes = @[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, renderer.swapchain.inFlightFrames)]
        if samplers.len > 0:
          var samplercount = 0
          for sampler in samplers:
            samplercount += (if sampler.arrayCount == 0: 1 else: sampler.arrayCount)
          poolsizes.add (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, renderer.swapchain.inFlightFrames * samplercount * 2)
      
        scenedata.descriptorPools[pipeline.vk] = renderer.device.createDescriptorSetPool(poolsizes)
    
        scenedata.descriptorSets[pipeline.vk] = pipeline.setupDescriptors(
          scenedata.descriptorPools[pipeline.vk],
          scenedata.uniformBuffers.getOrDefault(pipeline.vk, @[]),
          scenedata.textures,
          inFlightFrames=renderer.swapchain.inFlightFrames,
          emptyTexture=renderer.emptyTexture,
        )
        for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
          scenedata.descriptorSets[pipeline.vk][frame_i].writeDescriptorSet()

  renderer.scenedata[scene] = scenedata

proc refreshMeshAttributeData(renderer: Renderer, scene: Scene, drawable: Drawable, meshIndex: int, attribute: string) =
  debug &"Refreshing data on mesh {scene.meshes[meshIndex]} for {attribute}"
  # ignore attributes that are not used in this shader
  if not (attribute in renderer.scenedata[scene].attributeLocation):
    return
  var (pdata, size) = scene.meshes[meshIndex].getRawData(attribute)
  let memoryPerformanceHint = renderer.scenedata[scene].attributeLocation[attribute]
  renderer.scenedata[scene].vertexBuffers[memoryPerformanceHint].setData(pdata, size, renderer.scenedata[scene].vertexBufferOffsets[(meshIndex, attribute)])

proc updateMeshData*(renderer: var Renderer, scene: var Scene, forceAll=false) =
  assert scene in renderer.scenedata

  for (drawable, meshIndex) in renderer.scenedata[scene].drawables.mitems:
    if scene.meshes[meshIndex].attributes.contains(TRANSFORMATTRIBUTE):
      scene.meshes[meshIndex].updateInstanceTransforms(TRANSFORMATTRIBUTE)
    let attrs = (if forceAll: scene.meshes[meshIndex].attributes else: scene.meshes[meshIndex].dirtyAttributes)
    for attribute in attrs:
      renderer.refreshMeshAttributeData(scene, drawable, meshIndex, attribute)
      debug &"Update mesh attribute {attribute}"
    scene.meshes[meshIndex].clearDirtyAttributes()

proc updateUniformData*(renderer: var Renderer, scene: var Scene) =
  assert scene in renderer.scenedata

  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterialType(materialType) and renderer.scenedata[scene].uniformBuffers.hasKey(pipeline.vk) and renderer.scenedata[scene].uniformBuffers[pipeline.vk].len != 0:
        assert renderer.scenedata[scene].uniformBuffers[pipeline.vk][renderer.swapchain.currentInFlight].vk.valid
        var offset = 0
        for uniform in pipeline.uniforms:
          var value = newDataList(thetype=uniform.thetype)
          if scene.shaderGlobals.hasKey(uniform.name):
            assert scene.shaderGlobals[uniform.name].thetype == value.thetype
            value = scene.shaderGlobals[uniform.name]
          else:
            for mat in renderer.scenedata[scene].materials:
                for name, materialConstant in mat.constants.pairs:
                  if uniform.name == name:
                    value.appendValue(materialConstant)
          if value.len == 0:
            raise newException(Exception, &"Uniform '{uniform.name}' not found in scene shaderGlobals or materials")
          debug &"Update uniform {uniform.name}"
          let (pdata, size) = value.getRawData()
          renderer.scenedata[scene].uniformBuffers[pipeline.vk][renderer.swapchain.currentInFlight].setData(pdata, size, offset)
          offset += size

proc render*(renderer: var Renderer, scene: Scene) =
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

  debug "Scene buffers:"
  for (location, buffer) in renderer.scenedata[scene].vertexBuffers.pairs:
    debug "  ", location, ": ", buffer
  debug "  Index buffer: ", renderer.scenedata[scene].indexBuffer

  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialType, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterialType(materialType):
        debug &"Start pipeline for {materialType}"
        commandBuffer.vkCmdBindPipeline(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.vk)
        commandBuffer.vkCmdBindDescriptorSets(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.layout, 0, 1, addr(renderer.scenedata[scene].descriptorSets[pipeline.vk][renderer.swapchain.currentInFlight].vk), 0, nil)

        for (drawable, meshIndex) in renderer.scenedata[scene].drawables:
          if scene.meshes[meshIndex].material.materialType == materialType:
            drawable.draw(commandBuffer, vertexBuffers=renderer.scenedata[scene].vertexBuffers, indexBuffer=renderer.scenedata[scene].indexBuffer, pipeline.vk)

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
  for scenedata in renderer.scenedata.mvalues:
    for buffer in scenedata.vertexBuffers.mvalues:
      assert buffer.vk.valid
      buffer.destroy()
    if scenedata.indexBuffer.vk.valid:
      assert scenedata.indexBuffer.vk.valid
      scenedata.indexBuffer.destroy()
    for pipelineUniforms in scenedata.uniformBuffers.mvalues:
      for buffer in pipelineUniforms.mitems:
        assert buffer.vk.valid
        buffer.destroy()
    for textures in scenedata.textures.mvalues:
      for texture in textures.mitems:
        texture.destroy()
    for descriptorPool in scenedata.descriptorPools.mvalues:
      descriptorPool.destroy()
  renderer.emptyTexture.destroy()
  renderer.renderPass.destroy()
  renderer.swapchain.destroy()
