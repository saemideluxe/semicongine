import std/os
import std/strformat

import semicongine

proc testSimple(storage: StorageType) =
  const TEST_VALUE = 42
  const KEY = "test"

  # get default
  assert load[int](storage, KEY) == default(type(TEST_VALUE))

  # save and load custom
  store(storage, KEY, TEST_VALUE)
  assert load[int](storage, KEY) == TEST_VALUE

proc stressTest(storage: StorageType) =
  for i in 1 .. 10000:
    let key = &"key-{i}"
    store(storage, key, i)
    assert load[int](storage, key) == i

proc main() =
  SystemStorage.purge()
  echo "SystemStorage: Testing simple store/load"
  SystemStorage.testSimple()

  UserStorage.purge()
  echo "UserStorage: Testing simple store/load"
  UserStorage.testSimple()

  echo "Stress test with 10'000 saves/loads"
  SystemStorage.stressTest()

  SystemStorage.purge()
  UserStorage.purge()


when isMainModule:
  main()
