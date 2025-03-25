import std/[options, typetraits, tables, macros, strformat]
import shared

type Decoder*[DataType: SeqOrArr[byte]] = object
  strs*: seq[string] ## List of strings that are indexed by string indexes
  when DataType is seq[byte]:
    stream*: seq[byte]
  else:
    stream*: UnsafeView[byte]
  pos*: int

template debug(args: varargs[typed, `$`]): untyped =
  when defined(vsbfDebug):
    unpackVarargs(echo, args)

proc len(dec: Decoder): int =
  dec.stream.len

proc atEnd*(dec: Decoder): bool =
  dec.pos >= dec.len

template data*[T](decoder: Decoder[T]): untyped =
  if decoder.pos >= decoder.stream.len:
    raise insufficientData("More data expect, but hit end of stream.", decoder.pos)

  decoder.stream.toOpenArray(decoder.pos, decoder.stream.len - 1)

proc read*[T: SomeInteger](oa: openArray[byte], res: var T): bool =
  if sizeof(T) <= oa.len:
    res = T(0)
    for i in T(0) ..< sizeof(T):
      res = res or (T(oa[int i]) shl (i * 8))

    true
  else:
    false

proc read*(frm: openArray[byte], to: var openArray[byte | char]): int =
  if to.len > frm.len:
    -1
  else:
    for i in 0 .. to.high:
      to[i] = typeof(to[0])(frm[i])
    to.len

proc read*[T](dec: var Decoder[T], data: typedesc): Option[data] =
  var val = default data
  if dec.data.read(val) > 0:
    some(val)
  else:
    none(data)

proc readString*(dec: var Decoder) =
  var strLen = 0
  dec.pos += dec.data.readLeb128(strLen)

  var buffer = newString(strLen)

  for i in 0 ..< strLen:
    buffer[i] = char dec.data[i]
  debug "Stored string ", buffer, " at index ", dec.strs.len
  dec.strs.add buffer
  dec.pos += strLen

proc typeNamePair*(
    dec: var Decoder
): tuple[typ: SerialisationType, nameInd: options.Option[int]] =
  ## reads the type and name's string index if it has it
  var encodedType = 0u8
  if not dec.data.read(encodedType):
    raise newException(VsbfError, fmt"Failed to read type info. Position: {dec.pos}")
  dec.pos += 1

  var hasName: bool
  (result.typ, hasName) = encodedType.decodeType(dec.pos - 1)

  if hasName:
    var ind = 0
    let indSize = dec.data.readLeb128(ind)
    dec.pos += indSize
    result.nameInd = some(ind)
    if indSize > 0:
      if ind notin 0 .. dec.strs.high:
        dec.readString()
    else:
      raise
        (ref VsbfError)(msg: fmt"No name following a declaration. Position {dec.pos}")

proc peekTypeNamePair*(dec: var Decoder): tuple[typ: SerialisationType, name: string] =
  ## peek the type and name's string index if it has it
  let encodedType = dec.data[0]
  var hasName: bool
  (result.typ, hasName) = encodedType.decodeType(dec.pos - 1)
  debug result.typ, " has name: ", hasName
  if hasName:
    var val = 0
    let indSize = dec.data.toOpenArray(1).readLeb128(val)
    debug "String of index: ", val, " found at ", dec.pos

    if indSize > 0:
      if val notin 0 .. dec.strs.high:
        debug "String not loaded, reading it"
        var strLen = 0
        let
          strLenBytes = dec.data.toOpenArray(1 + indSize).readLeb128(strLen)
          start = 1 + indSize + strLenBytes
        result.name = newString(strLen)

        if start >= dec.len or start + strLen - 1 > dec.len:
          raise insufficientData("Need more data for a field", dec.pos)

        for i, x in dec.data.toOpenArray(start, start + strLen - 1):
          result.name[i] = char x
      else:
        result.name = dec.strs[val]
    else:
      raise incorrectData("No name following a declaration.", dec.pos)

