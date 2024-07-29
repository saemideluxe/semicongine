import std/algorithm
import std/dynlib
import std/endians
import std/enumerate
import std/hashes
import std/json
import std/locks
import std/logging
import std/marshal
import std/math
import std/macros
import std/monotimes
import std/os
import std/options
import std/parsecfg
import std/parseutils
import std/paths
import std/random
import std/sequtils
import std/sets
import std/strformat
import std/streams
import std/strutils
import std/tables
import std/times
import std/typetraits
import std/unicode


include ./semicongine/rendering/vulkan/api
include ./semicongine/core

setLogFilter(ENGINE_LOGLEVEL)

include ./semicongine/resources

include ./semicongine/image

include ./semicongine/events
include ./semicongine/rendering

include ./semicongine/storage
include ./semicongine/input

include ./semicongine/audio

# texture packing is required for font atlas
include ./semicongine/contrib/algorithms/texture_packing
include ./semicongine/text

include ./semicongine/gltf

when not defined(WITHOUT_CONTRIB):
  include ./semicongine/contrib/steam
  include ./semicongine/contrib/settings
  include ./semicongine/contrib/algorithms/collision
  include ./semicongine/contrib/algorithms/noise
