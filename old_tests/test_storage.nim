import std/strformat

import semicongine

proc testSimple(storage: StorageType) =
  const TEST_VALUE = 42
  const KEY = "test"

  # get default
  assert storage.Load(KEY, 0) == default(type(TEST_VALUE))

  # save and load custom
  Store(storage, KEY, TEST_VALUE)
  assert storage.Load(KEY, 0) == TEST_VALUE

proc stressTest(storage: StorageType) =
  for i in 1 .. 10000:
    let key = &"key-{i}"
    Store(storage, key, i)
    assert storage.Load(key, 0) == i

proc main() =
  SystemStorage.Purge()
  echo "SystemStorage: Testing simple store/load"
  SystemStorage.testSimple()

  UserStorage.Purge()
  echo "UserStorage: Testing simple store/load"
  UserStorage.testSimple()

  echo "Stress test with 10'000 saves/loads"
  SystemStorage.stressTest()

  SystemStorage.Purge()
  UserStorage.Purge()


when isMainModule:
  main()
