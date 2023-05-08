import std/typetraits
import std/strutils
import std/strformat

func cleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

func toCPointer*[T](list: var seq[T]): ptr T =
  if list.len > 0: addr list[0] else: nil

proc staticExecChecked*(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(
      command = command,
      input = input)
  if exitcode != 0:
    raise newException(Exception, &"Running '{command}' produced exit code: {exitcode}" & output)
  return output

func size*[T: seq](list: T): uint64 =
  uint64(list.len * sizeof(get(genericParams(typeof(list)), 0)))
