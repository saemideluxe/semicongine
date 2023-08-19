import std/hashes
import std/options
import std/typetraits
import std/tables
import std/strformat
import std/enumerate
import std/strutils
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
    vertexCount*: uint32
    instanceCount*: uint32
    instanceTransforms*: seq[Mat4] # this should not reside in instanceData["transform"], as we will use instanceData["transform"] to store the final transformation matrix (as derived from the scene-tree)
    material*: Material
    case indexType*: MeshIndexType
      of None: discard
      of Tiny: tinyIndices: seq[array[3, uint8]]
      of Small: smallIndices: seq[array[3, uint16]]
      of Big: bigIndices: seq[array[3, uint32]]
    visible: bool = true
    dirtyInstanceTransforms: bool
    vertexData: Table[string, DataList]
    instanceData: Table[string, DataList]
    dirtyAttributes: seq[string]
  Material* = ref object
    materialType*: string
    name*: string
    constants*: Table[string, DataValue]
    textures*: Table[string, Texture]

proc hash*(material: Material): Hash =
  hash(cast[int64](material))

converter toVulkan*(indexType: MeshIndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of Tiny: VK_INDEX_TYPE_UINT8_EXT
    of Small: VK_INDEX_TYPE_UINT16
    of Big: VK_INDEX_TYPE_UINT32

func indicesCount*(mesh: Mesh): uint32 =
  (
    case mesh.indexType
    of None: 0'u32
    of Tiny: uint32(mesh.tinyIndices.len)
    of Small: uint32(mesh.smallIndices.len)
    of Big: uint32(mesh.bigIndices.len)
  ) * 3

method `$`*(mesh: Mesh): string =
  &"Mesh, vertexCount: {mesh.vertexCount}, vertexData: {mesh.vertexData.keys().toSeq()}, indexType: {mesh.indexType}"

proc `$`*(material: Material): string =
  var constants: seq[string]
  for key, value in material.constants.pairs:
    constants.add &"{key}: {value}"
  var textures: seq[string]
  for key in material.textures.keys:
    textures.add &"{key}"
  return &"""{material.name} | Values: {constants.join(", ")} | Textures: {textures.join(", ")}"""

func prettyData*(mesh: Mesh): string =
  for attr, data in mesh.vertexData.pairs:
    result &= &"{attr}: {data}\n"
  result &= (case mesh.indexType
    of None: ""
    of Tiny: &"indices: {mesh.tinyIndices}"
    of Small: &"indices: {mesh.smallIndices}"
    of Big: &"indices: {mesh.bigIndices}")

proc setMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert not (attribute in mesh.vertexData)
  mesh.vertexData[attribute] = newDataList(data)

proc setMeshData*(mesh: Mesh, attribute: string, data: DataList) =
  assert not (attribute in mesh.vertexData)
  mesh.vertexData[attribute] = data

proc setInstanceData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  assert not (attribute in mesh.instanceData)
  mesh.instanceData[attribute] = newDataList(data)

func newMesh*(
  positions: openArray[Vec3f],
  indices: openArray[array[3, uint32|int32|uint16|int16|int]],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  material: Material=nil,
  instanceCount=1'u32,
  autoResize=true
): auto =
  assert colors.len == 0 or colors.len == positions.len
  assert uvs.len == 0 or uvs.len == positions.len

  # determine index type (uint8, uint16, uint32)
  var indexType = None
  if indices.len > 0:
    indexType = Big
    if autoResize and uint32(positions.len) < uint32(high(uint8)) and false: # TODO: check feature support
      indexType = Tiny
    elif autoResize and uint32(positions.len) < uint32(high(uint16)):
      indexType = Small

  result = Mesh(
    instanceCount: instanceCount,
    instanceTransforms: newSeqWith(int(instanceCount), Unit4F32),
    indexType: indexType,
    vertexCount: uint32(positions.len)
  )
  result.material = material

  setMeshData(result, "position", positions.toSeq)
  if colors.len > 0: setMeshData(result, "color", colors.toSeq)
  if uvs.len > 0: setMeshData(result, "uv", uvs.toSeq)

  # assert all indices are valid
  for i in indices:
    assert uint32(i[0]) < result.vertexCount
    assert uint32(i[1]) < result.vertexCount
    assert uint32(i[2]) < result.vertexCount

  # cast index values to appropiate type
  if result.indexType == Tiny and uint32(positions.len) < uint32(high(uint8)) and false: # TODO: check feature support
    for i, tri in enumerate(indices):
      result.tinyIndices.add [uint8(tri[0]), uint8(tri[1]), uint8(tri[2])]
  elif result.indexType == Small and uint32(positions.len) < uint32(high(uint16)):
    for i, tri in enumerate(indices):
      result.smallIndices.add [uint16(tri[0]), uint16(tri[1]), uint16(tri[2])]
  elif result.indexType == Big:
    for i, tri in enumerate(indices):
      result.bigIndices.add [uint32(tri[0]), uint32(tri[1]), uint32(tri[2])]
  setInstanceData(result, "transform", newSeqWith(int(instanceCount), Unit4F32))

func newMesh*(
  positions: openArray[Vec3f],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  instanceCount=1'u32,
  material: Material=nil,
): auto =
  newMesh(
    positions=positions,
    indices=newSeq[array[3, int]](),
    colors=colors,
    uvs=uvs,
    material=material,
    instanceCount=instanceCount,
  )

func vertexAttributes*(mesh: Mesh): seq[string] =
  mesh.vertexData.keys.toSeq

func instanceAttributes*(mesh: Mesh): seq[string] =
  mesh.instanceData.keys.toSeq

func attributeSize*(mesh: Mesh, attribute: string): uint32 =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].size
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].size
  else:
    0

