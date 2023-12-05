import std/strformat
import std/os

import ./core/audiotypes

proc semicongine_outdir*(buildname: string, builddir="./build"): string =
  var platformDir = "unkown"
  if defined(linux):
    switch("define", "VK_USE_PLATFORM_XLIB_KHR")
    platformDir = "linux"
  if defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    platformDir = "windows"

  return builddir / buildname / platformDir / projectName()

proc semicongine_build*(buildname: string, bundleType: string, resourceRoot: string, builddir="./build"): string =
  switch("experimental", "strictEffects")
  switch("experimental", "strictFuncs")
  switch("define", "nimPreviewHashRef")

  switch("define", &"BUNDLETYPE={bundleType}")
  switch("define", &"RESOURCEROOT={resourceRoot}")

  var platformDir = "unkown"
  if defined(linux):
    switch("define", "VK_USE_PLATFORM_XLIB_KHR")
    platformDir = "linux"
  if defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    platformDir = "windows"

  var outdir = builddir / buildname / platformDir / projectName()
  switch("outdir", outdir)
  setCommand "c"
  rmDir(outdir)
  mkDir(outdir)
  let resourcedir = joinPath(projectDir(), resourceRoot)
  if os.dirExists(resourcedir):
    let outdir_resources = joinPath(outdir, resourceRoot)
    if bundleType == "dir":
      cpDir(resourcedir, outdir_resources)
    elif bundleType == "zip":
      mkDir(outdir_resources)
      for resource in listDirs(resourcedir):
        let outputfile = joinPath(outdir_resources, resource.splitPath().tail & ".zip")
        withdir resource:
          if defined(linux):
            exec &"zip -r {outputfile} ."
          elif defined(windows):
            exec &"powershell Compress-Archive * {outputfile}"
  return outdir

proc semicongine_zip*(dir: string) =
  withdir dir.parentDir:
    if defined(linux):
      exec &"zip -r {dir.lastPathPart} ."
    elif defined(windows):
      exec &"powershell Compress-Archive * {dir.lastPathPart}"

