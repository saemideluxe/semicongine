import std/strformat
import std/strutils
import std/os

const BUILDBASE = "build"
const DEBUG = "debug"
const RELEASE = "release"
const LINUX = "linux"
const WINDOWS = "windows"

proc compilerFlags() =
  switch("path", "src")
  switch("mm", "orc")
  switch("experimental", "strictEffects")
  switch("threads", "on")

proc compilerFlagsDebug() =
  switch("debugger", "native")
  switch("checks", "on")
  switch("assertions", "on")

proc compilerFlagsRelease() =
  switch("define", "release")
  switch("checks", "off")
  switch("assertions", "off")
  switch("app", "gui")

task single_linux_debug, "build linux debug":
  compilerFlags()
  compilerFlagsDebug()
  switch("outdir", BUILDBASE / DEBUG / LINUX)
  setCommand "c"
  mkDir(BUILDBASE / DEBUG / LINUX)

task single_linux_release, "build linux release":
  compilerFlags()
  compilerFlagsRelease()
  switch("outdir", BUILDBASE / RELEASE / LINUX)
  setCommand "c"
  mkDir(BUILDBASE / RELEASE / LINUX)

task single_windows_debug, "build windows debug":
  compilerFlags()
  compilerFlagsDebug()
  switch("outdir", BUILDBASE & "/" & DEBUG & "/" & WINDOWS)
  setCommand "c"
  mkDir(BUILDBASE & "/" & DEBUG & "/" & WINDOWS)


task single_windows_release, "build windows release":
  compilerFlags()
  compilerFlagsRelease()
  switch("outdir", BUILDBASE & "/" & RELEASE & "/" & WINDOWS)
  setCommand "c"
  mkDir(BUILDBASE & "/" & RELEASE & "/" & WINDOWS)

task single_crosscompile_windows_debug, "build crosscompile windows debug":
  switch("define", "mingw")
  single_windows_debugTask()

task single_crosscompile_windows_release, "build crosscompile windows release":
  switch("define", "mingw")
  single_windows_releaseTask()

task build_all_linux_debug, "build all examples with linux/debug":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      selfExec(&"single_linux_debug {file}")

task build_all_linux_release, "build all examples with linux/release":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      selfExec(&"single_linux_release {file}")

task build_all_windows_debug, "build all examples with windows/debug":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      exec(&"nim single_windows_debug --define:mingw {file}")

task build_all_windows_release, "build all examples with windows/release":
  for file in listFiles("examples"):
    if file.endsWith(".nim"):
      exec(&"nim single_windows_release --define:mingw {file}")

task build_all_debug, "build all examples with */debug":
  build_all_linux_debugTask()
  build_all_windows_debugTask()

task build_all_release, "build all examples with */release":
  build_all_linux_releaseTask()
  build_all_windows_releaseTask()

task build_all_linux, "build all examples with linux/*":
  build_all_linux_debugTask()
  build_all_linux_releaseTask()

task build_all_windows, "build all examples with windows/*":
  build_all_windows_debugTask()
  build_all_windows_releaseTask()

task build_all, "build all examples":
  build_all_linuxTask()
  build_all_windowsTask()

task clean, "remove all build files":
  exec(&"rm -rf {BUILDBASE}")

task publish, "publish all build":
  for file in listFiles("build/debug/linux"):
    exec(&"scp {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/debug/linux/")
  for file in listFiles("build/release/linux"):
    exec(&"scp {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/release/linux/")
  for file in listFiles("build/debug/windows"):
    exec(&"scp {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/debug/windows/")
  for file in listFiles("build/release/windows"):
    exec(&"scp {file} sam@mail.basx.dev:/var/www/public.basx.dev/semicongine/release/windows/")

task glslangValidator, "Download glslangValidator (required for linux compilation)":
  let dirname = "/tmp/glslang_download"
  exec &"mkdir -p {dirname}"
  exec &"cd {dirname} && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Release.zip"
  exec &"cd {dirname} && unzip *.zip"
  exec &"mv {dirname}/bin/glslangValidator examples/"
  exec &"rm -rf {dirname}"

task glslangValidator_exe, "Download glslangValidator.exe (required for windows compilation)":
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

if getCommand() in ["c", "compile", "r", "dump", "check", "idetools"]:
  compilerFlags()
