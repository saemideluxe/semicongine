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
  if list.len > 0:
    addr(list[0])
  else:
    nil

# required for some external libraries
proc nativeFree*(p: pointer) {.importc: "free".}

proc StaticExecChecked*(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(command = command, input = input)
  if exitcode != 0:
    raise newException(
      Exception, &"Running '{command}' produced exit code: {exitcode}" & output
    )
  return output

proc AppName*(): string =
  return string(Path(getAppFilename()).splitFile.name)

func Size*[T: seq](list: T): uint64 =
  uint64(list.len * sizeof(get(genericParams(typeof(list)), 0)))

const ENABLE_TIMELOG {.booldefine.}: bool = not defined(release)

template TimeAndLog*(body: untyped): untyped =
  when ENABLE_TIMELOG:
    {.cast(noSideEffect).}:
      let t0 = getMonoTime()
      body
    {.cast(noSideEffect).}:
      debugecho (getMonoTime() - t0).inNanoseconds.float / 1_000_000
  else:
    body

template TimeAndLog*(name: string, body: untyped): untyped =
  when ENABLE_TIMELOG:
    {.cast(noSideEffect).}:
      let t0 = getMonoTime()
      body
    {.cast(noSideEffect).}:
      debugecho name, ": ", (getMonoTime() - t0).inNanoseconds.float / 1_000_000, "ms"
  else:
    body

# allow enforcing use of iterators with lent
iterator litems*[IX, T](a: array[IX, T]): lent T {.inline.} =
  ## Iterates over each item of `a`.
  when a.len > 0:
    var i = low(IX)
    while true:
      yield a[i]
      if i >= high(IX):
        break
      inc(i)

# usefull to calculate next position for correct memory alignment
func alignedTo*[T: SomeInteger](value: T, alignment: T): T =
  let remainder = value mod alignment
  if remainder == 0:
    return value
  else:
    return value + alignment - remainder

template debugAssert*(expr: untyped, msg = ""): untyped =
  when not defined(release):
    assert expr, msg

