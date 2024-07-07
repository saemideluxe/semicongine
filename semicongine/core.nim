import std/algorithm
import std/dynlib
import std/logging
import std/math
import std/macros
import std/os
import std/paths
import std/random
import std/sequtils
import std/strformat
import std/strutils
import std/tables
import std/typetraits as typetraits

const RESOURCEROOT = "resources"

include ./core/utils
include ./core/vulkan/api
include ./core/buildconfig
include ./core/vector
include ./core/matrix
