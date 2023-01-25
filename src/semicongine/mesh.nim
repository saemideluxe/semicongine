import std/options
import std/typetraits

import ./vulkan
import ./thing
import ./buffer
import ./vertex
import ./math/vector

type
  Mesh*[T] = ref object of Part
    vertexData*: T
  IndexedMesh*[T: object, U: uint16|uint32] = ref object of Part
    vertexData*: T
    indices*: seq[array[3, U]]

func createUberMesh*[T](meshes: openArray[Mesh[T]]): Mesh[T] =
  for mesh in meshes:
    for srcname, srcvalue in mesh.vertexData.fieldPairs:
      when typeof(srcvalue) is VertexAttribute:
        for dstname, dstvalue in result.vertexData.fieldPairs:
          when srcname == dstname:
            dstvalue.data.add srcvalue.data

func createUberMesh*[T: object, U: uint16|uint32](meshes: openArray[IndexedMesh[
    T, U]]): IndexedMesh[T, U] =
  var indexoffset = U(0)
  for mesh in meshes:
    for srcname, srcvalue in mesh.vertexData.fieldPairs:
      when typeof(srcvalue) is VertexAttribute:
        for dstname, dstvalue in result.vertexData.fieldPairs:
          when srcname == dstname:
            dstvalue.data.add srcvalue.data
      var indexdata: seq[array[3, U]]
      for i in mesh.indices:
        indexdata.add [i[0] + indexoffset, i[1] + indexoffset, i[2] + indexoffset]
      result.indices.add indexdata
    indexoffset += U(mesh.vertexData.VertexCount)

func getVkIndexType[T: object, U: uint16|uint32](m: IndexedMesh[T,
    U]): VkIndexType =
  when U is uint16: VK_INDEX_TYPE_UINT16
  elif U is uint32: VK_INDEX_TYPE_UINT32

proc createVertexBuffers*[M: Mesh|IndexedMesh](
  mesh: M,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
): (seq[Buffer], uint32) =
  result[1] = mesh.vertexData.VertexCount
  for name, value in mesh.vertexData.fieldPairs:
    when typeof(value) is VertexAttribute:
      assert value.data.len > 0
      var flags = if value.useOnDeviceMemory: {TransferSrc} else: {VertexBuffer}
      var stagingBuffer = device.InitBuffer(physicalDevice, value.datasize,
          flags, {HostVisible, HostCoherent})
      copyMem(stagingBuffer.data, addr(value.data[0]), value.datasize)

      if value.useOnDeviceMemory:
        var finalBuffer = device.InitBuffer(physicalDevice, value.datasize, {
            TransferDst, VertexBuffer}, {DeviceLocal})
        transferBuffer(commandPool, queue, stagingBuffer, finalBuffer,
            value.datasize)
        stagingBuffer.trash()
        result[0].add(finalBuffer)
        value.buffer = finalBuffer
      else:
        result[0].add(stagingBuffer)
        value.buffer = stagingBuffer

proc createIndexBuffer*(
  mesh: IndexedMesh,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBuffer: bool = true # decides if data is transfered to the fast device-local memory or not
): Buffer =
  let bufferSize = uint64(mesh.indices.len * sizeof(get(genericParams(typeof(
      mesh.indices)), 0)))
  let flags = if useDeviceLocalBuffer: {TransferSrc} else: {IndexBuffer}

  var stagingBuffer = device.InitBuffer(physicalDevice, bufferSize, flags, {
      HostVisible, HostCoherent})
  copyMem(stagingBuffer.data, addr(mesh.indices[0]), bufferSize)

  if useDeviceLocalBuffer:
    var finalBuffer = device.InitBuffer(physicalDevice, bufferSize, {
        TransferDst, IndexBuffer}, {DeviceLocal})
    transferBuffer(commandPool, queue, stagingBuffer, finalBuffer, bufferSize)
    stagingBuffer.trash()
    return finalBuffer
  else:
    return stagingBuffer

proc createIndexedVertexBuffers*(
  mesh: IndexedMesh,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBufferForIndices: bool = true # decides if data is transfered to the fast device-local memory or not
): (seq[Buffer], Buffer, uint32, VkIndexType) =
  result[0] = createVertexBuffers(mesh, device, physicalDevice, commandPool,
      queue)[0]
  result[1] = createIndexBuffer(mesh, device, physicalDevice, commandPool,
      queue, useDeviceLocalBufferForIndices)
  result[2] = uint32(mesh.indices.len * mesh.indices[0].len)

  result[3] = getVkIndexType(mesh)

func squareData*[T: SomeFloat](): auto = PositionAttribute[TVec2[T]](
  data: @[TVec2[T]([T(0), T(0)]), TVec2[T]([T(0), T(1)]), TVec2[T]([T(1), T(
      1)]), TVec2[T]([T(1), T(0)])]
)
func squareIndices*[T: uint16|uint32](): auto = seq[array[3, T]](
  @[[T(0), T(1), T(3)], [T(2), T(1), T(3)]]
)

method update*(mesh: Mesh, dt: float32) =
  echo "The update"
  echo mesh.thing.getModelTransform()
  echo mesh.vertexData
method update*(mesh: IndexedMesh, dt: float32) =
  echo "The update"
  echo mesh.thing.getModelTransform()
  echo mesh.vertexData
