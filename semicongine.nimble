# Package

# name          = "semicongine"
version = "0.3.0"
author = "Sam <sam@basx.dev>"
description = "Game engine, for games that run on semiconductor engines"
license = "MIT"
backend = "c"

if detectOS(Linux):
  # required for packaging, on windows we use powershell
  foreignDep "zip"
  foreignDep "unzip"
  # required for builds using steam
  foreignDep "libstdc++6:i386"
  foreignDep "libc6:i386"
  foreignDep "libx11-dev"

requires "nim >= 2.0"
requires "zippy"

