import std/options
import std/tables
import std/strformat
import std/sequtils
import std/logging

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

const TRANSFORMATTRIBUTE = "transform"
const VERTEX_ATTRIB_ALIGNMENT = 4 # used for buffer alignment

type
  SceneData = ref object
    drawables*: seq[tuple[drawable: Drawable, mesh: Mesh]]
    vertexBuffers*: Table[MemoryPerformanceHint, Buffer]
    indexBuffer*: Buffer
    uniformBuffers*: Table[VkPipeline, seq[Buffer]] # one per frame-in-flight
    textures*: Table[string, seq[VulkanTexture]] # per frame-in-flight
    attributeLocation*: Table[string, MemoryPerformanceHint]
    vertexBufferOffsets*: Table[(Mesh, string), int]
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

func usesMaterial(scene: Scene, materialName: string): bool =
  return scene.meshes.anyIt(it.material.name == materialName)

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
    for materialName, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterial(materialName):
        for input in pipeline.inputs:
          if found.contains(input.name):
            assert input.name == found[input.name].name, &"{input.name}: {input.name} != {found[input.name].name}"
            assert input.theType == found[input.name].theType, &"{input.name}: {input.theType} != {found[input.name].theType}"
            assert input.arrayCount == found[input.name].arrayCount, &"{input.name}: {input.arrayCount} != {found[input.name].arrayCount}"
            assert input.memoryPerformanceHint == found[input.name].memoryPerformanceHint, &"{input.name}: {input.memoryPerformanceHint} != {found[input.name].memoryPerformanceHint}"
          else:
            result.add input
            found[input.name] = input

func samplers(renderer: Renderer, scene: Scene): seq[ShaderAttribute] =
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialName, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterial(materialName):
        result.add pipeline.samplers

func materialCompatibleWithPipeline(scene: Scene, material: Material, pipeline: Pipeline): (bool, string) =
  for uniform in pipeline.uniforms:
    if scene.shaderGlobals.contains(uniform.name):
      if scene.shaderGlobals[uniform.name].theType != uniform.theType:
        return (true, &"shader uniform needs type {uniform.theType} but scene global is of type {scene.shaderGlobals[uniform.name].theType}")
    else:
      var foundMatch = true
      for name, constant in material.constants.pairs:
        if name == uniform.name and constant.theType == uniform.theType:
          foundMatch = true
          break
      if not foundMatch:
        return (true, &"shader uniform '{uniform.name}' was not found in scene globals or scene materials")
  for sampler in pipeline.samplers:
    if scene.shaderGlobals.contains(sampler.name):
      if scene.shaderGlobals[sampler.name].theType != sampler.theType:
        return (true, &"shader sampler '{sampler.name}' needs type {sampler.theType} but scene global is of type {scene.shaderGlobals[sampler.name].theType}")
    else:
      var foundMatch = true
      for name, value in material.textures:
        if name == sampler.name:
          foundMatch = true
          break
      if not foundMatch:
        return (true, &"Required texture for shader sampler '{sampler.name}' was not found in scene materials")

  return (false, "")

func meshCompatibleWithPipeline(scene: Scene, mesh: Mesh, pipeline: Pipeline): (bool, string) =
  for input in pipeline.inputs:
    if input.name == TRANSFORMATTRIBUTE: # will be populated automatically
      continue
    if not (input.name in mesh[].attributes):
      return (true, &"Shader input '{input.name}' is not available for mesh '{mesh}'")
    if input.theType != mesh[].attributeType(input.name):
      return (true, &"Shader input '{input.name}' expects type {input.theType}, but mesh '{mesh}' has {mesh[].attributeType(input.name)}")
    if not input.perInstance and not mesh[].vertexAttributes.contains(input.name):
      return (true, &"Shader input '{input.name}' expected to be vertex attribute, but mesh has no such vertex attribute (available are: {mesh[].vertexAttributes})")
    if input.perInstance and not mesh[].instanceAttributes.contains(input.name):
      return (true, &"Shader input '{input.name}' expected to be per instance attribute, but mesh has no such instance attribute (available are: {mesh[].instanceAttributes})")

  return materialCompatibleWithPipeline(scene, mesh.material, pipeline)

func checkSceneIntegrity(renderer: Renderer, scene: Scene) =
  if scene.meshes.len == 0:
    return

  var foundRenderableObject = false
  var shaderTypes: seq[string]
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialName, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      shaderTypes.add materialName
      for mesh in scene.meshes:
        if mesh.material.name == materialName:
          foundRenderableObject = true
          let (error, message) = scene.meshCompatibleWithPipeline(mesh, pipeline)
          if error:
            raise newException(Exception, &"Mesh '{mesh}' not compatible with assigned pipeline ({materialName}) because: {message}")

  if not foundRenderableObject:
    var materialTypes: seq[string]
    for mesh in scene.meshes:
      if not materialTypes.contains(mesh.material.name):
          materialTypes.add mesh.material.name
    raise newException(Exception, &"Scene '{scene.name}' has been added but materials are not compatible with any registered shader: Materials in scene: {materialTypes}, registered shader-materialtypes: {shaderTypes}")

