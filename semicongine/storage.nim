import std/marshal
import std/logging
import std/algorithm
import std/os
import std/dirs
import std/paths
import std/streams
import std/strformat
import std/strutils
import std/tables
import std/times
import std/typetraits

import ./core

import ./thirdparty/db_connector/db_sqlite

const STORAGE_NAME = Path("storage.db")
const DEFAULT_KEY_VALUE_TABLE_NAME = "shelf"

# ==============================================================
#
# API to store key/value pairs
#
# ==============================================================

proc getPath(storageType: StorageType): Path =
  case storageType
  of SystemStorage:
    Path(getAppDir()) / STORAGE_NAME
  of UserStorage:
    (Path(getDataDir()) / Path(AppName())).createDir()
    Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc ensureStorageExists(storageType: StorageType) =
  if storageType in engine().db:
    return
  engine().db[storageType] = open(string(storageType.getPath), "", "", "")

proc ensureStorageExists(storageType: StorageType, table: string) =
  storageType.ensureStorageExists()
  engine().db[storageType].exec(
    sql(
      &"""CREATE TABLE IF NOT EXISTS {table} (
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  )"""
    )
  )

proc store*[T](
    storageType: StorageType,
    key: string,
    value: T,
    table = DEFAULT_KEY_VALUE_TABLE_NAME,
) =
  storageType.ensureStorageExists(table)
  engine().db[storageType].exec(
    sql(
      &"""INSERT INTO {table} VALUES(?, ?)
  ON CONFLICT(key) DO UPDATE SET value=excluded.value
  """
    ),
    key,
    $$value,
  )

proc load*[T](
    storageType: StorageType,
    key: string,
    default: T,
    table = DEFAULT_KEY_VALUE_TABLE_NAME,
): T =
  storageType.ensureStorageExists(table)
  let dbResult = engine().db[storageType].getValue(
    sql(&"""SELECT value FROM {table} WHERE key = ? """), key
  )
  if dbResult == "":
    return default
  return to[T](dbResult)

proc list*[T](
    storageType: StorageType, table = DEFAULT_KEY_VALUE_TABLE_NAME
): seq[string] =
  storageType.ensureStorageExists(table)
  for row in engine().db[storageType].fastRows(sql(&"""SELECT key FROM {table}""")):
    result.add row[0]

proc purge*(storageType: StorageType) =
  storageType.getPath().string.removeFile()

# ==============================================================
#
# API to store "worlds", which is one database per "world"
#
# ==============================================================

const DEFAULT_WORLD_TABLE_NAME = "world"
const WORLD_DIR = "worlds"
let worldDir = Path(getDataDir()) / Path(AppName()) / Path(WORLD_DIR)
worldDir.createDir()

proc getPath(worldName: string): Path =
  worldDir / Path(worldName & ".db")

proc openWorldFile(worldName: string, table: string): DbConn =
  result = open(string(worldName.getPath), "", "", "")
  result.exec(
    sql(
      &"""CREATE TABLE IF NOT EXISTS {table} (
    key INT NOT NULL UNIQUE,
    value BLOB NOT NULL
  )"""
    )
  )

proc writeValue[T](s: Stream, value: T)

proc writeTimeValue[T](s: Stream, value: T) =
  s.write(value.toTime().toUnixFloat().float64)

proc writeNumericValue[T](s: Stream, value: T) =
  s.write(value)

proc writeStringValue(s: Stream, value: string) =
  s.write(value.len.int32)
  s.write(value)

proc writeSeqValue[T](s: Stream, value: T) =
  s.write(value.len.int32)
  for i in 0 ..< value.len:
    writeValue(s, value[i])

proc writeArrayValue[T](s: Stream, value: T) =
  for i in 0 ..< value.len:
    writeValue(s, value[genericParams(distinctBase(T)).get(0)(i)])

proc writeObjectValue[T](s: Stream, data: T) =
  for field, value in data.fieldPairs():
    writeValue(s, value)

proc writeValue[T](s: Stream, value: T) =
  when distinctBase(T) is DateTime:
    writeTimeValue[T](s, value)
  elif distinctBase(T) is SomeOrdinal or T is SomeFloat:
    writeNumericValue[T](s, value)
  elif distinctBase(T) is seq:
    writeSeqValue[T](s, value)
  elif distinctBase(T) is array:
    writeArrayValue[T](s, value)
  elif distinctBase(T) is string:
    writeStringValue(s, value)
  elif distinctBase(T) is object or T is tuple:
    writeObjectValue[T](s, value)
  else:
    {.error: "Cannot load type " & $T.}

