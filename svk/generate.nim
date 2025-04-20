import std/strtabs
import std/xmltree
import std/tables
import std/options
import std/sequtils
import std/strutils
import std/strformat
import std/xmlparser
import std/os
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

# generate core types ===============================================================================
# preamble, much easier to hardcode than to generate from xml
echo """
when defined(linux):
  include ./platform/xlib
when defined(windows):
  include ./platform/win32

func VK_MAKE_API_VERSION*(
    variant: uint32, major: uint32, minor: uint32, patch: uint32
): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch


"""

echo "type"

for t in types:
  if t.attr("deprecated") == "true":
    continue
  echo t
echo ""

# generate consts ===============================================================================
echo "const"
for c in consts:
  var value = c.value
  if value.endsWith("U"):
    value = value[0 ..^ 2] & "'u32"
  elif value.endsWith("ULL"):
    value = value[0 ..^ 4] & "'u64"
  if value[0] == '~':
    value = "not " & value[1 ..^ 1]
  echo &"  {c.name}*: {c.datatype} = {value}"
echo ""

# generate enums ===============================================================================
echo "type"
for edef in enums.values():
  if edef.values.len > 0:
    echo &"  {edef.name}* {{.size: 4.}} = enum"
    for ee in edef.values:
      echo &"    {ee.name} = {ee.value}"
echo ""
