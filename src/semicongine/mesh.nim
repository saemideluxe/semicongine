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

type
  MeshIndexType* = enum
    None
    Tiny # up to 2^8 vertices # TODO: need to check and enable support for this
    Small # up to 2^16 vertices
    Big # up to 2^32 vertices
  MeshObject* = object
    vertexCount*: int
    case indexType*: MeshIndexType
      of None: discard
      of Tiny: tinyIndices: seq[array[3, uint8]]
      of Small: smallIndices: seq[array[3, uint16]]
      of Big: bigIndices: seq[array[3, uint32]]
    material*: Material
    transform*: Mat4 = Unit4F32
    instanceTransforms*: seq[Mat4]
    transformCache: seq[Mat4]
    vertexData: Table[string, DataList]
    instanceData: Table[string, DataList]
    dirtyAttributes: seq[string]
  Mesh* = ref MeshObject
  Material* = object
    name*: string
    constants*: Table[string, DataList]
    textures*: Table[string, Texture]
    index*: uint16 # optional, may be used to index into uniform arrays in shader

let EMPTY_MATERIAL = Material(
  name: "empty material"
)

func `$`*(mesh: MeshObject): string =
  &"Mesh(vertexCount: {mesh.vertexCount}, vertexData: {mesh.vertexData.keys().toSeq()}, instanceData: {mesh.instanceData.keys().toSeq()}, indexType: {mesh.indexType})"
func `$`*(mesh: Mesh): string =
  $mesh[]

proc `$`*(material: Material): string =
  var constants: seq[string]
  for key, value in material.constants.pairs:
    constants.add &"{key}: {value}"
  var textures: seq[string]
  for key in material.textures.keys:
    textures.add &"{key}"
  return &"""{material.name} | Values: {constants.join(", ")} | Textures: {textures.join(", ")}"""

func vertexAttributes*(mesh: MeshObject): seq[string] =
  mesh.vertexData.keys.toSeq

func instanceAttributes*(mesh: MeshObject): seq[string] =
  mesh.instanceData.keys.toSeq

func attributes*(mesh: MeshObject): seq[string] =
  mesh.vertexAttributes & mesh.instanceAttributes

func hash*(material: Material): Hash =
  hash(material.name)

func hash*(mesh: Mesh): Hash =
  hash(cast[ptr MeshObject](mesh))

func instanceCount*(mesh: MeshObject): int =
  mesh.instanceTransforms.len

converter toVulkan*(indexType: MeshIndexType): VkIndexType =
  case indexType:
    of None: VK_INDEX_TYPE_NONE_KHR
    of Tiny: VK_INDEX_TYPE_UINT8_EXT
    of Small: VK_INDEX_TYPE_UINT16
    of Big: VK_INDEX_TYPE_UINT32

func indicesCount*(mesh: MeshObject): int =
  (
    case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len
    of Small: mesh.smallIndices.len
    of Big: mesh.bigIndices.len
  ) * 3

func initVertexAttribute*[T](mesh: var MeshObject, attribute: string, value: seq[T]) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.vertexData[attribute] = newDataList(thetype=getDataType[T]())
  mesh.vertexData[attribute].initData(mesh.vertexCount)
  mesh.vertexData[attribute].setValues(value)
func initVertexAttribute*[T](mesh: var MeshObject, attribute: string, value: T) =
  initVertexAttribute(mesh, attribute, newSeqWith(mesh.vertexCount, value))
func initVertexAttribute*[T](mesh: var MeshObject, attribute: string) =
  initVertexAttribute(mesh=mesh, attribute=attribute, value=default(T))
func initVertexAttribute*(mesh: var MeshObject, attribute: string, datatype: DataType) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.vertexData[attribute] = newDataList(thetype=datatype)
  mesh.vertexData[attribute].initData(mesh.vertexCount)

func initInstanceAttribute*[T](mesh: var MeshObject, attribute: string, value: seq[T]) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.instanceData[attribute] = newDataList(thetype=getDataType[T]())
  mesh.instanceData[attribute].initData(mesh.instanceCount)
  mesh.instanceData[attribute].setValues(value)
func initInstanceAttribute*[T](mesh: var MeshObject, attribute: string, value: T) =
  initInstanceAttribute(mesh, attribute, newSeqWith(mesh.instanceCount, value))
func initInstanceAttribute*[T](mesh: var MeshObject, attribute: string) =
  initInstanceAttribute(mesh=mesh, attribute=attribute, value=default(T))
func initInstanceAttribute*(mesh: var MeshObject, attribute: string, datatype: DataType) =
  assert not mesh.vertexData.contains(attribute) and not mesh.instanceData.contains(attribute)
  mesh.instanceData[attribute] = newDataList(thetype=datatype)
  mesh.instanceData[attribute].initData(mesh.instanceCount)

