import std/typetraits
import std/tables
import std/enumerate
import std/strformat
import std/sequtils

import ./vulkan/utils
import ./gpu_data
import ./entity
import ./math

type
  SurfaceDataType = enum
    Position, Color, Normal, Tangent, BiTangent, TextureCoordinate, Index, BigIndex
  MeshIndexType* = enum
    None
    Small # up to 2^16 vertices
    Big # up to 2^32 vertices
  MeshData = object
    case thetype*: SurfaceDataType
      of Position: position: seq[Vec3f]
      of Color: color: seq[Vec3f]
      of Normal: normal: seq[Vec3f]
      of Tangent: tangent: seq[Vec3f]
      of BiTangent: bitangent: seq[Vec3f]
      of TextureCoordinate: texturecoord: seq[Vec2f]
      of Index: index: seq[uint16]
      of BigIndex: bigindex: seq[uint32]
  Mesh* = ref object of Component
    vertexCount*: uint32
    data: Table[Attribute, MeshData]
    case indexType*: MeshIndexType
    of None:
      discard
    of Small:
      smallIndices*: seq[array[3, uint16]]
    of Big:
      bigIndices*: seq[array[3, uint32]]


method `$`*(mesh: Mesh): string =
  &"Mesh ({mesh.vertexCount})"

func initMesh*(positions: openArray[Vec3f], colors: openArray[Vec3f]=[]): Mesh =
  assert colors.len == 0 or colors.len == positions.len
  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.indexType = None
  result.data[asAttribute(default(Vec3f), "position")] = MeshData(thetype: Position, position: positions.toSeq)
  if colors.len > 0:
    result.data[asAttribute(default(Vec3f), "color")] = MeshData(thetype: Color, color: colors.toSeq)


func initMesh*(positions: openArray[Vec3f], indices: openArray[array[3, uint32|int32]]): auto =
  let meshdata = {asAttribute(default(Vec3f), "position"): MeshData(thetype: Position, position: positions.toSeq)}.toTable
  if uint16(positions.len) < high(uint16):
    var smallIndices = newSeq[array[3, uint16]](indices.len)
    for i, tri in enumerate(indices):
      smallIndices[i] = [uint16(tri[0]), uint16(tri[1]), uint16(tri[3])]
    Mesh(vertexCount: uint32(positions.len), data: meshdata, indexType: Small, smallIndices: smallIndices)
  else:
    var bigIndices = newSeq[array[3, uint32]](indices.len)
    for i, tri in enumerate(indices):
      bigIndices[i] = [uint32(tri[0]), uint32(tri[1]), uint32(tri[3])]
    Mesh(vertexCount: uint32(positions.len), data: meshdata, indexType: Big, bigIndices: bigIndices)

func initMesh*(positions: openArray[Vec3f], indices: openArray[array[3, uint16|int16]]): auto =
  let meshdata = {asAttribute(default(Vec3f), "position"): MeshData(thetype: Position, position: positions.toSeq)}.toTable
  var smallIndices = newSeq[array[3, uint16]](indices.len)
  for i, tri in enumerate(indices):
    smallIndices[i] = [uint16(tri[0]), uint16(tri[1]), uint16(tri[3])]
  Mesh(vertexCount: positions.len, data: meshdata, indexType: Small, smallIndices: smallIndices)


func size*(meshdata: MeshData): uint64 =
  case meshdata.thetype:
    of Position: meshdata.position.size
    of Color: meshdata.color.size
    of Normal: meshdata.normal.size
    of Tangent: meshdata.tangent.size
    of BiTangent: meshdata.bitangent.size
    of TextureCoordinate: meshdata.texturecoord.size
    of Index: meshdata.index.size
    of BigIndex: meshdata.bigindex.size

func size*(mesh: Mesh, attribute: Attribute): uint64 =
  mesh.data[attribute].size

func size*(mesh: Mesh): uint64 =
  for d in mesh.data.values:
    result += d.size

proc rawData[T: seq](value: var T): (pointer, uint64) =
  (pointer(addr(value[0])), uint64(sizeof(get(genericParams(typeof(value)), 0)) * value.len))

proc getRawData(data: var MeshData): (pointer, uint64) =
  case data.thetype:
    of Position: rawData(data.position)
    of Color: rawData(data.color)
    of Normal: rawData(data.normal)
    of Tangent: rawData(data.tangent)
    of BiTangent: rawData(data.bitangent)
    of TextureCoordinate: rawData(data.texturecoord)
    of Index: rawData(data.index)
    of BigIndex: rawData(data.bigindex)

proc hasDataFor*(mesh: Mesh, attribute: Attribute): bool =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  attribute in mesh.data

proc getRawData*(mesh: Mesh, attribute: Attribute): (pointer, uint64) =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  mesh.data[attribute].getRawData()

proc getData*(mesh: Mesh, attribute: Attribute): MeshData =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  mesh.data[attribute]

#[

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
    var stagingBuffer = device.InitBuffer(physicalDevice, value.datasize, flags, {HostVisible, HostCoherent})
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
]#
