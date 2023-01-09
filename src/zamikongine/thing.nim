{.experimental: "codeReordering".}

type
  Part* = object of RootObj
    thing: ref Thing

  Thing* = object of RootObj
    parent*: ref Thing
    children*: seq[ref Thing]
    parts*: seq[ref Part]

iterator partsOfType*[T: ref Part](root: ref Thing): T =
  var queue = @[root]
  while queue.len > 0:
    let thing = queue.pop
    for part in thing.parts:
      if part of T:
        yield T(part)
    for child in thing.children:
      queue.insert(child, 0)
