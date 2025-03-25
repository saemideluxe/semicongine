import std/[options, typetraits, tables, macros]
import shared

type
  Encoder*[DataType: SeqOrArr[byte]] = object
    strs: Table[string, int]
    when DataType is seq[byte]:
      dataBuffer*: seq[byte]
    else:
      dataBuffer*: UnsafeView[byte]
      dataPos*: int

template offsetDataBuffer*(encoder: Encoder[openArray[byte]]): untyped =
  encoder.dataBuffer.toOpenArray(encoder.dataPos)

template data*[T](encoder: Encoder[T]): untyped =
  when T is seq:
    encoder.databuffer.toOpenArray(0, encoder.dataBuffer.high)
  else:
    encoder.dataBuffer.toOpenArray(0, encoder.dataPos - 1)

proc writeTo*[T](encoder: var Encoder[T], toWrite: SomeInteger) =
  when T is seq:
    discard encoder.dataBuffer.write(toWrite)
  else:
    encoder.dataPos += encoder.offsetDataBuffer().write toWrite

proc writeTo*[T](encoder: var Encoder[T], toWrite: openArray[byte]) =
  when T is seq:
    encoder.dataBuffer.add toWrite
  else:
    for i, x in toWrite:
      encoder.offsetDataBuffer()[i] = x
    encoder.dataPos += toWrite.len

proc close*(encoder: sink Encoder): seq[byte] = ensureMove encoder.databuffer

proc init*(
    _: typedesc[Encoder], dataBuffer: openArray[byte]
): Encoder[openArray[byte]] =
  Encoder[openArray[byte]](
    dataBuffer: dataBuffer.toUnsafeView(),
  )

proc init*(_: typedesc[Encoder]): Encoder[seq[byte]] =
  result =
    Encoder[seq[byte]](
      dataBuffer: newSeqOfCap[byte](256),
    )
  result.dataBuffer.add cast[array[headerSize, byte]](header)


proc cacheStr*(encoder: var Encoder, str: sink string) =
  ## Writes the string to the buffer
  ## If the string has not been seen yet it'll print Index Len StringData to cache it
  withValue encoder.strs, str, val:
    let (data, len) = leb128 val[]
    encoder.writeTo data.toOpenArray(0, len - 1)
  do:
    var (data, len) = leb128 encoder.strs.len
    encoder.writeTo(data.toOpenArray(0, len - 1))
    (data, len) = leb128 str.len
    encoder.writeTo(data.toOpenArray(0, len - 1))
    encoder.writeTo(str.toOpenArrayByte(0, str.high))
    encoder.strs[str] = encoder.strs.len

proc serializeTypeInfo[T](encoder: var Encoder, val: T, name: sink string) =
  ## Stores the typeID and name if it's required(0b1xxx_xxxx if there is a name)
  encoder.writeTo T.vsbfId.encoded(name.len > 0)
  if name.len > 0:
    encoder.cacheStr(name)

proc serialize*(encoder: var Encoder, i: LebEncodedInt, name: string) =
  serializeTypeInfo(encoder, i, name)
  let (data, len) = leb128 i
  encoder.writeTo data.toOpenArray(0, len - 1)

proc serialize*(encoder: var Encoder, val: bool | char | uint8 | int8, name: string) =
  serializeTypeInfo(encoder, val, name)
  encoder.writeTo cast[byte](val)

proc serialize*(encoder: var Encoder, i: enum, name: string) =
 encoder.serialize(int64(i), name)

proc serialize*(encoder: var Encoder, f: SomeFloat, name: string) =
  serializeTypeInfo(encoder, f, name)
  when f is float32:
    encoder.writeTo cast[int32](f)
  else:
    encoder.writeTo cast[int64](f)

proc serialize*(encoder: var Encoder, str: string, name: string) =
  serializeTypeInfo(encoder, str, name)
  encoder.cacheStr(str)

proc serialize*[T](encoder: var Encoder, arr: openArray[T], name: string) =
  serializeTypeInfo(encoder, arr, name)
  let (data, len) = leb128 arr.len
  encoder.writeTo data.toOpenArray(0, len - 1)
  for val in arr.items:
    encoder.serialize(val, "")

proc serialize*[T: object | tuple](encoder: var Encoder, obj: T, name: string) =
  mixin serialize
  serializeTypeInfo(encoder, obj, name)
  for fieldName, field in obj.fieldPairs:
    const realName {.used.} =
      when field.hasCustomPragma(vsbfName):
        field.getCustomPragmaVal(vsbfName)
      else:
        fieldName
    when not field.hasCustomPragma(skipSerialization):
      encoder.serialize(field, realName)

  encoder.writeTo EndStruct.encoded(false)


proc serialize*(encoder: var Encoder, data: ref, name: string) =
  serializeTypeInfo(encoder, data, name)
  encoder.writeTo byte(data != nil)
  if data != nil:
    encoder.serialize(data[], "")

proc serialize*[T: Option](encoder: var Encoder, data: T, name: string) =
  serializeTypeInfo(encoder, data, name)
  encoder.writeTo byte(data.isSome)
  if data.isSome:
    encoder.serialize(data.unsafeGet, "")

proc serialize*(encoder: var Encoder, data: distinct, name: string) =
  encoder.serialize(distinctBase(data), name)

proc serialize*[T: range](encoder: var Encoder, data: T, name: string) =
  encoder.serialize((T.rangeBase) data, name)

proc serialize*[T](encoder: var Encoder, data: set[T], name: string) =
  const setSize = sizeof(data)
  when setSize == 1:
    encoder.serialize(cast[uint8](data), name)
  elif setSize == 2:
    encoder.serialize(cast[uint16](data), name)
  elif setSize == 4:
    encoder.serialize(cast[uint32](data), name)
  elif setSize == 8:
    encoder.serialize(cast[uint64](data), name)
  else:
    encoder.serialize(cast[array[setSize, byte]](data), name)

proc serializeRoot*(encoder: var Encoder, val: object or tuple) =
  encoder.serialize(val, "")
