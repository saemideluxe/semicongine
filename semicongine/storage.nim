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
      string(Path(getDataDir()) / Path(AppName())).createDir()
      Path(getDataDir()) / Path(AppName()) / STORAGE_NAME

proc openDb(storageType: StorageType): DbConn =
  const KEY_VALUE_TABLE_NAME = "shelf"
  result = open(string(storageType.path), "", "", "")
  result.exec(sql(&"""CREATE TABLE IF NOT EXISTS {KEY_VALUE_TABLE_NAME} (
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  )"""))

proc storeInDb[T](db: DbConn, key: string, value: T) =
  const KEY_VALUE_TABLE_NAME = "shelf"
  db.exec(sql(&"""INSERT INTO {KEY_VALUE_TABLE_NAME} VALUES(?, ?)
  ON CONFLICT(key) DO UPDATE SET value=excluded.value
  """), key, $$value)

proc loadFromDb[T](db: DbConn, key: string, default = default(T)): T =
  const KEY_VALUE_TABLE_NAME = "shelf"
  let dbResult = db.getValue(sql(&"""SELECT value FROM {KEY_VALUE_TABLE_NAME} WHERE key = ? """), key)
  if dbResult == "":
    return default
  return to[T](dbResult)

# mini async API
#
# LOADING ######################################3333
#
#
proc purge*(storageType: StorageType) =
  storageType.path().string.removeFile()

type
  LoadFuture*[T, U] = object
    thread: Thread[U]
    channel: ptr Channel[T]
    result: T

proc cleanup*[T, U](p: var LoadFuture[T, U]) =
  if p.channel != nil:
    p.thread.joinThread()
    p.channel[].close()
    deallocShared(p.channel)
    p.channel = nil

proc awaitResult*[T, U](p: var LoadFuture[T, U]): T =
  if p.channel == nil:
    return p.result
  result = p.channel[].recv()
  p.result = result
  p.cleanup()

proc hasResult*[T, U](p: var LoadFuture[T, U]): bool =
  let ret = p.channel[].tryRecv()
  result = ret.dataAvailable
  if result:
    p.result = ret.msg
    p.cleanup()

proc getResult*[T, U](p: LoadFuture[T, U]): T =
  assert p.channel == nil, "Result is not available yet"
  return p.result

proc loadWorker[T](params: (StorageType, string, ptr Channel[T])) =
  var db = params[0].openDb()
  defer: db.close()
  let ret = loadFromDb[T](db, params[1])
  params[2][].send(ret)

proc load*[T](storageType: StorageType, key: string): LoadFuture[T, (StorageType, string, ptr Channel[T])] =
  result.channel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.channel[].open()
  createThread(result.thread, loadWorker[T], (storageType, key, result.channel))

# STORING ######################################3333
#
type
  StoreFuture*[T, U] = object
    thread: Thread[U]
    channel: ptr Channel[T]
    doneChannel: ptr Channel[bool]

proc cleanup*[T, U](p: var StoreFuture[T, U]) =
  if p.channel != nil:
    p.thread.joinThread()
    p.channel[].close()
    p.doneChannel[].close()
    deallocShared(p.channel)
    deallocShared(p.doneChannel)
    p.channel = nil
    p.doneChannel = nil

proc awaitStored*[T, U](p: var StoreFuture[T, U]) =
  discard p.doneChannel[].recv()
  p.cleanup()

proc isStored*[T, U](p: var StoreFuture[T, U]): bool =
  let ret = p.doneChannel[].tryRecv()
  result = ret.dataAvailable
  if ret.dataAvailable:
    p.cleanup()

proc storeWorker[T](params: (StorageType, string, ptr Channel[T], ptr Channel[bool])) =
  var db = params[0].openDb()
  defer: db.close()
  storeInDb(db, params[1], params[2][].recv())
  params[3][].send(true)

proc store*[T](storageType: StorageType, key: string, value: T): StoreFuture[T, (StorageType, string, ptr Channel[T], ptr Channel[bool])] =
  result.channel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.channel[].open()
  result.doneChannel = cast[ptr Channel[bool]](allocShared0(sizeof(Channel[bool])))
  result.doneChannel[].open()
  createThread(result.thread, storeWorker[T], (storageType, key, result.channel, result.doneChannel))
  result.channel[].send(value)
