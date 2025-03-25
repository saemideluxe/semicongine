import std/marshal
import std/os
import std/dirs
import std/paths
import std/strformat
import std/strutils
import std/tables
import std/times

import ./core

import ./thirdparty/db_connector/db_sqlite
import ./thirdparty/vsbf/vsbf

const STORAGE_NAME = Path("storage.db")
const DEFAULT_KEY_VALUE_TABLE_NAME = "shelf"

# ==============================================================
#
# API to store key/value pairs
#
# ==============================================================

proc path(storageType: StorageType): Path =
  case storageType
  of SystemStorage:
    Path(getAppDir()) / STORAGE_NAME
  of UserStorage:
    string(Path(getDataDir()) / Path(AppName())).createDir()
    Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc ensureExists(storageType: StorageType) =
  if storageType in engine().db:
    return
  engine().db[storageType] = open(string(storageType.path), "", "", "")

proc ensureExists(storageType: StorageType, table: string) =
  storageType.ensureExists()
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
  storageType.ensureExists(table)
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
  storageType.ensureExists(table)
  let dbResult = engine().db[storageType].getValue(
    sql(&"""SELECT value FROM {table} WHERE key = ? """), key
  )
  if dbResult == "":
    return default
  return to[T](dbResult)

proc list*[T](
    storageType: StorageType, table = DEFAULT_KEY_VALUE_TABLE_NAME
): seq[string] =
  storageType.ensureExists(table)
  for row in engine().db[storageType].fastRows(sql(&"""SELECT key FROM {table}""")):
    result.add row[0]

proc purge*(storageType: StorageType) =
  storageType.path().string.removeFile()

# ==============================================================
#
# API to store "worlds", which is one database per "world"
#
# ==============================================================

const DEFAULT_WORLD_TABLE_NAME = "world"
const WORLD_DIR = "worlds"

proc path(worldName: string): Path =
  let dir = Path(getDataDir()) / Path(AppName()) / Path(WORLD_DIR)
  string(dir).createDir()
  dir / Path(worldName & ".db")

proc ensureExists(worldName: string): DbConn =
  open(string(worldName.path), "", "", "")

proc ensureExists(worldName: string, table: string): DbConn =
  result = worldName.ensureExists()
  result.exec(
    sql(
      &"""CREATE TABLE IF NOT EXISTS {table} (
    key INT NOT NULL UNIQUE,
    value BLOB NOT NULL
  )"""
    )
  )

proc storeWorld*[T: object | tuple](
    worldName: string, world: T, table = DEFAULT_WORLD_TABLE_NAME, deleteOld = false
) =
  let db = worldName.ensureExists(table)
  defer:
    db.close()
  let key = $(int(now().toTime().toUnixFloat() * 1000))

  var encoder = Encoder.init()
  encoder.serializeRoot(world)

  let s = db.prepare(&"""INSERT INTO {table} VALUES(?, ?)""")
  s.bindParam(1, key)
  s.bindParam(2, encoder.data)
  db.exec(s)
  s.finalize()
  db.exec(sql(&"""DELETE FROM {table} WHERE key <> ?"""), key)

proc loadWorld*[T: object | tuple](
    worldName: string, table = DEFAULT_WORLD_TABLE_NAME
): T =
  let db = worldName.ensureExists(table)
  defer:
    db.close()
  let dbResult =
    db.getValue(sql(&"""SELECT value FROM {table} ORDER BY key DESC LIMIT 1"""))

  var decoder = Decoder.init(cast[seq[byte]](dbResult))
  decoder.deserialize(T)

proc listWorlds*(): seq[string] =
  let dir = Path(getDataDir()) / Path(AppName()) / Path(WORLD_DIR)

  if dir.dirExists():
    for (kind, path) in walkDir(
      dir = string(dir), relative = true, checkDir = true, skipSpecial = true
    ):
      if kind in [pcFile, pcLinkToFile] and path.endsWith(".db"):
        result.add path[0 .. ^4]

proc purgeWorld*(worldName: string) =
  worldName.path().string.removeFile()
