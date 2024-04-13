import std/hashes
import std/options
import std/typetraits
import std/tables
import std/strformat
import std/enumerate
import std/strutils
import std/sequtils

import ./core
import ./collision
import ./material

const DEFAULT_POSITION_ATTRIBUTE = "position"

var instanceCounter* = 0

type
  MeshIndexType* = enum
    None
    Tiny  # up to 2^8 vertices # TODO: need to check and enable support for this
    Small # up to 2^16 vertices
    Big   # up to 2^32 vertices
  MeshObject* = object
    name*: string
    vertexCount*: int
    case indexType*: MeshIndexType
      of None: discard
      of Tiny: tinyIndices*: seq[array[3, uint8]]
      of Small: smallIndices*: seq[array[3, uint16]]
      of Big: bigIndices*: seq[array[3, uint32]]
    material*: MaterialData
    transform*: Mat4 = Unit4
    instanceTransforms*: seq[Mat4]
    applyMeshTransformToInstances*: bool = true # if true, the transform attribute for the shader will apply the instance transform AND the mesh transform, to each instance
    visible*: bool = true
    transformCache: seq[Mat4]
    vertexData: Table[string, DataList]
    instanceData: Table[string, DataList]
    dirtyAttributes: seq[string]
  Mesh* = ref MeshObject

func material*(mesh: MeshObject): MaterialData =
  mesh.material

func `material=`*(mesh: var MeshObject, material: MaterialData) =
  for name, theType in material.theType.vertexAttributes:
    if mesh.vertexData.contains(name):
      assert mesh.vertexData[name].theType == theType, &"{material.theType} expected vertex attribute '{name}' to be '{theType}' but it is {mesh.vertexData[name].theType}"
    else:
      assert false, &"Mesh '{mesh.name}' is missing required vertex attribute '{name}: {theType}' for {material.theType}"
  for name, theType in material.theType.instanceAttributes:
    if mesh.instanceData.contains(name):
      assert mesh.instanceData[name].theType == theType, &"{material.theType} expected instance attribute '{name}' to be '{theType}' but it is {mesh.instanceData[name].theType}"
    else:
      assert false, &"Mesh '{mesh.name}' is missing required instance attribute '{name}: {theType}' for {material.theType}"
  mesh.material = material

func instanceCount*(mesh: MeshObject): int =
  mesh.instanceTransforms.len

func indicesCount*(mesh: MeshObject): int =
  (
    case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len
    of Small: mesh.smallIndices.len
    of Big: mesh.bigIndices.len
  ) * 3

func `$`*(mesh: MeshObject): string =
  if mesh.indexType == None:
    &"Mesh('{mesh.name}', vertexCount: {mesh.vertexCount}, instanceCount: {mesh.instanceCount}, vertexData: {mesh.vertexData.keys().toSeq()}, instanceData: {mesh.instanceData.keys().toSeq()}, indexType: {mesh.indexType}, material: {mesh.material})"
  else:
    &"Mesh('{mesh.name}', vertexCount: {mesh.vertexCount}, indexCount: {mesh.indicesCount}, instanceCount: {mesh.instanceCount}, vertexData: {mesh.vertexData.keys().toSeq()}, instanceData: {mesh.instanceData.keys().toSeq()}, indexType: {mesh.indexType}, material: {mesh.material})"
func `$`*(mesh: Mesh): string =
  $mesh[]

func vertexAttributes*(mesh: MeshObject): seq[string] =
  mesh.vertexData.keys.toSeq

func instanceAttributes*(mesh: MeshObject): seq[string] =
  mesh.instanceData.keys.toSeq

func attributes*(mesh: MeshObject): seq[string] =
  mesh.vertexAttributes & mesh.instanceAttributes

func hash*(mesh: Mesh): Hash =
  hash(cast[ptr MeshObject](mesh))

