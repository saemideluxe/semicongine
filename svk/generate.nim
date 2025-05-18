import std/strtabs
import std/syncio
import std/xmltree
import std/tables
import std/options
import std/sequtils
import std/strutils
import std/strformat
import std/xmlparser
import std/os
import std/osproc
import std/paths

# helpers
func smartParseInt(value: string): int =
  if value.startsWith("0x"):
    parseHexInt(value)
  else:
    parseInt(value)

const TYPEMAP = {
  "void": "void",
  "char": "char",
  "float": "float32",
  "double": "float64",
  "int8_t": "int8",
  "uint8_t": "uint8",
  "int16_t": "int16",
  "uint16_t": "uint16",
  "int32_t": "int32",
  "uint32_t": "uint32",
  "uint64_t": "uint64",
  "int64_t": "int64",
  "size_t": "csize_t",
  "int": "cint",
}.toTable
# load xml
let xml = (system.currentSourcePath.parentDir() / "vk.xml").loadXml()
let platforms = xml.findAll("platforms")[0]
let types = xml.findAll("types")[0]
let xmlenums = xml.findAll("enums")
let commands = xml.findAll("commands")[0]
let features = xml.findAll("feature") # features has extends="<ENUM>"
let extensions = xml.findAll("extensions")[0] # extensions has extends="<ENUM>"
let formats = xml.findAll("formats")[0]

# gather all enums

type
  EnumEntry = object
    name: string
    value: string

  EnumDef = object
    name: string
    values: seq[EnumEntry]
    isBitmask: bool

  ConstantDef = object
    name: string
    datatype: string
    value: string

var consts: seq[ConstantDef]
var enums: Table[string, EnumDef]

func addValue(edef: var EnumDef, n: XmlNode) =
  if n.attr("deprecated") != "aliased" and n.attr("alias") == "":
    if n.attr("name") in edef.values.mapIt(it.name):
      return

    var value = ""
    if n.attr("value") != "":
      value = n.attr("value")
    elif n.attr("bitpos") != "":
      value = $(1 shl parseInt(n.attr("bitpos")))
    elif n.attr("offset") != "":
      var enumBase = 1000000000
      if n.attr("extnumber") != "":
        enumBase += (smartParseInt(n.attr("extnumber")) - 1) * 1000
      var v = smartParseInt(n.attr("offset")) + enumBase
      if n.attr("dir") == "-":
        v = -v
      value = $(v)

    if value notin edef.values.mapIt(it.value):
      edef.values.add EnumEntry(name: n.attr("name"), value: value)

func doTypename(typename: string, pointerType: int): string =
  ## pointerType == 0: no pointer
  ## pointerType == 1: normal pointer (e.g. char *)
  ## pointerType == 2: double pointer (e.g. void **)
  assert pointerType in [0, 1, 2]
  result = TYPEMAP.getOrDefault(typename.strip(), typename.strip()).strip(chars = {'_'})

  if typename == "void":
    assert pointerType > 0

  if pointerType > 0:
    if typename == "void":
      result = "pointer"
    elif typename == "char":
      if pointerType == 1:
        result = "cstring"
      elif pointerType == 2:
        result = "cstringArray"
      else:
        assert false, "Unsupported char pointer type"
    else:
      result = "ptr " & result

  if pointerType == 2 and typename != "char":
    result = "ptr " & result

func doIdentifier(typename: string): string =
  if typename in ["type", "object"]:
    return &"`{typename}`"
  return typename.strip()

func doMember(typename, theType: string, pointerType: int, value: string): string =
  if value == "":
    &"{doIdentifier(typename)}: {doTypename(theType, pointerType)}"
  else:
    &"{doIdentifier(typename)}: {doTypename(theType, pointerType)} = {value}"

