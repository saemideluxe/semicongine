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
  MaterialData* = object
    theType*: MaterialType
    name*: string
    attributes*: Table[string, DataList]

proc hash*(materialType: MaterialType): Hash =
  return hash(materialType.name)

proc hash*(materialData: MaterialData): Hash =
  return hash(materialData.name)

proc `==`*(a, b: MaterialType): bool =
  return a.name == b.name

proc `==`*(a, b: MaterialData): bool =
  return a.name == b.name

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
  materialType: MaterialType,
  name: string,
  attributes: Table[string, DataList],
): MaterialData =
  var theName = name
  if theName == "":
    theName = &"material instance of '{materialType}'"
  for matName, theType in materialType.attributes.pairs:
    assert attributes.contains(matName), &"missing material attribute '{matName}' for {materialType}"
    assert attributes[matName].theType == theType
  MaterialData(
    theType: materialType,
    name: theName,
    attributes: attributes,
  )

proc initMaterialData*(
  materialType: MaterialType,
  name: string = "",
  attributes: seq[(string, DataList)] = @[],
): MaterialData =
  var theName = name
  if theName == "":
    theName = &"material instance of '{materialType}'"
  initMaterialData(materialType=materialType, name=theName, attributes=attributes.toTable)

let DEFAULT_MATERIAL* = MaterialData(
  name: "default material"
)

