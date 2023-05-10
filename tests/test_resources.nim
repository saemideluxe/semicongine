import std/times

import semicongine

proc main() =
  echo "Mods available: ", modList()
  for modName in modList():
    echo modName, ":"
    selectedMod = modName
    for i in walkResources():
      echo "  ", i, ": ", loadResource(i)[]

when isMainModule:
  main()
