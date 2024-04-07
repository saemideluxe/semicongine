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

proc purge*(storageType: StorageType) =
  storageType.path().string.removeFile()

# mini async API
#
# LOADING ######################################3333
#
#
type
  LoadFuture*[T] = object
    thread: Thread[(DbConn, string, ptr Channel[T])]
    channel: ptr Channel[T]
    result: T

proc cleanup*[T](p: var LoadFuture[T]) =
  if p.channel != nil:
    p.thread.joinThread()
    p.channel[].close()
    deallocShared(p.channel)
    p.channel = nil

proc awaitResult*[T](p: var LoadFuture[T]): T =
  if p.channel == nil:
    return p.result
  result = p.channel[].recv()
  p.result = result
  p.cleanup()

proc hasResult*[T](p: var LoadFuture[T]): bool =
  let ret = p.channel[].tryRecv()
  result = ret.dataAvailable
  if result:
    p.result = ret.msg
    p.cleanup()

proc getResult*[T](p: LoadFuture[T]): T =
  assert p.channel == nil, "Result is not available yet"
  return p.result

proc loadWorker[T](params: (DbConn, string, ptr Channel[T])) {.thread.} =
  let ret = loadFromDb[T](params[0], params[1])
  params[2][].send(ret)

proc load*[T](storageType: StorageType, key: string): LoadFuture[T] =
  storageType.setup()
  result.channel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.channel[].open()
  createThread(result.thread, loadWorker[T], (db[storageType], key, result.channel))

# STORING ######################################3333
#
type
  StoreFuture*[T] = object
    # thread: Thread[(DbConn, string, ptr Channel[T], ptr Channel[bool])]
    thread: Thread[void]
    channel: ptr Channel[T]
    doneChannel: ptr Channel[bool]

proc cleanup*[T](p: var StoreFuture[T]) =
  if p.channel != nil:
    p.thread.joinThread()
    p.channel[].close()
    p.doneChannel[].close()
    deallocShared(p.channel)
    deallocShared(p.doneChannel)
    p.channel = nil
    p.doneChannel = nil

proc awaitStored*[T](p: var StoreFuture[T]) =
  discard p.doneChannel[].recv()
  p.cleanup()

proc isStored*[T](p: var StoreFuture[T]): bool =
  let ret = p.doneChannel[].tryRecv()
  result = ret.dataAvailable
  if ret.dataAvailable:
    p.cleanup()

# proc storeWorker[T](params: (DbConn, string, ptr Channel[T], ptr Channel[bool])) {.thread.} =
  # storeInDb(params[0], params[1], params[2][].recv())
  # params[3][].send(true)


# proc store*[T](storageType: StorageType, key: string, value: T): StoreFuture[T] =
  # storageType.setup()
  # result.channel = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  # result.channel[].open()
  # result.doneChannel = cast[ptr Channel[bool]](allocShared0(sizeof(Channel[bool])))
  # result.doneChannel[].open()
  # createThread(result.thread, storeWorker[T], (db[storageType], key, result.channel, result.doneChannel))
  # createThread(result.thread, storeWorker)
  # result.channel[].send(value)

proc storeWorker() {.thread.} =
  echo "storeWorker"

proc store*() =
  var thread: Thread[void]
  createThread(thread, storeWorker)
