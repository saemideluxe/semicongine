import std/strutils
import std/os

import ./core

type
  Binary* = seq[uint8]
  ResourceBundlingType = enum
    Dir # Directories
    Zip # Zip files
    Exe # Embeded in executable

const thebundletype = parseEnum[ResourceBundlingType](BUNDLETYPE.toLowerAscii().capitalizeAscii())
var selectedMod* = "default"

# resource loading

when thebundletype == Dir:

  proc resourceRoot(): string =
    joinPath(absolutePath(getAppDir()), RESOURCEROOT)
  proc modRoot(): string =
    joinPath(resourceRoot(), selectedMod)

  proc loadResource_intern(path: string): Binary =
    cast[Binary](readFile(joinPath(modRoot(), path)))

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative=true):
      if kind == pcDir:
        result.add file

  iterator walkResources_intern(): string =
    for i in walkDir(modRoot(), relative=true):
      yield i.path

elif thebundletype == Zip:

  import zippy/ziparchives

  proc resourceRoot(): string =
    joinPath(absolutePath(getAppDir()), RESOURCEROOT)
  proc modRoot(): string =
    joinPath(resourceRoot(), selectedMod)

  proc loadResource_intern(path: string): Binary =
    let reader = openZipArchive(modRoot() & ".zip")
    result = cast[Binary](reader.extractFile(path))
    reader.close()

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative=true):
      if kind == pcFile and file.endsWith(".zip"):
        result.add file[0 ..< ^4]

  iterator walkResources_intern(): string =
    let reader = openZipArchive(modRoot() & ".zip")
    for i in reader.walkFiles:
      yield i.splitPath().tail
    reader.close()

elif thebundletype == Exe:

  import std/compilesettings
  import std/tables
  import std/sequtils

  proc loadResources(): Table[string, Table[string, string]] {.compileTime.} =

    let srcdir = joinPath(parentDir(querySetting(projectFull)), RESOURCEROOT)
    for kind, moddir in walkDir(srcdir):
      if kind == pcDir:
        let modname = moddir.splitPath.tail
        result[modname] = Table[string, string]()
        for resourcefile in walkDirRec(moddir, relative=true):
        # TODO: add Lempel–Ziv–Welch compression or something similar simple
          result[modname][resourcefile] = staticRead(joinPath(moddir, resourcefile))
  const bundledResources = loadResources()

  proc loadResource_intern(path: string): Binary =
    # TODO: add Lempel–Ziv–Welch compression or something similar simple
    cast[seq[uint8]](bundledResources[selectedMod][path])

  proc modList_intern(): seq[string] =
    result = bundledResources.keys().toSeq()

  iterator walkResources_intern(): string =
    for i in bundledResources[selectedMod].keys:
      yield i

proc loadResource*(path: string): ref Binary =
    result = new Binary
    result[] = loadResource_intern(path)

proc modList*(): seq[string] =
  modList_intern()

iterator walkResources*(): string =
  for i in walkResources_intern():
    yield i
