{.experimental: "codeReordering".}
import std/times

type
  Part* = object of RootObj
    thing: ref Thing

  Thing* = object of RootObj
    parent*: ref Thing
    children*: seq[ref Thing]
    parts*: seq[ref Part]

method update*(thing: ref Thing, dt: Duration) {.base.} = discard

iterator partsOfType*[T: ref Part](root: ref Thing): T =
  var queue = @[root]
  while queue.len > 0:
    let thing = queue.pop
    for part in thing.parts:
      if part of T:
        yield T(part)
    for child in thing.children:
      queue.insert(child, 0)

iterator allEntities*(root: ref Thing): ref Thing =
  var queue = @[root]
  while queue.len > 0:
    let next = queue.pop
    for child in next.children:
      queue.add child
    yield next
