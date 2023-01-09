import os

const buildbase = "build"

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

proc compilerFlagsDebugWindows() =
  switch("cc", "vcc")
  switch("passC", "/MDd")
  switch("passL", "ucrtd.lib")

proc compilerFlagsReleaseWindows() =
  switch("cc", "vcc")
  switch("passC", "/MD")
  switch("passL", "ucrt.lib")

task build_linux_debug, "build linux debug":
  compilerFlags()
  compilerFlagsDebug()
  buildbase.joinPath("debug/linux").mkDir()
  setCommand "c"

task build_linux_release, "build linux release":
  compilerFlags()
  compilerFlagsRelease()
  buildbase.joinPath("release/linux").mkDir()
  setCommand "c"

task build_windows_debug, "build windows debug":
  compilerFlags()
  compilerFlagsDebug()
  compilerFlagsDebugWindows()
  buildbase.joinPath("debug/windows").mkDir()
  setCommand "c"

task build_windows_release, "build windows release":
  compilerFlags()
  compilerFlagsRelease()
  compilerFlagsReleaseWindows()
  buildbase.joinPath("release/windows").mkDir()
  setCommand "c"

compilerFlags()
