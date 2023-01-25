import std/strformat
import std/typetraits

import ./vertex
import ./math/matrix

type
  Part* = ref object of RootObj
    thing: Thing
  Transform* = ref object of Part
    mat: Mat44

  Thing* = ref object of RootObj
    name*: string
    parent*: Thing
    children*: seq[Thing]
    parts*: seq[Part]


func `$`*(thing: Thing): string = thing.name
method `$`*(part: Part): string {.base.} = &"{part.thing} -> Part"
method `$`*(part: Transform): string = &"{part.thing} -> Transform"

func newTransform*(mat: Mat44): Transform =
  result = new Transform
  result.mat = mat

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
  if result.name == "":
    result.name = &"Thing[{$(cast[ByteAddress](result))}]"
func newThing*(name: string, firstChild: Thing, children: varargs[
    Thing]): Thing =
  result = new Thing
  result.add firstChild
  for child in children:
    result.add child
  result.name = name
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

func getModelTransform*(thing: Thing): Mat44 =
  result = Unit44
  var currentThing = thing
  while currentThing != nil:
    for part in currentThing.parts:
      if part of Transform:
        result = Transform(part).mat * result
    currentThing = currentThing.parent

iterator allPartsOfType*[T: Part](root: Thing): T =
  var queue = @[root]
  while queue.len > 0:
    let thing = queue.pop
    for part in thing.parts:
      if part of T:
        yield T(part)
    for child in thing.children:
      queue.insert(child, 0)

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

method update*(thing: Thing, dt: float32) {.base.} = discard
method update*(part: Part, dt: float32) {.base.} = discard
