import std/tables

import ./imagetypes
import ./gpu_data

type
  Material* = object
    textures: Table[string, Image]
    constants: Table[string, DataValue]
