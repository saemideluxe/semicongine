import std/typetraits

import ./vulkan
import ./thing
import ./buffer
import ./vertex

type
  Mesh*[T] = object of Part
    vertexData*: T
  IndexedMesh*[T: object, U: uint16|uint32] = object of Part
    vertexData*: T
    indices*: seq[array[3, U]]

func getVkIndexType[T: object, U: uint16|uint32](m: IndexedMesh[T, U]): VkIndexType =
  when U is uint16: VK_INDEX_TYPE_UINT16
  elif U is uint32: VK_INDEX_TYPE_UINT32
      
proc createVertexBuffers*[M: Mesh|IndexedMesh](
  mesh: var M,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBuffer: bool = true # decides if data is transfered to the fast device-local memory or not
): (seq[Buffer], uint32) =
  result[1] = mesh.vertexData.VertexCount
  for name, value in mesh.vertexData.fieldPairs:
    when typeof(value) is VertexAttribute:
      assert value.data.len > 0
      var flags = if useDeviceLocalBuffer: {TransferSrc} else: {VertexBuffer}
      var stagingBuffer = device.InitBuffer(physicalDevice, value.datasize, flags, {VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT})
      var d: pointer
      stagingBuffer.withMapping(d):
        copyMem(d, addr(value.data[0]), value.datasize)

      if useDeviceLocalBuffer:
        var finalBuffer = device.InitBuffer(physicalDevice, value.datasize, {TransferDst, VertexBuffer}, {VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT})
        copyBuffer(commandPool, queue, stagingBuffer, finalBuffer, value.datasize)
        stagingBuffer.trash()
        result[0].add(finalBuffer)
      else:
        result[0].add(stagingBuffer)

proc createIndexBuffer*(
  mesh: var IndexedMesh,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBuffer: bool = true # decides if data is transfered to the fast device-local memory or not
): Buffer =
  let bufferSize = uint64(mesh.indices.len * sizeof(get(genericParams(typeof(mesh.indices)), 0)))
  let flags = if useDeviceLocalBuffer: {TransferSrc} else: {IndexBuffer}

  var stagingBuffer = device.InitBuffer(physicalDevice, bufferSize, flags, {VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT})
  var d: pointer
  stagingBuffer.withMapping(d):
    copyMem(d, addr(mesh.indices[0]), bufferSize)

  if useDeviceLocalBuffer:
    var finalBuffer = device.InitBuffer(physicalDevice, bufferSize, {TransferDst, IndexBuffer}, {VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT})
    copyBuffer(commandPool, queue, stagingBuffer, finalBuffer, bufferSize)
    stagingBuffer.trash()
    return finalBuffer
  else:
    return stagingBuffer

proc createIndexedVertexBuffers*(
  mesh: var IndexedMesh,
  device: VkDevice,
  physicalDevice: VkPhysicalDevice,
  commandPool: VkCommandPool,
  queue: VkQueue,
  useDeviceLocalBuffer: bool = true # decides if data is transfered to the fast device-local memory or not
): (seq[Buffer], Buffer, uint32, VkIndexType) =
  result[0] = createVertexBuffers(mesh, device, physicalDevice, commandPool, queue, useDeviceLocalBuffer)[0]
  result[1] = createIndexBuffer(mesh, device, physicalDevice, commandPool, queue, useDeviceLocalBuffer)
  result[2] = uint32(mesh.indices.len * mesh.indices[0].len)

  result[3] = getVkIndexType(mesh)