converter toVulkan*(indexType: MeshIndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of Tiny: VK_INDEX_TYPE_UINT8_EXT
    of Small: VK_INDEX_TYPE_UINT16
    of Big: VK_INDEX_TYPE_UINT32

proc initVertexAttribute*[T](mesh: var MeshObject, attribute: string, value: seq[T]) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.vertexData[attribute] = initDataList(thetype = getDataType[T]())
  mesh.vertexData[attribute].setLen(mesh.vertexCount)
  mesh.vertexData[attribute] = value
proc initVertexAttribute*[T](mesh: var MeshObject, attribute: string, value: T) =
  initVertexAttribute(mesh, attribute, newSeqWith(mesh.vertexCount, value))
proc initVertexAttribute*[T](mesh: var MeshObject, attribute: string) =
  initVertexAttribute(mesh = mesh, attribute = attribute, value = default(T))
proc initVertexAttribute*(mesh: var MeshObject, attribute: string, datatype: DataType) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.vertexData[attribute] = initDataList(thetype = datatype)
  mesh.vertexData[attribute].setLen(mesh.vertexCount)
proc initVertexAttribute*(mesh: var MeshObject, attribute: string, data: DataList) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.vertexData[attribute] = data


proc initInstanceAttribute*[T](mesh: var MeshObject, attribute: string, value: seq[T]) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.instanceData[attribute] = initDataList(thetype = getDataType[T]())
  mesh.instanceData[attribute].setLen(mesh.instanceCount)
  mesh.instanceData[attribute] = value
proc initInstanceAttribute*[T](mesh: var MeshObject, attribute: string, value: T) =
  initInstanceAttribute(mesh, attribute, newSeqWith(mesh.instanceCount, value))
proc initInstanceAttribute*[T](mesh: var MeshObject, attribute: string) =
  initInstanceAttribute(mesh = mesh, attribute = attribute, value = default(T))
proc initInstanceAttribute*(mesh: var MeshObject, attribute: string, datatype: DataType) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.instanceData[attribute] = initDataList(thetype = datatype)
  mesh.instanceData[attribute].setLen(mesh.instanceCount)
proc initInstanceAttribute*(mesh: var MeshObject, attribute: string, data: DataList) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.instanceData[attribute] = data

proc newMesh*(
  positions: openArray[Vec3f],
  indices: openArray[array[3, uint32|uint16|uint8]],
  colors: openArray[Vec4f] = [],
  uvs: openArray[Vec2f] = [],
  transform: Mat4 = Unit4,
  instanceTransforms: openArray[Mat4] = [Unit4],
  material = EMPTY_MATERIAL.initMaterialData(),
  autoResize = true,
  name: string = ""
): Mesh =
  assert colors.len == 0 or colors.len == positions.len
  assert uvs.len == 0 or uvs.len == positions.len
  var theName = name
  if theName == "":
    theName = &"mesh-{instanceCounter}"
    inc instanceCounter

  # determine index type (uint8, uint16, uint32)
  var indexType = None
  if indices.len > 0:
    indexType = Big
    if autoResize and uint32(positions.len) < uint32(high(uint8)) and false: # TODO: check feature support
      indexType = Tiny
    elif autoResize and uint32(positions.len) < uint32(high(uint16)):
      indexType = Small

  result = Mesh(
    name: theName,
    indexType: indexType,
    vertexCount: positions.len,
    instanceTransforms: @instanceTransforms,
    transform: transform,
  )

  result[].initVertexAttribute(DEFAULT_POSITION_ATTRIBUTE, positions.toSeq)
  if colors.len > 0: result[].initVertexAttribute("color", colors.toSeq)
  if uvs.len > 0: result[].initVertexAttribute("uv", uvs.toSeq)

  # assert all indices are valid
  for i in indices:
    assert int(i[0]) < result[].vertexCount
    assert int(i[1]) < result[].vertexCount
    assert int(i[2]) < result[].vertexCount

  # cast index values to appropiate type
  if result[].indexType == Tiny and uint32(positions.len) < uint32(high(uint8)) and false: # TODO: check feature support
    for i, tri in enumerate(indices):
      result[].tinyIndices.add [uint8(tri[0]), uint8(tri[1]), uint8(tri[2])]
  elif result[].indexType == Small and uint32(positions.len) < uint32(high(uint16)):
    for i, tri in enumerate(indices):
      result[].smallIndices.add [uint16(tri[0]), uint16(tri[1]), uint16(tri[2])]
  elif result[].indexType == Big:
    for i, tri in enumerate(indices):
      result[].bigIndices.add [uint32(tri[0]), uint32(tri[1]), uint32(tri[2])]
  `material=`(result[], material)

proc newMesh*(
  positions: openArray[Vec3f],
  colors: openArray[Vec4f] = [],
  uvs: openArray[Vec2f] = [],
  transform: Mat4 = Unit4,
  instanceTransforms: openArray[Mat4] = [Unit4],
  material = EMPTY_MATERIAL.initMaterialData(),
  name: string = "",
): Mesh =
  newMesh(
    positions = positions,
    indices = newSeq[array[3, uint16]](),
    colors = colors,
    uvs = uvs,
    transform = transform,
    instanceTransforms = instanceTransforms,
    material = material,
    name = name,
  )

func attributeSize*(mesh: MeshObject, attribute: string): uint64 =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].size
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].size
  else:
    0

