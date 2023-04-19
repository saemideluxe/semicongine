import std/parsecfg
import std/strutils
import std/sequtils
import std/parseutils
import std/strformat
import std/tables
import std/os


# build configuration
# =====================

# compile-time defines, usefull for build-dependent settings
# can be overriden with compiler flags, e.g. -d:Foo=42 -d:Bar=false
# pramas: {.intdefine.} {.strdefine.} {.booldefine.}

# root of where config files will be searched
# must be relative (to the directory of the binary)
const DEBUG* = not defined(release)
const CONFIGROOT {.strdefine.}: string = "."
assert not isAbsolute(CONFIGROOT)

const CONFIGEXTENSION {.strdefine.}: string = "ini"

# by default enable hot-reload of runtime-configuration only in debug builds
const CONFIGHOTRELOAD {.booldefine.}: bool = DEBUG

# milliseconds to wait between checks for config hotreload
const CONFIGHOTRELOADINTERVAL {.intdefine.}: int = 1000


when CONFIGHOTRELOAD:
  var configUpdates: Channel[(string, Config)]
  configUpdates.open()


# runtime configuration
# =====================
# namespace is the path from the CONFIGROOT to the according config file without the file extension
# a config file must always have the extension CONFIGEXTENSION
# a fully qualified config identifier can be in the form {namespace}.{section}.{key}
# {key} and {section} may not contain dots

# a "namespace" is the path from the config root to an *.CONFIGEXTENSION file, without the file extension
# config is a namespace <-> config mapping
var theConfig: Table[string, Config]

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

proc configStr(key: string, section="", namespace = ""): string =
  var ns = namespace
  if ns == "":
    ns = "config"
  when CONFIGHOTRELOAD:
    while configUpdates.peek() > 0:
      let (updatedNamespace, updatedConfig) = configUpdates.recv()
      theConfig[updatedNamespace] = updatedConfig
  if not theConfig.hasKey(ns):
    raise newException(Exception, &"Namespace {ns} not found, available namespaces are {theConfig.keys().toSeq}")
  theConfig[ns].getSectionValue(section, key)

proc config*[T: int|float|string](key: string, section: string, namespace = "config"): T =
  when T is int:
    let value = configStr(key, section, namespace)
    if parseInt(value, result) == 0:
      raise newException(Exception, &"Unable to parse int from config {namespace}.{section}.{key}: {value}")
  elif T is float:
    let value = configStr(key, section, namespace)
    if parseFloat(value, result) == 0:
      raise newException(Exception, &"Unable to parse float from config {namespace}.{section}.{key}: {value}")
  else:
    result = configStr(key, section, namespace)

proc config*[T: int|float|string](identifier: string): T =
  # identifier can be in the form:
  # {key}
  # {section}.{key}
  # {namespace}.{section}.{key}
  let parts = identifier.rsplit(".", maxsplit=2)
  if parts.len == 1: result = config[T](parts[0], "")
  elif parts.len == 2: result = config[T](parts[1], parts[0])
  elif parts.len == 3: result = config[T](parts[2], parts[1], parts[0])

theConfig = loadAllConfig()

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
          configUpdates.send((namespace, namespace.getFile().loadConfig()))
      sleep CONFIGHOTRELOADINTERVAL
  var thethread: Thread[void]
  createThread(thethread, configFileWatchdog)

