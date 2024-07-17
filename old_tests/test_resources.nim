import std/os
import std/streams
import std/strformat
import std/strutils

import semicongine

proc list_all_mods_all_files() =
  for package in Packages():
    echo &"Files in package {package}:"
    for i in WalkResources(package = package):
      echo "  ", i, ": ", i.LoadResource(package = package).readAll().len

proc print_ls(dir, package: string, indent = 2) =
  for i in dir.List(package = package):
    if i.kind == pcDir:
      echo "".align(indent), i.path, "/"
      print_ls(dir.joinPath(i.path), package = package, indent = indent + 2)
    else:
      echo "".align(indent), i.path, ": ", dir.joinPath(i.path).LoadResource(package = package).readAll().len

proc list_files() =
  for package in Packages():
    echo &"Recursive walk of package {package}: "
    print_ls("", package = package)


proc main() =
  echo "Packages available: ", Packages()
  list_all_mods_all_files()
  list_files()

when isMainModule:
  main()
