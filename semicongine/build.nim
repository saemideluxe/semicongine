# this should be used with nimscript

import std/strformat
import std/os
import std/strutils

import ./core/audiotypes
import ./core/constants

const BLENDER_CONVERT_SCRIPT = currentSourcePath().parentDir().parentDir().joinPath("tools/blender_gltf_converter.py")

proc semicongine_builddir*(buildname: string, builddir = "./build"): string =
  var platformDir = "unkown"

  if defined(linux):
    platformDir = "linux"
  elif defined(windows):
    platformDir = "windows"

  return builddir / buildname / platformDir / projectName()

proc semicongine_build_switches*(buildname: string, builddir = "./build") =
  switch("experimental", "strictEffects")
  switch("experimental", "strictFuncs")
  switch("define", "nimPreviewHashRef")
  if defined(linux): switch("define", "VK_USE_PLATFORM_XLIB_KHR")
  if defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    switch("app", "gui")
  switch("outdir", semicongine_builddir(buildname, builddir = builddir))

proc semicongine_pack*(outdir: string, bundleType: string, resourceRoot: string) =
  switch("define", "PACKAGETYPE=" & bundleType)

  rmDir(outdir)
  mkDir(outdir)

  echo "BUILD: Packing assets from '" & resourceRoot & "' into directory '" & outdir & "'"
  let outdir_resources = joinPath(outdir, RESOURCEROOT)
  if bundleType == "dir":
    cpDir(resourceRoot, outdir_resources)
  elif bundleType == "zip":
    mkDir(outdir_resources)
    for resource in listDirs(resourceRoot):
      let outputfile = joinPath(outdir_resources, resource.splitPath().tail & ".zip")
      withdir resource:
        if defined(linux):
          exec &"zip -r {outputfile} ."
        elif defined(windows):
          exec &"powershell Compress-Archive * {outputfile}"
  elif bundleType == "exe":
    switch("define", "BUILD_RESOURCEROOT=" & joinPath(getCurrentDir(), resourceRoot)) # required for in-exe packing of resources, must be absolute

proc semicongine_zip*(dir: string) =
  withdir dir.parentDir:
    if defined(linux):
      exec &"zip -r {dir.lastPathPart} ."
    elif defined(windows):
      exec &"powershell Compress-Archive * {dir.lastPathPart}"


# need this because fileNewer from std/os does not work in Nim VM
proc fileNewerStatic(file1, file2: string): bool =
  assert file1.fileExists
  assert file2.fileExists
  when defined(linux):
    let command = "/usr/bin/test " & file1 & " -nt " & file2
    let ex = gorgeEx(command)
    return ex.exitCode == 0
  elif defined(window):
    {.error "Resource imports not supported on windows for now".}

proc import_meshes*(files: seq[(string, string)]) =
  if files.len == 0:
    return

  var args = @["--background", "--python", BLENDER_CONVERT_SCRIPT, "--"]
  for (input, output) in files:
    args.add input
    args.add output

  exec("blender " & args.join(" "))

proc import_audio*(files: seq[(string, string)]) =
  for (input, output) in files:
    let command = "ffmpeg " & ["-y", "-i", input, "-ar", $AUDIO_SAMPLE_RATE, output].join(" ")
    exec(command)

proc semicongine_import_resource_file*(resourceMap: openArray[(string, string)]) =
  when not defined(linux):
    {.warning: "Resource files can only be imported on linux, please make sure that the required files are created by runing the build on a linux machine.".}
    return
  var meshfiles: seq[(string, string)]
  var audiofiles: seq[(string, string)]

  for (target_rel, source_rel) in resourceMap:
    let target = joinPath(thisDir(), target_rel)
    let source = joinPath(thisDir(), source_rel)
    if not source.fileExists:
      raise newException(IOError, &"Not found: {source}")
    if not target.fileExists or source.fileNewerStatic(target):
      echo &"{target} is outdated"
      if source.endsWith("blend"):
        meshfiles.add (source, target)
      elif source.endsWith("mp3") or source.endsWith("ogg") or source.endsWith("wav"):
        audiofiles.add (source, target)
      else:
        raise newException(Exception, &"unkown file type: {source}")
      target.parentDir().mkDir()
    else:
      echo &"{target} is up-to-date"
  import_meshes meshfiles
  import_audio audiofiles

const STEAM_DIR_NAME = "steamcmd"

proc semicongine_steam*() =
  if not defined(linux):
    echo "steam builds must be done on linux for now"
    return

  let steamdir = thisDir().joinPath(STEAM_DIR_NAME)
  if not dirExists(steamdir):