proc newMesh*(
  positions: openArray[Vec3f],
  indices: openArray[array[3, uint32|uint16|uint8]],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  transform: Mat4=Unit4F32,
  instanceTransforms: openArray[Mat4]=[Unit4F32],
  material: Material=EMPTY_MATERIAL,
  autoResize=true,
): Mesh =
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
    indexType: indexType,
    vertexCount: positions.len,
    instanceTransforms: @instanceTransforms,
    transform: transform,
    material: material,
  )

  result[].initVertexAttribute("position", positions.toSeq)
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

proc newMesh*(
  positions: openArray[Vec3f],
  colors: openArray[Vec4f]=[],
  uvs: openArray[Vec2f]=[],
  transform: Mat4=Unit4F32,
  instanceTransforms: openArray[Mat4]=[Unit4F32],
  material: Material=EMPTY_MATERIAL,
): Mesh =
  newMesh(
    positions=positions,
    indices=newSeq[array[3, uint16]](),
    colors=colors,
    uvs=uvs,
    transform=transform,
    instanceTransforms=instanceTransforms,
    material=material,
  )

func attributeSize*(mesh: MeshObject, attribute: string): int =
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

func indexSize*(mesh: MeshObject): int =
  case mesh.indexType
    of None: 0
    of Tiny: mesh.tinyIndices.len * sizeof(get(genericParams(typeof(mesh.tinyIndices)), 0))
    of Small: mesh.smallIndices.len * sizeof(get(genericParams(typeof(mesh.smallIndices)), 0))
    of Big: mesh.bigIndices.len * sizeof(get(genericParams(typeof(mesh.bigIndices)), 0))

func rawData[T: seq](value: T): (pointer, int) =
  (pointer(addr(value[0])), sizeof(get(genericParams(typeof(value)), 0)) * value.len)

func getRawIndexData*(mesh: MeshObject): (pointer, int) =
  case mesh.indexType:
    of None: raise newException(Exception, "Trying to get index data for non-indexed mesh")
    of Tiny: rawData(mesh.tinyIndices)
    of Small: rawData(mesh.smallIndices)
    of Big: rawData(mesh.bigIndices)

func getRawData*(mesh: var MeshObject, attribute: string): (pointer, int) =
  if mesh.vertexData.contains(attribute):
    mesh.vertexData[attribute].getRawData()
  elif mesh.instanceData.contains(attribute):
    mesh.instanceData[attribute].getRawData()
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

proc getAttribute[T: GPUType|int|uint|float](mesh: MeshObject, attribute: string): seq[T] =
  if mesh.vertexData.contains(attribute):
    getValues[T](mesh.vertexData[attribute])
  elif mesh.instanceData.contains(attribute):
    getValues[T](mesh.instanceData[attribute])
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

template `[]`*(mesh: MeshObject, attribute: string, t: typedesc): seq[t] =
  getAttribute[t](mesh, attribute)
template `[]`*(mesh: Mesh, attribute: string, t: typedesc): seq[t] =
  getAttribute[t](mesh[], attribute)

proc updateAttributeData[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: seq[T]) =
  if mesh.vertexData.contains(attribute):
    assert data.len == mesh.vertexCount
    setValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    assert data.len == mesh.instanceCount
    setValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc updateAttributeData[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, i: int, value: T) =
  if mesh.vertexData.contains(attribute):
    assert i < mesh.vertexData[attribute].len
    setValue(mesh.vertexData[attribute], i, value)
  elif mesh.instanceData.contains(attribute):
    assert i < mesh.instanceData[attribute].len
    setValue(mesh.instanceData[attribute], i, value)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: seq[T]) =
  updateAttributeData[T](mesh, attribute, data)
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, data: seq[T]) =
  updateAttributeData[t](mesh[], attribute, data)

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, value: T) =
  updateAttributeData[T](mesh, attribute, newSeqWith(mesh.vertexCount, value))
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, value: T) =
  updateAttributeData[T](mesh[], attribute, newSeqWith(mesh.vertexCount, value))

proc `[]=`*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, i: int, value: T) =
  updateAttributeData[T](mesh, attribute, i, value)
proc `[]=`*[T: GPUType|int|uint|float](mesh: Mesh, attribute: string, i: int, value: T) =
  updateAttributeData[T](mesh[], attribute, i, value)

proc appendAttributeData*[T: GPUType|int|uint|float](mesh: var MeshObject, attribute: string, data: seq[T]) =
  if mesh.vertexData.contains(attribute):
    appendValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    appendValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

# currently only used for loading from files, shouls
proc appendAttributeData*(mesh: var MeshObject, attribute: string, data: DataList) =
  if mesh.vertexData.contains(attribute):
    assert data.thetype == mesh.vertexData[attribute].thetype
    appendValues(mesh.vertexData[attribute], data)
  elif mesh.instanceData.contains(attribute):
    assert data.thetype == mesh.instanceData[attribute].thetype
    appendValues(mesh.instanceData[attribute], data)
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")
  if not mesh.dirtyAttributes.contains(attribute):
    mesh.dirtyAttributes.add attribute

