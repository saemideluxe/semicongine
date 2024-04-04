# Package

# name          = "semicongine"
version = "0.3.0"
author = "Sam <sam@basx.dev>"
description = "Game engine, for games that run on semiconductor engines"
license = "MIT"
backend = "c"
installDirs = @["semicongine"]

# Dependencies
# On linux/debian also run the following to get everything working
# sudo dpkg --add-architecture i386
# sudo apt-get update
# sudo apt-get install zip unzip libstdc++6:i386 libc6:i386


requires "nim >= 2.0"
requires "winim"
requires "x11" # also requires libx11-dev e.g. on debian systems
requires "zippy"

