import std/strutils

func cleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

