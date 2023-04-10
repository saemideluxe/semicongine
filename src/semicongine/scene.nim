import std/tables
import std/strformat

import ./vulkan/api
import ./vulkan/buffer
import ./vulkan/pipeline
import ./vulkan/renderpass
import ./gpu_data
import ./entity
import ./mesh

type
  Drawable* = object
    elementCount*: uint32 # number of vertices or indices
    bufferOffsets*: Table[MemoryLocation, seq[uint64]] # list of buffers and list of offset for each attribute in that buffer
    instanceCount*: uint32 # number of instance
    case indexed*: bool
    of true:
      indexType*: VkIndexType
      indexBufferOffset*: uint64
    of false:
      discard

  ShaderGlobal* = ref object of Component
    name*: string
    value*: DataValue

  Scene* = object
    name*: string
    root*: Entity
    drawables: Table[VkPipeline, seq[Drawable]]
    vertexBuffers*: Table[MemoryLocation, Buffer]
    indexBuffer*: Buffer

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets}, indexType: {drawable.indexType}, indexBufferOffset: {drawable.indexBufferOffset})"
  else:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets})"

func `$`*(global: ShaderGlobal): string =
  &"ShaderGlobal(name: {global.name}, {global.value})"

func initShaderGlobal*[T](name: string, data: T): ShaderGlobal =
  var value = DataValue(thetype: getDataType[T]())
  value.setValue(data)
  ShaderGlobal(name: name, value: value)

proc destroy*(scene: var Scene, pipeline: VkPipeline) =
  for buffer in scene.vertexBuffers.mvalues:
    buffer.destroy()
  if scene.indexBuffer.vk.valid:
    scene.indexBuffer.destroy

proc destroy*(scene: var Scene) =
  for pipeline in scene.drawables.keys:
    scene.destroy(pipeline)

proc setupDrawables(scene: var Scene, pipeline: Pipeline) =
  assert pipeline.device.vk.valid

  if pipeline.vk in scene.drawables:
    for drawable in scene.drawables[pipeline.vk].mitems:
      scene.destroy(pipeline.vk)
  scene.drawables[pipeline.vk] = @[]

  var allMeshes: seq[Mesh]
  for mesh in allComponentsOfType[Mesh](scene.root):
    allMeshes.add mesh
    for inputAttr in pipeline.inputs:
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
    scene.indexBuffer = pipeline.device.createBuffer(
      size=indicesBufferSize,
      usage=[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      useVRAM=true,
      mappable=false,
    )

  # one vertex data buffer per memory location
  var perLocationOffsets: Table[MemoryLocation, uint64]
  for location, attributes in pipeline.inputs.groupByMemoryLocation().pairs:
    # setup one buffer per attribute-location-type
    var bufferSize = 0'u64
    for mesh in allMeshes:
      for attribute in attributes:
        bufferSize += mesh.dataSize(attribute.name)
    if bufferSize > 0:
      scene.vertexBuffers[location] = pipeline.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        useVRAM=location in [VRAM, VRAMVisible],
        mappable=location in [VRAMVisible, RAM],
      )
      perLocationOffsets[location] = 0

  var indexBufferOffset = 0'u64
  for mesh in allMeshes:
    var offsets: Table[MemoryLocation, seq[uint64]]
    for location, attributes in pipeline.inputs.groupByMemoryLocation().pairs:
      for attribute in attributes:
        if not (location in offsets):
          offsets[location] = @[]
        offsets[location].add perLocationOffsets[location]
        var (pdata, size) = mesh.getRawData(attribute.name)
        scene.vertexBuffers[location].setData(pdata, size, perLocationOffsets[location])
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
      scene.indexBuffer.setData(pdata, size, indexBufferOffset)
      indexBufferOffset += size
    scene.drawables[pipeline.vk].add drawable

proc setupDrawables*(scene: var Scene, renderPass: RenderPass) =
  for subpass in renderPass.subpasses:
    for pipeline in subpass.pipelines:
      scene.setupDrawables(pipeline)

func getDrawables*(scene: Scene, pipeline: Pipeline): seq[Drawable] =
  scene.drawables.getOrDefault(pipeline.vk, @[])
