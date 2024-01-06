import std/options
import std/tables
import std/strformat
import std/sequtils
import std/strutils
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
import ./material

const TRANSFORM_ATTRIBUTE = "transform"
const MATERIALINDEX_ATTRIBUTE = "materialIndex"
const VERTEX_ATTRIB_ALIGNMENT = 4 # used for buffer alignment

type
  SceneData = ref object
    drawables*: seq[tuple[drawable: Drawable, mesh: Mesh]]
    vertexBuffers*: Table[MemoryPerformanceHint, Buffer]
    indexBuffer*: Buffer
    uniformBuffers*: Table[VkPipeline, seq[Buffer]] # one per frame-in-flight
    textures*: Table[VkPipeline, Table[string, seq[VulkanTexture]]] # per frame-in-flight
    attributeLocation*: Table[string, MemoryPerformanceHint]
    vertexBufferOffsets*: Table[(Mesh, string), int]
    descriptorPools*: Table[VkPipeline, DescriptorPool]
    descriptorSets*: Table[VkPipeline, seq[DescriptorSet]]
    materials: Table[MaterialType, seq[MaterialData]]
  Renderer* = object
    device: Device
    surfaceFormat: VkSurfaceFormatKHR
    renderPass: RenderPass
    swapchain: Swapchain
    scenedata: Table[Scene, SceneData]
    emptyTexture: VulkanTexture

proc initRenderer*(device: Device, shaders: openArray[(MaterialType, ShaderConfiguration)], clearColor=Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32]), backFaceCulling=true): Renderer =
  assert device.vk.valid
  
  result.device = device
  result.renderPass = device.simpleForwardRenderPass(shaders, clearColor=clearColor, backFaceCulling=backFaceCulling)
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
    for (materialType, shaderPipeline) in renderer.renderPass.subpasses[i].shaderPipelines:
      if scene.usesMaterial(materialType):
        for input in shaderPipeline.inputs:
          if found.contains(input.name):
            assert input.name == found[input.name].name, &"{input.name}: {input.name} != {found[input.name].name}"
            assert input.theType == found[input.name].theType, &"{input.name}: {input.theType} != {found[input.name].theType}"
            assert input.arrayCount == found[input.name].arrayCount, &"{input.name}: {input.arrayCount} != {found[input.name].arrayCount}"
            assert input.memoryPerformanceHint == found[input.name].memoryPerformanceHint, &"{input.name}: {input.memoryPerformanceHint} != {found[input.name].memoryPerformanceHint}"
          else:
            result.add input
            found[input.name] = input

func materialCompatibleWithPipeline(scene: Scene, materialType: MaterialType, shaderPipeline: ShaderPipeline): (bool, string) =
  for uniform in shaderPipeline.uniforms:
    if scene.shaderGlobals.contains(uniform.name):
      if scene.shaderGlobals[uniform.name].theType != uniform.theType:
        return (true, &"shader uniform needs type {uniform.theType} but scene global is of type {scene.shaderGlobals[uniform.name].theType}")
    else:
      if not materialType.hasMatchingAttribute(uniform):
        return (true, &"shader uniform '{uniform.name}' was not found in scene globals or scene materials")
  for texture in shaderPipeline.samplers:
    if scene.shaderGlobals.contains(texture.name):
      if scene.shaderGlobals[texture.name].theType != texture.theType:
        return (true, &"shader texture '{texture.name}' needs type {texture.theType} but scene global is of type {scene.shaderGlobals[texture.name].theType}")
    else:
      if not materialType.hasMatchingAttribute(texture):
        return (true, &"Required texture for shader texture '{texture.name}' was not found in scene materials")

  return (false, "")

func meshCompatibleWithPipeline(scene: Scene, mesh: Mesh, shaderPipeline: ShaderPipeline): (bool, string) =
  for input in shaderPipeline.inputs:
    if input.name in [TRANSFORM_ATTRIBUTE, MATERIALINDEX_ATTRIBUTE]: # will be populated automatically
      assert input.perInstance == true, &"Currently the {input.name} attribute must be a per instance attribute"
      continue
    if not (input.name in mesh[].attributes):
      return (true, &"Shader input '{input.name}' is not available for mesh")
    if input.theType != mesh[].attributeType(input.name):
      return (true, &"Shader input '{input.name}' expects type {input.theType}, but mesh has {mesh[].attributeType(input.name)}")
    if not input.perInstance and not mesh[].vertexAttributes.contains(input.name):
      return (true, &"Shader input '{input.name}' expected to be vertex attribute, but mesh has no such vertex attribute (available are: {mesh[].vertexAttributes})")
    if input.perInstance and not mesh[].instanceAttributes.contains(input.name):
      return (true, &"Shader input '{input.name}' expected to be per instance attribute, but mesh has no such instance attribute (available are: {mesh[].instanceAttributes})")

  let pipelineCompatability = scene.materialCompatibleWithPipeline(mesh.material.theType, shaderPipeline)
  if pipelineCompatability[0]:
    return (true, pipelineCompatability[1])
  return (false, "")

