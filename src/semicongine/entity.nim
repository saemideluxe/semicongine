import std/strformat
import std/typetraits

import ./math/matrix

type
  Component* = ref object of RootObj
    entity*: Entity

  Entity* = ref object of RootObj
    name*: string
    transform*: Mat44 # todo: cache transform + only update VBO when transform changed
    parent*: Entity
    children*: seq[Entity]
    components*: seq[Component]


func `$`*(entity: Entity): string = entity.name
method `$`*(part: Component): string {.base.} =
  if part.entity != nil:
    &"{part.entity} -> Component"
  else:
    &"Standalone Component"

proc add*(entity: Entity, child: Entity) =
  child.parent = entity
  entity.children.add child
proc add*(entity: Entity, part: Component) =
  part.entity = entity
  entity.components.add part
proc add*(entity: Entity, children: seq[Entity]) =
  for child in children:
    child.parent = entity
    entity.children.add child
proc add*(entity: Entity, components: seq[Component]) =
  for part in components:
    part.entity = entity
    entity.components.add part

func newEntity*(name: string = ""): Entity =
  result = new Entity
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

func newEntity*(name: string, firstChild: Entity, children: varargs[
    Entity]): Entity =
  result = new Entity
  result.add firstChild
  for child in children:
    result.add child
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

proc newEntity*(name: string, firstPart: Component, components: varargs[Component]): Entity =
  result = new Entity
  result.name = name
  result.add firstPart
  for part in components:
    result.add part
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"
  result.transform = Unit44

func getModelTransform*(entity: Entity): Mat44 =
  result = Unit44
  var currentEntity = entity
  while currentEntity != nil:
    result = currentEntity.transform * result
    currentEntity = currentEntity.parent

iterator allPartsOfType*[T: Component](root: Entity): T =
  var queue = @[root]
  while queue.len > 0:
    let entity = queue.pop
    for part in entity.components:
      if part of T:
        yield T(part)
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

func firstPartWithName*[T: Component](root: Entity, name: string): T =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for part in child.components:
          if part of T:
            return T(part)
      queue.add child

func allWithName*(root: Entity, name: string): seq[Entity] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        result.add child
      queue.add child

func allPartsWithName*[T: Component](root: Entity, name: string): seq[T] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for part in child.components:
          if part of T:
            result.add T(part)
      queue.add child

iterator allEntities*(root: Entity): Entity =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      queue.add child
    yield next
