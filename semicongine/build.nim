import std/strformat
import std/os

proc semicongine_build*(buildType: string, bundleType: string, resourceRoot="resources", builddir="./build"): string =
  switch("experimental", "strictEffects")
  switch("experimental", "strictFuncs")
  switch("define", "nimPreviewHashRef")


  var platformDir = "unkown"
  if defined(linux):
    switch("define", "VK_USE_PLATFORM_XLIB_KHR")
    platformDir = "linux"
  if defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    platformDir = "windows"

  var outdir = builddir / buildType / platformDir / projectName()
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
        let
          oldcwd = getCurrentDir()
          outputfile = joinPath(outdir_resources, resource.splitPath().tail & ".zip")
        cd(resource)
        if defined(linux):
          exec &"zip -r {outputfile} ."
        elif defined(windows):
          exec &"powershell Compress-Archive * {outputfile}"
        cd(oldcwd)
  return outdir
