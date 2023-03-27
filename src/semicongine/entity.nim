import std/strformat
import std/typetraits

import ./math/matrix

type
  Component* = ref object of RootObj
    thing*: Entity

  Entity* = ref object of RootObj
    name*: string
    transform*: Mat44 # todo: cache transform + only update VBO when transform changed
    parent*: Entity
    children*: seq[Entity]
    parts*: seq[Component]


func `$`*(thing: Entity): string = thing.name
method `$`*(part: Component): string {.base.} =
  if part.thing != nil:
    &"{part.thing} -> Component"
  else:
    &"Standalone Component"

proc add*(thing: Entity, child: Entity) =
  child.parent = thing
  thing.children.add child
proc add*(thing: Entity, part: Component) =
  part.thing = thing
  thing.parts.add part
proc add*(thing: Entity, children: seq[Entity]) =
  for child in children:
    child.parent = thing
    thing.children.add child
proc add*(thing: Entity, parts: seq[Component]) =
  for part in parts:
    part.thing = thing
    thing.parts.add part

func newThing*(name: string = ""): Entity =
  result = new Entity
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

func newThing*(name: string, firstChild: Entity, children: varargs[
    Entity]): Entity =
  result = new Entity
  result.add firstChild
  for child in children:
    result.add child
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"

proc newThing*(name: string, firstPart: Component, parts: varargs[Component]): Entity =
  result = new Entity
  result.name = name
  result.add firstPart
  for part in parts:
    result.add part
  if result.name == "":
    result.name = &"Entity[{$(cast[ByteAddress](result))}]"
  result.transform = Unit44

func getModelTransform*(thing: Entity): Mat44 =
  result = Unit44
  var currentThing = thing
  while currentThing != nil:
    result = currentThing.transform * result
    currentThing = currentThing.parent

iterator allPartsOfType*[T: Component](root: Entity): T =
  var queue = @[root]
  while queue.len > 0:
    let thing = queue.pop
    for part in thing.parts:
      if part of T:
        yield T(part)
    for i in countdown(thing.children.len - 1, 0):
      queue.add thing.children[i]

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
        for part in child.parts:
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
        for part in child.parts:
          if part of T:
            result.add T(part)
      queue.add child

iterator allThings*(root: Entity): Entity =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      queue.add child
    yield next