func memberDecl(n: XmlNode): string =
  for i in 0 ..< n.len:
    if n[i].kind == xnElement and n[i].tag == "comment":
      n.delete(i)
      break
  assert n.tag == "member"
  if n.len == 2:
    return doMember(n[1][0].text, n[0][0].text, 0, n.attr("values"))
  elif n.len == 3:
    assert "*" notin n[0][0].text.strip()
    if n[1].kind == xnElement and n[1].tag == "name":
      # bitfield
      if n[2].text.strip().startsWith(":"):
        return
          &"{doIdentifier(n[1][0].text)} {{.bitsize:{n[2].text.strip()[1 .. ^1]}.}}: {doTypename(n[0][0].text, 0)}"
      # array definition
      elif n[2].text.strip().startsWith("["):
        let arrayDim = n[2].text[1 ..< ^1]
        if "][" in arrayDim:
          let dims = arrayDim.split("][", 1)
          let (dim1, dim2) = (dims[0], dims[1])
          return doMember(
            n[1][0].text,
            &"array[{dim1}, array[{dim2}, {doTypename(n[0][0].text, 0)}]]",
            0,
            n.attr("values"),
          )
        else:
          return doMember(
            n[1][0].text,
            &"array[{arrayDim}, {doTypename(n[0][0].text, 0)}]",
            0,
            n.attr("values"),
          )
      else:
        debugecho n.toSeq
        doAssert false, "This should not happen"
    else:
      # pointer definition
      assert n[1].text.strip() == "*"
      return doMember(n[2][0].text, n[0][0].text, 1, n.attr("values"))
  elif n.len == 4:
    if n[0].text.strip() in ["struct", "const struct"]:
      return doMember(n[3][0].text, n[1][0].text, 1, n.attr("values"))
    else:
      assert n[0].text.strip() == "const" # can be ignored
      assert n[1].tag == "type"
      assert n[2].text.strip() in ["*", "* const *", "* const*"]
      assert n[3].tag == "name"
      assert n[1].len == 1
      assert n[3].len == 1
      return doMember(
        n[3][0].text, n[1][0].text, n[2].text.strip().count("*"), n.attr("values")
      )
  elif n.len in [5, 6]:
    # array definition, using const-value for array length
    # <type>uint8_t</type>,<name>pipelineCacheUUID</name>[<enum>VK_UUID_SIZE</enum>]
    assert n[2].text.strip() == "["
    assert n[4].text.strip() == "]"
    return doMember(
      n[1][0].text,
      &"array[{n[3][0].text}, {doTypename(n[0][0].text, 0)}]",
      0,
      n.attr("values"),
    )
  assert false

for e in xmlenums:
  if e.attr("type") == "constants":
    for c in e.findAll("enum"):
      var value = c.attr("value").strip(chars = {'(', ')'})
      consts.add ConstantDef(
        name: c.attr("name"), datatype: TYPEMAP[c.attr("type")], value: value
      )
  elif e.attr("type") == "enum":
    var edef = EnumDef(name: e.attr("name"), isBitmask: false)
    for ee in e.findAll("enum"):
      edef.addValue(ee)
    enums[edef.name] = edef
  elif e.attr("type") == "bitmask":
    var edef = EnumDef(name: e.attr("name"), isBitmask: true)
    for ee in e.findAll("enum"):
      edef.addValue(ee)
    enums[edef.name] = edef

for f in features:
  for extendenum in f.findAll("enum"):
    if extendenum.attr("extends") != "":
      enums[extendenum.attr("extends")].addValue(extendenum)

var extensionLoaders: seq[(string, seq[string])]

for extension in extensions.findAll("extension"):
  let extNum = extension.attr("number")
  extensionLoaders.add (extension.attr("name"), newSeq[string]())
  for c in extension.findAll("command"):
    if "Video" notin c.attr("name"):
      extensionLoaders[^1][1].add c.attr("name")

  for extendenum in extension.findAll("enum"):
    if extendenum.attr("extends") != "":
      if extendenum.attr("extnumber") == "":
        extendenum.attrs["extnumber"] = extNum
      enums[extendenum.attr("extends")].addValue(extendenum)

