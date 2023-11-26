import std/tables
import std/sequtils
import std/strformat
import std/hashes

import ./core
import ./mesh
import ./material

type
  Scene* = object
    name*: string
    shaderGlobals*: Table[string, DataList]
    meshes*: seq[Mesh]
    dirtyShaderGlobals: seq[string]
    loaded*: bool = false

proc add*(scene: var Scene, mesh: MeshObject) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  var tmp = new Mesh
  tmp[] = mesh
  scene.meshes.add tmp

proc add*(scene: var Scene, mesh: Mesh) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  assert not mesh.isNil, "Cannot add a mesh that is 'nil'"
  scene.meshes.add mesh

proc add*(scene: var Scene, meshes: seq[Mesh]) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  for mesh in meshes:
    assert not mesh.isNil, "Cannot add a mesh that is 'nil'"
  scene.meshes.add meshes

# generic way to add objects that have a mesh-attribute
proc add*[T](scene: var Scene, obj: T) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  for name, value in obj.fieldPairs:
    when typeof(value) is Mesh:
      assert not value.isNil, "Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value
    when typeof(value) is seq[Mesh]:
      assert not value.isNil, &"Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value

proc addShaderGlobal*[T](scene: var Scene, name: string, data: T) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add shader values"
  scene.shaderGlobals[name] = initDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], @[data])
  scene.dirtyShaderGlobals.add name

proc addShaderGlobalArray*[T](scene: var Scene, name: string, data: openArray[T]) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add shader values"
  scene.shaderGlobals[name] = initDataList(data)
  scene.dirtyShaderGlobals.add name

func getShaderGlobal*[T](scene: Scene, name: string): T =
  getValues[T](scene.shaderGlobals[name])[0]

func getShaderGlobalArray*[T](scene: Scene, name: string): seq[T] =
  getValues[T](scene.shaderGlobals[name])

proc setShaderGlobal*[T](scene: var Scene, name: string, value: T) =
  setValues[T](scene.shaderGlobals[name], @[value])
  if not scene.dirtyShaderGlobals.contains(name):
    scene.dirtyShaderGlobals.add name

proc setShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  setValues[T](scene.shaderGlobals[name], value)
  if not scene.dirtyShaderGlobals.contains(name):
    scene.dirtyShaderGlobals.add name

func dirtyShaderGlobals*(scene: Scene): seq[string] =
  scene.dirtyShaderGlobals

func clearDirtyShaderGlobals*(scene: var Scene) =
  scene.dirtyShaderGlobals.reset

func hash*(scene: Scene): Hash =
  hash(scene.name)

func `==`*(a, b: Scene): bool =
  a.name == b.name

func usesMaterial*(scene: Scene, materialType: MaterialType): bool =
  return scene.meshes.anyIt(it.material.theType == materialType)

func getMaterials*(scene: Scene, materialType: MaterialType): seq[MaterialData] =
  for mesh in scene.meshes:
    if mesh.material.theType == materialType and (not result.contains(mesh.material)):
      result.add mesh.material
