import std/tables
import std/macros

import ../math
import ./api


# add pragma to fields of the VertexType that represent per instance attributes
template PerInstance*() {.pragma.}