proc setupDrawableBuffers*(renderer: var Renderer, scene: var Scene) =
  assert not (scene in renderer.scenedata)
  renderer.checkSceneIntegrity(scene)

  let
    inputs = renderer.inputs(scene)
    samplers = renderer.samplers(scene)
  var scenedata = SceneData()

  for mesh in scene.meshes:
    if not scenedata.materials.contains(mesh.material):
      scenedata.materials.add mesh.material
      for textureName, texture in mesh.material.textures.pairs:
        if scene.shaderGlobals.contains(textureName) and scene.shaderGlobals[textureName].theType == Sampler2D:
          warn &"Ignoring material texture '{textureName}' as scene-global textures with the same name have been defined"
        else:
          if not scenedata.textures.hasKey(textureName):
            scenedata.textures[textureName] = @[]
          scenedata.textures[textureName].add renderer.device.uploadTexture(texture)

  for name, value in scene.shaderGlobals.pairs:
    if value.theType == Sampler2D:
      assert not scenedata.textures.contains(name) # should be handled by the above code
      scenedata.textures[name] = @[]
      for texture in getValues[Texture](value)[]:
        scenedata.textures[name].add renderer.device.uploadTexture(texture)


  # find all meshes, populate missing attribute values for shader
  for mesh in scene.meshes.mitems:
    for inputAttr in inputs:
      if inputAttr.name == TRANSFORMATTRIBUTE:
        mesh[].initInstanceAttribute(inputAttr.name, inputAttr.thetype)
      elif not mesh[].attributes.contains(inputAttr.name):
        warn(&"Mesh is missing data for shader attribute {inputAttr.name}, auto-filling with empty values")
        if inputAttr.perInstance:
          mesh[].initInstanceAttribute(inputAttr.name, inputAttr.thetype)
        else:
          mesh[].initVertexAttribute(inputAttr.name, inputAttr.thetype)
      assert mesh[].attributeType(inputAttr.name) == inputAttr.thetype, &"mesh attribute {inputAttr.name} has type {mesh[].attributeType(inputAttr.name)} but shader expects {inputAttr.thetype}"
  
  # create index buffer if necessary
  var indicesBufferSize = 0
  for mesh in scene.meshes:
    if mesh[].indexType != MeshIndexType.None:
      let indexAlignment = case mesh[].indexType
        of MeshIndexType.None: 0
        of Tiny: 1
        of Small: 2
        of Big: 4
      # index value alignment required by Vulkan
      if indicesBufferSize mod indexAlignment != 0:
        indicesBufferSize += indexAlignment - (indicesBufferSize mod indexAlignment)
      indicesBufferSize += mesh[].indexSize
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
      perLocationSizes[attribute.memoryPerformanceHint] += mesh[].attributeSize(attribute.name)

  # create vertex buffers
  for memoryPerformanceHint, bufferSize in perLocationSizes.pairs:
    if bufferSize > 0:
      scenedata.vertexBuffers[memoryPerformanceHint] = renderer.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        requireMappable=memoryPerformanceHint==PreferFastWrite,
        preferVRAM=true,
      )

  # calculate offset of each attribute for all meshes
  var perLocationOffsets: Table[MemoryPerformanceHint, int]
  var indexBufferOffset = 0
  for hint in MemoryPerformanceHint:
    perLocationOffsets[hint] = 0

  for mesh in scene.meshes:
    for attribute in inputs:
      scenedata.vertexBufferOffsets[(mesh, attribute.name)] = perLocationOffsets[attribute.memoryPerformanceHint]
      let size = mesh[].getRawData(attribute.name)[1]
      perLocationOffsets[attribute.memoryPerformanceHint] += size
      if perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
        perLocationOffsets[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)

    # fill offsets per pipeline (as sequence corresponds to shader input binding)
    var offsets: Table[VkPipeline, seq[(string, MemoryPerformanceHint, int)]]
    for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
      for materialName, pipeline in renderer.renderPass.subpasses[subpass_i].pipelines.pairs:
        if scene.usesMaterial(materialName):
          offsets[pipeline.vk] = newSeq[(string, MemoryPerformanceHint, int)]()
          for attribute in pipeline.inputs:
            offsets[pipeline.vk].add (attribute.name, attribute.memoryPerformanceHint, scenedata.vertexBufferOffsets[(mesh, attribute.name)])

    # create drawables
    let indexed = mesh.indexType != MeshIndexType.None
    var drawable = Drawable(
      elementCount: if indexed: mesh[].indicesCount else: mesh[].vertexCount,
      bufferOffsets: offsets,
      instanceCount: mesh[].instanceCount,
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
      var (pdata, size) = mesh[].getRawIndexData()
      scenedata.indexBuffer.setData(pdata, size, indexBufferOffset)
      indexBufferOffset += size
    scenedata.drawables.add (drawable, mesh)

  # setup uniforms and samplers
  for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
    for materialName, pipeline in renderer.renderPass.subpasses[subpass_i].pipelines.pairs:
      if scene.usesMaterial(materialName):
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

proc refreshMeshAttributeData(renderer: Renderer, scene: var Scene, drawable: Drawable, mesh: Mesh, attribute: string) =
  debug &"Refreshing data on mesh mesh for {attribute}"
  # ignore attributes that are not used in this shader
  if not (attribute in renderer.scenedata[scene].attributeLocation):
    return

  let (pdata, size) = mesh[].getRawData(attribute)
  let memoryPerformanceHint = renderer.scenedata[scene].attributeLocation[attribute]
  renderer.scenedata[scene].vertexBuffers[memoryPerformanceHint].setData(pdata, size, renderer.scenedata[scene].vertexBufferOffsets[(mesh, attribute)])

proc updateMeshData*(renderer: var Renderer, scene: var Scene, forceAll=false) =
  assert scene in renderer.scenedata

  for (drawable, mesh) in renderer.scenedata[scene].drawables.mitems:
    if mesh[].attributes.contains(TRANSFORMATTRIBUTE):
      mesh[].updateInstanceTransforms(TRANSFORMATTRIBUTE)
    let attrs = (if forceAll: mesh[].attributes else: mesh[].dirtyAttributes)
    for attribute in attrs:
      renderer.refreshMeshAttributeData(scene, drawable, mesh, attribute)
      debug &"Update mesh attribute {attribute}"
    mesh[].clearDirtyAttributes()

proc updateUniformData*(renderer: var Renderer, scene: var Scene, forceAll=false) =
  assert scene in renderer.scenedata
  # TODO: maybe check for dirty materials too, but atm we copy materials into the
  # renderers scenedata, so they will are immutable after initialization, would 
  # need to allow updates of materials too in order to make sense

  let dirty = scene.dirtyShaderGlobals
  if not forceAll and dirty.len == 0:
    return

  if forceAll:
    debug "Update uniforms because 'forceAll' was given"
  else:
    debug &"Update uniforms because of dirty scene globals: {dirty}"

  # loop over all used shaders/pipelines
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for materialName, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if (
        scene.usesMaterial(materialName) and
        renderer.scenedata[scene].uniformBuffers.hasKey(pipeline.vk) and
        renderer.scenedata[scene].uniformBuffers[pipeline.vk].len != 0
      ):
        assert renderer.scenedata[scene].uniformBuffers[pipeline.vk][renderer.swapchain.currentInFlight].vk.valid
        if forceAll:
          for buffer in renderer.scenedata[scene].uniformBuffers[pipeline.vk]:
            assert buffer.vk.valid

        var offset = 0
        # loop over all uniforms of the shader-pipeline
        for uniform in pipeline.uniforms:
          var foundValue = false
          var value: DataList
          if scene.shaderGlobals.hasKey(uniform.name):
            assert scene.shaderGlobals[uniform.name].thetype == uniform.thetype
            value = scene.shaderGlobals[uniform.name]
            foundValue = true
          else:
            for mat in renderer.scenedata[scene].materials:
              for name, materialConstant in mat.constants.pairs:
                if uniform.name == name:
                  value = materialConstant
                  foundValue = true
                  break
              if foundValue: break
          if not foundValue:
            raise newException(Exception, &"Uniform '{uniform.name}' not found in scene shaderGlobals or materials")
          debug &"  update uniform {uniform.name} with value: {value}"
          let (pdata, size) = value.getRawData()
          if dirty.contains(uniform.name) or forceAll: # only update if necessary
            # TODO: technically we would only need to update the uniform buffer of the current
            # frameInFlight, but we don't track for which frame the shaderglobals are no longer dirty
            # therefore we have to update the uniform values in all buffers, of all inFlightframes (usually 2)
            for buffer in renderer.scenedata[scene].uniformBuffers[pipeline.vk]:
              buffer.setData(pdata, size, offset)
          offset += size
  scene.clearDirtyShaderGlobals()

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
    for materialName, pipeline in renderer.renderPass.subpasses[i].pipelines.pairs:
      if scene.usesMaterial(materialName):
        debug &"Start pipeline for {materialName}"
        commandBuffer.vkCmdBindPipeline(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.vk)
        commandBuffer.vkCmdBindDescriptorSets(renderer.renderPass.subpasses[i].pipelineBindPoint, pipeline.layout, 0, 1, addr(renderer.scenedata[scene].descriptorSets[pipeline.vk][renderer.swapchain.currentInFlight].vk), 0, nil)

        for (drawable, mesh) in renderer.scenedata[scene].drawables:
          if mesh.material.name == materialName:
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
