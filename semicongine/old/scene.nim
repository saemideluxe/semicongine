import std/tables
import std/sequtils
import std/strformat
import std/hashes

import ./core
import ./mesh
import ./material

type
  Scene* = ref object
    name*: string
    shaderGlobals*: Table[string, DataList]
    meshes*: seq[Mesh]
    dirtyShaderGlobals: seq[string]
    loaded*: bool = false

proc Add*(scene: var Scene, mesh: MeshObject) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  var tmp = new Mesh
  tmp[] = mesh
  scene.meshes.add tmp

proc Add*(scene: var Scene, mesh: Mesh) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  assert not mesh.isNil, "Cannot add a mesh that is 'nil'"
  scene.meshes.add mesh

proc Add*(scene: var Scene, meshes: seq[Mesh]) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  for mesh in meshes:
    assert not mesh.isNil, "Cannot add a mesh that is 'nil'"
  scene.meshes.add meshes

# generic way to add objects that have a mesh-attribute
proc Add*[T](scene: var Scene, obj: T) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add meshes"
  for name, value in obj.fieldPairs:
    when typeof(value) is Mesh:
      assert not value.isNil, "Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value
    when typeof(value) is seq[Mesh]:
      assert not value.isNil, &"Cannot add a mesh that is 'nil': " & name
      scene.meshes.add value

proc AddShaderGlobalArray*[T](scene: var Scene, name: string, data: openArray[T]) =
  assert not scene.loaded, &"Scene {scene.name} has already been loaded, cannot add shader values"
  scene.shaderGlobals[name] = InitDataList(data)
  scene.dirtyShaderGlobals.add name

proc AddShaderGlobal*[T](scene: var Scene, name: string, data: T) =
  scene.AddShaderGlobalArray(name, [data])

proc GetShaderGlobalArray*[T](scene: Scene, name: string): ref seq[T] =
  scene.shaderGlobals[name][T]

proc GetShaderGlobal*[T](scene: Scene, name: string): T =
  GetShaderGlobalArray[T](scene, name)[][0]

proc SetShaderGlobalArray*[T](scene: var Scene, name: string, value: openArray[T]) =
  if scene.shaderGlobals[name, T][] == @value:
    return
  scene.shaderGlobals[name] = value
  if not scene.dirtyShaderGlobals.contains(name):
    scene.dirtyShaderGlobals.add name

proc SetShaderGlobal*[T](scene: var Scene, name: string, value: T) =
  scene.SetShaderGlobalArray(name, [value])

func DirtyShaderGlobals*(scene: Scene): seq[string] =
  scene.dirtyShaderGlobals

proc ClearDirtyShaderGlobals*(scene: var Scene) =
  scene.dirtyShaderGlobals.reset

func hash*(scene: Scene): Hash =
  hash(scene.name)

func UsesMaterial*(scene: Scene, materialType: MaterialType): bool =
  return scene.meshes.anyIt(it.material.theType == materialType)

func GetMaterials*(scene: Scene, materialType: MaterialType): seq[MaterialData] =
  for mesh in scene.meshes:
    if mesh.material.theType == materialType and (not result.contains(mesh.material)):
      result.add mesh.material