proc storeWorld*[T](
    worldName: string, data: T, table = DEFAULT_WORLD_TABLE_NAME, deleteOld = false
) =
  var s = newStringStream()
  writeValue(s, data)
  let data = newSeq[byte](s.getPosition())
  s.setPosition(0)
  discard s.readData(addr(data[0]), data.len)

  let db = worldName.openWorldFile(table)
  defer:
    db.close()
  let key = int(now().utc.toTime.toUnixFloat * 1000)
  let stm = db.prepare(&"""INSERT INTO {table} VALUES(?, ?)""")
  stm.bindParam(1, key)
  stm.bindParam(2, data)
  db.exec(stm)
  stm.finalize()
  if deleteOld:
    db.exec(sql(&"""DELETE FROM {table} WHERE key <> ?"""), key)

proc loadValue[T](s: Stream, value: var T)

proc loadTimeValue[T](s: Stream, value: var T) =
  var t: float64
  read(s, t)
  value = fromUnixFloat(t).utc()

proc loadNumericValue[T](s: Stream, value: var T) =
  read(s, value)

proc loadSeqValue[T](s: Stream, value: var T) =
  let ll = s.readInt32()
  value.setLen(ll)
  for i in 0 ..< value.len:
    loadValue[elementType(value)](s, value[i])

proc loadArrayValue[T](s: Stream, value: var T) =
  for i in 0 .. high(distinctBase(T)):
    loadValue[elementType(value)](s, value[genericParams(distinctBase(T)).get(0)(i)])

proc loadStringValue(s: Stream, value: var string) =
  let len = s.readInt32()
  value = readStr(s, len)

proc loadObjectValue[T](s: Stream, value: var T) =
  for field, v in value.fieldPairs():
    debug "Load field " & field & " of object " & $T
    {.cast(uncheckedAssign).}:
      loadValue[typeof(v)](s, v)

proc loadValue[T](s: Stream, value: var T) =
  when distinctBase(T) is DateTime:
    loadTimeValue[T](s, value)
  elif distinctBase(T) is SomeOrdinal or distinctBase(T) is SomeFloat:
    loadNumericValue[T](s, value)
  elif distinctBase(T) is seq:
    loadSeqValue[T](s, value)
  elif distinctBase(T) is array:
    loadArrayValue[T](s, value)
  elif distinctBase(T) is string:
    loadStringValue(s, value)
  elif distinctBase(T) is object or distinctBase(T) is tuple:
    loadObjectValue[T](s, value)
  else:
    {.error: "Cannot load type " & $T.}

proc loadWorld*[T](worldName: string, world: var T, table = DEFAULT_WORLD_TABLE_NAME) =
  let db = worldName.openWorldFile(table)
  defer:
    db.close()
  let dbResult =
    db.getValue(sql(&"""SELECT value FROM {table} ORDER BY key DESC LIMIT 1"""))

  var s = newStringStream(dbResult)
  loadValue[T](s, world)

proc listWorlds*(): seq[(DateTime, string)] =
  let dir = Path(getDataDir()) / Path(AppName()) / Path(WORLD_DIR)

  if dir.dirExists():
    for (kind, path) in walkDir(
      dir = string(dir), relative = true, checkDir = true, skipSpecial = true
    ):
      if kind in [pcFile, pcLinkToFile] and path.endsWith(".db"):
        try:
          let db = path[0 .. ^4].openWorldFile(DEFAULT_WORLD_TABLE_NAME)
          defer:
            db.close()
          let dbResult = db.getValue(
            sql(
              &"""SELECT key FROM {DEFAULT_WORLD_TABLE_NAME} ORDER BY key DESC LIMIT 1"""
            )
          )
          result.add (
            (parseInt(dbResult) / 1000).fromUnixFloat().local(), path[0 .. ^4]
          )
        except CatchableError:
          discard

  result.sort(Descending)

proc purgeWorld*(worldName: string) =
  worldName.getPath().string.removeFile()
