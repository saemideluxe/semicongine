# Package

# name          = "semicongine"
version = "0.3.0"
author = "Sam <sam@basx.dev>"
description = "Game engine, for games that run on semiconductor engines"
license = "MIT"
backend = "c"
installDirs = @["semicongine"]

# Dependencies

requires "nim >= 2.0"
requires "winim"
requires "x11" # also requires libx11-dev e.g. on debian systems
requires "zippy"