func attributeType*(mesh: MeshObject, attribute: string): DataType =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].theType
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].theType
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

func indexSize*(mesh: MeshObject): uint64 =
  case mesh.indexType
    of None: 0'u64
    of Tiny: uint64(mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0)))
    of Small: uint64(mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0)))
    of Big: uint64(mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0)))

func rawData[T: seq](value: T): (pointer, uint64) =
  (
    pointer(addr(value[0])),
    uint64(sizeof(get(genericParams(typeof(value)), 0)) * value.len)
  )

func getRawIndexData*(mesh: MeshObject): (pointer, uint64) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

func getPointer*(mesh: var MeshObject, attribute: string): pointer =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].getPointer()
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].getPointer()
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

proc getAttribute[T: GPUType|int|uint|float](mesh: MeshObject, attribute: string): ref seq[T] =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute][T]
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute][T]
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

proc getAttribute[T: GPUType|int|uint|float](mesh: MeshObject, attribute: string, i: int): T =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute][i, T]
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute][i, T]
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

template `[]`*(mesh: MeshObject, attribute: string, t: typedesc): ref seq[t] =
  getAttribute[t](mesh, attribute)
template `[]`*(mesh: MeshObject, attribute: string, i: int, t: typedesc): untyped =
  getAttribute[t](mesh, attribute, i)
template `[]=`*[T](mesh: MeshObject, attribute: string, value: seq[T]) =
  getAttribute[t](mesh, attribute)
template `[]=`*[T](mesh: MeshObject, attribute: string, i: int, value: T) =
  getAttribute[t](mesh, attribute, i)

template `[]`*(mesh: Mesh, attribute: string, t: typedesc): ref seq[t] =
  mesh[][attribute, t]
template `[]`*(mesh: Mesh, attribute: string, i: int, t: typedesc): untyped =
  mesh[][attribute, i, t]

proc updateAttributeData[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: DataList) =
  if mesh.vertexData.contains(attribute):
    assert data.len == mesh.vertexCount
    assert data.theType == mesh.vertexData[attribute].theType
    mesh.vertexData[attribute] = data
  elif mesh.instanceData.contains(attribute):
    assert data.len == mesh.instanceCount
    assert data.theType == mesh.instanceData[attribute].theType
    mesh.instanceData[attribute] = data
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc updateAttributeData[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: seq[T]) =
  if mesh.vertexData.contains(attribute):
    assert data.len == mesh.vertexCount
    mesh.vertexData[attribute] = data
  elif mesh.instanceData.contains(attribute):
    assert data.len == mesh.instanceCount
    mesh.instanceData[attribute] = data
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc updateAttributeData[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, i: int, value: T) =
  if mesh.vertexData.contains(attribute):
    assert i < mesh.vertexData[attribute].len
    mesh.vertexData[attribute][i] = value
  elif mesh.instanceData.contains(attribute):
    assert i < mesh.instanceData[attribute].len
    mesh.instanceData[attribute][i] = value
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: DataList) =
  updateAttributeData[T](mesh, attribute, data)
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: DataList) =
  updateAttributeData[t](mesh[], attribute, data)

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: seq[T]) =
  updateAttributeData[T](mesh, attribute, data)
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  updateAttributeData[T](mesh[], attribute, data)

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, value: T) =
  updateAttributeData[T](mesh, attribute, newSeqWith(mesh.vertexCount, value))
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, value: T) =
  updateAttributeData[T](mesh[], attribute, newSeqWith(mesh.vertexCount, value))

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, i: int, value: T) =
  updateAttributeData[T](mesh, attribute, i, value)
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, i: int, value: T) =
  updateAttributeData[T](mesh[], attribute, i, value)

