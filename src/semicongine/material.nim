import std/tables
import std/strformat
import std/strutils

import ./core

type
  Material* = ref object
    name*: string
    index*: int
    constants*: Table[string, DataValue]
    textures*: Table[string, Texture]

proc `$`*(material: Material): string =
  var constants: seq[string]
  for key, value in material.constants.pairs:
    constants.add &"{key}: {value}"
  var textures: seq[string]
  for key in material.textures.keys:
    textures.add &"{key}"
  return &"""{material.name} ({material.index}) | Values: {constants.join(", ")} | Textures: {textures.join(", ")}"""
