import std/os

import semicongine

proc testSimple(storage: StorageType) =
  const TEST_VALUE = 42
  const KEY = "test"

  # get default
  var promise1 = load[int](storage, KEY)
  assert promise1.awaitResult() == default(type(TEST_VALUE))

  # save and load custom
  var promise2 = store(storage, KEY, TEST_VALUE)
  promise2.awaitStored()
  promise1 = load[int](storage, KEY)
  assert promise1.awaitResult() == TEST_VALUE

proc testBusyWait(storage: StorageType) =
  const TEST_VALUE = "43"
  const KEY = "test2"

  # get default
  var promise1 = load[string](storage, KEY)
  while not promise1.hasResult():
    sleep(1)
  assert promise1.getResult() == default(type(TEST_VALUE))

  # save and load custom
  var promise2 = store(storage, KEY, TEST_VALUE)
  while not promise2.isStored():
    sleep(1)
  promise1 = load[string](storage, KEY)
  while not promise1.hasResult():
    sleep(1)
  assert promise1.awaitResult() == TEST_VALUE

proc main() =
  echo "SystemStorage: Testing simple store/load"
  SystemStorage.testSimple()
  echo "SystemStorage: Testing store/load with busy wait"
  SystemStorage.testBusyWait()

  UserStorage.purge()
  echo "UserStorage: Testing simple store/load"
  UserStorage.testSimple()
  echo "UserStorage: Testing store/load with busy wait"
  UserStorage.testBusyWait()
  UserStorage.purge()

when isMainModule:
  main()