proc removeAttribute*(mesh: var MeshObject, attribute: string) =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData.del(attribute)
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData.del(attribute)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

proc appendIndicesData*(mesh: var MeshObject, v1, v2, v3: int) =
  case mesh.indexType
  of None: raise newException(Exception, "Mesh does not support indexed data")
  of Tiny: mesh.tinyIndices.add([uint8(v1), uint8(v2), uint8(v3)])
  of Small: mesh.smallIndices.add([uint16(v1), uint16(v2), uint16(v3)])
  of Big: mesh.bigIndices.add([uint32(v1), uint32(v2), uint32(v3)])

proc updateInstanceTransforms*(mesh: var MeshObject, attribute: string) =
  var currentTransforms: seq[Mat4]
  if mesh.applyMeshTransformToInstances:
    currentTransforms = mesh.instanceTransforms.mapIt(mesh.transform * it)
  else:
    currentTransforms = mesh.instanceTransforms
  if currentTransforms != mesh.transformCache:
    mesh[attribute] = currentTransforms
    mesh.transformCache = currentTransforms

proc renameAttribute*(mesh: var MeshObject, oldname, newname: string) =
  if mesh.vertexData.contains(oldname):
    mesh.vertexData[newname] = mesh.vertexData[oldname]
    mesh.vertexData.del oldname
  elif mesh.instanceData.contains(oldname):
    mesh.instanceData[newname] = mesh.vertexData[oldname]
    mesh.instanceData.del oldname
  else:
    raise newException(Exception, &"Attribute {oldname} is not defined for mesh {mesh}")

func dirtyAttributes*(mesh: MeshObject): seq[string] =
  mesh.dirtyAttributes

proc clearDirtyAttributes*(mesh: var MeshObject) =
  mesh.dirtyAttributes.reset

proc transform*[T: GPUType](mesh: var MeshObject, attribute: string, transform: Mat4) =
  if mesh.vertexData.contains(attribute):
    for i in 0 ..< mesh.vertexData[attribute].len:
      mesh.vertexData[attribute][i] = transform * mesh.vertexData[attribute][i, T]
  elif mesh.instanceData.contains(attribute):
    for i in 0 ..< mesh.instanceData[attribute].len:
      mesh.instanceData[attribute][i] = transform * mesh.vertexData[attribute][i, T]
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  mesh.dirtyAttributes.add attribute

proc applyTransformToVertices*(mesh: var MeshObject, positionAttribute = DEFAULT_POSITION_ATTRIBUTE) =
  for i in 0 ..< mesh.vertexData[positionAttribute].len:
    mesh.vertexData[positionAttribute][i] = mesh.transform * mesh.vertexData[positionAttribute][i, Vec3f]
  mesh.transform = Unit4

func getCollisionPoints*(mesh: MeshObject, positionAttribute = DEFAULT_POSITION_ATTRIBUTE): seq[Vec3f] =
  for p in mesh[positionAttribute, Vec3f][]:
    result.add mesh.transform * p

func getCollider*(mesh: MeshObject, positionAttribute = DEFAULT_POSITION_ATTRIBUTE): Collider =
  return mesh.getCollisionPoints(positionAttribute).calculateCollider(Points)

