import std/strformat
import std/os

import ./core/audiotypes

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

proc semicongine_import_mesh*(blender_file: string, output_file: string) =
  assert blender_file.fileExists
  let converter_script  = currentSourcePath.parentDir().parentDir().joinPath("scripts/blender_gltf_converter.py")
  exec &"blender --background --python {converter_script} -- {blender_file} {output_file}"

proc semicongine_import_audio*(in_file: string, output_file: string) =
  exec &"ffmpeg -i {in_file} -ar {AUDIO_SAMPLE_RATE} {output_file}"
