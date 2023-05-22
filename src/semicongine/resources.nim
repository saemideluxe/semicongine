import std/streams
import std/strutils
import std/os

import ./core
import ./resources/image
import ./resources/audio
import ./resources/mesh

from ./scene import Entity, Scene

export image
export audio
export mesh

type
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

  proc loadResource_intern(path: string): Stream =
    newFileStream(joinPath(modRoot(), path), fmRead)

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative=true):
      if kind == pcDir:
        result.add file

  iterator walkResources_intern(): string =
    for file in walkDirRec(modRoot(), relative=true):
      yield file

elif thebundletype == Zip:

  import zip/zipfiles

  proc resourceRoot(): string =
    joinPath(absolutePath(getAppDir()), RESOURCEROOT)
  proc modRoot(): string =
    joinPath(resourceRoot(), selectedMod)

  proc loadResource_intern(path: string): Stream =
    var archive: ZipArchive
    if not archive.open(modRoot() & ".zip", fmRead):
      raise newException(Exception, "Unable to open file " & path)
    # read all here so we can close the stream
    result = newStringStream(archive.getStream(path).readAll())
    archive.close()

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative=true):
      if kind == pcFile and file.endsWith(".zip"):
        result.add file[0 ..< ^4]

  iterator walkResources_intern(): string =
    var archive: ZipArchive
    if not archive.open(modRoot() & ".zip", fmRead):
      raise newException(Exception, "Unable to open file " & modRoot() & ".zip")

    for i in archive.walkFiles:
      if i[^1] != '/':
        yield i
    archive.close()

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

  proc loadResource_intern(path: string): Stream =
    # TODO: add Lempel–Ziv–Welch compression or something similar simple
    newStringStream(bundledResources[selectedMod][path])

  proc modList_intern(): seq[string] =
    result = bundledResources.keys().toSeq()

  iterator walkResources_intern(): string =
    for i in bundledResources[selectedMod].keys:
      yield i

proc loadResource*(path: string): Stream =
  loadResource_intern(path)

proc loadImage*(path: string): Image =
  if path.splitFile().ext.toLowerAscii == ".bmp":
    loadResource_intern(path).readBMP()
  elif path.splitFile().ext.toLowerAscii == ".png":
    loadResource_intern(path).readPNG()
  else:
    raise newException(Exception, "Unsupported image file type: " & path)

proc loadAudio*(path: string): Sound =
  loadResource_intern(path).readAU()

proc loadMesh*(path: string): Entity =
  loadResource_intern(path).readglTF()[0].root

proc loadScene*(path: string, name=""): Scene =
  result = loadResource_intern(path).readglTF()[0]
  if name != "":
    result.name = name

proc loadScenes*(path: string): seq[Scene] =
  loadResource_intern(path).readglTF()

proc modList*(): seq[string] =
  modList_intern()

iterator walkResources*(): string =
  for i in walkResources_intern():
    yield i