proc getStr*(dec: Decoder, ind: int): lent string =
  dec.strs[ind]

proc readHeader(dec: var Decoder) =
  var ext = dec.read(array[4, char])
  if ext.isNone or ext.unsafeGet != "vsbf":
    raise incorrectData("Not a VSBF stream, missing the header", 0)
  dec.pos += 4

  let ver = dec.read(array[2, byte])

  if ver.isNone:
    raise incorrectData("Cannot read, missing version", 4)

  dec.pos += 2

proc init*(_: typedesc[Decoder], data: sink seq[byte]): Decoder[seq[byte]] =
  ## Heap allocated version, it manages it's own buffer you give it and reads from this.
  ## Can recover the buffer using `close` after parsin
  result = Decoder[seq[byte]](stream: data)
  result.readHeader()
  # We now should be sitting right on the root entry's typeId

proc close*(decoder: sink Decoder[seq[byte]]): seq[byte] =
  ensureMove(decoder.stream)

proc init*(_: typedesc[Decoder], data: openArray[byte]): Decoder[openArray[byte]] =
  ## Non heap allocating version of the decoder uses preallocated memory that must outlive the structure
  result = Decoder[openArray[byte]](stream: toUnsafeView data)
  result.readHeader()

proc deserialize*(dec: var Decoder, i: var LebEncodedInt) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, i, dec.pos)
  dec.pos += dec.data.readLeb128(i)

proc deserialize*(dec: var Decoder, f: var SomeFloat) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, f, dec.pos)
  var val = when f is float32: 0i32 else: 0i64
  if dec.data.read(val):
    dec.pos += sizeof(val)
    f = cast[typeof(f)](val)
  else:
    raise incorrectData("Could not read a float", dec.pos)

proc deserialize*(dec: var Decoder, str: var string) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, str, dec.pos)
  var ind = 0
  dec.pos += dec.data.readLeb128(ind)

  if ind notin 0 .. dec.strs.high:
    # It has not been read into yet
    dec.readString()

  str = dec.getStr(ind)

proc deserialize*[Idx, T](dec: var Decoder, arr: var array[Idx, T]) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, arr, dec.pos)
  var len = 0
  dec.pos += dec.data.readLeb128(len)
  if len > arr.len:
    raise incorrectData(
      "Expected an array with a length less than or equal to '" & $arr.len &
        "', but got length of '" & $len & "'.",
      dec.pos,
    )
  for i in 0 ..< len:
    dec.deserialize(arr[Idx(Idx.low.ord + i)])

proc deserialize*[T](dec: var Decoder, arr: var seq[T]) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, arr, dec.pos)
  var len = 0
  dec.pos += dec.data.readLeb128(len)
  arr = newSeq[T](len)
  for i in 0 ..< len:
    dec.deserialize(arr[i])

proc skipToEndOfStructImpl(dec: var Decoder) =
  var (typ, ind) = dec.typeNamePair()

  if ind.isSome:
    debug "Skipping over field ", dec.strs[ind.get], " with type of ", typ

  case typ
  of Bool:
    inc dec.pos
  of Int8 .. Int64:
    var i = 0
    dec.pos += dec.data.readLeb128(i)
  of Float32:
    dec.pos += sizeof(float32)
  of Float64:
    dec.pos += sizeof(float64)
  of String:
    dec.readString()
  of Array:
    var len = 0
    dec.pos += dec.data.readLeb128(len)
    debug "Skipping array of size ", len
    for i in 0 ..< len:
      dec.skipToEndOfStructImpl()
  of Struct:
    while not (dec.atEnd) and (var (typ, _) = dec.peekTypeNamePair(); typ) != EndStruct:
      dec.skipToEndOfStructImpl()
  of EndStruct:
    discard
  of Option:
    let isOpt = dec.data[0].bool
    inc dec.pos
    if isOpt:
      dec.skipToEndOfStructImpl()

