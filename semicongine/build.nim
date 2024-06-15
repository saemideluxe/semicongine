# this should be used with nimscript

import std/strformat
import std/os
import std/strutils

import ./core/audiotypes
import ./core/constants

const BLENDER_CONVERT_SCRIPT = currentSourcePath().parentDir().parentDir().joinPath("tools/blender_gltf_converter.py")
const STEAMCMD_ZIP = currentSourcePath().parentDir().parentDir().joinPath("tools/steamcmd.zip")
const STEAMBUILD_DIR_NAME = "steam"

var STEAMLIB: string
if defined(linux):
  STEAMLIB = currentSourcePath().parentDir().parentDir().joinPath("libs/libsteam_api.so")
elif defined(windows):
  STEAMLIB = currentSourcePath().parentDir().parentDir().joinPath("libs/steam_api.dll")
else:
  raise newException(Exception, "Unsupported platform")
# let SQLITELIB_32 = currentSourcePath().parentDir().parentDir().joinPath("libs/sqlite3_32.dll")
let SQLITELIB_64 = currentSourcePath().parentDir().parentDir().joinPath("libs/sqlite3_64.dll")

proc semicongine_builddir*(buildname: string, builddir = "./build"): string =
  assert projectName() != "", "Please specify project file as a commandline argument"
  var platformDir = "unkown"

  if defined(linux):
    platformDir = "linux"
  elif defined(windows):
    platformDir = "windows"
  else:
    raise newException(Exception, "Unsupported platform")

  return builddir / buildname / platformDir / projectName()

proc semicongine_build_switches*(buildname: string, builddir = "./build") =
  switch("experimental", "strictEffects")
  switch("experimental", "strictFuncs")
  switch("define", "nimPreviewHashRef")
  if defined(linux):
    switch("define", "VK_USE_PLATFORM_XLIB_KHR")
  elif defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    switch("app", "gui")
  else:
    raise newException(Exception, "Unsupported platform")

  switch("outdir", semicongine_builddir(buildname, builddir = builddir))
  switch("passL", "-Wl,-rpath,'$ORIGIN'") # adds directory of executable to dynlib search path

proc semicongine_pack*(outdir: string, bundleType: string, resourceRoot: string, withSteam: bool) =
  switch("define", "PACKAGETYPE=" & bundleType)

  assert resourceRoot.dirExists, &"Resource root '{resourceRoot}' does not exists"

  outdir.rmDir()
  outdir.mkDir()

  echo "BUILD: Packing assets from '" & resourceRoot & "' into directory '" & outdir & "'"
  let outdir_resources = joinPath(outdir, RESOURCEROOT)
  if bundleType == "dir":
    cpDir(resourceRoot, outdir_resources)
  elif bundleType == "zip":
    outdir_resources.mkDir()
    for resourceDir in resourceRoot.listDirs():
      let outputfile = joinPath(outdir_resources, resourceDir.splitPath().tail & ".zip")
      withdir resourceDir:
        if defined(linux):
          echo &"zip -r {relativePath(outputfile, resourceDir)} ."
          exec &"zip -r {relativePath(outputfile, resourceDir)} ."
        elif defined(windows):
          echo &"powershell Compress-Archive * {relativePath(outputfile, resourceDir)}"
          exec &"powershell Compress-Archive * {relativePath(outputfile, resourceDir)}"
        else:
          raise newException(Exception, "Unsupported platform")
  elif bundleType == "exe":
    switch("define", "BUILD_RESOURCEROOT=" & joinPath(getCurrentDir(), resourceRoot)) # required for in-exe packing of resources, must be absolute
  if defined(windows):
    # SQLITELIB_32.cpFile(outdir.joinPath(SQLITELIB_32.extractFilename))
    SQLITELIB_64.cpFile(outdir.joinPath(SQLITELIB_64.extractFilename))
  if withSteam:
    STEAMLIB.cpFile(outdir.joinPath(STEAMLIB.extractFilename))

proc semicongine_zip*(dir: string) =
  withdir dir.parentDir:
    let zipFile = dir.lastPathPart & ".zip"
    if zipFile.fileExists:
      zipFile.rmFile()
    if defined(linux):
      exec &"zip -r {dir.lastPathPart} {dir.lastPathPart}"
    elif defined(windows):
      exec &"powershell Compress-Archive * {dir.lastPathPart}"
    else:
      raise newException(Exception, "Unsupported platform")


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
    let target = thisDir().joinPath(target_rel)
    let source = thisDir().joinPath(source_rel)
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


# for steam-buildscript docs see https://partner.steamgames.com/doc/sdk/uploading
proc semicongine_steam_upload*(steamaccount, password, buildscript: string) =
  let steamdir = thisDir().joinPath(STEAMBUILD_DIR_NAME)
  if not dirExists(steamdir):
    steamdir.mkDir
    let zipFilename = STEAMCMD_ZIP.extractFilename
    STEAMCMD_ZIP.cpFile(steamdir.joinPath(zipFilename))
    withDir(steamdir):
      if defined(linux):
        exec &"unzip {zipFilename}"
        rmFile zipFilename
        exec "steamcmd/steamcmd.sh +quit" # self-update steamcmd
      elif defined(windows):
        exec &"powershell Expand-Archive -LiteralPath {zipFilename} ."
        rmFile zipFilename
        exec "steamcmd/steamcmd.exe +quit" # self-update steamcmd
      else:
        raise newException(Exception, "Unsupported platform")

  var steamcmd: string
  if defined(linux):
    steamcmd = STEAMBUILD_DIR_NAME.joinPath("steamcmd").joinPath("steamcmd.sh")
  elif defined(windows):
    steamcmd = STEAMBUILD_DIR_NAME.joinPath("steamcmd").joinPath("steamcmd.exe")
  else:
    raise newException(Exception, "Unsupported platform")
  let scriptPath = "..".joinPath("..").joinPath(buildscript)
  exec &"./{steamcmd} +login \"{steamaccount}\" \"{password}\" +run_app_build {scriptPath} +quit"

proc semicongine_sign_executable*(file: string) =
  const SIGNTOOL_EXE = "C:/Program Files (x86)/Windows Kits/10/App Certification Kit/signtool.exe"
  if not SIGNTOOL_EXE.fileExists:
    raise newException(Exception, &"signtool.exe not found at ({SIGNTOOL_EXE}), please install the Windows SDK")
  exec &"\"{SIGNTOOL_EXE}\" sign /a /tr http://timestamp.globalsign.com/tsa/r6advanced1 /fd SHA256 /td SHA256 {file}"
