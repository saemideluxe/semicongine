import std/tables
import std/unicode

import ./imagetypes

type
  Font* = object
    bitmaps*: Table[Rune, Image]
