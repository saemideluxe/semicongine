import std/strformat
import std/strutils
import std/os

import semiconginev2/build

task build_dev, "build dev":
  semicongine_build_switches(buildname = "dev")
  setCommand "c"
  let outdir = semicongine_builddir(buildname = "dev")
  semicongine_pack(outdir, bundleType = "exe", resourceRoot = "tests/resources", withSteam = false)

task build_dev_zip, "build dev zip":
  semicongine_build_switches(buildname = "dev")
  setCommand "c"
  let outdir = semicongine_builddir(buildname = "dev")
  semicongine_pack(outdir, bundleType = "zip", resourceRoot = "tests/resources", withSteam = false)

task build_dev_dir, "build dev dir":
  semicongine_build_switches(buildname = "dev")
  setCommand "c"
  let outdir = semicongine_builddir(buildname = "dev")
  semicongine_pack(outdir, bundleType = "dir", resourceRoot = "tests/resources", withSteam = false)

task build_release, "build release":
  switch "define", "release"
  switch "app", "gui"
  semicongine_build_switches(buildname = "release")
  setCommand "c"
  let outdir = semicongine_builddir(buildname = "release")
  semicongine_pack(outdir, bundleType = "exe", resourceRoot = "tests/resources", withSteam = false)


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
    if file.endsWith(".nim") and not file.endsWith("test_resources.nim"):
      exec(&"nim build_dev --run {file}")

  exec("nim build_dev --run tests/test_resources.nim")
  exec("nim build_dev_zip --run tests/test_resources.nim")
  exec("nim build_dev_dir --run tests/test_resources.nim")

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
  if defined(linux):
    --d: VK_USE_PLATFORM_XLIB_KHR
  if defined(windows):
    --d: VK_USE_PLATFORM_WIN32_KHR
