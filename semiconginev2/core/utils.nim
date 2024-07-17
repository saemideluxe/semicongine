type
  HorizontalAlignment* = enum
    Left
    Center
    Right
  VerticalAlignment* = enum
    Top
    Center
    Bottom

func CleanString*(str: openArray[char]): string =
  for i in 0 ..< len(str):
    if str[i] == char(0):
      result = join(str[0 ..< i])
      break

func ToCPointer*[T](list: openArray[T]): ptr T =
  if list.len > 0: addr(list[0]) else: nil

proc StaticExecChecked*(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(
      command = command,
      input = input)
  if exitcode != 0:
    raise newException(Exception, &"Running '{command}' produced exit code: {exitcode}" & output)
  return output

proc AppName*(): string =
  return string(Path(getAppFilename()).splitFile.name)

func Size*[T: seq](list: T): uint64 =
  uint64(list.len * sizeof(get(genericParams(typeof(list)), 0)))

template TimeAndLog*(body: untyped): untyped =
  let t0 = getMonoTime()
  body
  echo (getMonoTime() - t0).inNanoseconds.float / 1_000_000

template TimeAndLog*(name: string, body: untyped): untyped =
  let t0 = getMonoTime()
  body
  echo name, ": ", (getMonoTime() - t0).inNanoseconds.float / 1_000_000