func checkSceneIntegrity(renderer: Renderer, scene: Scene) =
  # TODO: this and the sub-functions can likely be simplified a ton
  if scene.meshes.len == 0:
    return

  var foundRenderableObject = false
  var materialTypes: seq[MaterialType]
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for (materialType, shaderPipeline) in renderer.renderPass.subpasses[i].shaderPipelines:
      materialTypes.add materialType
      for mesh in scene.meshes:
        if mesh.material.theType == materialType:
          foundRenderableObject = true
          let (error, message) = scene.meshCompatibleWithPipeline(mesh, shaderPipeline)
          assert not error, &"Mesh '{mesh}' not compatible with assigned shaderPipeline ({materialType}) because: {message}"

  if not foundRenderableObject:
    var matTypes: Table[string, MaterialType]
    for mesh in scene.meshes:
      if not matTypes.contains(mesh.material.name):
          matTypes[mesh.material.name] = mesh.material.theType
    assert false, &"Scene '{scene.name}' has been added but materials are not compatible with any registered shader: Materials in scene: {matTypes}, registered shader-materialtypes: {materialTypes}"

proc setupDrawableBuffers*(renderer: var Renderer, scene: var Scene) =
  assert not (scene in renderer.scenedata)

  var scenedata = SceneData()

  # find all material data and group it by material type
  for mesh in scene.meshes:
    if not scenedata.materials.contains(mesh.material.theType):
      scenedata.materials[mesh.material.theType] = @[]
    if not scenedata.materials[mesh.material.theType].contains(mesh.material):
      scenedata.materials[mesh.material.theType].add mesh.material

  # automatically populate material and tranform attributes
  for mesh in scene.meshes:
    if not (TRANSFORM_ATTRIBUTE in mesh[].attributes):
      mesh[].initInstanceAttribute(TRANSFORM_ATTRIBUTE, Unit4)
    if not (MATERIALINDEX_ATTRIBUTE in mesh[].attributes):
      mesh[].initInstanceAttribute(MATERIALINDEX_ATTRIBUTE, uint16(scenedata.materials[mesh.material.theType].find(mesh.material)))

  renderer.checkSceneIntegrity(scene)

  let inputs = renderer.inputs(scene)

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
      if mesh[].attributes.contains(attribute.name):
        perLocationOffsets[attribute.memoryPerformanceHint] += mesh[].attributeSize(attribute.name)
        if perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT != 0:
          perLocationOffsets[attribute.memoryPerformanceHint] += VERTEX_ATTRIB_ALIGNMENT - (perLocationOffsets[attribute.memoryPerformanceHint] mod VERTEX_ATTRIB_ALIGNMENT)

    # fill offsets per shaderPipeline (as sequence corresponds to shader input binding)
    var offsets: Table[VkPipeline, seq[(string, MemoryPerformanceHint, int)]]
    for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
      for (materialType, shaderPipeline) in renderer.renderPass.subpasses[subpass_i].shaderPipelines:
        if scene.usesMaterial(materialType):
          offsets[shaderPipeline.vk] = newSeq[(string, MemoryPerformanceHint, int)]()
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

  # setup uniforms and textures (anything descriptor)
  var uploadedTextures: Table[Texture, VulkanTexture]
  for subpass_i in 0 ..< renderer.renderPass.subpasses.len:
    for (materialType, shaderPipeline) in renderer.renderPass.subpasses[subpass_i].shaderPipelines:
      if scene.usesMaterial(materialType):
        # gather textures
        scenedata.textures[shaderPipeline.vk] = initTable[string, seq[VulkanTexture]]()
        for texture in shaderPipeline.samplers:
          scenedata.textures[shaderPipeline.vk][texture.name] = newSeq[VulkanTexture]()
          if scene.shaderGlobals.contains(texture.name):
            for textureValue in scene.shaderGlobals[texture.name][Texture][]:
              if not uploadedTextures.contains(textureValue):
                uploadedTextures[textureValue] = renderer.device.uploadTexture(textureValue)
              scenedata.textures[shaderPipeline.vk][texture.name].add uploadedTextures[textureValue]
          else:
            var foundTexture = false
            for material in scene.getMaterials(materialType):
              if material.hasMatchingAttribute(texture):
                foundTexture = true
                let value = material[texture.name, Texture][]
                assert value.len == 1, &"Mesh material attribute '{texture.name}' has texture-array, but only single textures are allowed"
                if not uploadedTextures.contains(value[0]):
                  uploadedTextures[value[0]] = renderer.device.uploadTexture(value[0])
                scenedata.textures[shaderPipeline.vk][texture.name].add uploadedTextures[value[0]]
            assert foundTexture, &"No texture found in shaderGlobals or materials for '{texture.name}'"
          let nTextures = scenedata.textures[shaderPipeline.vk][texture.name].len
          assert (texture.arrayCount == 0 and nTextures == 1) or texture.arrayCount == nTextures, &"Shader assigned to render '{materialType}' expected {texture.arrayCount} textures for '{texture.name}' but got {nTextures}"

        # gather uniform sizes
        var uniformBufferSize = 0
        for uniform in shaderPipeline.uniforms:
          uniformBufferSize += uniform.size
        if uniformBufferSize > 0:
          scenedata.uniformBuffers[shaderPipeline.vk] = newSeq[Buffer]()
          for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
            scenedata.uniformBuffers[shaderPipeline.vk].add renderer.device.createBuffer(
              size=uniformBufferSize,
              usage=[VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT],
              requireMappable=true,
              preferVRAM=true,
            )
            
        # setup descriptors
        var poolsizes = @[(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, renderer.swapchain.inFlightFrames)]
        if scenedata.textures[shaderPipeline.vk].len > 0:
          var textureCount = 0
          for textures in scenedata.textures[shaderPipeline.vk].values:
            textureCount += textures.len
          poolsizes.add (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, renderer.swapchain.inFlightFrames * textureCount * 2)
      
        scenedata.descriptorPools[shaderPipeline.vk] = renderer.device.createDescriptorSetPool(poolsizes)
    
        scenedata.descriptorSets[shaderPipeline.vk] = shaderPipeline.setupDescriptors(
          scenedata.descriptorPools[shaderPipeline.vk],
          scenedata.uniformBuffers.getOrDefault(shaderPipeline.vk, @[]),
          scenedata.textures[shaderPipeline.vk],
          inFlightFrames=renderer.swapchain.inFlightFrames,
          emptyTexture=renderer.emptyTexture,
        )
        for frame_i in 0 ..< renderer.swapchain.inFlightFrames:
          scenedata.descriptorSets[shaderPipeline.vk][frame_i].writeDescriptorSet()

  renderer.scenedata[scene] = scenedata

