import std/marshal
import std/os
import std/paths
import std/strformat
import std/tables

import ./core

import ./thirdparty/db_connector/db_sqlite

const STORAGE_NAME = Path("storage.db")
const DEFAULT_KEY_VALUE_TABLE_NAME = "shelf"

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
