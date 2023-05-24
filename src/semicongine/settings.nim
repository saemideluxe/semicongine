import std/logging
import std/streams
import std/parsecfg
import std/strutils
import std/sequtils
import std/parseutils
import std/strformat
import std/tables
import std/os

import ./core

when CONFIGHOTRELOAD:
  var
    configUpdates: Channel[(string, string)]
    notifyConfigUpdate: Channel[bool]
  configUpdates.open()
  notifyConfigUpdate.open()

# runtime configuration
# =====================
# namespace is the path from the CONFIGROOT to the according settings file without the file extension
# a settings file must always have the extension CONFIGEXTENSION
# a fully qualified settings identifier can be in the form {namespace}.{section}.{key}
# {key} and {section} may not contain dots

# a "namespace" is the path from the settings root to an *.CONFIGEXTENSION file, without the file extension
# settings is a namespace <-> settings mapping
var allsettings: Table[string, Config]

proc configRoot(): string =
  joinPath(absolutePath(getAppDir()), CONFIGROOT)

proc getFile(namespace: string): string =
  joinPath(configRoot(), namespace & "." & CONFIGEXTENSION)

iterator walkConfigNamespaces(): string =
  for file in walkDirRec(dir=configRoot(), relative=true, checkDir=true):
    if file.endsWith("." & CONFIGEXTENSION):
      yield file[0 ..< ^(CONFIGEXTENSION.len + 1)]

proc loadAllConfig(): Table[string, Config] =
  for ns in walkConfigNamespaces():
    result[ns] = ns.getFile().loadConfig()

proc reloadSettings*() =
  allsettings = loadAllConfig()

proc configStr(key, section, namespace: string): string =
  when CONFIGHOTRELOAD:
    while configUpdates.peek() > 0:
      let (updatedNamespace, updatedConfig) = configUpdates.recv()
      allsettings[updatedNamespace] = loadConfig(newStringStream(updatedConfig))
  if not allsettings.hasKey(namespace):
    raise newException(Exception, &"Namespace {namespace} not found, available namespaces are {allsettings.keys().toSeq}")
  allsettings[namespace].getSectionValue(section, key)

proc setting*[T: int|float|string](key, section, namespace: string): T =
  when T is int:
    let value = configStr(key, section, namespace)
    if parseInt(value, result) == 0:
      raise newException(Exception, &"Unable to parse int from settings {namespace}.{section}.{key}: {value}")
  elif T is float:
    let value = configStr(key, section, namespace)
    if parseFloat(value, result) == 0:
      raise newException(Exception, &"Unable to parse float from settings {namespace}.{section}.{key}: {value}")
  else:
    result = configStr(key, section, namespace)

proc setting*[T: int|float|string](identifier: string): T =
  # identifier can be in the form:
  # {namespace}.{key}
  # {namespace}.{section}.{key}
  let parts = identifier.rsplit(".")
  if parts.len == 1:
    raise newException(Exception, &"Setting with name {identifier} has no namespace")
  if parts.len == 2: result = setting[T](parts[1], "", parts[0])
  else: result = setting[T](parts[^1], parts[^2], joinPath(parts[0 .. ^3]))

proc hadConfigUpdate*(): bool =
  result = false
  when CONFIGHOTRELOAD == true:
    while notifyConfigUpdate.peek() > 0:
      result = true


allsettings = loadAllConfig()

when CONFIGHOTRELOAD == true:
  import std/times

  proc configFileWatchdog() {.thread.} =
    var configModTimes: Table[string, Time]
    while true:
      for namespace in walkConfigNamespaces():
        if not (namespace in configModTimes):
          configModTimes[namespace] = Time()
        let lastMod = namespace.getFile().getLastModificationTime()
        if lastMod != configModTimes[namespace]:
          let configStr = newFileStream(namespace.getFile()).readAll()
          configUpdates.send((namespace, configStr))
          notifyConfigUpdate.send(true)
      sleep CONFIGHOTRELOADINTERVAL
  var thethread: Thread[void]
  createThread(thethread, configFileWatchdog)

if DEBUG:
  setLogFilter(lvlAll)
else:
  setLogFilter(lvlWarn)
