import std/tables
import std/strformat

import ./vulkan/api
import ./vulkan/buffer
import ./vulkan/device
import ./vulkan/drawable

import ./gpu_data
import ./entity
import ./mesh

type
  Scene* = object
    name*: string
    root*: Entity
    drawables*: seq[Drawable]
    vertexBuffers*: Table[MemoryLocation, Buffer]
    indexBuffer*: Buffer

proc setupDrawableBuffers*(scene: var Scene, device: Device, inputs: seq[ShaderAttribute]) =
  assert scene.drawables.len == 0
  var allMeshes: seq[Mesh]
  for mesh in allComponentsOfType[Mesh](scene.root):
    allMeshes.add mesh
    for inputAttr in inputs:
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
    scene.indexBuffer = device.createBuffer(
      size=indicesBufferSize,
      usage=[VK_BUFFER_USAGE_INDEX_BUFFER_BIT],
      useVRAM=true,
      mappable=false,
    )

  # one vertex data buffer per memory location
  var perLocationOffsets: Table[MemoryLocation, uint64]
  for location, attributes in inputs.groupByMemoryLocation().pairs:
    # setup one buffer per attribute-location-type
    var bufferSize = 0'u64
    for mesh in allMeshes:
      for attribute in attributes:
        bufferSize += mesh.dataSize(attribute.name)
    if bufferSize > 0:
      scene.vertexBuffers[location] = device.createBuffer(
        size=bufferSize,
        usage=[VK_BUFFER_USAGE_VERTEX_BUFFER_BIT],
        useVRAM=location in [VRAM, VRAMVisible],
        mappable=location in [VRAMVisible, RAM],
      )
      perLocationOffsets[location] = 0

  var indexBufferOffset = 0'u64
  for mesh in allMeshes:
    var offsets: Table[MemoryLocation, seq[uint64]]
    for location, attributes in inputs.groupByMemoryLocation().pairs:
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
    scene.drawables.add drawable

proc destroy*(scene: var Scene) =
  for buffer in scene.vertexBuffers.mvalues:
    buffer.destroy()
  if scene.indexBuffer.vk.valid:
    scene.indexBuffer.destroy

