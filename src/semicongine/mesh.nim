import std/math as nimmath
import std/typetraits
import std/tables
import std/enumerate
import std/strformat
import std/sequtils

import ./core
import ./scene
import ./collision

type
  MeshIndexType* = enum
    None
    Tiny # up to 2^8 vertices # TODO: need to check and enable support for this
    Small # up to 2^16 vertices
    Big # up to 2^32 vertices
  Mesh* = ref object of Component
    instanceCount*: uint32
    instanceTransforms*: seq[Mat4] # this should not reside in data["transform"], as we will use data["transform"] to store the final transformation matrix (as derived from the scene-tree)
    dirtyInstanceTransforms: bool
    data: Table[string, DataList]
    changedAttributes: seq[string]
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

func vertexCount*(mesh: Mesh): uint32 =
  result = 0'u32
  for list in mesh.data.values:
    result = max(list.len, result)

func indicesCount*(mesh: Mesh): uint32 =
  (
    case mesh.indexType
    of None: 0'u32
    of Tiny: uint32(mesh.tinyIndices.len)
    of Small: uint32(mesh.smallIndices.len)
    of Big: uint32(mesh.bigIndices.len)
  ) * 3

method `$`*(mesh: Mesh): string =
  &"Mesh, vertexCount: {mesh.vertexCount}, vertexData: {mesh.data.keys().toSeq()}, indexType: {mesh.indexType}"

func prettyData*(mesh: Mesh): string =
  for attr, data in mesh.data.pairs:
    result &= &"{attr}: {data}\n"
  result &= (case mesh.indexType
    of None: ""
    of Tiny: &"indices: {mesh.tinyIndices}"
    of Small: &"indices: {mesh.smallIndices}"
    of Big: &"indices: {mesh.bigIndices}")

proc setMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert not (attribute in mesh.data)
  mesh.data[attribute] = newDataList(data)

proc setMeshData*(mesh: Mesh, attribute: string, data: DataList) =
  assert not (attribute in mesh.data)
  mesh.data[attribute] = data

proc setInstanceData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert not (attribute in mesh.data)
  mesh.data[attribute] = newDataList(data)

func newMesh*(
  positions: openArray[Vec3f],
  indices: openArray[array[3, uint32|int32|uint16|int16|int]],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  instanceCount=1'u32,
  autoResize=true
): auto =
  assert colors.len == 0 or colors.len == positions.len
  assert uvs.len == 0 or uvs.len == positions.len

  result = Mesh(instanceCount: instanceCount, instanceTransforms: newSeqWith(int(instanceCount), Unit4F32))
  setMeshData(result, "position", positions.toSeq)
  if colors.len > 0: setMeshData(result, "color", colors.toSeq)
  if uvs.len > 0: setMeshData(result, "uv", uvs.toSeq)

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
  setInstanceData(result, "transform", newSeqWith(int(instanceCount), Unit4F32))

func newMesh*(
  positions: openArray[Vec3f],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  instanceCount=1'u32,
): auto =
  newMesh(positions, newSeq[array[3, int]](), colors, uvs, instanceCount)

func availableAttributes*(mesh: Mesh): seq[string] =
  mesh.data.keys.toSeq

func dataSize*(mesh: Mesh, attribute: string): uint32 =
  mesh.data[attribute].size

func dataType*(mesh: Mesh, attribute: string): DataType =
  mesh.data[attribute].theType

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

proc getMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string): ref seq[T] =
  assert attribute in mesh.data
  getValues[T](mesh.data[attribute])

proc initData*(mesh: Mesh, attribute: ShaderAttribute) =
  assert not (attribute.name in mesh.data)
  mesh.data[attribute.name] = newDataList(thetype=attribute.thetype)
  if attribute.perInstance:
    mesh.data[attribute.name].initData(mesh.instanceCount)
  else:
    mesh.data[attribute.name].initData(mesh.vertexCount)

proc updateMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert attribute in mesh.data
  mesh.changedAttributes.add attribute
  setValues(mesh.data[attribute], data)

proc updateMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, i: uint32, value: T) =
  assert attribute in mesh.data
  mesh.changedAttributes.add attribute
  setValue(mesh.data[attribute], i, value)

proc appendMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert attribute in mesh.data
  mesh.changedAttributes.add attribute
  appendValues(mesh.data[attribute], data)

# currently only used for loading from files, shouls
proc appendMeshData*(mesh: Mesh, attribute: string, data: DataList) =
  assert attribute in mesh.data
  assert data.thetype == mesh.data[attribute].thetype
  mesh.changedAttributes.add attribute
  appendValues(mesh.data[attribute], data)