proc refreshMeshAttributeData(renderer: Renderer, scene: var Scene, drawable: Drawable, mesh: Mesh, attribute: string) =
  debug &"Refreshing data on mesh mesh for {attribute}"
  # ignore attributes that are not used in this shader
  if not (attribute in renderer.scenedata[scene].attributeLocation):
    return

  let memoryPerformanceHint = renderer.scenedata[scene].attributeLocation[attribute]
  renderer.scenedata[scene].vertexBuffers[memoryPerformanceHint].setData(
    mesh[].getPointer(attribute),
    mesh[].attributeSize(attribute),
    renderer.scenedata[scene].vertexBufferOffsets[(mesh, attribute)]
  )

proc updateMeshData*(renderer: var Renderer, scene: var Scene, forceAll=false) =
  assert scene in renderer.scenedata

  for (drawable, mesh) in renderer.scenedata[scene].drawables.mitems:
    if mesh[].attributes.contains(TRANSFORM_ATTRIBUTE):
      mesh[].updateInstanceTransforms(TRANSFORM_ATTRIBUTE)
    let attrs = (if forceAll: mesh[].attributes else: mesh[].dirtyAttributes)
    for attribute in attrs:
      renderer.refreshMeshAttributeData(scene, drawable, mesh, attribute)
      debug &"Update mesh attribute {attribute}"
    mesh[].clearDirtyAttributes()