proc skipToEndOfStruct(dec: var Decoder) =
  dec.skipToEndOfStructImpl()

  if (let (typ, _) = dec.peekTypeNamePair(); typ != EndStruct):
    raise incorrectData("Cannot continue skipping over field.", dec.pos)

proc deserialize*[T: object | tuple](dec: var Decoder, obj: var T) =
  mixin deserialize
  var (typ, nameInd) = dec.typeNamePair()
  if nameInd.isSome:
    debug "Deserialising struct: ", dec.strs[nameInd.get]
  canConvertFrom(typ, obj, dec.pos)

  when compiles(obj = default(T)):
    obj = default(T)

  while not (dec.atEnd) and (var (typ, name) = dec.peekTypeNamePair(); typ) != EndStruct:
    if name == "":
      raise incorrectData("Expected field name.", dec.pos)

    debug "Deserializing field: ", name

    var found = false
    for fieldName, field in obj.fieldPairs:
      const realName {.used.} =
        when field.hasCustomPragma(vsbfName):
          field.getCustomPragmaVal(vsbfName)
        else:
          fieldName

      when not field.hasCustomPragma(skipSerialization):
        if realName == name:
          found = true
          debug "Deserializing ", astToStr(field), " for ", T
          {.cast(uncheckedAssign).}:
            when compiles(reset field):
              reset field
            dec.deserialize(field)
          break

    if not found:
      dec.skipToEndOfStruct()

  debug "End of struct ", T
  if (let (typ, _) = dec.typeNamePair(); typ) != EndStruct:
    # Pops the end and ensures it's correct'
    raise incorrectData("Invalid struct expected EndStruct.", dec.pos)

proc deserialize*(dec: var Decoder, data: var (distinct)) =
  dec.deserialize(distinctBase(data))

proc deserialize*[T](dec: var Decoder, data: var set[T]) =
  const setSize = sizeof(data)
  when setSize == 1:
    dec.deserialize(cast[ptr uint8](data.addr)[])
  elif setSize == 2:
    dec.deserialize(cast[ptr uint16](data.addr)[])
  elif setSize == 4:
    dec.deserialize(cast[ptr uint32](data.addr)[])
  elif setSize == 8:
    dec.deserialize(cast[ptr uint64](data.addr)[])
  else:
    dec.deserialize(cast[ptr array[setSize, byte]](data.addr)[])

proc deserialize*[T: bool | char | int8 | uint8 and not range](
    dec: var Decoder, data: var T
) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, data, dec.pos)
  data = cast[T](dec.data[0])
  inc dec.pos

proc deserialize*[T: enum](dec: var Decoder, data: var T) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, data, dec.pos)

  var base = 0i64
  let pos = dec.pos
  dec.pos += dec.data.readLeb128(base)
  if base notin T.low.ord .. T.high.ord:
    raise typeMismatch(fmt"Cannot convert '{base}' to '{$T}'.", pos)

  data = T(base)

proc deserialize*[T: range](dec: var Decoder, data: var T) =
  var base = default T.rangeBase()
  let pos = dec.pos
  dec.deserialize(base)
  if base notin T.low .. T.high:
    raise typeMismatch(
      fmt"Cannot convert to range got '{base}', but expected value in '{$T}'.", pos
    )

  data = T(base)

proc deserialize*[T](dec: var Decoder, data: var Option[T]) =
  let (typ, nameInd) = dec.typeNamePair()
  canConvertFrom(typ, data, dec.pos)
  let isOpt = dec.data[0].bool
  dec.pos += 1
  if isOpt:
    var val = default(T)
    dec.deserialize(val)
    data = some(val)
  else:
    data = none(T)

proc deserialize*(dec: var Decoder, data: var ref) =
  let (typ, _) = dec.typeNamePair()
  canConvertFrom(typ, data, dec.pos)
  let isRef = dec.data[0].bool
  dec.pos += 1
  if isRef:
    new data
    dec.deserialize(data[])

proc deserialize*(dec: var Decoder, T: typedesc): T =
  dec.deserialize(result)
