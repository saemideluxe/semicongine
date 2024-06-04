import std/tables
import std/strformat
import std/strutils

import ./core
import ./vulkan/shader

type
  MaterialType* = object
    name*: string
    vertexAttributes*: Table[string, DataType]
    instanceAttributes*: Table[string, DataType]
    attributes*: Table[string, DataType]
  MaterialData* = ref object # needs to be ref, so we can update stuff from other locations
    theType*: MaterialType
    name*: string
    attributes: Table[string, DataList]
    dirtyAttributes: seq[string]

proc hasMatchingAttribute*(materialType: MaterialType, attr: ShaderAttribute): bool =
  return materialType.attributes.contains(attr.name) and materialType.attributes[attr.name] == attr.theType

proc hasMatchingAttribute*(material: MaterialData, attr: ShaderAttribute): bool =
  return material.attributes.contains(attr.name) and material.attributes[attr.name].theType == attr.theType

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

proc `$`*(materialType: MaterialType): string =
  return materialType.name

proc assertCanRender*(shader: ShaderConfiguration, materialType: MaterialType) =
  for attr in shader.inputs:
    if attr.perInstance:
      if attr.name in [TRANSFORM_ATTRIB, MATERIALINDEX_ATTRIBUTE]:
        continue
      assert materialType.instanceAttributes.contains(attr.name), &"MaterialType '{materialType}' requires instance attribute '{attr.name}' in order to be renderable with the assigned shader '{shader}'"
      assert materialType.instanceAttributes[attr.name] == attr.theType, &"Instance attribute '{attr.name}' of MaterialType '{materialType}' is of type {materialType.instanceAttributes[attr.name]} but assigned shader '{shader}' declares type '{attr.theType}'"
    else:
      assert materialType.vertexAttributes.contains(attr.name), &"MaterialType '{materialType}' requires vertex attribute '{attr.name}' in order to be renderable with the assigned shader '{shader}'"
      assert materialType.vertexAttributes[attr.name] == attr.theType, &"Vertex attribute '{attr.name}' of MaterialType '{materialType}' is of type {materialType.vertexAttributes[attr.name]} but assigned shader '{shader}' declares type '{attr.theType}'"

proc `$`*(material: MaterialData): string =
  var attributes: seq[string]
  for key, value in material.attributes.pairs:
    attributes.add &"{key}: {value}"
  return &"""{material.name}: [{attributes.join(", ")}]"""

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
  initMaterialData(theType = theType, name = theName, attributes = attributes.toTable)

const
  VERTEX_COLORED_MATERIAL* = MaterialType(
    name: "vertex color material",
    vertexAttributes: {
      "position": Vec3F32,
      "color": Vec4F32,
    }.toTable,
  )
  SINGLE_COLOR_MATERIAL* = MaterialType(
    name: "single color material",
    vertexAttributes: {
      "position": Vec3F32,
    }.toTable,
    attributes: {"color": Vec4F32}.toTable
  )
  SINGLE_TEXTURE_MATERIAL* = MaterialType(
    name: "single texture material",
    vertexAttributes: {
      "position": Vec3F32,
      "uv": Vec2F32,
    }.toTable,
    attributes: {"baseTexture": TextureType}.toTable
  )
  COLORED_SINGLE_TEXTURE_MATERIAL* = MaterialType(
    name: "colored single texture material",
    vertexAttributes: {
      "position": Vec3F32,
      "uv": Vec2F32,
    }.toTable,
    attributes: {"baseTexture": TextureType, "color": Vec4F32}.toTable
  )
  EMPTY_MATERIAL* = MaterialType(
    name: "empty material",
    vertexAttributes: {"position": Vec3F32}.toTable,
    instanceAttributes: {TRANSFORM_ATTRIB: Mat4F32}.toTable,
  )
  EMPTY_SHADER* = createShaderConfiguration(
    name = "empty shader",
    inputs = [
      Attr[Mat4](TRANSFORM_ATTRIB, memoryPerformanceHint = PreferFastWrite, perInstance = true),
      Attr[Vec3f]("position", memoryPerformanceHint = PreferFastRead),
    ],
    outputs = [Attr[Vec4f]("color")],
    vertexCode = &"gl_Position = vec4(position, 1.0) * {TRANSFORM_ATTRIB};",
    fragmentCode = &"color = vec4(1, 0, 1, 1);"
  )
