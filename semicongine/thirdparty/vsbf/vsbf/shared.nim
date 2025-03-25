import std/options

const
  version* = "\1\0"
  header* = ['v', 's', 'b', 'f', version[0], version[1]]
  headerSize* = header.len

template skipSerialization*() {.pragma.}
template vsbfName*(s: string) {.pragma.}

type
  LebEncodedInt* = SomeInteger and not (int8 | uint8)

  SerialisationType* = enum
    Bool
    Int8
    Int16
    Int32
    Int64
    Float32 ## Floats do not use `Int` types to allow transitioning to and from floats
    Float64
    String ## Strings are stored in a 'String section'
    Array
    Struct
    EndStruct # Marks we've finished reading
    Option ## If the next byte is 0x1 you parse the internal otherwise you skip

  SeqOrArr*[T] = seq[T] or openarray[T]

  UnsafeView*[T] = object
    data*: ptr UncheckedArray[T]
    len*: int

  VsbfErrorKind* = enum
    None ## No error hit
    InsufficientData ## Not enough data in the buffer
    IncorrectData ## Expected something else in the buffer
    ExpectedField ## Expected a field but got something else
    TypeMismatch ## Expected a specific type but got another

  VsbfError* = object of ValueError
    kind*: VsbfErrorKind
    position*: int = -1

static:
  assert sizeof(SerialisationType) == 1 # Types are always 1
  assert SerialisationType.high.ord <= 127

const
  VsbfTypes* = {Bool .. Option}
  LowerSeven = 0b0111_1111
  MSBit = 0b1000_0000u8

proc insufficientData*(msg: string, position: int = -1): ref VsbfError =
  (ref VsbfError)(kind: InsufficientData, msg: msg, position: position)

proc incorrectData*(msg: string, position: int = -1): ref VsbfError =
  (ref VsbfError)(kind: IncorrectData, msg: msg, position: position)

proc expectedField*(msg: string, position: int = -1): ref VsbfError =
  (ref VsbfError)(kind: ExpectedField, msg: msg, position: position)

proc typeMismatch*(msg: string, position: int = -1): ref VsbfError =
  (ref VsbfError)(kind: TypeMismatch, msg: msg, position: position)

proc encoded*(serType: SerialisationType, storeName: bool): byte =
  if storeName: # las bit reserved for 'hasName'
    0b1000_0000u8 or byte(serType)
  else:
    byte(serType)

{.warning[HoleEnumConv]: off.}
proc decodeType*(data: byte, pos: int): tuple[typ: SerialisationType, hasName: bool] =
  result.hasName = (MSBit and data) > 0 # Extract whether the lastbit is set
  let val = (data and LowerSeven)
  if val notin 0u8 .. SerialisationType.high.uint8:
    raise incorrectData("Cannot decode value " & $val & " into vsbf type tag", pos)

  result.typ = SerialisationType((data and LowerSeven))

{.warning[HoleEnumConv]: on.}

proc vsbfId*(_: typedesc[bool]): SerialisationType =
  Bool

proc vsbfId*(_: typedesc[int8 or uint8 or char]): SerialisationType =
  Int8

proc vsbfId*(_: typedesc[int16 or uint16]): SerialisationType =
  Int16

proc vsbfId*(_: typedesc[int32 or uint32]): SerialisationType =
  Int32

proc vsbfId*(_: typedesc[int64 or uint64]): SerialisationType =
  Int64

proc vsbfId*(_: typedesc[int or uint]): SerialisationType =
  Int64
  # Always 64 bits to ensure compatibillity

proc vsbfId*(_: typedesc[float32]): SerialisationType =
  Float32

proc vsbfId*(_: typedesc[float64]): SerialisationType =
  Float64

proc vsbfId*(_: typedesc[string]): SerialisationType =
  String

proc vsbfId*(_: typedesc[openArray]): SerialisationType =
  Array

