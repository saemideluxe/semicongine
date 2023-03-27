import std/math
import std/options
import std/typetraits

import ./vulkan
import ./thing
import ./buffer
import ./math/vector

type
  # TODO: make single mesh type, with case-of attribute for indices
  Mesh*[T: object, U: uint16|uint32] = ref object of Part
    vertexData*: T
    case indexed*: bool
    of true:
      indices*: seq[array[3, U]]
    of false:
      discard

func createUberMesh*[T: object, U: uint16|uint32](meshes: openArray[Mesh[
    T, U]]): Mesh[T, U] =
  var indexoffset = U(0)
  for mesh in meshes:
    for srcname, srcvalue in mesh.vertexData.fieldPairs:
      for dstname, dstvalue in result.vertexData.fieldPairs:
        when srcname == dstname:
          dstvalue.data.add srcvalue.data
      var indexdata: seq[array[3, U]]
      for i in mesh.indices:
        indexdata.add [i[0] + indexoffset, i[1] + indexoffset, i[2] + indexoffset]
      result.indices.add indexdata
    indexoffset += U(mesh.vertexData.VertexCount)

func getVkIndexType[T: object, U: uint16|uint32](m: Mesh[T,
    U]): VkIndexType =
  when U is uint16: VK_INDEX_TYPE_UINT16
  elif U is uint32: VK_INDEX_TYPE_UINT32

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
  mesh: Mesh,
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
  mesh: Mesh,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBufferForIndices: bool = true # decides if data is transfered to the fast device-local memory or not
): (seq[Buffer], bool, Buffer, uint32, VkIndexType) =
  result[0] = createVertexBuffers(mesh, device, physicalDevice, commandPool,
      queue)[0]
  result[1] = mesh.indexed
  if mesh.indexed:
    result[2] = createIndexBuffer(mesh, device, physicalDevice, commandPool,
        queue, useDeviceLocalBufferForIndices)
    result[3] = uint32(mesh.indices.len * mesh.indices[0].len)
    result[4] = getVkIndexType(mesh)
  else:
    result[3] = uint32(mesh.vertexData.VertexCount)

func quad*[VertexType, VecType, T](): Mesh[VertexType, uint16] =
  result = new Mesh[VertexType, uint16]
  result.indexed = true
  result.indices = @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]]
  result.vertexData = VertexType()
  for attrname, value in result.vertexData.fieldPairs:
    when typeof(value) is PositionAttribute:
      value.data = @[
        VecType([T(-0.5), T(-0.5), T(0)]),
        VecType([T(+0.5), T(-0.5), T(0)]),
        VecType([T(+0.5), T(+0.5), T(0)]),
        VecType([T(-0.5), T(+0.5), T(0)]),
      ]
      value.useOnDeviceMemory = true

func circle*[VertexType, VecType, T](n = 16): Mesh[VertexType, uint16] =
  result = new Mesh[VertexType, uint16]
  result.indexed = true
  let angleStep = (2'f * PI) / float32(n)
  var data = @[VecType([T(0), T(0), T(0)])]
  for i in 1 .. n:
    data.add VecType([T(cos(float32(i) * angleStep)), T(sin(float32(i) *
        angleStep)), T(0)])
    result.indices.add [0'u16, uint16(i), uint16(i mod (n) + 1)]

  result.vertexData = VertexType()
  for attrname, value in result.vertexData.fieldPairs:
    when typeof(value) is PositionAttribute:
      value.data = data
      value.useOnDeviceMemory = true
