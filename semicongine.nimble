# Package

# name          = "semicongine"
version       = "0.3.0"
author        = "Sam <sam@basx.dev>"
description   = "Game engine, for games that run on semiconductor engines"
license       = "MIT"
backend       = "c"
bin           = @["simporter"]
installDirs   = @["semicongine"]

# Dependencies

requires "nim >= 2.0"
requires "winim"
requires "x11"
requires "zippy"