proc appendIndicesData*(mesh: var MeshObject, v1, v2, v3: int) =
  case mesh.indexType
  of None: raise newException(Exception, "Mesh does not support indexed data")
  of Tiny: mesh.tinyIndices.add([uint8(v1), uint8(v2), uint8(v3)])
  of Small: mesh.smallIndices.add([uint16(v1), uint16(v2), uint16(v3)])
  of Big: mesh.bigIndices.add([uint32(v1), uint32(v2), uint32(v3)])

proc updateInstanceTransforms*(mesh: var MeshObject, attribute: string) =
  let currentTransforms = mesh.instanceTransforms.mapIt(mesh.transform * it)
  if currentTransforms != mesh.transformCache:
    mesh[attribute] = currentTransforms
    mesh.transformCache = currentTransforms

func dirtyAttributes*(mesh: MeshObject): seq[string] =
  mesh.dirtyAttributes

proc clearDirtyAttributes*(mesh: var MeshObject) =
  mesh.dirtyAttributes.reset

proc transform*[T: GPUType](mesh: var MeshObject, attribute: string, transform: Mat4) =
  if mesh.vertexData.contains(attribute):
    for i in 0 ..< mesh.vertexData[attribute].len:
      setValue(mesh.vertexData[attribute], i, transform * getValue[T](mesh.vertexData[attribute], i))
  elif mesh.instanceData.contains(attribute):
    for i in 0 ..< mesh.instanceData[attribute].len:
      setValue(mesh.instanceData[attribute], i, transform * getValue[T](mesh.vertexData[attribute], i))
  else:
    raise newException(Exception, &"Attribute {attribute} is not defined for mesh {mesh}")

func getCollisionPoints*(mesh: MeshObject, positionAttribute="position"): seq[Vec3f] =
  for p in mesh[positionAttribute, Vec3f]:
    result.add mesh.transform * p

# GENERATORS ============================================================================

proc rect*(width=1'f32, height=1'f32, color="ffffffff"): Mesh =
  result = Mesh(
    vertexCount: 4,
    instanceTransforms: @[Unit4F32],
    indexType: Small,
    smallIndices: @[[0'u16, 1'u16, 2'u16], [2'u16, 3'u16, 0'u16]],
  )

  let
    half_w = width / 2
    half_h = height / 2
    pos = @[newVec3f(-half_w, -half_h), newVec3f( half_w, -half_h), newVec3f( half_w,  half_h), newVec3f(-half_w,  half_h)]
    c = hexToColorAlpha(color)

  result[].initVertexAttribute("position", pos)
  result[].initVertexAttribute("color", @[c, c, c, c])
  result[].initVertexAttribute("uv", @[newVec2f(0, 0), newVec2f(1, 0), newVec2f(1, 1), newVec2f(0, 1)])

proc tri*(width=1'f32, height=1'f32, color="ffffffff"): Mesh =
  result = Mesh(vertexCount: 3, instanceTransforms: @[Unit4F32])
  let
    half_w = width / 2
    half_h = height / 2
    colorVec = hexToColorAlpha(color)

  result[].initVertexAttribute("position", @[newVec3f(0, -half_h), newVec3f( half_w, half_h), newVec3f(-half_w,  half_h)])
  result[].initVertexAttribute("color", @[colorVec, colorVec, colorVec])

proc circle*(width=1'f32, height=1'f32, nSegments=12, color="ffffffff"): Mesh =
  assert nSegments >= 3
  result = Mesh(vertexCount: 3 + nSegments, instanceTransforms: @[Unit4F32], indexType: Small)

  let
    half_w = width / 2
    half_h = height / 2
    c = hexToColorAlpha(color)
    step = (2'f32 * PI) / float32(nSegments)
  var
    pos = @[newVec3f(0, 0), newVec3f(0, half_h)]
    col = @[c, c]
  for i in 0 .. nSegments:
    pos.add newVec3f(cos(float32(i) * step) * half_w, sin(float32(i) * step) * half_h)
    col.add c
    result[].smallIndices.add [uint16(0), uint16(i + 1), uint16(i + 2)]

  result[].initVertexAttribute("position", pos)
  result[].initVertexAttribute("color", col)

# MESH TREES =============================================================================

type
  MeshTree* = ref object
    mesh*: Mesh
    transform*: Mat4 = Unit4F32
    children*: seq[MeshTree]

func toStringRec*(tree: MeshTree, theindent=0): seq[string] =
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

proc updateTransforms*(tree: MeshTree, parentTransform=Unit4F32) =
  let currentTransform = parentTransform * tree.transform
  if not tree.mesh.isNil:
    tree.mesh.transform = currentTransform
  for child in tree.children:
    child.updateTransforms(currentTransform)