proc updateInstanceData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert attribute in mesh.data
  mesh.changedAttributes.add attribute
  setValues(mesh.data[attribute], data)

proc appendInstanceData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert attribute in mesh.data
  mesh.changedAttributes.add attribute
  appendValues(mesh.data[attribute], data)

proc appendIndicesData*(mesh: Mesh, v1, v2, v3: uint32) =
  case mesh.indexType
  of None: raise newException(Exception, "Mesh does not support indexed data")
  of Tiny: mesh.tinyIndices.add([uint8(v1), uint8(v2), uint8(v3)])
  of Small: mesh.smallIndices.add([uint16(v1), uint16(v2), uint16(v3)])
  of Big: mesh.bigIndices.add([v1, v2, v3])

func hasDataChanged*(mesh: Mesh, attribute: string): bool =
  attribute in mesh.changedAttributes

proc clearDataChanged*(mesh: Mesh) =
  mesh.changedAttributes = @[]

proc transform*[T: GPUType](mesh: Mesh, attribute: string, transform: Mat4) =
  assert attribute in mesh.data
  for v in getValues[T](mesh.data[attribute])[].mitems:
    v = transform * v

func rect*(width=1'f32, height=1'f32, color="ffffffff"): Mesh =
  result = Mesh(
    instanceCount: 1,
    indexType: Small,
    smallIndices: @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
    instanceTransforms: @[Unit4F32]
  )

  let
    half_w = width / 2
    half_h = height / 2
    pos = @[newVec3f(-half_w, -half_h), newVec3f( half_w, -half_h), newVec3f( half_w,  half_h), newVec3f(-half_w,  half_h)]
    c = hexToColorAlpha(color)

  setMeshData(result, "position", pos)
  setMeshData(result, "color", @[c, c, c, c])
  setMeshData(result, "uv", @[newVec2f(0, 0), newVec2f(1, 0), newVec2f(1, 1), newVec2f(0, 1)])
  setInstanceData(result, "transform", @[Unit4F32])

func tri*(width=1'f32, height=1'f32, color="ffffffff"): Mesh =
  result = Mesh(instanceCount: 1, instanceTransforms: @[Unit4F32])
  let
    half_w = width / 2
    half_h = height / 2
    colorVec = hexToColorAlpha(color)
  setMeshData(result, "position", @[newVec3f(0, -half_h), newVec3f( half_w, half_h), newVec3f(-half_w,  half_h)])
  setMeshData(result, "color", @[colorVec, colorVec, colorVec])
  setInstanceData(result, "transform", @[Unit4F32])

func circle*(width=1'f32, height=1'f32, nSegments=12'u16, color="ffffffff"): Mesh =
  assert nSegments >= 3
  result = Mesh(instanceCount: 1, indexType: Small, instanceTransforms: @[Unit4F32])

  let
    half_w = width / 2
    half_h = height / 2
    c = hexToColorAlpha(color)
    step = (2'f32 * PI) / float32(nSegments)
  var
    pos = @[newVec3f(0, 0), newVec3f(0, half_h)]
    col = @[c, c]
  for i in 0'u16 .. nSegments:
    pos.add newVec3f(cos(float32(i) * step) * half_w, sin(float32(i) * step) * half_h)
    col.add c
    result.smallIndices.add [0'u16, i + 1, i + 2]

  setMeshData(result, "position", pos)
  setMeshData(result, "color", col)
  setInstanceData(result, "transform", @[Unit4F32])

proc areInstanceTransformsDirty*(mesh: Mesh): bool =
  result = mesh.dirtyInstanceTransforms
  mesh.dirtyInstanceTransforms = false

proc setInstanceTransform*(mesh: Mesh, i: uint32, mat: Mat4) =
  assert 0 <= i and i < mesh.instanceCount
  mesh.instanceTransforms[i] = mat
  mesh.dirtyInstanceTransforms = true

proc setInstanceTransforms*(mesh: Mesh, mat: seq[Mat4]) =
  mesh.instanceTransforms = mat
  mesh.dirtyInstanceTransforms = true

func getInstanceTransform*(mesh: Mesh, i: uint32): Mat4 =
  assert 0 <= i and i < mesh.instanceCount
  mesh.instanceTransforms[i]

func getInstanceTransforms*(mesh: Mesh): seq[Mat4] =
  mesh.instanceTransforms

func getCollisionPoints*(mesh: Mesh, positionAttribute="position"): seq[Vec3f] =
  for p in getMeshData[Vec3f](mesh, positionAttribute)[]:
    result.add mesh.entity.getModelTransform() * p