proc asNonIndexedMesh*(mesh: MeshObject): MeshObject =
  if mesh.indexType == None:
    return mesh

  result = MeshObject(
    vertexCount: mesh.indicesCount,
    indexType: None,
    transform: mesh.transform,
    instanceTransforms: mesh.instanceTransforms,
    visible: mesh.visible,
  )
  for attribute, datalist in mesh.vertexData.pairs:
    result.initVertexAttribute(attribute, datalist.theType)
  for attribute, datalist in mesh.instanceData.pairs:
    result.instanceData[attribute] = datalist.copy()
  var i = 0
  case mesh.indexType
  of Tiny:
    for indices in mesh.tinyIndices:
      for attribute, value in mesh.vertexData.pairs:
        result.vertexData[attribute].appendFrom(i, mesh.vertexData[attribute], int(indices[0]))
        result.vertexData[attribute].appendFrom(i + 1, mesh.vertexData[attribute], int(indices[1]))
        result.vertexData[attribute].appendFrom(i + 2, mesh.vertexData[attribute], int(indices[2]))
      i += 3
  of Small:
    for indices in mesh.smallIndices:
      for attribute, value in mesh.vertexData.pairs:
        result.vertexData[attribute].appendFrom(i, value, int(indices[0]))
        result.vertexData[attribute].appendFrom(i + 1, value, int(indices[1]))
        result.vertexData[attribute].appendFrom(i + 2, value, int(indices[2]))
      i += 3
  of Big:
    for indices in mesh.bigIndices:
      for attribute, value in mesh.vertexData.pairs:
        result.vertexData[attribute].appendFrom(i, mesh.vertexData[attribute], int(indices[0]))
        result.vertexData[attribute].appendFrom(i + 1, mesh.vertexData[attribute], int(indices[1]))
        result.vertexData[attribute].appendFrom(i + 2, mesh.vertexData[attribute], int(indices[2]))
      i += 3
  else:
    discard
  `material=`(result, mesh.material)


# GENERATORS ============================================================================

proc rect*(width = 1'f32, height = 1'f32, color = "ffffffff", material = EMPTY_MATERIAL.initMaterialData()): Mesh =
  result = Mesh(
    vertexCount: 4,
    instanceTransforms: @[Unit4],
    indexType: Small,
    smallIndices: @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
    name: &"rect-{instanceCounter}",
  )
  inc instanceCounter

  let
    half_w = width / 2
    half_h = height / 2
    pos = @[newVec3f(-half_w, -half_h), newVec3f(half_w, -half_h), newVec3f(half_w, half_h), newVec3f(-half_w, half_h)]
    c = toRGBA(color)

  result[].initVertexAttribute(DEFAULT_POSITION_ATTRIBUTE, pos)
  result[].initVertexAttribute("color", @[c, c, c, c])
  result[].initVertexAttribute("uv", @[newVec2f(0, 0), newVec2f(1, 0), newVec2f(1, 1), newVec2f(0, 1)])
  `material=`(result[], material)

proc tri*(width = 1'f32, height = 1'f32, color = "ffffffff", material = EMPTY_MATERIAL.initMaterialData()): Mesh =
  result = Mesh(
    vertexCount: 3,
    instanceTransforms: @[Unit4],
    name: &"tri-{instanceCounter}",
  )
  inc instanceCounter
  let
    half_w = width / 2
    half_h = height / 2
    colorVec = toRGBA(color)

  result[].initVertexAttribute(DEFAULT_POSITION_ATTRIBUTE, @[newVec3f(0, -half_h), newVec3f(half_w, half_h), newVec3f(-half_w, half_h)])
  result[].initVertexAttribute("color", @[colorVec, colorVec, colorVec])
  `material=`(result[], material)

