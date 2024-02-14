import std/streams
import std/algorithm
import std/strutils
import std/sequtils
import std/strformat
import std/os
import std/sets
import std/unicode

import ./core
import ./resources/image
import ./resources/audio
import ./resources/mesh
import ./resources/font
import ./mesh
import ./material

export image
export audio
export mesh

type
  ResourceBundlingType = enum
    Dir # Directories
    Zip # Zip files
    Exe # Embeded in executable

const
  thebundletype = parseEnum[ResourceBundlingType](PACKAGETYPE.toLowerAscii().capitalizeAscii())
  ASCII_CHARSET = PrintableChars.toSeq.toRunes
  DEFAULT_PACKAGE = "default"

# resource loading

func normalizeDir(dir: string): string =
  result = dir
  if result.startsWith("./"):
    result = result[2 .. ^1]
  if result.startsWith("/"):
    result = result[1 .. ^1]
  result = dir.replace('\\', '/')
  if not result.endsWith("/") and result != "":
    result = result & "/"

when thebundletype == Dir:

  proc resourceRoot(): string =
    getAppDir().absolutePath().joinPath(RESOURCEROOT)
  proc packageRoot(package: string): string =
    resourceRoot().joinPath(package)

  proc loadResource_intern(path: string, package: string): Stream =
    let realpath = package.packageRoot().joinPath(path)
    if not realpath.fileExists():
      raise newException(Exception, &"Resource {path} not found (checked {realpath})")
    newFileStream(realpath, fmRead)

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative = true):
      if kind == pcDir:
        result.add file

  iterator walkResources_intern(dir: string, package = DEFAULT_PACKAGE): string =
    for file in walkDirRec(package.packageRoot().joinPath(dir), relative = true):
      yield file

  iterator ls_intern(dir: string, package: string): tuple[kind: PathComponent, path: string] =
    for i in walkDir(package.packageRoot().joinPath(dir), relative = true):
      yield i

elif thebundletype == Zip:

  import zippy/ziparchives

  proc resourceRoot(): string =
    absolutePath(getAppDir()).joinPath(RESOURCEROOT)
  proc packageRoot(package: string): string =
    resourceRoot().joinPath(package)

  proc loadResource_intern(path: string, package: string): Stream =
    let archive = openZipArchive(package.packageRoot() & ".zip")
    try:
      result = newStringStream(archive.extractFile(path))
    except ZippyError:
      raise newException(Exception, &"Resource {path} not found")
    archive.close()

  proc modList_intern(): seq[string] =
    for kind, file in walkDir(resourceRoot(), relative = true):
      if kind == pcFile and file.endsWith(".zip"):
        result.add file[0 ..< ^4]

  iterator walkResources_intern(dir: string, package = DEFAULT_PACKAGE): string =
    let archive = openZipArchive(package.packageRoot() & ".zip")
    let normDir = dir.normalizeDir()
    for i in archive.walkFiles:
      if i.startsWith(normDir):
        yield i
    archive.close()

  iterator ls_intern(dir: string, package: string): tuple[kind: PathComponent, path: string] =
    let archive = openZipArchive(package.packageRoot() & ".zip")
    let normDir = dir.normalizeDir()
    var yielded: HashSet[string]

    for i in archive.walkFiles:
      if i.startsWith(normDir):
        let components = i[normDir.len .. ^1].split('/', maxsplit = 1)
        if components.len == 1:
          if not (components[0] in yielded):
            yield (kind: pcFile, path: components[0])
        else:
          if not (components[0] in yielded):
            yield (kind: pcDir, path: components[0])
    archive.close()

elif thebundletype == Exe:

  import std/compilesettings
  import std/tables
  import std/sequtils

  const BUILD_RESOURCEROOT* {.strdefine.}: string = ""

  proc loadResources(): Table[string, Table[string, string]] {.compileTime.} =
    assert BUILD_RESOURCEROOT != "", "define BUILD_RESOURCEROOT to build for bundle type 'exe'"
    for kind, packageDir in walkDir(BUILD_RESOURCEROOT):
      if kind == pcDir:
        let package = packageDir.splitPath.tail
        result[package] = Table[string, string]()
        for resourcefile in walkDirRec(packageDir, relative = true):
          result[package][resourcefile] = staticRead(packageDir.joinPath(resourcefile))
  const bundledResources = loadResources()

  proc loadResource_intern(path: string, package: string): Stream =
    if not (path in bundledResources[package]):
      raise newException(Exception, &"Resource {path} not found")
    newStringStream(bundledResources[package][path])

  proc modList_intern(): seq[string] =
    result = bundledResources.keys().toSeq()

  iterator walkResources_intern(dir: string, package = DEFAULT_PACKAGE): string =
    for i in bundledResources[package].keys:
      yield i

  iterator ls_intern(dir: string, package: string): tuple[kind: PathComponent, path: string] =
    let normDir = dir.normalizeDir()
    var yielded: HashSet[string]

    for i in bundledResources[package].keys:
      if i.startsWith(normDir):
        let components = i[normDir.len .. ^1].split('/', maxsplit = 1)
        if components.len == 1:
          if not (components[0] in yielded):
            yield (kind: pcFile, path: components[0])
        else:
          if not (components[0] in yielded):
            yield (kind: pcDir, path: components[0])

proc loadResource*(path: string, package = DEFAULT_PACKAGE): Stream =
  loadResource_intern(path, package = package)

proc loadImage*[T](path: string, package = DEFAULT_PACKAGE): Image[RGBAPixel] =
  if path.splitFile().ext.toLowerAscii == ".bmp":
    loadResource_intern(path, package = package).readBMP()
  elif path.splitFile().ext.toLowerAscii == ".png":
    loadResource_intern(path, package = package).readPNG()
  else:
    raise newException(Exception, "Unsupported image file type: " & path)

proc loadAudio*(path: string, package = DEFAULT_PACKAGE): Sound =
  if path.splitFile().ext.toLowerAscii == ".au":
    loadResource_intern(path, package = package).readAU()
  elif path.splitFile().ext.toLowerAscii == ".ogg":
    loadResource_intern(path, package = package).readVorbis()
  else:
    raise newException(Exception, "Unsupported audio file type: " & path)

proc loadFont*(
  path: string,
  name = "",
  lineHeightPixels = 80'f32,
  additional_codepoints: openArray[Rune] = [],
  charset = ASCII_CHARSET,
  package = DEFAULT_PACKAGE
): Font =
  var thename = name
  if thename == "":
    thename = path.splitFile().name
  loadResource_intern(path, package = package).readTrueType(name, charset & additional_codepoints.toSeq, lineHeightPixels)

proc loadMeshes*(path: string, defaultMaterial: MaterialType, package = DEFAULT_PACKAGE): seq[MeshTree] =
  loadResource_intern(path, package = package).readglTF(defaultMaterial)

proc loadFirstMesh*(path: string, defaultMaterial: MaterialType, package = DEFAULT_PACKAGE): Mesh =
  loadResource_intern(path, package = package).readglTF(defaultMaterial)[0].toSeq[0]

proc packages*(): seq[string] =
  modList_intern()

proc walkResources*(dir = "", package = DEFAULT_PACKAGE): seq[string] =
  for i in walkResources_intern(dir, package = package):
    if i.startsWith(dir):
      result.add i
  result.sort()

proc ls*(dir: string, package = DEFAULT_PACKAGE): seq[tuple[kind: PathComponent, path: string]] =
  for i in ls_intern(dir = dir, package = package):
    result.add i
  result.sort()
