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
    buffer*: Buffer # buffer
    offsets*: seq[uint64] # offsets from buffer
    elementCount*: uint32 # number of vertices or indices
    instanceCount*: uint32 # number of instance
    case indexed*: bool
    of true:
      indexBuffer*: Buffer
      indexType*: VkIndexType
      indexOffset*: uint64
    of false:
      discard

  ShaderGlobal* = ref object of Component
    name*: string
    value*: DataValue

  Scene* = object
    name*: string
    root*: Entity
    drawables: Table[VkPipeline, seq[Drawable]]

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, buffer: {drawable.buffer}, offsets: {drawable.offsets}, indexType: {drawable.indexType}, indexOffset: {drawable.indexOffset}, indexBuffer: {drawable.indexBuffer})"
  else:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, buffer: {drawable.buffer}, offsets: {drawable.offsets})"

func `$`*(global: ShaderGlobal): string =
  &"ShaderGlobal(name: {global.name}, {global.value})"

func initShaderGlobal*[T](name: string, data: T): ShaderGlobal =
  var value = DataValue(thetype: getDataType[T]())
  value.setValue(data)
  ShaderGlobal(name: name, value: value)

func getBuffers*(scene: Scene, pipeline: VkPipeline): seq[Buffer] =
  var counted: seq[VkBuffer]
  for drawable in scene.drawables[pipeline]:
    if not (drawable.buffer.vk in counted):
      result.add drawable.buffer
      counted.add drawable.buffer.vk
    if drawable.indexed and not (drawable.indexBuffer.vk in counted):
      result.add drawable.indexBuffer
      counted.add drawable.indexBuffer.vk

proc destroy*(scene: var Scene, pipeline: VkPipeline) =
  var buffers = scene.getBuffers(pipeline)
  for buffer in buffers.mitems:
      buffer.destroy()

proc destroy*(scene: var Scene) =
  for pipeline in scene.drawables.keys:
    scene.destroy(pipeline)

proc setupDrawables(scene: var Scene, pipeline: Pipeline) =
  assert pipeline.device.vk.valid
  if pipeline.vk in scene.drawables:
    for drawable in scene.drawables[pipeline.vk].mitems:
      scene.destroy(pipeline.vk)
  scene.drawables[pipeline.vk] = @[]

  var
    nonIndexedMeshes: seq[Mesh]
    tinyIndexedMeshes: seq[Mesh]
    smallIndexedMeshes: seq[Mesh]
    bigIndexedMeshes: seq[Mesh]
    allIndexedMeshes: seq[Mesh]
  for mesh in allComponentsOfType[Mesh](scene.root):
    for inputAttr in pipeline.inputs.vertexInputs:
      assert mesh.hasVertexDataFor(inputAttr.name), &"{mesh} missing data for {inputAttr}"
    case mesh.indexType:
      of None: nonIndexedMeshes.add mesh
      of Tiny: tinyIndexedMeshes.add mesh
      of Small: smallIndexedMeshes.add mesh
      of Big: bigIndexedMeshes.add mesh

  # ordering meshes this way allows us to ignore value alignment (I think, needs more testing)
  allIndexedMeshes = bigIndexedMeshes & smallIndexedMeshes & tinyIndexedMeshes
  
  var
    indicesBufferSize = 0'u64
    indexOffset = 0'u64
  for mesh in allIndexedMeshes:
    indicesBufferSize += mesh.indexDataSize
  var indexBuffer: Buffer
  if indicesBufferSize > 0:
    indexBuffer = pipeline.device.createBuffer(
      size=indicesBufferSize,
      usage=[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      useVRAM=true,
      mappable=false,
    )

  for location, attributes in pipeline.inputs.vertexInputs.groupByMemoryLocation().pairs:
    # setup one buffer per attribute-location-type
    var bufferSize = 0'u64
    for mesh in nonIndexedMeshes & allIndexedMeshes:
      bufferSize += mesh.vertexDataSize
    if bufferSize == 0:
      continue
    var
      bufferOffset = 0'u64
      buffer = pipeline.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        useVRAM=location in [VRAM, VRAMVisible],
        mappable=location in [VRAMVisible, RAM],
      )

    # TODO: gather instance data/buffers
    # non-indexed mesh drawable
    if nonIndexedMeshes.len > 0:
      var vertexCount = 0'u32
      for mesh in nonIndexedMeshes:
        vertexCount += mesh.vertexCount
      # remark: we merge all meshes into a single drawcall... smart?#
      # I think bad for instancing...
      var nonIndexedDrawable = Drawable(
        elementCount: vertexCount,
        buffer: buffer,
        indexed: false,
        instanceCount: 1
      )
      for inputAttr in attributes:
        nonIndexedDrawable.offsets.add bufferOffset
        for mesh in nonIndexedMeshes:
          var (pdata, size) = mesh.getRawVertexData(inputAttr.name)
          buffer.setData(pdata, size, bufferOffset)
          bufferOffset += size
      scene.drawables[pipeline.vk].add nonIndexedDrawable

    # indexed mesh drawable
    for mesh in allIndexedMeshes:
      var drawable = Drawable(
        elementCount: mesh.indicesCount,
        buffer: buffer,
        indexed: true,
        indexBuffer: indexBuffer,
        indexOffset: indexOffset,
        indexType: mesh.indexType,
        instanceCount: 1
      )
      var (pdata, size) = mesh.getRawIndexData()
      indexBuffer.setData(pdata, size, indexOffset)
      indexOffset += size
      for inputAttr in attributes:
        drawable.offsets.add bufferOffset
        var (pdata, size) = mesh.getRawVertexData(inputAttr.name)
        buffer.setData(pdata, size, bufferOffset)
        bufferOffset += size
      scene.drawables[pipeline.vk].add drawable

proc setupDrawables*(scene: var Scene, renderPass: RenderPass) =
  for subpass in renderPass.subpasses:
    for pipeline in subpass.pipelines:
      scene.setupDrawables(pipeline)

func getDrawables*(scene: Scene, pipeline: Pipeline): seq[Drawable] =
  scene.drawables.getOrDefault(pipeline.vk, @[])
