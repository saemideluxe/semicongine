import std/marshal
import std/tables
import std/strformat
import std/paths
import std/os

import db_connector/db_sqlite

import ./core

const STORAGE_NAME = Path("storage.db")
const KEY_VALUE_TABLE_NAME = "shelf"

type
  StorageType* = enum
    SystemStorage
    UserStorage
    # ? level storage type ?

var db: Table[StorageType, DbConn]

proc path(storageType: StorageType): Path =
  case storageType:
    of SystemStorage:
      Path(getAppDir()) / STORAGE_NAME
    of UserStorage:
      string(Path(getDataDir()) / Path(AppName())).createDir()
      Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc setup(storageType: StorageType) =
  if storageType in db:
    return
  db[storageType] = open(string(storageType.path), "", "", "")
  db[storageType].exec(sql(&"""CREATE TABLE IF NOT EXISTS {KEY_VALUE_TABLE_NAME} (
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  )"""))

proc store*[T](storageType: StorageType, key: string, value: T) =
  storageType.setup()
  const KEY_VALUE_TABLE_NAME = "shelf"
  db[storageType].exec(sql(&"""INSERT INTO {KEY_VALUE_TABLE_NAME} VALUES(?, ?)
  ON CONFLICT(key) DO UPDATE SET value=excluded.value
  """), key, $$value)

proc load*[T](storageType: StorageType, key: string, default: T): T =
  storageType.setup()
  const KEY_VALUE_TABLE_NAME = "shelf"
  let dbResult = db[storageType].getValue(sql(&"""SELECT value FROM {KEY_VALUE_TABLE_NAME} WHERE key = ? """), key)
  if dbResult == "":
    return default
  return to[T](dbResult)

proc purge*(storageType: StorageType) =
  storageType.path().string.removeFile()
