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


include ./semiconginev2/rendering/vulkan/api
include ./semiconginev2/core

setLogFilter(ENGINE_LOGLEVEL)

include ./semiconginev2/resources

include ./semiconginev2/image

include ./semiconginev2/events
include ./semiconginev2/rendering

include ./semiconginev2/storage
include ./semiconginev2/input

include ./semiconginev2/audio

# texture packing is required for font atlas
include ./semiconginev2/contrib/algorithms/texture_packing
include ./semiconginev2/text

when not defined(WITHOUT_CONTRIB):
  include ./semiconginev2/contrib/steam
  include ./semiconginev2/contrib/settings
  include ./semiconginev2/contrib/algorithms/collision
  include ./semiconginev2/contrib/algorithms/noise
