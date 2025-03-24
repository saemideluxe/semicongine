import std/strformat

import ../semicongine
import ../semicongine/storage

proc testSimple(storage: StorageType) =
  const TEST_VALUE = 42
  const KEY = "test"

  # get default
  assert storage.load(KEY, 0) == default(type(TEST_VALUE))

  # save and load custom
  store(storage, KEY, TEST_VALUE)
  assert storage.load(KEY, 0) == TEST_VALUE

proc testWorldAPI() =
  assert listWorlds().len == 0

  "testWorld".storeWorld(42)
  assert listWorlds() == @["testWorld"]
  assert loadWorld[int]("testWorld") == 42

  "testWorld".storeWorld("hello")
  assert listWorlds() == @["testWorld"]
  assert loadWorld[string]("testWorld") == "hello"

  "earth".storeWorld("hello")
  assert "earth" in listWorlds()
  assert "testWorld" in listWorlds()
  assert loadWorld[string]("earth") == "hello"

  "earth".purgeWorld()
  assert listWorlds() == @["testWorld"]

  "testWorld".purgeWorld()
  assert listWorlds().len == 0

proc stressTest(storage: StorageType) =
  for i in 1 .. 10000:
    let key = &"key-{i}"
    store(storage, key, i)
    assert storage.load(key, 0) == i

proc main() =
  initEngine("Test storage")
  SystemStorage.purge()
  echo "SystemStorage: Testing simple store/load"
  SystemStorage.testSimple()

  UserStorage.purge()
  echo "UserStorage: Testing simple store/load"
  UserStorage.testSimple()

  echo "Testing world-storage API"
  testWorldAPI()

  echo "Stress test with 10'000 saves/loads"
  SystemStorage.stressTest()

  SystemStorage.purge()
  UserStorage.purge()

when isMainModule:
  main()
