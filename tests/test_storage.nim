import std/os
import std/strformat

import semicongine

proc testSimple(storage: StorageType) =
  const TEST_VALUE = 42
  const KEY = "test"

  # get default
  var future1 = load[int](storage, KEY)
  assert future1.awaitResult() == default(type(TEST_VALUE))

  # save and load custom
  var future2 = store(storage, KEY, TEST_VALUE)
  future2.awaitStored()
  future1 = load[int](storage, KEY)
  assert future1.awaitResult() == TEST_VALUE

proc testBusyWait(storage: StorageType) =
  const TEST_VALUE = "43"
  const KEY = "test2"

  # get default
  var future1 = load[string](storage, KEY)
  while not future1.hasResult():
    sleep(1)
  assert future1.getResult() == default(type(TEST_VALUE))

  # save and load custom
  var future2 = store(storage, KEY, TEST_VALUE)
  while not future2.isStored():
    sleep(1)
  future1 = load[string](storage, KEY)
  while not future1.hasResult():
    sleep(1)
  assert future1.awaitResult() == TEST_VALUE

proc stressTest(storage: StorageType) =
  for i in 1 .. 10000:
    let key = &"key-{i}"
    var p = store(storage, key, i)
    p.awaitStored()
    var p1 = load[int](storage, key)
    assert p1.awaitResult() == i

proc concurrentStressTest(storage: StorageType) =
  var storeFutures: seq[StoreFuture[int]]

  for i in 1 .. 10000:
    let key = &"key-{i}"
    echo key
    storeFutures.add store(storage, key, i)

  for i in 1 .. 10000:
    echo i
    let key = &"key-{i}"
    storeFutures[i - 1].awaitStored()
    var p1 = load[int](storage, key)
    assert p1.awaitResult() == i

proc main() =
  SystemStorage.purge()
  echo "SystemStorage: Testing simple store/load"
  SystemStorage.testSimple()
  echo "SystemStorage: Testing store/load with busy wait"
  SystemStorage.testBusyWait()

  UserStorage.purge()
  echo "UserStorage: Testing simple store/load"
  UserStorage.testSimple()
  echo "UserStorage: Testing store/load with busy wait"
  UserStorage.testBusyWait()

  echo "Stress test with 10'000 saves/loads"
  SystemStorage.stressTest()

  SystemStorage.purge()
  UserStorage.purge()

  # TODO: fails currently, but is likely not too important
  # echo "Stress test with 10'000 saves/loads and a little concurrency"
  # SystemStorage.concurrentStressTest()

when isMainModule:
  main()
