import std/tables
import std/sequtils
import std/hashes

import ./core
import ./mesh

type
  Scene* = object
    name*: string
    shaderGlobals*: Table[string, DataList]
    meshes*: seq[Mesh]
    dirtyShaderGlobals: seq[string]

proc add*(scene: var Scene, mesh: MeshObject) =
  var tmp = new Mesh
  tmp[] = mesh
  scene.meshes.add tmp

proc add*(scene: var Scene, mesh: Mesh) =
  assert not mesh.isNil, "Cannot add a mesh that is 'nil'"
  scene.meshes.add mesh

# generic way to add objects that have a mesh-attribute
proc add*[T](scene: var Scene, obj: T) =
  for name, value in obj.fieldPairs:
    when typeof(value) is Mesh:
      assert not value.isNil, "Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value
    when typeof(value) is seq[Mesh]:
      assert not value.isNil, &"Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value

proc addShaderGlobal*[T](scene: var Scene, name: string, data: T) =
  scene.shaderGlobals[name] = newDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], @[data])
  scene.dirtyShaderGlobals.add name

proc addShaderGlobalArray*[T](scene: var Scene, name: string, data: openArray[T]) =
  scene.shaderGlobals[name] = newDataList(data)
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

func appendShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  appendValues[T](scene.shaderGlobals[name], value)
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

func usesMaterial*(scene: Scene, materialName: string): bool =
  return scene.meshes.anyIt(it.materials.anyIt(it.name == materialName))
