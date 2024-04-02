import std/algorithm

import ./core

type
  Rect = tuple
    i: int
    x, y, w, h: uint32

func between(a1, a2, b: uint32): bool =
  a1 <= b and b <= a2

func overlap(a1, a2, b1, b2: uint32): bool =
  return between(a1, a2, b1) or
         between(a1, a2, b2) or
         between(b1, b2, a1) or
         between(b1, b2, a2)

# FYI: also serves as "overlaps"
func advanceIfOverlap(fix, newRect: Rect): (bool, uint32) =
  let overlapping = overlap(fix.x, fix.x + fix.w - 1, newRect.x, newRect.x + newRect.w - 1) and
                    overlap(fix.y, fix.y + fix.h - 1, newRect.y, newRect.y + newRect.h - 1)
  if overlapping: (true, fix.x + fix.w) # next free x coordinate to the right
  else: (false, newRect.x) # current position is fine

proc find_insertion_position(alreadyPlaced: seq[Rect], area: tuple[i: int, w, h: uint32], maxDim: uint32): (bool, Rect) =
  var newRect = (i: area.i, x: 0'u32, y: 0'u32, w: area.w, h: area.h)

  while newRect.y + newRect.h <= maxDim:
    var hasOverlap = false
    var advanceX: uint32

    for placed in alreadyPlaced:
      (hasOverlap, advanceX) = placed.advanceIfOverlap(newRect)
      if hasOverlap: # rects were overlapping and newRect needs to be shifted to the right
        newRect.x = advanceX
        break

    if not hasOverlap: # found a collision free position
      return (true, newRect)

    if newRect.x + newRect.w >= maxDim: # move to next scanline
      newRect.x = 0
      newRect.y += 1

  return (false, newRect)


proc pack*[T: Pixel](images: seq[Image[T]]): tuple[atlas: Image[T], coords: seq[tuple[x: uint32, y: uint32]]] =
  const MAX_ATLAS_SIZE = 4096'u32
  var areas: seq[tuple[i: int, w, h: uint32]]

  for i in 0 ..< images.len:
    areas.add (i, images[i].width, images[i].height)

  let areasBySize = areas.sortedByIt(-(it[1] * it[2]).int64)
  var assignedAreas: seq[Rect]
  var maxDim = 128'u32

  for area in areasBySize:
    var pos = find_insertion_position(assignedAreas, area, maxDim)
    while not pos[0]: # this should actually never loop more than once, but weird things happen ¯\_(ツ)_/¯
      maxDim = maxDim * 2
      assert maxDim <= MAX_ATLAS_SIZE, &"Atlas gets bigger than {MAX_ATLAS_SIZE}, cannot pack images"
      pos = find_insertion_position(assignedAreas, area, maxDim)

    assignedAreas.add pos[1]

  # check there are overlaps
  for i in 0 ..< assignedAreas.len - 1:
    for j in i + 1 ..< assignedAreas.len:
      assert not assignedAreas[i].advanceIfOverlap(assignedAreas[j])[0], &"{assignedAreas[i]} and {assignedAreas[j]} overlap!"

  result.atlas = newImage[T](maxDim, maxDim)
  result.coords.setLen(images.len)
  for rect in assignedAreas:
    for y in 0 ..< rect.h:
      for x in 0 ..< rect.w:
        assert result.atlas[rect.x + x, rect.y + y] == 0, "Atlas texture packing encountered an overlap error"
        result.atlas[rect.x + x, rect.y + y] = images[rect.i][x, y]
        result.coords[rect.i] = (x: rect.x, y: rect.y)