let outPath = (system.currentSourcePath.parentDir() / "vkapi.nim")
let outFile = open(outPath, fmWrite)

# generate core types ===============================================================================
# preamble, much easier to hardcode than to generate from xml
outFile.writeLine """

import std/dynlib
import std/strutils
import std/tables
import std/macros
import std/typetraits

import ../semicongine/thirdparty/winim/winim/inc/winbase
import ../semicongine/thirdparty/winim/winim/inc/windef
import ../semicongine/thirdparty/x11/xlib
import ../semicongine/thirdparty/x11/x
import ../semicongine/thirdparty/x11/xrandr

func VK_MAKE_API_VERSION*(
    variant: uint32, major: uint32, minor: uint32, patch: uint32
): uint32 =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch

macro enumFullRange(a: typed): untyped =
  newNimNode(nnkBracket).add(a.getType[1][1 ..^ 1])

func asBits[T, S](flags: openArray[T]): S =
  for flag in flags:
    let a = distinctBase(S)(result)
    let b = distinctBase(S)(flag)
    result = S(a or b)

func toEnums*[T, S](number: T): seq[S] =
  for value in enumFullRange(S):
    if (value.ord and cint(number)) > 0:
      result.add value
"""

outFile.writeLine "type"
outFile.writeLine """

  # some unused native types
  #
  # android
  ANativeWindow = object
  AHardwareBuffer = object

  # apple/metal
  CAMetalLayer = object
  MTLSharedEvent_id = object
  MTLDevice_id = object
  MTLCommandQueue_id = object
  MTLBuffer_id = object
  MTLTexture_id = object
  IOSurfaceRef = object

  # wayland
  wl_display = object
  wl_surface = object

  # XCB
  xcb_connection_t = object
  xcb_window_t = object
  xcb_visualid_t = object

  # directfb
  IDirectFB = object
  IDirectFBSurface = object

  # Zircon
  zx_handle_t = object

  # GGP C
  GgpStreamDescriptor = object
  GgpFrameToken = object

  # Screen (nintendo switch?)
  screen_context = object
  screen_window = object
  screen_buffer = object

  # Nvidia
  NvSciSyncAttrList = object
  NvSciSyncObj = object
  NvSciSyncFence = object
  NvSciBufAttrList = object
  NvSciBufObj = object

  # some base vulkan base types
  VkSampleMask* = distinct uint32 
  VkBool32* = distinct uint32 
  VkFlags* = distinct uint32 
  VkFlags64* = distinct uint64 
  VkDeviceSize* = distinct uint64 
  VkDeviceAddress* = distinct uint64 
  VkRemoteAddressNV* = pointer
"""

# generate consts ===============================================================================
outFile.writeLine "const"
for c in consts:
  var value = c.value
  if value.endsWith("U"):
    value = value[0 ..^ 2] & "'u32"
  elif value.endsWith("ULL"):
    value = value[0 ..^ 4] & "'u64"
  if value[0] == '~':
    value = "not " & value[1 ..^ 1]
  if c.name in ["VK_TRUE", "VK_FALSE"]:
    outFile.writeLine &"  {c.name}*: VkBool32 = VkBool32({value})"
  else:
    outFile.writeLine &"  {c.name}*: {c.datatype} = {value}"
outFile.writeLine ""

# generate enums ===============================================================================
const nameCollisions = [
  "VK_PIPELINE_CACHE_HEADER_VERSION_ONE",
  "VK_PIPELINE_CACHE_HEADER_VERSION_SAFETY_CRITICAL_ONE",
  "VK_DEVICE_FAULT_VENDOR_BINARY_HEADER_VERSION_ONE_EXT",
]

for edef in enums.values():
  if edef.values.len > 0:
    outFile.writeLine &"type {edef.name}* {{.size: 4.}} = enum"
    for ee in edef.values:
      # due to the nim identifier-system, there might be collisions between typenames and enum-member names
      if ee.name in nameCollisions:
        outFile.writeLine &"  {ee.name}_VALUE = {ee.value}"
      else:
        outFile.writeLine &"  {ee.name} = {ee.value}"

