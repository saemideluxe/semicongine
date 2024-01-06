import std/tables
import std/strformat
import std/strutils
import std/hashes


import ./core

type
  MaterialType* = object
    name*: string
    vertexAttributes*: Table[string, DataType]
    instanceAttributes*: Table[string, DataType]
    attributes*: Table[string, DataType]
  MaterialData* = ref object
    theType*: MaterialType
    name*: string
    attributes: Table[string, DataList]
    dirtyAttributes: seq[string]

proc hasMatchingAttribute*(materialType: MaterialType, attr: ShaderAttribute): bool =
  return materialType.attributes.contains(attr.name) and materialType.attributes[attr.name] == attr.theType

proc hasMatchingAttribute*(material: MaterialData, attr: ShaderAttribute): bool =
  return material.attributes.contains(attr.name) and material.attributes[attr.name].theType == attr.theType

proc hash*(materialType: MaterialType): Hash =
  return hash(materialType.name)

proc hash*(materialData: MaterialData): Hash =
  return hash(materialData.name)

proc `==`*(a, b: MaterialType): bool =
  return a.name == b.name

proc `==`*(a, b: MaterialData): bool =
  return a.name == b.name

template `[]`*(material: MaterialData, attributeName: string): DataList =
  material.attributes[attributeName]
template `[]`*(material: MaterialData, attributeName: string, t: typedesc): ref seq[t] =
  material.attributes[attributeName][t]
template `[]`*(material: MaterialData, attributeName: string, i: int, t: typedesc): untyped =
  material.attributes[attributeName][i, t]

template `[]=`*(material: var MaterialData, attribute: string, newList: DataList) =
  material.attributes[attribute] = newList
  if not material.dirtyAttributes.contains(attribute):
    material.dirtyAttributes.add attribute
template `[]=`*[T](material: var MaterialData, attribute: string, newList: seq[T]) =
  material.attributes[attribute][] = newList
  if not material.dirtyAttributes.contains(attribute):
    material.dirtyAttributes.add attribute
template `[]=`*[T](material: var MaterialData, attribute: string, i: int, newValue: T) =
  material.attributes[attribute][i] = newValue
  if not material.dirtyAttributes.contains(attribute):
    material.dirtyAttributes.add attribute

func dirtyAttributes*(material: MaterialData): seq[string] =
  material.dirtyAttributes

proc clearDirtyAttributes*(material: var MaterialData) =
  material.dirtyAttributes.reset

let EMPTY_MATERIAL* = MaterialType(
  name: "empty material",
  vertexAttributes: {"position": Vec3F32}.toTable,
)
let COLORED_MATERIAL* = MaterialType(
  name: "single color material",
  vertexAttributes: {"position": Vec3F32}.toTable,
  attributes: {"color": Vec4F32}.toTable,
)
let VERTEX_COLORED_MATERIAL* = MaterialType(
  name: "vertex color material",
  vertexAttributes: {
    "position": Vec3F32,
    "color": Vec4F32,
  }.toTable,
)
let SINGLE_COLOR_MATERIAL* = MaterialType(
  name: "single color material",
  vertexAttributes: {
    "position": Vec3F32,
  }.toTable,
  attributes: {"color": Vec4F32}.toTable
)
let SINGLE_TEXTURE_MATERIAL* = MaterialType(
  name: "single texture material",
  vertexAttributes: {
    "position": Vec3F32,
    "uv": Vec2F32,
  }.toTable,
  attributes: {"baseTexture": TextureType}.toTable
)
let COLORED_SINGLE_TEXTURE_MATERIAL* = MaterialType(
  name: "colored single texture material",
  vertexAttributes: {
    "position": Vec3F32,
    "uv": Vec2F32,
  }.toTable,
  attributes: {"baseTexture": TextureType, "color": Vec4F32}.toTable
)

proc `$`*(materialType: MaterialType): string =
  var attributes: seq[string]
  for key, value in materialType.attributes.pairs:
    attributes.add &"{key}: {value}"
  return &"""MaterialType '{materialType.name}' | Attributes: {attributes.join(", ")}"""

proc `$`*(material: MaterialData): string =
  var attributes: seq[string]
  for key, value in material.attributes.pairs:
    attributes.add &"{key}: {value}"
  return &"""Material '{material.name}' | Attributes: {attributes.join(", ")}"""

proc initMaterialData*(
  theType: MaterialType,
  name: string,
  attributes: Table[string, DataList],
): MaterialData =
  var theName = name
  if theName == "":
    theName = &"material instance of '{theType}'"
  for matName, theType in theType.attributes.pairs:
    assert attributes.contains(matName), &"missing material attribute '{matName}' for {theType}"
    assert attributes[matName].theType == theType
  MaterialData(
    theType: theType,
    name: theName,
    attributes: attributes,
  )

proc initMaterialData*(
  theType: MaterialType,
  name: string = "",
  attributes: openArray[(string, DataList)] = @[],
): MaterialData =
  var theName = name
  if theName == "":
    theName = &"material instance of '{theType}'"
  initMaterialData(theType=theType, name=theName, attributes=attributes.toTable)

