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
    of false:
      discard

  Scene* = object
    name*: string
    root*: Entity
    drawables: Table[VkPipeline, seq[Drawable]]

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, buffer: {drawable.buffer}, offsets: {drawable.offsets}, indexType: {drawable.indexType})"
  else:
    &"Drawable(elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, buffer: {drawable.buffer}, offsets: {drawable.offsets})"

proc destroy(drawable: var Drawable) =
  drawable.buffer.destroy()
  if drawable.indexed:
    drawable.indexBuffer.destroy()

proc setupDrawables(scene: var Scene, pipeline: Pipeline) =
  assert pipeline.device.vk.valid
  if pipeline.vk in scene.drawables:
    for drawable in scene.drawables[pipeline.vk].mitems:
      drawable.destroy()
  scene.drawables[pipeline.vk] = @[]

  var
    nonIMeshes: seq[Mesh]
    smallIMeshes: seq[Mesh]
    bigIMeshes: seq[Mesh]
  for mesh in allPartsOfType[Mesh](scene.root):
    for inputAttr in pipeline.inputs.vertexInputs:
      assert mesh.hasDataFor(inputAttr), &"{mesh} missing data for {inputAttr}"
    case mesh.indexType:
      of None: nonIMeshes.add mesh
      of Small: smallIMeshes.add mesh
      of Big: bigIMeshes.add mesh
  
  if nonIMeshes.len > 0:
    var
      bufferSize = 0'u64
      vertexCount = 0'u32
    for mesh in nonIMeshes:
      bufferSize += mesh.size
      vertexCount += mesh.vertexCount
    var buffer = pipeline.device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        memoryFlags=[VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT],
      )
    var offset = 0'u64
    var drawable = Drawable(elementCount: vertexCount, buffer: buffer, indexed: false, instanceCount: 1)
    for inputAttr in pipeline.inputs.vertexInputs:
      drawable.offsets.add offset
      for mesh in nonIMeshes:
        var (pdata, size) = mesh.getRawData(inputAttr)
        buffer.setData(pdata, size, offset)
        offset += size
    scene.drawables[pipeline.vk].add drawable

#[
proc createVertexBuffers*[M: Mesh](
  mesh: M,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
): (seq[Buffer], uint32) =
  result[1] = mesh.vertexData.VertexCount
  for name, value in mesh.vertexData.fieldPairs:
    assert value.data.len > 0
    var flags = if value.useOnDeviceMemory: {TransferSrc} else: {VertexBuffer}
    var stagingBuffer = device.InitBuffer(physicalDevice, value.datasize, flags, {HostVisible, HostCoherent})
    copyMem(stagingBuffer.data, addr(value.data[0]), value.datasize)

    if value.useOnDeviceMemory:
      var finalBuffer = device.InitBuffer(physicalDevice, value.datasize, {TransferDst, VertexBuffer}, {DeviceLocal})
      transferBuffer(commandPool, queue, stagingBuffer, finalBuffer, value.datasize)
      stagingBuffer.trash()
      result[0].add(finalBuffer)
      value.buffer = finalBuffer
    else:
      result[0].add(stagingBuffer)
      value.buffer = stagingBuffer
]#

proc setupDrawables*(scene: var Scene, renderPass: var RenderPass) =
  for subpass in renderPass.subpasses.mitems:
    for pipeline in subpass.pipelines.mitems:
      scene.setupDrawables(pipeline)


proc getDrawables*(scene: Scene, pipeline: Pipeline): seq[Drawable] =
  scene.drawables.getOrDefault(pipeline.vk, @[])

proc destroy*(scene: var Scene) =
  for drawables in scene.drawables.mvalues:
    for drawable in drawables.mitems:
      drawable.destroy()