outFile.writeLine "type"

# generate types ===============================================================================
var stringConverters: seq[string]
for t in types:
  let category = t.attr("category")
  let tName = t.attr("name")
  if tName.startsWith("VkVideo"): # we are not doing the video API, sorry
    continue
  if tName.startsWith("VkPhysicalDeviceVideo"): # we are not doing the video API, sorry
    continue
  if t.attr("api") == "vulkansc":
    continue
  elif t.attr("deprecated") == "true":
    continue
  elif category == "include":
    continue
  elif category == "define":
    continue
  elif t.attr("requires").startsWith("vk_video"):
    continue
  elif t.attr("alias") != "":
    let a = t.attr("alias")
    outFile.writeLine &"  {tName}* = {a}"
  elif category == "bitmask":
    if t.len > 0 and t[0].text.startsWith("typedef"):
      outFile.writeLine &"  {t[2][0].text.strip()}* = distinct {t[1][0].text.strip()}"
  elif category == "union":
    outFile.writeLine &"  {tName}* {{.union.}} = object"
    for member in t.findAll("member"):
      outFile.writeLine &"    {member.memberDecl()}"
  elif category == "handle":
    outFile.writeLine &"  {t[2][0].text.strip()} = distinct pointer"
    stringConverters.add t[2][0].text.strip()
  elif category == "struct":
    outFile.writeLine &"  {tName}* = object"
    for member in t.findAll("member"):
      if member.attr("api") == "vulkansc":
        continue
      outFile.writeLine &"    {member.memberDecl()}"
  elif category == "funcpointer":
    assert t[0].text.startsWith("typedef ")
    let retName = t[0].text[8 ..< ^13].strip()
    let funcName = t.findAll("name")[0][0].text

    outFile.write &"  {funcname}* = proc("
    let nParams = (t.len - 3) div 2
    for i in 0 ..< nParams:
      assert t[i * 2 + 3].tag == "type"
      let typename = t[i * 2 + 3][0].text.strip()
      var identifier = t[i * 2 + 4].text.strip(chars = {' ', ')', ';', ',', '\n'})
      var pointerType = if identifier.startsWith("*"): 1 else: 0
      if pointerType > 0:
        identifier = identifier[1 .. ^1].strip(chars = {' ', ')', ';', ',', '\n'})
      if identifier.endsWith("const"):
        identifier = identifier[0 .. ^6].strip(chars = {' ', ')', ';', ',', '\n'})
      identifier = identifier.strip(chars = {','})
      outFile.write &"{doIdentifier(identifier)}: {doTypename(typename, pointerType)}, "

    if retName == "void":
      outFile.writeLine &") {{.cdecl.}}"
    elif retName == "void*":
      outFile.writeLine &"): pointer {{.cdecl.}}"
    else:
      outFile.writeLine &"): {doTypename(retName, 0)} {{.cdecl.}}"
  else:
    doAssert category in ["", "basetype", "enum"], "unknown type category: " & category
outFile.writeLine ""

for edef in enums.values():
  if edef.values.len > 0:
    if edef.isBitmask:
      let bitsName = edef.name
      let p = bitsName.rfind("FlagBits")
      let flagsName = bitsName[0 ..< p] & "Flags" & bitsName[p + 8 .. ^1]

      outFile.writeLine &"converter {bitsName}ToBits*(flags: openArray[{bitsName}]): {flagsName} ="
      outFile.writeLine &"  asBits[{bitsName}, {flagsName}](flags)"
      outFile.writeLine &"func `$`*(bits: {flagsName}): string ="
      outFile.writeLine &"  $toEnums[{flagsName}, {bitsName}](bits)"
outFile.writeLine ""