proc vsbfId*(_: typedesc[object or tuple]): SerialisationType =
  Struct

proc vsbfId*(_: typedesc[ref]): SerialisationType =
  Option

proc vsbfId*(_: typedesc[enum]): SerialisationType =
  Int64

proc vsbfId*(_: typedesc[Option]): SerialisationType =
  Option

proc canConvertFrom*(typ: SerialisationType, val: auto, pos: int) =
  var expected = typeof(val).vsbfId()
  if typ != expected:
    raise typeMismatch("Expected: " & $expected & " but got " & $typ, pos)

proc toUnsafeView*[T](oa: openArray[T]): UnsafeView[T] =
  UnsafeView[T](data: cast[ptr UncheckedArray[T]](oa[0].addr), len: oa.len)

template toOa*[T](view: UnsafeView[T]): auto =
  view.data.toOpenArray(0, view.len - 1)

template toOpenArray*[T](view: UnsafeView[T], low, high: int): auto =
  view.data.toOpenArray(low, high)

template toOpenArray*[T](view: UnsafeView[T], low: int): auto =
  view.data.toOpenArray(low, view.len - 1)

template toOpenArray*[T](oa: openArray[T], low: int): auto =
  oa.toOpenArray(low, oa.len - 1)

proc write*(oa: var openArray[byte], toWrite: SomeInteger): int =
  if oa.len > sizeof(toWrite):
    result = sizeof(toWrite)
    for offset in 0 ..< sizeof(toWrite):
      oa[offset] = byte(toWrite shr (offset * 8) and 0xff)

proc write*(sq: var seq[byte], toWrite: SomeInteger): int =
  result = sizeof(toWrite)
  for offset in 0 ..< sizeof(toWrite):
    sq.add byte((toWrite shr (offset * 8)) and 0xff)

template doWhile(cond: bool, body: untyped) =
  body
  while cond:
    body

proc writeLeb128*(buffer: var openArray[byte], i: SomeUnsignedInt): int =
  var val = uint64(i)
  doWhile(val != 0):
    var data = byte(val and LowerSeven)
    val = val shr 7
    if val != 0:
      data = MSBit or data
    buffer[result] = data
    inc result
    if result > buffer.len:
      raise insufficientData("Not enough space to encode an unsigned leb128 integer.")

proc writeLeb128*[T: SomeSignedInt](buffer: var openArray[byte], i: T): int =
  var
    val = i
    more = true

  while more:
    var data = byte(val and T(LowerSeven))
    val = val shr 7

    let isSignSet = (0x40 and data) == 0x40
    if (val == 0 and not isSignSet) or (val == -1 and isSignSet):
      more = false
    else:
      data = MSBit or data

    buffer[result] = data

    inc result
    if result > buffer.len and more:
      raise insufficientData("Not enough space to encode a signed leb128 integer")

proc readLeb128*[T: SomeUnsignedInt](data: openArray[byte], val: var T): int =
  var shift = T(0)

  while true:
    if result > data.len:
      raise incorrectData("Attempting to read a too large integer")
    let theByte = data[result]
    val = val or (T(theByte and LowerSeven) shl shift)
    inc result

    if (MSBit and theByte) != MSBit:
      break
    shift += 7

proc readLeb128*[T: SomeSignedInt](data: openArray[byte], val: var T): int =
  var
    shift = T(0)
    theByte = 0u8

  while (MSBit and theByte) == MSBit or result == 0:
    if result > data.len:
      raise incorrectData("Attempting to read a too large integer")

    theByte = data[result]
    val = val or (T(theByte and LowerSeven) shl shift)
    shift += 7
    inc result

  if (shift < T(sizeof(T) * 8)) and (theByte and 0x40) == 0x40:
    val = val or (not (T(0)) shl shift)

proc leb128*(i: SomeInteger): (array[16, byte], int) =
  var data = default array[16, byte]
  let len = data.writeLeb128(i)
  (data, len)
