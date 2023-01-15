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
  switch("app", "gui")

proc compilerFlagsDebug() =
  switch("debugger", "native")
  switch("checks", "on")
  switch("assertions", "on")

proc compilerFlagsRelease() =
  switch("define", "release")
  switch("checks", "off")
  switch("assertions", "off")

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
  # for some the --define:mingw does not work from inside here...
  # so we need to set it when calling the task and use "/" to prevent
  # the use of backslash while crosscompiling
  switch("define", "mingw")
  switch("outdir", BUILDBASE & "/" & DEBUG & "/" & WINDOWS)
  setCommand "c"
  mkDir(BUILDBASE & "/" & DEBUG & "/" & WINDOWS)

task single_windows_release, "build windows release":
  compilerFlags()
  compilerFlagsRelease()
  switch("outdir", BUILDBASE & "/" & RELEASE & "/" & WINDOWS)
  switch("define", "mingw")
  setCommand "c"
  mkDir(BUILDBASE & "/" & RELEASE & "/" & WINDOWS)

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
  exec("rsync -rv build/ basx.dev:/var/www/public.basx.dev/zamikongine")


if getCommand() in ["c", "compile", "r", "dump", "check"]:
  compilerFlags()