proc circle*(width = 1'f32, height = 1'f32, nSegments = 12, color = "ffffffff", material = EMPTY_MATERIAL.initMaterialData()): Mesh =
  assert nSegments >= 3
  result = Mesh(
    vertexCount: 3 + nSegments,
    instanceTransforms: @[Unit4],
    indexType: Small,
    name: &"circle-{instanceCounter}",
  )
  inc instanceCounter

  let
    rX = width / 2
    rY = height / 2
    c = toRGBA(color)
    step = (2'f32 * PI) / float32(nSegments)
  var
    pos = @[newVec3f(0, 0), newVec3f(rX, 0)]
    col = @[c, c]
    uv = @[newVec2f(0.5, 0.5), newVec2f(rX, height / 2)]
  for i in 1 .. nSegments:
    pos.add newVec3f(cos(float32(i) * step) * rX, sin(float32(i) * step) * rY)
    col.add c
    uv.add newVec2f(cos(float32(i) * step) * 0.5 + 0.5, sin(float32(i) * step) * 0.5 + 0.5)
    result[].smallIndices.add [uint16(0), uint16(i), uint16(i + 1)]

  result[].initVertexAttribute(DEFAULT_POSITION_ATTRIBUTE, pos)
  result[].initVertexAttribute("color", col)
  result[].initVertexAttribute("uv", uv)
  `material=`(result[], material)

proc grid*(columns, rows: uint16, cellSize = 1.0'f32, color = "ffffffff", material = EMPTY_MATERIAL.initMaterialData()): Mesh =

  result = Mesh(
    vertexCount: int((rows + 1) * (columns + 1)),
    instanceTransforms: @[Unit4],
    indexType: Small,
    name: &"grid-{instanceCounter}",
  )
  inc instanceCounter

  let
    color = toRGBA(color)
    center_offset_x = -(float32(columns) * cellSize) / 2'f32
    center_offset_y = -(float32(rows) * cellSize) / 2'f32
  var
    pos: seq[Vec3f]
    col: seq[Vec4f]
    i = 0'u16
  for h in 0'u16 .. rows:
    for w in 0'u16 .. columns:
      pos.add newVec3f(center_offset_x + float32(w) * cellSize, center_offset_y + float32(h) * cellSize)
      col.add color
      if w > 0 and h > 0:
        result[].smallIndices.add [i, i - 1, i - rows - 2]
        result[].smallIndices.add [i, i - rows - 2, i - rows - 1]
      i.inc

  result[].initVertexAttribute(DEFAULT_POSITION_ATTRIBUTE, pos)
  result[].initVertexAttribute("color", col)
  `material=`(result[], material)

proc mergeMeshData*(a: var Mesh, b: Mesh) =
  let originalOffset = a.vertexCount
  a.vertexCount = a.vertexCount + b.vertexCount
  assert a.indexType == b.indexType
  for key in a.vertexData.keys:
    assert key in b.vertexData, &"Mesh {b} is missing vertex data for '{key}'"
  for (key, value) in b.vertexData.pairs:
    a.vertexData[key].appendValues(value)

  case a.indexType:
    of None:
      discard
    of Tiny:
      let offset = uint8(originalOffset)
      for i in b.tinyIndices:
        a.tinyIndices.add [i[0] + offset, i[1] + offset, i[2] + offset]
    of Small:
      let offset = uint16(originalOffset)
      for i in b.smallIndices:
        a.smallIndices.add [i[0] + offset, i[1] + offset, i[2] + offset]
    of Big:
      let offset = uint32(originalOffset)
      for i in b.bigIndices:
        a.bigIndices.add [i[0] + offset, i[1] + offset, i[2] + offset]

# MESH TREES =============================================================================

type
  MeshTree* = ref object
    mesh*: Mesh
    transform*: Mat4 = Unit4
    children*: seq[MeshTree]

func toStringRec*(tree: MeshTree, theindent = 0): seq[string] =
  if tree.mesh.isNil:
    result.add "*"
  else:
    result.add indent($tree.mesh, theindent)
  for child in tree.children:
    result.add child.toStringRec(theindent + 4)

func `$`*(tree: MeshTree): string =
  toStringRec(tree).join("\n")


proc toSeq*(tree: MeshTree): seq[Mesh] =
  var queue = @[tree]
  while queue.len > 0:
    var current = queue.pop
    if not current.mesh.isNil:
      result.add current.mesh
    queue.add current.children

proc updateTransforms*(tree: MeshTree, parentTransform = Unit4) =
  let currentTransform = parentTransform * tree.transform
  if not tree.mesh.isNil:
    tree.mesh.transform = currentTransform
  for child in tree.children:
    child.updateTransforms(currentTransform)
