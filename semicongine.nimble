# Package

# name          = "semicongine"
version = "0.3.0"
author = "Sam <sam@basx.dev>"
description = "Game engine, for games that run on semiconductor engines"
license = "MIT"
backend = "c"

if detectOS(Linux):
  foreignDep "zip"
  foreignDep "unzip"
  # required for builds using steam
  foreignDep "libstdc++6:i386"
  foreignDep "libc6:i386"

requires "nim >= 2.0"
requires "winim"
requires "x11" # also requires libx11-dev e.g. on debian systems
requires "zippy"
requires "db_connector"

