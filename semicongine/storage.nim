import std/marshal
import std/strformat
import std/paths
import std/os

import db_connector/db_sqlite

import ./core

const STORAGE_NAME = Path("storage.db")
const KEY_VALUE_TABLE_NAME = "shelf"
const KILL_SIGNAL_KEY = "__semicongine__kill_worker"

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
    keyChannel: Channel[(StorageOperation, string)] # false is read, true is write
    dataChannel: Channel[T]
    thread: Thread[(ptr Channel[string], ptr Channel[T])]

proc path(storageType: StorageType): Path =
  case storageType:
    of SystemStorage:
      Path(getAppDir()) / STORAGE_NAME
    of UserStorage:
      Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc openDb(storageType: StorageType): DbConn =
  result = open(string(storageType.path), "", "", "")
  result.exec(sql(&"""CREATE TABLE IF NOT EXISTS {KEY_VALUE_TABLE_NAME} (
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
  )"""))

proc store[T](db: DbConn, key: string, value: T) =
  db.exec(sql(f"""INSERT INTO {KEY_VALUE_TABLE_NAME} VALUES(?, ?)
  ON CONFLICT(key) DO UPDATE SET value=excluded.value
  """), key, $$value)

proc load[T](db: DbConn, key: string, default = default(T)): T =
  let dbResult = db.getValue(sql(f"""SELECT value FROM {KEY_VALUE_TABLE_NAME} WHERE key = ? """), key)
  if dbResult == "":
    return default
  return to[T](dbResult)

proc storageWorker[T](params: tuple[storageType: StorageType, keyChannel: ptr Channel[(StorageOperation, string)], dataChannel: ptr Channel[T]]) =
  var db = params.storageType.openDb()
  defer: db.close()
  var key: (string, bool)
  while key[0] != KILL_SIGNAL_KEY:
    key = params.keyChannel[].recv()
    case key:
      of Read: params.dataChannel[].send(db.load(key))
      of Write: db.store(key, params.dataChannel[].recv())
      of KillWorker: break

proc openStorage*[T](storageType: StorageType): Storage[T] =
  result.keyChannel = cast[ptr Channel[(string, bool)]](allocShared0(sizeof(Channel[(string, bool)])))
  result.keyChannel[].open()
  result.dataChannel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.dataChannel[].open()
  createThread(result.thread, storageWorker, (storageType, result.keyChannel, result.dataChannel))

proc get[T](storage: Storage[T], key: string): Channel[T] =
  storage.keyChannel.send((Read, key))
  return storage.dataChannel[]

proc set[T](storage: Storage[T], key: string, value: T) =
  storage.keyChannel.send((Write, key))
  storage.dataChannel.send(value)

proc closeStorage*[T](storage: var Storage[T]) =
  storage.keyChannel[].send((KillWorker, ""))
  storage.thread.joinThread()

  storage.keyChannel[].close()
  storage.deallocShared(storage.keyChannel)

  storage.dataChannel[].close()
  storage.deallocShared(storage.dataChannel)
