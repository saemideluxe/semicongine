import std/strformat
import std/strutils
import std/tables
import std/hashes
import std/typetraits

import ./core
import ./animation
import ./mesh

type
  Scene* = object
    name*: string
    shaderGlobals*: Table[string, DataList]
    transformAttribute*: string = "transform"
    materialIndexAttribute*: string = "materialIndex"
    meshes*: seq[Mesh]

func addShaderGlobal*[T](scene: var Scene, name: string, data: T) =
  scene.shaderGlobals[name] = newDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], @[data])

func addShaderGlobalArray*[T](scene: var Scene, name: string, data: seq[T]) =
  scene.shaderGlobals[name] = newDataList(thetype=getDataType[T]())
  setValues(scene.shaderGlobals[name], data)

func getShaderGlobal*[T](scene: Scene, name: string): T =
  getValues[T](scene.shaderGlobals[name])[0]

func getShaderGlobalArray*[T](scene: Scene, name: string): seq[T] =
  getValues[T](scene.shaderGlobals[name])

func setShaderGlobal*[T](scene: var Scene, name: string, value: T) =
  setValues[T](scene.shaderGlobals[name], @[value])

func setShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  setValues[T](scene.shaderGlobals[name], value)

func appendShaderGlobalArray*[T](scene: var Scene, name: string, value: seq[T]) =
  appendValues[T](scene.shaderGlobals[name], value)

func hash*(scene: Scene): Hash =
  hash(scene.name)

func `==`*(a, b: Scene): bool =
  a.name == b.name
