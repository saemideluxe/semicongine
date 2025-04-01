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

type ID = distinct int
proc `==`(a, b: ID): bool =
  `==`(int(a), int(b))

proc testWorldAPI() =
  type Obj1 = object
    value: int
    id: ID

  type Obj2 = object
    a: string
    b: Obj1
    c: seq[int]
    d: array[3, Obj1]
    e: bool

  assert listWorlds().len == 0

  const obj1 = Obj1(value: 42, id: ID(1))
  "testWorld".storeWorld(obj1)
  assert listWorlds() == @["testWorld"]
  assert loadWorld[Obj1]("testWorld") == obj1

  const obj2 = Obj2(
    a: "Hello world",
    b: Obj1(value: 20, id: ID(20)),
    c: @[1, 2, 3, 4],
    d: [
      Obj1(value: 1, id: ID(11)), Obj1(value: 2, id: ID(22)), Obj1(value: 3, id: ID(33))
    ],
    e: true,
  )
  "testWorld".storeWorld(obj2)
  assert listWorlds() == @["testWorld"]
  assert loadWorld[Obj2]("testWorld") == obj2

  "earth".storeWorld(obj2)
  assert "earth" in listWorlds()
  assert "testWorld" in listWorlds()
  assert loadWorld[Obj2]("earth") == obj2

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
