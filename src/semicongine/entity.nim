import std/strformat
import std/typetraits

import ./math/matrix

type
  Component* = ref object of RootObj
    entity*: Entity

  Entity* = ref object of RootObj
    name*: string
    transform*: Mat4 # todo: cache transform + only update VBO when transform changed
    parent*: Entity
    children*: seq[Entity]
    components*: seq[Component]


method `$`*(entity: Entity): string {.base.} = entity.name
method `$`*(component: Component): string {.base.} =
  "Unknown Component"

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

func getModelTransform*(entity: Entity): Mat4 =
  result = Unit4
  var currentEntity = entity
  while currentEntity != nil:
    result = currentEntity.transform * result
    currentEntity = currentEntity.parent

iterator allComponentsOfType*[T: Component](root: Entity): T =
  var queue = @[root]
  while queue.len > 0:
    let entity = queue.pop
    for component in entity.components:
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