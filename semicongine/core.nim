import std/dynlib
import std/hashes
import std/locks
import std/macros
import std/math
import std/monotimes
import std/os
import std/paths
import std/strutils
import std/strformat
import std/tables
import std/times
import std/unicode
import std/typetraits

import std/logging

include ./rendering/vulkan/api

include ./core/utils
include ./core/buildconfig
include ./core/vector
include ./core/matrix
include ./core/constants
include ./core/types

var engine_obj_internal*: Engine

proc engine*(): Engine =
  assert engine_obj_internal != nil, "Engine has not been initialized yet"
  assert engine_obj_internal.initialized, "Engine has not been initialized yet"
  return engine_obj_internal
