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
  "void*": "pointer",
  "char*": "cstring",
  "ptr char": "cstring",
  "ptr void": "pointer",
    # "VK_DEFINE_HANDLE": "VkHandle", # not required, can directly defined as a distinct pointer, (in C is a pointer to an empty struct type)
    # "VK_DEFINE_NON_DISPATCHABLE_HANDLE": "VkNonDispatchableHandle", # same here
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
    if n.attr("name").endsWith("_EXT") and
        n.attr("name")[0 ..< ^4] in edef.values.mapIt(it.name):
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

    edef.values.add EnumEntry(name: n.attr("name"), value: value)

func memberDecl(n: XmlNode): string =
  for i in 0 ..< n.len:
    if n[i].kind == xnElement and n[i].tag == "comment":
      n.delete(i)
      break
  assert n.tag == "member"
  debugecho n.toSeq, " ", n.len
  if n.len == 2:
    return &"{n[1][0].text}: {n[0][0]}"
  elif n.len == 3:
    if n[1].kind == xnElement and n[1].tag == "name":
      return
        &"{n[1][0].text}: array[{n[2].text[1 ..< ^1]}, {TYPEMAP.getOrDefault(n[0][0].text, n[0][0].text)}]]"
    else:
      assert n[1].text.strip() == "*"
      return &"{n[2][0].text}: ptr {n[0][0].text}"
  elif n.len == 4:
    if n[0].text.strip() in ["struct", "const struct"]:
      return &"{n[3][0].text}: ptr {n[1][0].text}"
    else:
      assert n[2].text.strip() in ["*", "* const *", "* const*"]
      return &"?"
  elif n.len in [5, 6]:
    return &"{n[1][0].text}: array[{n[3][0].text}, {n[0][0].text}]"
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

for extension in extensions.findAll("extension"):
  let extNum = extension.attr("number")
  for extendenum in extension.findAll("enum"):
    if extendenum.attr("extends") != "":
      if extendenum.attr("extnumber") == "":
        extendenum.attrs["extnumber"] = extNum
      enums[extendenum.attr("extends")].addValue(extendenum)

let outPath = (system.currentSourcePath.parentDir() / "api.nim")
let outFile = open(outPath, fmWrite)

# generate core types ===============================================================================
# preamble, much easier to hardcode than to generate from xml
outFile.writeLine """
func VK_MAKE_API_VERSION*(
    variant: uint32, major: uint32, minor: uint32, patch: uint32
): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch
"""

outFile.writeLine "type"
outFile.writeLine """
  VkSampleMask = distinct uint32 
  VkBool32 = distinct uint32 
  VkFlags = distinct uint32 
  VkFlags64 = distinct uint64 
  VkDeviceSize = distinct uint64 
  VkDeviceAddress = distinct uint64 
  VkRemoteAddressNV = pointer
"""

for t in types:
  if t.attr("api") == "vulkansc":
    continue
  if t.attr("alias") != "":
    continue
  if t.attr("deprecated") == "true":
    continue
  if t.attr("category") == "include":
    continue
  if t.attr("category") == "define":
    continue
  if t.attr("category") == "bitmask":
    if t.len > 0 and t[0].text.startsWith("typedef"):
      outFile.writeLine &"  {t[2][0].text} = distinct {t[1][0].text}"
  elif t.attr("category") == "union":
    let n = t.attr("name")
    outFile.writeLine &"  {n}* {{.union.}} = object"
    for member in t.findAll("member"):
      outFile.writeLine &"    {member.memberDecl()}"
  elif t.attr("category") == "handle":
    outFile.writeLine &"  {t[2][0].text} = distinct pointer"
  elif t.attr("category") == "struct":
    let n = t.attr("name")
    outFile.writeLine &"  {n}* = object"
    for member in t.findAll("member"):
      outFile.writeLine &"    {member.memberDecl()}"
  # TODO: funcpointer

outFile.writeLine ""

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
  outFile.writeLine &"  {c.name}*: {c.datatype} = {value}"
outFile.writeLine ""

# generate enums ===============================================================================
outFile.writeLine "type"
for edef in enums.values():
  if edef.values.len > 0:
    outFile.writeLine &"  {edef.name}* {{.size: 4.}} = enum"
    for ee in edef.values:
      outFile.writeLine &"    {ee.name} = {ee.value}"
outFile.writeLine ""

outFile.writeLine """
when defined(linux):
  include ../semicongine/rendering/vulkan/platform/xlib
when defined(windows):
  include ../semicongine/rendering/vulkan/platform/win32
"""

outFile.close()

assert execCmd("nim c " & outPath) == 0
