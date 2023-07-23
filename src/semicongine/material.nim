import std/tables

import ./core

type
  Material* = ref object
    name*: string
    index*: int
    constants*: Table[string, DataValue]
    textures*: Table[string, Texture]

func `$`*(mat: Material): string = mat.name