for command in commands:
  if command.attr("api") == "vulkansc":
    continue
  if command.attr("alias") != "":
    let funcName = command.attr("name")
    let funcAlias = command.attr("alias")
    outFile.write &"var {funcName}* = {funcAlias}\n"
    continue

  let proto = command.findAll("proto")[0]
  let retType = proto.findAll("type")[0][0].text.strip()
  let funcName = proto.findAll("name")[0][0].text.strip()

  if "Video" in funcName: # Video API not supported at this time
    continue

  outFile.write &"var {funcName}*: proc("
  for param in command:
    if param.tag != "param":
      continue
    if param.attr("api") == "vulkansc":
      continue
    assert param.len in [2, 3, 4]
    let paramType = param.findAll("type")[0][0].text
    let paramName = param.findAll("name")[0][0].text
    assert "*" notin paramType, $param

    if param.len == 4:
      param.delete(0)

    var pointerType = 0

    if param.len == 3:
      if param[param.len - 1].kind == xnText:
        assert param[param.len - 1].text[^1] == ']'
      else:
        assert param[0].tag == "type"
        assert param[param.len - 1].tag == "name"
        if param[1].text.strip() == "*":
          pointerType = 1
        elif param[1].text.strip() == "**":
          pointerType = 2
        # echo "3: ", param[1].text, " ", paramType, " ", paramName
    outFile.write &"{doIdentifier(paramName)}: {doTypename(paramType, pointerType)}, "

  outFile.write &")"
  if retType != "void":
    assert "*" notin retType
    outFile.write &": {doTypename(retType, 0)}"
  outFile.write " {.stdcall.}\n"

outFile.write """

proc loadFunc[T](instance: VkInstance, f: var T, name: string) =
  f = cast[T](vkGetInstanceProcAddr(instance, name))

proc initVulkanLoader*() =
  if vkGetInstanceProcAddr != nil:
    return

  when defined(linux):
    let vulkanLib = loadLib("libvulkan.so.1")
  when defined(windows):
    let vulkanLib = loadLib("vulkan-1.dll")
  if vulkanLib == nil:
    raise newException(Exception, "Unable to load vulkan library")

  # init two global functions
  vkGetInstanceProcAddr = cast[proc(instance: VkInstance, pName: cstring, ): PFN_vkVoidFunction {.stdcall.}](checkedSymAddr(vulkanLib, "vkGetInstanceProcAddr"))

  loadFunc(VkInstance(nil), vkCreateInstance, "vkCreateInstance")

"""

for f in features:
  let name = f.attr("name").replace(",", "_")
  if f.attr("struct") != "":
    continue
  outFile.writeLine &"proc load_{name}(instance: VkInstance) ="
  var hasEntries = false
  for cmd in f.findAll("command"):
    if cmd.attr("name") == "vkCreateInstance":
      continue
    hasEntries = true
    let cName = cmd.attr("name")
    outFile.writeLine &"  loadFunc(instance, {cName}, \"{cName}\")"
  if not hasEntries:
    outFile.writeLine "  discard"
  outFile.writeLine ""

for (extName, commands) in extensionLoaders:
  outFile.writeLine &"proc load_{extName}(instance: VkInstance) ="
  for c in commands:
    outFile.writeLine &"  loadFunc(instance, {c}, \"{c}\")"
  if commands.len == 0:
    outFile.writeLine &"  discard"
outFile.writeLine ""

outFile.writeLine "const EXTENSION_LOADERS = {"
for (extName, commands) in extensionLoaders:
  outFile.writeLine &"  \"{extName}\": load_{extName},"
outFile.writeLine "}.toTable"
outFile.writeLine ""

outFile.writeLine "proc loadExtension*(instance: VkInstance, name: string) ="
outFile.writeLine "  assert name in EXTENSION_LOADERS"
outFile.writeLine "  EXTENSION_LOADERS[name](instance)"
outFile.writeLine ""

for strCon in stringConverters:
  outFile.writeLine &"""proc `$`*(v: {strCon}): string = "0x" & cast[uint](v).toHex()"""
outFile.writeLine ""

outFile.writeLine ""

outFile.close()

assert execCmd("nim c " & outPath) == 0
