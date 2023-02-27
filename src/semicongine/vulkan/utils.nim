import std/strutils

func cleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

func toCPointer*[T](list: var seq[T]): ptr T =
  if list.len > 0: addr list[0] else: nil
