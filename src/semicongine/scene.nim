import std/strformat
import std/sequtils
import std/strutils
import std/tables
import std/hashes
import std/typetraits

import ./core
import ./material
import ./animation

type
  Scene* = object
    name*: string
    root*: Entity
    shaderGlobals*: Table[string, DataList]
    materials: OrderedTable[string, Material]

  Component* = ref object of RootObj
    entity*: Entity

  Entity* = ref object of RootObj
    name*: string
    internal_transform: Mat4 # todo: cache transform + only update VBO when transform changed
    parent: Entity
    children: seq[Entity]
    components: Table[string, Component]

  EntityAnimation* = ref object of Component
    player: AnimationPlayer[Mat4]

func newEntityAnimation*(animation: Animation[Mat4]): EntityAnimation =
  result = EntityAnimation(player: newAnimator(animation))
  result.player.currentValue = Unit4

func setAnimation*(entityAnimation: EntityAnimation, animation: Animation[Mat4]) =
  entityAnimation.player.animation = animation
  entityAnimation.player.resetPlayer()

func start*(animation: EntityAnimation) =
  animation.player.start()

func stop*(animation: EntityAnimation) =
  animation.player.stop()

func reset*(animation: EntityAnimation) =
  animation.player.stop()
  animation.player.resetPlayer()

func playing*(animation: EntityAnimation): bool =
  animation.player.playing

func update*(animation: EntityAnimation, dt: float32) =
  animation.player.advance(dt)

func parent(entity: Entity): Entity =
  entity.parent

# TODO: this is wrong: transfrom setter + getter are not "symetric"
func transform*(entity: Entity): Mat4 =
  result = entity.internal_transform
  for component in entity.components.mvalues:
    if component of EntityAnimation and EntityAnimation(component).player.playing:
      result = result * EntityAnimation(component).player.currentValue

func `transform=`*(entity: Entity, value: Mat4) =
  entity.internal_transform = value

# TODO: position-setter
func position*(entity: Entity): Vec3f =
  return entity.transform.col(3)

func originalTransform*(entity: Entity): Mat4 =
  entity.internal_transform

func getModelTransform*(entity: Entity): Mat4 =
  result = entity.transform
  if not entity.parent.isNil:
    result = entity.transform * entity.parent.getModelTransform()

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

func addMaterial*(scene: var Scene, material: Material) =
  assert not scene.materials.contains(material.name), &"Material with name '{material.name}' already exists in scene"
  for name, value in material.constants.pairs:
    scene.shaderGlobals[name] = newDataList(thetype=value.thetype)

  for name, value in material.constants.pairs:
    scene.shaderGlobals[name].appendValue(value)

  scene.materials[material.name] = material

func materialIndex*(scene: Scene, materialName: string): int =
  for name in scene.materials.keys:
    if name == materialName:
      return result
    inc result 
  return -1

func materials*(scene: Scene): auto =
  scene.materials.values.toSeq

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
method `$`*(animation: EntityAnimation): string =
  &"Entity animation: {animation.player.animation}"

proc add*(entity: Entity, child: Entity) =
  child.parent = entity
  entity.children.add child
proc `[]=`*[T](entity: Entity, index: int, child: var T) =
  child.parent = entity
  entity.children[index] = child
proc `[]`*(entity: Entity, index: int): Entity =
  entity.children[index]

proc `[]=`*[T](entity: Entity, name: string, component: T) =
  component.entity = entity
  entity.components[name] = component
proc `[]`*[T](entity: Entity, name: string, component: T): T =
  T(entity.components[name])

func newEntity*(name: string, components: openArray[(string, Component)] = [], children: varargs[Entity]): Entity =
  result = new Entity
  for child in children:
    result.add child
  result.name = name
  for (name, comp) in components:
    result[name] = comp
  if result.name == "":
    result.name = &"Entity[{$(cast[uint](result))}]"
  result.internal_transform = Unit4

iterator allEntitiesOfType*[T: Entity](root: Entity): T =
  var queue = @[root]
  while queue.len > 0:
    var entity = queue.pop
    if entity of T:
      yield T(entity)
    for i in countdown(entity.children.len - 1, 0):
      queue.add entity.children[i]

iterator allComponentsOfType*[T: Component](root: Entity): var T =
  var queue = @[root]
  while queue.len > 0:
    let entity = queue.pop
    for component in entity.components.mvalues:
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

proc prettyRecursive*(entity: Entity): seq[string] =
  var compList: seq[string]
  for (name, comp) in entity.components.pairs:
    compList.add name & ": " & $comp

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
