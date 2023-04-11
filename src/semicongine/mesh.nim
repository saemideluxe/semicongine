import std/math as nimmath
import std/typetraits
import std/tables
import std/enumerate
import std/strformat
import std/sequtils

import ./vulkan/api
import ./gpu_data
import ./entity
import ./math
import ./color

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
    data: Table[string, DataList]
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
  instanceCount=1'u32,
  autoResize=true
): auto =
  assert colors.len == 0 or colors.len == positions.len

  result = new Mesh
  result.vertexCount = uint32(positions.len)
  result.indicesCount = uint32(indices.len * 3)
  result.instanceCount = instanceCount
  result.data["position"] = DataList(thetype: Vec3F32)
  setValues(result.data["position"], positions.toSeq)
  if colors.len > 0:
    result.data["color"] = DataList(thetype: Vec3F32)
    setValues(result.data["color"], colors.toSeq)

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
  instanceCount=1'u32,
): auto =
  newMesh(positions, newSeq[array[3, int]](), colors, instanceCount)

func dataSize*(mesh: Mesh, attribute: string): uint32 =
  mesh.data[attribute].size

func indexDataSize*(mesh: Mesh): uint32 =
  case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0))
    of Small: mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0))
    of Big: mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0))

func rawData[T: seq](value: var T): (pointer, uint32) =
  (pointer(addr(value[0])), uint32(sizeof(get(genericParams(typeof(value)), 0)) * value.len))

func getRawIndexData*(mesh: Mesh): (pointer, uint32) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

func hasDataFor*(mesh: Mesh, attribute: string): bool =
  attribute in mesh.data

func getRawData*(mesh: Mesh, attribute: string): (pointer, uint32) =
  mesh.data[attribute].getRawData()

proc setInstanceData*[T: GPUType|int|uint|float](mesh: var Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert not (attribute in mesh.data)
  mesh.data[attribute] = DataList(thetype: getDataType[T]())
  setValues(mesh.data[attribute], data)


func rect*(width=1'f32, height=1'f32, color="ffffff"): Mesh =
  result = new Mesh
  result.vertexCount = 4
  result.indicesCount = 6
  result.instanceCount = 1
  result.data["position"] = DataList(thetype: Vec3F32)
  result.data["color"] = DataList(thetype: Vec3F32)
  result.indexType = Small
  result.smallIndices = @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]]

  let
    half_w = width / 2
    half_h = height / 2
    c = RGBfromHex(color)
    v = [newVec3f(-half_w, -half_h), newVec3f( half_w, -half_h), newVec3f( half_w,  half_h), newVec3f(-half_w,  half_h)]

  setValues(result.data["position"], v.toSeq)
  setValues(result.data["color"], @[c, c, c, c])

func tri*(width=1'f32, height=1'f32, color="ffffff"): Mesh =
  result = new Mesh
  result.vertexCount = 3
  result.instanceCount = 1
  result.data["position"] = DataList(thetype: Vec3F32)
  result.data["color"] = DataList(thetype: Vec3F32)
  let
    half_w = width / 2
    half_h = height / 2
    colorVec = RGBfromHex(color)
  setValues(result.data["position"], @[
    newVec3f(0, -half_h), newVec3f( half_w, half_h), newVec3f(-half_w,  half_h),
  ])
  setValues(result.data["color"], @[colorVec, colorVec, colorVec])

func circle*(width=1'f32, height=1'f32, nSegments=12'u16, color="ffffff"): Mesh =
  assert nSegments >= 3
  result = new Mesh
  result.vertexCount = nSegments + 2
  result.instanceCount = 1
  result.indexType = Small
  result.data["position"] = DataList(thetype: Vec3F32)
  result.data["color"] = DataList(thetype: Vec3F32)
  let
    half_w = width / 2
    half_h = height / 2
    c = RGBfromHex(color)
    step = (2'f32 * PI) / float32(nSegments)
  var
    pos = @[newVec3f(0, 0), newVec3f(0, half_h)]
    col = @[c, c]
  for i in 0'u16 .. nSegments:
    pos.add newVec3f(cos(float32(i) * step) * half_w, sin(float32(i) * step) * half_h)
    col.add c
    result.smallIndices.add [0'u16, i + 1, i + 2]

  result.indicesCount = uint32(result.smallIndices.len * 3)
  setValues(result.data["position"], pos)
  setValues(result.data["color"], col)
