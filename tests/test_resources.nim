import std/streams

import semicongine

proc main() =
  echo "Mods available: ", modList()
  for modName in modList():
    echo modName, ":"
    selectedMod = modName
    for i in walkResources():
      echo "  ", i, ": ", loadResource(i).readAll().len

when isMainModule:
  main()
