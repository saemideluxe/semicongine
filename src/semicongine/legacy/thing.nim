import std/strformat
import std/typetraits

import ./math/matrix

type
  Part* = ref object of RootObj
    thing*: Thing

  Thing* = ref object of RootObj
    name*: string
    transform*: Mat44 # todo: cache transform + only update VBO when transform changed
    parent*: Thing
    children*: seq[Thing]
    parts*: seq[Part]


func `$`*(thing: Thing): string = thing.name
method `$`*(part: Part): string {.base.} =
  if part.thing != nil:
    &"{part.thing} -> Part"
  else:
    &"Standalone Part"

proc add*(thing: Thing, child: Thing) =
  child.parent = thing
  thing.children.add child
proc add*(thing: Thing, part: Part) =
  part.thing = thing
  thing.parts.add part
proc add*(thing: Thing, children: seq[Thing]) =
  for child in children:
    child.parent = thing
    thing.children.add child
proc add*(thing: Thing, parts: seq[Part]) =
  for part in parts:
    part.thing = thing
    thing.parts.add part

func newThing*(name: string = ""): Thing =
  result = new Thing
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Thing[{$(cast[ByteAddress](result))}]"

func newThing*(name: string, firstChild: Thing, children: varargs[
    Thing]): Thing =
  result = new Thing
  result.add firstChild
  for child in children:
    result.add child
  result.name = name
  result.transform = Unit44
  if result.name == "":
    result.name = &"Thing[{$(cast[ByteAddress](result))}]"

proc newThing*(name: string, firstPart: Part, parts: varargs[Part]): Thing =
  result = new Thing
  result.name = name
  result.add firstPart
  for part in parts:
    result.add part
  if result.name == "":
    result.name = &"Thing[{$(cast[ByteAddress](result))}]"
  result.transform = Unit44

func getModelTransform*(thing: Thing): Mat44 =
  result = Unit44
  var currentThing = thing
  while currentThing != nil:
    result = currentThing.transform * result
    currentThing = currentThing.parent

iterator allPartsOfType*[T: Part](root: Thing): T =
  var queue = @[root]
  while queue.len > 0:
    let thing = queue.pop
    for part in thing.parts:
      if part of T:
        yield T(part)
    for i in countdown(thing.children.len - 1, 0):
      queue.add thing.children[i]

func firstWithName*(root: Thing, name: string): Thing =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        return child
      queue.add child

func firstPartWithName*[T: Part](root: Thing, name: string): T =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for part in child.parts:
          if part of T:
            return T(part)
      queue.add child

func allWithName*(root: Thing, name: string): seq[Thing] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        result.add child
      queue.add child

func allPartsWithName*[T: Part](root: Thing, name: string): seq[T] =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      if child.name == name:
        for part in child.parts:
          if part of T:
            result.add T(part)
      queue.add child

iterator allThings*(root: Thing): Thing =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      queue.add child
    yield next
