import std/strformat
import std/sequtils
import std/algorithm
import std/strutils
import std/tables
import std/hashes
import std/typetraits

import ./core

type
  Scene* = object
    name*: string
    root*: Entity
    shaderGlobals*: Table[string, DataList]
    materials: seq[Material]

  Material* = object
    name*: string
    textures*: Table[string, Texture]
    data*: Table[string, DataValue]

  Component* = ref object of RootObj
    entity*: Entity

  Entity* = ref object of RootObj
    name*: string
    transform*: Mat4 # todo: cache transform + only update VBO when transform changed
    parent*: Entity
    children*: seq[Entity]
    components*: seq[Component]

func getModelTransform*(entity: Entity): Mat4 =
  result = Unit4
  var currentEntity = entity
  while currentEntity != nil:
    result = currentEntity.transform * result
    currentEntity = currentEntity.parent

func addShaderGlobal*[T](scene: var Scene, name: string, data: T) =
  scene.shaderGlobals[name] = newDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], @[data])

func addShaderGlobalArray*[T](scene: var Scene, name: string, data: seq[T]) =
  scene.shaderGlobals[name] = newDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], data)

func getShaderGlobal*[T](scene: Scene, name: string): T =
  getValues[T](scene.shaderGlobals[name])[0]

func getShaderGlobalArray*[T](scene: Scene, name: string): seq[T] =
  getValues[T](scene.shaderGlobals[name])

func setShaderGlobal*[T](scene: var Scene, name: string, value: T) =
  setValues[T](scene.shaderGlobals[name], @[value])

func setShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  setValues[T](scene.shaderGlobals[name], value)

func appendShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  appendValues[T](scene.shaderGlobals[name], value)

func newScene*(name: string, root: Entity): Scene =
  Scene(name: name, root: root)

func getMaterials*(scene: Scene): seq[Material] = scene.materials

func addMaterial*(scene: var Scene, material: Material) =
  if scene.materials.len > 0:
    assert material.data.keys.toSeq.sorted() == scene.materials[0].data.keys.toSeq.sorted(), &"{material.data.keys.toSeq.sorted()} == {scene.materials[0].data.keys.toSeq.sorted()}"
  else:
    for name, value in material.data.pairs:
      scene.shaderGlobals[name] = newDataList(thetype=value.thetype)

  for name, value in material.data.pairs:
    scene.shaderGlobals[name].appendValue(value)

  scene.materials.add material

func hash*(scene: Scene): Hash =
  hash(scene.name)

func `==`*(a, b: Scene): bool =
  a.name == b.name

func hash*(entity: Entity): Hash =
  hash(cast[pointer](entity))

func hash*(component: Component): Hash =
  hash(cast[pointer](component))

method `$`*(entity: Entity): string {.base.} = entity.name
method `$`*(component: Component): string {.base.} =
  "Unknown Component"

proc prettyRecursive*(entity: Entity): seq[string] =
  var compList: seq[string]
  for comp in entity.components:
    compList.add $comp

  var trans = entity.transform.col(3)
  var pos = entity.getModelTransform().col(3)
  result.add "- " & $entity & " [" & $trans.x & ", " & $trans.y & ", " & $trans.z & "] ->  [" & $pos.x & ", " & $pos.y & ", " & $pos.z & "]"
  if compList.len > 0:
    result.add "  [" & compList.join(", ") & "]"

  for child in entity.children:
    for childLine in child.prettyRecursive:
      result.add "  " & childLine

proc pretty*(entity: Entity): string =
  entity.prettyRecursive.join("\n")

proc add*(entity: Entity, child: Entity) =
  child.parent = entity
  entity.children.add child
proc add*(entity: Entity, component: Component) =
  component.entity = entity
  entity.components.add component
proc add*(entity: Entity, children: seq[Entity]) =
  for child in children:
    child.parent = entity
    entity.children.add child
proc add*(entity: Entity, components: seq[Component]) =
  for component in components:
    component.entity = entity
    entity.components.add component

func newEntity*(name: string = ""): Entity =
  result = new Entity
  result.name = name
  result.transform = Unit4
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

func newEntity*(name: string, firstChild: Entity, children: varargs[Entity]): Entity =
  result = new Entity
  result.add firstChild
  for child in children:
    result.add child
  result.name = name
  result.transform = Unit4
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

proc newEntity*(name: string, firstComponent: Component, components: varargs[Component]): Entity =
  result = new Entity
  result.name = name
  result.add firstComponent
  for component in components:
    result.add component
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"
  result.transform = Unit4

iterator allEntitiesOfType*[T: Entity](root: Entity): T =
  var queue = @[root]
  while queue.len > 0:
    let entity = queue.pop
    if entity of T:
      yield T(entity)
    for i in countdown(entity.children.len - 1, 0):
      queue.add entity.children[i]

iterator allComponentsOfType*[T: Component](root: Entity): var T =
  var queue = @[root]
  while queue.len > 0:
    let entity = queue.pop
    for component in entity.components.mitems:
      if component of T:
        yield T(component)
    for i in countdown(entity.children.len - 1, 0):
      queue.add entity.children[i]

func firstWithName*(root: Entity, name: string): Entity =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        return child
      queue.add child

func `[]`*(scene: Scene, name: string): Entity =
  return scene.root.firstWithName(name)

func firstComponentWithName*[T: Component](root: Entity, name: string): T =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for component in child.components:
          if component of T:
            return T(component)
      queue.add child

func allWithName*(root: Entity, name: string): seq[Entity] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        result.add child
      queue.add child

func allComponentsWithName*[T: Component](root: Entity, name: string): seq[T] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for component in child.components:
          if component of T:
            result.add T(component)
      queue.add child

iterator allEntities*(root: Entity): Entity =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      queue.add child
    yield next