proc updateUniformData*(renderer: var Renderer, scene: var Scene, forceAll=false) =
  assert scene in renderer.scenedata

  let dirty = scene.dirtyShaderGlobals
  # if not forceAll and dirty.len == 0:
    # return

  if forceAll:
    debug "Update uniforms because 'forceAll' was given"
  else:
    debug &"Update uniforms because of dirty scene globals: {dirty}"

  # loop over all used shaders/pipelines
  for i in 0 ..< renderer.renderPass.subpasses.len:
    for (materialType, shaderPipeline) in renderer.renderPass.subpasses[i].shaderPipelines:
      if (
        scene.usesMaterial(materialType) and
        renderer.scenedata[scene].uniformBuffers.hasKey(shaderPipeline.vk) and
        renderer.scenedata[scene].uniformBuffers[shaderPipeline.vk].len != 0
      ):
        var dirtyMaterialAttribs: seq[string]
        for material in renderer.scenedata[scene].materials[materialType].mitems:
          dirtyMaterialAttribs.add material.dirtyAttributes
          material.clearDirtyAttributes()
        assert renderer.scenedata[scene].uniformBuffers[shaderPipeline.vk][renderer.swapchain.currentInFlight].vk.valid
        if forceAll:
          for buffer in renderer.scenedata[scene].uniformBuffers[shaderPipeline.vk]:
            assert buffer.vk.valid

        var offset = 0
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
            assert (uniform.arrayCount == 0 and value.len == 1) or value.len == uniform.arrayCount, &"Uniform '{uniform.name}' found has wrong length (shader declares {uniform.arrayCount} but shaderGlobals and materials provide {value.len})"
            assert value.size == uniform.size, "During uniform update: gathered value has size {value.size} but uniform expects size {uniform.size}"
            debug &"  update uniform {uniform.name} with value: {value}"
            # TODO: technically we would only need to update the uniform buffer of the current
            # frameInFlight (I think), but we don't track for which frame the shaderglobals are no longer dirty
            # therefore we have to update the uniform values in all buffers, of all inFlightframes (usually 2)
            for buffer in renderer.scenedata[scene].uniformBuffers[shaderPipeline.vk]:
              buffer.setData(value.getPointer(), value.size, offset)
          offset += uniform.size
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
    for (materialType, shaderPipeline) in renderer.renderPass.subpasses[i].shaderPipelines:
      if scene.usesMaterial(materialType):
        debug &"Start shaderPipeline for '{materialType}'"
        commandBuffer.vkCmdBindPipeline(renderer.renderPass.subpasses[i].pipelineBindPoint, shaderPipeline.vk)
        commandBuffer.vkCmdBindDescriptorSets(renderer.renderPass.subpasses[i].pipelineBindPoint, shaderPipeline.layout, 0, 1, addr(renderer.scenedata[scene].descriptorSets[shaderPipeline.vk][renderer.swapchain.currentInFlight].vk), 0, nil)
        for (drawable, mesh) in renderer.scenedata[scene].drawables.filterIt(it[1].visible and it[1].material.theType == materialType):
          drawable.draw(commandBuffer, vertexBuffers=renderer.scenedata[scene].vertexBuffers, indexBuffer=renderer.scenedata[scene].indexBuffer, shaderPipeline.vk)

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

proc destroy*(renderer: var Renderer, scene: Scene) =
  var scenedata = renderer.scenedata[scene]

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
  var destroyedTextures: seq[VkImage]
  for pipelineTextures in scenedata.textures.mvalues:
    for textures in pipelineTextures.mvalues:
      for texture in textures.mitems:
        if not destroyedTextures.contains(texture.image.vk):
          destroyedTextures.add texture.image.vk
          texture.destroy()
  for descriptorPool in scenedata.descriptorPools.mvalues:
    descriptorPool.destroy()
  renderer.scenedata.del(scene)

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
    var destroyedTextures: seq[VkImage]
    for pipelineTextures in scenedata.textures.mvalues:
      for textures in pipelineTextures.mvalues:
        for texture in textures.mitems:
          if not destroyedTextures.contains(texture.image.vk):
            destroyedTextures.add texture.image.vk
            texture.destroy()
    for descriptorPool in scenedata.descriptorPools.mvalues:
      descriptorPool.destroy()
  for scene in renderer.scenedata.keys.toSeq:
    renderer.scenedata.del(scene)
  renderer.emptyTexture.destroy()
  renderer.renderPass.destroy()
  renderer.swapchain.destroy()