func attributeType*(mesh: Mesh, attribute: string): DataType =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].theType
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].theType
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

func indexSize*(mesh: Mesh): uint32 =
  case mesh.indexType
    of None: 0'u32
    of Tiny: uint32(mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0)))
    of Small: uint32(mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0)))
    of Big: uint32(mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0)))

func rawData[T: seq](value: var T): (pointer, uint32) =
  (pointer(addr(value[0])), uint32(sizeof(get(genericParams(typeof(value)), 0)) * value.len))

func getRawIndexData*(mesh: Mesh): (pointer, uint32) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

func hasAttribute*(mesh: Mesh, attribute: string): bool =
  mesh.vertexData.contains(attribute) or mesh.instanceData.contains(attribute)

func getRawData*(mesh: Mesh, attribute: string): (pointer, uint32) =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].getRawData()
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].getRawData()
  else:
    (nil, 0)

proc getMeshData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string): ref seq[T] =
  if mesh.vertexData.contains(attribute):
    getValues[T](mesh.vertexData[attribute])
  elif mesh.instanceData.contains(attribute):
    getValues[T](mesh.instanceData[attribute])
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

proc initAttribute*(mesh: Mesh, attribute: ShaderAttribute) =
  if attribute.perInstance:
    mesh.instanceData[attribute.name] = newDataList(thetype=attribute.thetype)
    mesh.instanceData[attribute.name].initData(mesh.instanceCount)
  else:
    mesh.vertexData[attribute.name] = newDataList(thetype=attribute.thetype)
    mesh.vertexData[attribute.name].initData(mesh.vertexCount)

proc initAttribute*[T](mesh: Mesh, attribute: ShaderAttribute, value: T) =
  if attribute.perInstance:
    mesh.instanceData[attribute.name] = newDataList(thetype=attribute.thetype)
    mesh.instanceData[attribute.name].initData(mesh.instanceCount)
    mesh.instanceData[attribute.name].setValues(newSeqWith(int(mesh.instanceCount), value))
  else:
    mesh.vertexData[attribute.name] = newDataList(thetype=attribute.thetype)
    mesh.vertexData[attribute.name].initData(mesh.vertexCount)
    mesh.instanceData[attribute.name].setValues(newSeqWith(int(mesh.vertexCount), value))

proc updateAttributeData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  if mesh.vertexData.contains(attribute):
    setValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    setValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

proc updateAttributeData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, i: uint32, value: T) =
  if mesh.vertexData.contains(attribute):
    setValue(mesh.vertexData[attribute], i, value)
  elif mesh.instanceData.contains(attribute):
    setValue(mesh.instanceData[attribute], i, value)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

proc updateInstanceData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  assert uint32(data.len) == mesh.instanceCount
  if mesh.vertexData.contains(attribute):
    setValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    setValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

proc appendAttributeData*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  if mesh.vertexData.contains(attribute):
    appendValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    appendValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

# currently only used for loading from files, shouls
proc appendAttributeData*(mesh: Mesh, attribute: string, data: DataList) =
  if mesh.vertexData.contains(attribute):
    assert data.thetype == mesh.vertexData[attribute].thetype
    appendValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    assert data.thetype == mesh.instanceData[attribute].thetype
    appendValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

proc appendIndicesData*(mesh: Mesh, v1, v2, v3: uint32) =
  case mesh.indexType
  of None: raise newException(Exception, "Mesh does not support indexed data")
  of Tiny: mesh.tinyIndices.add([uint8(v1), uint8(v2), uint8(v3)])
  of Small: mesh.smallIndices.add([uint16(v1), uint16(v2), uint16(v3)])
  of Big: mesh.bigIndices.add([v1, v2, v3])

func hasDataChanged*(mesh: Mesh, attribute: string): bool =
  attribute in mesh.dirtyAttributes

proc clearDataChanged*(mesh: Mesh) =
  mesh.dirtyAttributes = @[]

proc transform*[T: GPUType](mesh: Mesh, attribute: string, transform: Mat4) =
  if mesh.vertexData.contains(attribute):
    for v in getValues[T](mesh.vertexData[attribute])[].mitems:
      v = transform * v
  elif mesh.instanceData.contains(attribute):
    for v in getValues[T](mesh.instanceData[attribute])[].mitems:
      v = transform * v
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

func rect*(width=1'f32, height=1'f32, color="ffffffff"): Mesh =
  result = Mesh(
    vertexCount: 4,
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
  result = Mesh(vertexCount: 3, instanceCount: 1, instanceTransforms: @[Unit4F32])
  let
    half_w = width / 2
    half_h = height / 2
    colorVec = hexToColorAlpha(color)
  setMeshData(result, "position", @[newVec3f(0, -half_h), newVec3f( half_w, half_h), newVec3f(-half_w,  half_h)])
  setMeshData(result, "color", @[colorVec, colorVec, colorVec])
  setInstanceData(result, "transform", @[Unit4F32])

func circle*(width=1'f32, height=1'f32, nSegments=12'u16, color="ffffffff"): Mesh =
  assert nSegments >= 3
  result = Mesh(vertexCount: 3 + nSegments, instanceCount: 1, indexType: Small, instanceTransforms: @[Unit4F32])

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

