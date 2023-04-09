import std/typetraits
import std/tables
import std/enumerate
import std/strformat
import std/sequtils

import ./vulkan/api
import ./gpu_data
import ./entity
import ./math

type
  MeshIndexType* = enum
    None
    Tiny # up to 2^8 vertices # TODO: need to check and enable support for this
    Small # up to 2^16 vertices
    Big # up to 2^32 vertices
  Mesh* = ref object of Component
    vertexCount*: uint32
    indicesCount*: uint32
    instanceCount*: uint32
    vertexdata: Table[string, DataList]
    instancedata: Table[string, DataList]
    case indexType*: MeshIndexType
      of None: discard
      of Tiny: tinyIndices: seq[array[3, uint8]]
      of Small: smallIndices: seq[array[3, uint16]]
      of Big: bigIndices: seq[array[3, uint32]]

converter toVulkan*(indexType: MeshIndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of Tiny: VK_INDEX_TYPE_UINT8_EXT
    of Small: VK_INDEX_TYPE_UINT16
    of Big: VK_INDEX_TYPE_UINT32

method `$`*(mesh: Mesh): string =
  &"Mesh ({mesh.vertexCount})"


func newMesh*(
  positions: openArray[Vec3f],
  indices: openArray[array[3, uint32|int32|uint16|int16|int]],
  colors: openArray[Vec3f]=[],
  instances=1'u32,
  autoResize=true
): auto =
  assert colors.len == 0 or colors.len == positions.len

  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.indicesCount = uint32(indices.len * 3)
  result.instanceCount = instances
  result.vertexdata["position"] = DataList(thetype: Vec3F32)
  setValues(result.vertexdata["position"], positions.toSeq)
  if colors.len > 0:
    result.vertexdata["color"] = DataList(thetype: Vec3F32)
    setValues(result.vertexdata["color"], colors.toSeq)

  for i in indices:
    assert uint32(i[0]) < result.vertexCount
    assert uint32(i[1]) < result.vertexCount
    assert uint32(i[2]) < result.vertexCount

  if indices.len == 0:
      result.indexType = None
  else:
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

func newMesh*(
  positions: openArray[Vec3f],
  colors: openArray[Vec3f]=[],
  instances=1'u32,
): auto =
  newMesh(positions, newSeq[array[3, int]](), colors, instances)

func vertexDataSize*(mesh: Mesh): uint32 =
  for d in mesh.vertexdata.values:
    result += d.size

func indexDataSize*(mesh: Mesh): uint32 =
  case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0))
    of Small: mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0))
    of Big: mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0))

func instanceDataSize*(mesh: Mesh): uint32 =
  for d in mesh.instancedata.values:
    result += d.size

func rawData[T: seq](value: var T): (pointer, uint32) =
  (pointer(addr(value[0])), uint32(sizeof(get(genericParams(typeof(value)), 0)) * value.len))

func getRawIndexData*(mesh: Mesh): (pointer, uint32) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

func hasVertexDataFor*(mesh: Mesh, attribute: string): bool =
  attribute in mesh.vertexdata

func hasInstanceDataFor*(mesh: Mesh, attribute: string): bool =
  attribute in mesh.instancedata

func getRawVertexData*(mesh: Mesh, attribute: string): (pointer, uint32) =
  mesh.vertexdata[attribute].getRawData()

func getRawInstanceData*(mesh: Mesh, attribute: string): (pointer, uint32) =
  mesh.instancedata[attribute].getRawData()

proc setInstanceData*[T: GPUType|int|uint|float](mesh: var Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert not (attribute in mesh.instancedata)
  mesh.instancedata[attribute] = DataList(thetype: getDataType[T]())
  setValues(mesh.instancedata[attribute], data)
