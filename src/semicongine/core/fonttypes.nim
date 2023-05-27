import std/tables
import std/unicode

import ./imagetypes
import ./vector

type
  Font* = object
    name*: string # used to reference fontAtlas will be referenced in shader
    characterUVs*: Table[Rune, array[4, Vec2f]]
    characterDimensions*: Table[Rune, Vec2f]
    fontAtlas*: Image
