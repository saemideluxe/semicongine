import std/strutils
import std/os

import ./buildconfig

type
  ResourceBundlingType* = enum
    Dir # Directories
    Zip # Zip files
    Exe # Embeded in executable
  Resource = ref object of RootObj
    name: string
    data: seq[uint8]

const thebundletype = parseEnum[ResourceBundlingType](BUNDLETYPE)

proc loadResourceDirectory(path: string): Resource =
  var fullpath = joinPath(MODROOT, path)
  result
proc loadResourceZip(path: string): Resource =
  var fullpath = joinPath(MODROOT, path)
  result
proc loadResourceExecutable(path: string): Resource =
  result
proc loadResource*(path: string): Resource =
  case thebundletype
  of Dir: return loadResourceDirectory(path)
  of Zip: return loadResourceZip(path)
  of Exe: return loadResourceExecutable(path)

proc bundleResourcesDirectory() {.compiletime.} =
  # copy resource files to output directory
  discard
proc bundleResourcesZip() {.compiletime.} =
  # copy resource files to zip in output directory
  discard
proc bundleResourcesExecutable() {.compiletime.} =
  # put resource contents into variable here
  discard
proc bundleResources() {.compiletime.} =
  when thebundletype == Dir: bundleResourcesDirectory()
  elif thebundletype == Zip: bundleResourcesZip()
  elif thebundletype == Exe: bundleResourcesExecutable()

static: bundleResources()
