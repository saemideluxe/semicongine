import std/typetraits
import std/tables
import std/enumerate
import std/strformat
import std/sequtils

import ./vulkan/utils
import ./vulkan/api
import ./gpu_data
import ./entity
import ./math

type
  SurfaceDataType = enum
    Position, Color, Normal, Tangent, BiTangent, TextureCoordinate
  MeshIndexType* = enum
    None
    Tiny # up to 2^8 vertices # TODO: need to check and enable support for this
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
  Mesh* = ref object of Component
    vertexCount*: uint32
    data: Table[VertexAttribute, MeshData]
    case indexType*: MeshIndexType
      of None: discard
      of Tiny: tinyIndices*: seq[array[3, uint8]]
      of Small: smallIndices*: seq[array[3, uint16]]
      of Big: bigIndices*: seq[array[3, uint32]]

converter toVulkan*(indexType: MeshIndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of Tiny: VK_INDEX_TYPE_UINT8_EXT
    of Small: VK_INDEX_TYPE_UINT16
    of Big: VK_INDEX_TYPE_UINT32

func indicesCount*(mesh: Mesh): uint32 =
  case mesh.indexType:
    of None: 0
    of Tiny: mesh.tinyIndices.len * 3
    of Small: mesh.smallIndices.len * 3
    of Big: mesh.bigIndices.len * 3

method `$`*(mesh: Mesh): string =
  &"Mesh ({mesh.vertexCount})"

func newMesh*(positions: openArray[Vec3f], colors: openArray[Vec3f]=[]): Mesh =
  assert colors.len == 0 or colors.len == positions.len
  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.indexType = None
  result.data[attr[Vec3f]("position")] = MeshData(thetype: Position, position: positions.toSeq)
  if colors.len > 0:
    result.data[attr[Vec3f]("color")] = MeshData(thetype: Color, color: colors.toSeq)


func newMesh*(positions: openArray[Vec3f], colors: openArray[Vec3f]=[], indices: openArray[array[3, uint32|int32|int]], autoResize=true): auto =
  assert colors.len == 0 or colors.len == positions.len

  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.data[attr[Vec3f]("position")] = MeshData(thetype: Position, position: positions.toSeq)
  if colors.len > 0:
    result.data[attr[Vec3f]("color")] = MeshData(thetype: Color, color: colors.toSeq)

  for i in indices:
    assert uint32(i[0]) < result.vertexCount
    assert uint32(i[1]) < result.vertexCount
    assert uint32(i[2]) < result.vertexCount

  if autoResize and uint32(positions.len) < uint32(high(uint8)) and false: # TODO: check feature support
    result.indexType = Tiny
    for i, tri in enumerate(indices):
      result.tinyIndices.add [uint8(tri[0]), uint8(tri[1]), uint8(tri[2])]
  elif autoResize and uint32(positions.len) < uint32(high(uint16)):
    result.indexType = Small
    for i, tri in enumerate(indices):
      result.smallIndices.add [uint16(tri[0]), uint16(tri[1]), uint16(tri[2])]
  else:
    result.indexType = Big
    for i, tri in enumerate(indices):
      result.bigIndices.add [uint32(tri[0]), uint32(tri[1]), uint32(tri[2])]

func newMesh*(positions: openArray[Vec3f], colors: openArray[Vec3f]=[], indices: openArray[array[3, uint16|int16]]): auto =
  assert colors.len == 0 or colors.len == positions.len

  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.data[attr[Vec3f]("position")] = MeshData(thetype: Position, position: positions.toSeq)
  if colors.len > 0:
    result.data[attr[Vec3f]("color")] = MeshData(thetype: Color, color: colors.toSeq)

  for i in indices:
    assert i[0] < result.vertexCount
    assert i[1] < result.vertexCount
    assert i[2] < result.vertexCount
  result.indexType = Small
  for i, tri in enumerate(indices):
    result.smallIndices.add [uint16(tri[0]), uint16(tri[1]), uint16(tri[2])]

func newMesh*(positions: openArray[Vec3f], colors: openArray[Vec3f]=[], indices: openArray[array[3, uint8|int8]]): auto =
  assert colors.len == 0 or colors.len == positions.len
  assert false # TODO: check feature support

  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.data[attr[Vec3f]("position")] = MeshData(thetype: Position, position: positions.toSeq)
  if colors.len > 0:
    result.data[attr[Vec3f]("color")] = MeshData(thetype: Color, color: colors.toSeq)

  for i in indices:
    assert i[0] < result.vertexCount
    assert i[1] < result.vertexCount
    assert i[2] < result.vertexCount
  result.indexType = Tiny
  for i, tri in enumerate(indices):
    result.smallIndices.add [uint8(tri[0]), uint8(tri[1]), uint8(tri[2])]


func meshDataSize*(meshdata: MeshData): uint64 =
  case meshdata.thetype:
    of Position: meshdata.position.size
    of Color: meshdata.color.size
    of Normal: meshdata.normal.size
    of Tangent: meshdata.tangent.size
    of BiTangent: meshdata.bitangent.size
    of TextureCoordinate: meshdata.texturecoord.size

func attributeSize*(mesh: Mesh, attribute: VertexAttribute): uint64 =
  mesh.data[attribute].meshDataSize

func vertexDataSize*(mesh: Mesh): uint64 =
  for d in mesh.data.values:
    result += d.meshDataSize

func indexDataSize*(mesh: Mesh): uint64 =
  case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0))
    of Small: mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0))
    of Big: mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0))

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

proc getRawIndexData*(mesh: Mesh): (pointer, uint64) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

proc hasDataFor*(mesh: Mesh, attribute: VertexAttribute): bool =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  attribute in mesh.data

proc getRawData*(mesh: Mesh, attribute: VertexAttribute): (pointer, uint64) =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  mesh.data[attribute].getRawData()

proc getData*(mesh: Mesh, attribute: VertexAttribute): MeshData =
  assert attribute.perInstance == false, "Mesh data cannot handle per-instance attributes"
  mesh.data[attribute]
