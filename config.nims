import std/strformat
import std/strutils
import std/os

const BUILDBASE = "build"
const DEBUG = "debug"
const RELEASE = "release"
const LINUX = "linux"
const WINDOWS = "windows"

const BUNDLETYPE* {.strdefine.}: string = "dir" # dir, zip, exe
const RESOURCEROOT* {.strdefine.}: string = "resources"

switch("d", "nimPreviewHashRef")
switch("experimental", "strictEffects")
switch("experimental", "strictFuncs")
switch("nimblePath", "nimbledeps/pkgs2")

task build, "build":
  switch("d", "BUNDLETYPE=" & BUNDLETYPE)
  switch("d", "RESOURCEROOT=" & RESOURCEROOT)
  var buildType = DEBUG
  var platformDir = ""
  if defined(linux):
    switch("define", "VK_USE_PLATFORM_XLIB_KHR")
    platformDir = LINUX
  if defined(windows):
    switch("define", "VK_USE_PLATFORM_WIN32_KHR")
    platformDir = WINDOWS
  if defined(release):
    switch("app", "gui")
    buildType = RELEASE
  else:
    switch("debugger", "native")

  var outdir = getCurrentDir() / BUILDBASE / buildType / platformDir / projectName()
  switch("outdir", outdir)
  setCommand "c"
  rmDir(outdir)
  mkDir(outdir)
  let resourcedir = joinPath(projectDir(), RESOURCEROOT)
  if dirExists(resourcedir):
    let outdir_resources = joinPath(outdir, RESOURCEROOT)
    if BUNDLETYPE == "dir":
      cpDir(resourcedir, outdir_resources)
    elif BUNDLETYPE == "zip":
      mkDir(outdir_resources)
      for resource in listDirs(resourcedir):
        let
          oldcwd = getCurrentDir()
          outputfile = joinPath(outdir_resources, resource.splitPath().tail & ".zip")
          inputfile = resource.splitPath().tail
        cd(resource)
        if defined(linux):
          exec &"zip -r {outputfile} ."
        elif defined(windows):
          # TODO: test this
          exec &"powershell Compress-Archive * {outputfile}"
        cd(oldcwd)

task build_all_debug, "build all examples for debug":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      exec(&"nim build {file}")

task build_all_release, "build all examples for release":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      exec(&"nim build -d:release {file}")

task test_all, "Run all test programs":
  for file in listFiles("tests"):
    if file.endsWith(".nim"):
      exec(&"nim build --run {file}")

task clean, "remove all build files":
  exec(&"rm -rf {BUILDBASE}")

task publish, "publish all build":
  for file in listDirs("build/debug/linux"):
    exec(&"scp -r {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/debug/linux/")
  for file in listDirs("build/release/linux"):
    exec(&"scp -r {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/release/linux/")
  for file in listDirs("build/debug/windows"):
    exec(&"scp -r {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/debug/windows/")
  for file in listDirs("build/release/windows"):
    exec(&"scp -r {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/release/windows/")

task glslangValidator, "Download glslangValidator (required for linux compilation)":
  let dirname = "/tmp/glslang_download"
  exec &"mkdir -p {dirname}"
  exec &"cd {dirname} && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Release.zip"
  exec &"cd {dirname} && unzip *.zip"
  exec &"mv {dirname}/bin/glslangValidator examples/"
  exec &"rm -rf {dirname}"

task glslangValidator_exe, "Download glslangValidator.exe (required for windows compilation)":
  # TODO: make this work on windows
  let dirname = "/tmp/glslang_download"
  exec &"mkdir -p {dirname}"
  exec &"cd {dirname} && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Release.zip"
  exec &"cd {dirname} && unzip *.zip"
  exec &"mv {dirname}/bin/glslangValidator.exe examples/"
  exec &"rm -rf {dirname}"

task run_all, "Run all binaries":
  for file in listFiles("build/debug/linux"):
    exec file
  for file in listFiles("build/release/linux"):
    exec file
  for file in listFiles("build/debug/windows"):
    exec &"wine {file}"
  for file in listFiles("build/release/windows"):
    exec &"wine {file}"

task get_vulkan_wrapper, "Download vulkan wrapper":
  exec &"curl https://raw.githubusercontent.com/nimgl/nimgl/master/src/nimgl/vulkan.nim > src/semicongine/vulkan/c_api.nim"

task generate_vulkan_api, "Generate Vulkan API":
  selfExec &"c -d:ssl --run src/vulkan_api/vulkan_api_generator.nim"
  mkDir "src/semicongine/vulkan/"
  mkDir "src/semicongine/core/"
  cpFile "src/vulkan_api/output/api.nim", "src/semicongine/core/api.nim"
  cpDir "src/vulkan_api/output/platform", "src/semicongine/vulkan/platform"

if getCommand() in ["c", "compile", "r", "dump", "check", "idetools"]:
  if defined(linux):
    --d:VK_USE_PLATFORM_XLIB_KHR
  if defined(windows):
    --d:VK_USE_PLATFORM_WIN32_KHR
