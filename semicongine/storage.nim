import std/marshal
import std/strformat
import std/paths
import std/os

import db_connector/db_sqlite

import ./core

const STORAGE_NAME = Path("storage.db")

type
  StorageType* = enum
    SystemStorage
    UserStorage
    # ? level storage type ?
  StorageOperation = enum
    Read
    Write
    KillWorker
  Storage*[T] = object
    storageType: StorageType
    keyChannel: ptr Channel[(StorageOperation, string)] # false is read, true is write
    dataChannel: ptr Channel[T]
    thread: Thread[tuple[storageType: StorageType, keyChannel: ptr Channel[(StorageOperation, string)], dataChannel: ptr Channel[T]]]

proc path(storageType: StorageType): Path =
  case storageType:
    of SystemStorage:
      Path(getAppDir()) / STORAGE_NAME
    of UserStorage:
      Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc openDb(storageType: StorageType): DbConn =
  const KEY_VALUE_TABLE_NAME = "shelf"
  result = open(string(storageType.path), "", "", "")
  result.exec(sql(&"""CREATE TABLE IF NOT EXISTS {KEY_VALUE_TABLE_NAME} (
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  )"""))

proc store[T](db: DbConn, key: string, value: T) =
  const KEY_VALUE_TABLE_NAME = "shelf"
  db.exec(sql(&"""INSERT INTO {KEY_VALUE_TABLE_NAME} VALUES(?, ?)
  ON CONFLICT(key) DO UPDATE SET value=excluded.value
  """), key, $$value)

proc load[T](db: DbConn, key: string, default = default(T)): T =
  const KEY_VALUE_TABLE_NAME = "shelf"
  let dbResult = db.getValue(sql(&"""SELECT value FROM {KEY_VALUE_TABLE_NAME} WHERE key = ? """), key)
  if dbResult == "":
    return default
  return to[T](dbResult)

proc storageWorker[T](params: tuple[storageType: StorageType, keyChannel: ptr Channel[(StorageOperation, string)], dataChannel: ptr Channel[T]]) =
  var db = params.storageType.openDb()
  defer: db.close()
  var key: (StorageOperation, string)
  while true:
    key = params.keyChannel[].recv()
    case key[0]:
      of Read: params.dataChannel[].send(load[T](db, key[1]))
      of Write: store(db, key[1], params.dataChannel[].recv())
      of KillWorker: break

proc openStorage*[T](storageType: StorageType): Storage[T] =
  result.keyChannel = cast[ptr Channel[(StorageOperation, string)]](allocShared0(sizeof(Channel[(StorageOperation, string)])))
  result.keyChannel[].open()
  result.dataChannel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.dataChannel[].open()
  createThread(result.thread, storageWorker[T], (storageType, result.keyChannel, result.dataChannel))

proc get*[T](storage: Storage[T], key: string): Channel[T] =
  storage.keyChannel.send((Read, key))
  return storage.dataChannel[]

proc set*[T](storage: Storage[T], key: string, value: T) =
  storage.keyChannel.send((Write, key))
  storage.dataChannel.send(value)

proc purge*[T](storage: var Storage[T]) =
  storage.closeStorage()
  storage.path().string.removeFile()


proc closeStorage*[T](storage: var Storage[T]) =
  storage.keyChannel[].send((KillWorker, ""))
  storage.thread.joinThread()

  storage.keyChannel[].close()
  deallocShared(storage.keyChannel)

  storage.dataChannel[].close()
  deallocShared(storage.dataChannel)
