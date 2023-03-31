import std/tables

import ./vulkan/api
import ./vulkan/buffer
import ./vulkan/pipeline
import ./vulkan/renderpass
import ./entity
import ./mesh

type
  Drawable* = object
    buffers*: seq[(Buffer, int)] # buffer + offset from buffer
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

proc setupDrawables(scene: var Scene, pipeline: Pipeline) =
  var meshes: seq[Mesh]
  var smallIMeshes: seq[Mesh]
  var bigIMeshes: seq[Mesh]
  for mesh in allPartsOfType[Mesh](scene.root):
    case mesh.indexType:
      of None: meshes.add mesh
      of Small: smallIMeshes.add mesh
      of Big: bigIMeshes.add mesh
  echo pipeline.inputs

  # one drawable per mesh list
    # one buffer per pipeline.input
      # how to find data for pipeline.inputs attribute-buffer?
      # position: get from mesh, mark attribute
      # color/UVs: material component?
  scene.drawables[pipeline.vk] = @[]

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
