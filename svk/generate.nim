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

func doTypename(typename: string, isPointer: bool): string =
  result = TYPEMAP.getOrDefault(typename.strip(), typename.strip()).strip(chars = {'_'})

  if typename == "void":
    assert isPointer

  if isPointer:
    if typename == "void":
      result = "pointer"
    elif typename == "char":
      result = "cstring"
    else:
      result = "ptr " & result

func doIdentifier(typename: string): string =
  if typename in ["type", "object"]:
    return &"`{typename}`"
  return typename.strip()

func doMember(typename, theType: string, isPointer: bool, value: string): string =
  if value == "":
    &"{doIdentifier(typename)}: {doTypename(theType, isPointer)}"
  else:
    &"{doIdentifier(typename)}: {doTypename(theType, isPointer)} = {value}"

func memberDecl(n: XmlNode): string =
  for i in 0 ..< n.len:
    if n[i].kind == xnElement and n[i].tag == "comment":
      n.delete(i)
      break
  assert n.tag == "member"
  if n.len == 2:
    return doMember(n[1][0].text, n[0][0].text, false, n.attr("values"))
  elif n.len == 3:
    assert "*" notin n[0][0].text.strip()
    if n[1].kind == xnElement and n[1].tag == "name":
      # bitfield
      if n[2].text.strip().startsWith(":"):
        return
          &"{doIdentifier(n[1][0].text)} {{.bitsize:{n[2].text.strip()[1 .. ^1]}.}}: {doTypename(n[0][0].text, false)}"
      # array definition
      elif n[2].text.strip().startsWith("["):
        let arrayDim = n[2].text[1 ..< ^1]
        if "][" in arrayDim:
          let dims = arrayDim.split("][", 1)
          let (dim1, dim2) = (dims[0], dims[1])
          return doMember(
            n[1][0].text,
            &"array[{dim1}, array[{dim2}, {doTypename(n[0][0].text, false)}]]",
            false,
            n.attr("values"),
          )
        else:
          return doMember(
            n[1][0].text,
            &"array[{arrayDim}, {doTypename(n[0][0].text, false)}]",
            false,
            n.attr("values"),
          )
      else:
        debugecho n.toSeq
        doAssert false, "This should not happen"
    else:
      # pointer definition
      assert n[1].text.strip() == "*"
      return doMember(n[2][0].text, n[0][0].text, true, n.attr("values"))
  elif n.len == 4:
    if n[0].text.strip() in ["struct", "const struct"]:
      return doMember(n[3][0].text, n[1][0].text, true, n.attr("values"))
    else:
      assert n[0].text.strip() == "const" # can be ignored
      assert n[1].tag == "type"
      assert n[2].text.strip() in ["*", "* const *", "* const*"]
        # can be ignored, basically every type is a pointer
      assert n[3].tag == "name"
      assert n[1].len == 1
      assert n[3].len == 1
      return doMember(n[3][0].text, n[1][0].text, true, n.attr("values"))
  elif n.len in [5, 6]:
    # array definition, using const-value for array length
    # <type>uint8_t</type>,<name>pipelineCacheUUID</name>[<enum>VK_UUID_SIZE</enum>]
    assert n[2].text.strip() == "["
    assert n[4].text.strip() == "]"
    return doMember(
      n[1][0].text,
      &"array[{n[3][0].text}, {doTypename(n[0][0].text, false)}]",
      false,
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

for extension in extensions.findAll("extension"):
  let extNum = extension.attr("number")
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

import ../semicongine/thirdparty/winim/winim/inc/winbase
import ../semicongine/thirdparty/winim/winim/inc/windef
import ../semicongine/thirdparty/x11/xlib
import ../semicongine/thirdparty/x11/x
import ../semicongine/thirdparty/x11/xrandr

func VK_MAKE_API_VERSION*(
    variant: uint32, major: uint32, minor: uint32, patch: uint32
): uint32 {.compileTime.} =
  (variant shl 29) or (major shl 22) or (minor shl 12) or patch
"""

outFile.writeLine "type"
outFile.writeLine """
  # some unused native types
  #
  # android
  ANativeWindow = object
  AHardwareBuffer = object

  # apple
  CAMetalLayer = object
  MTLDevice = object
  MTLCommandQueue = object
  MTLBuffer = object
  MTLTexture = object
  MTLSharedEvent = object
  MTLSharedEvent_id = object

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
  VkSampleMask = distinct uint32 
  VkBool32 = distinct uint32 
  VkFlags = distinct uint32 
  VkFlags64 = distinct uint64 
  VkDeviceSize = distinct uint64 
  VkDeviceAddress = distinct uint64 
  VkRemoteAddressNV = pointer
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
  outFile.writeLine &"  {c.name}*: {c.datatype} = {value}"
outFile.writeLine ""

# generate enums ===============================================================================
const nameCollisions = [
  "VK_PIPELINE_CACHE_HEADER_VERSION_ONE",
  "VK_PIPELINE_CACHE_HEADER_VERSION_SAFETY_CRITICAL_ONE",
  "VK_DEVICE_FAULT_VENDOR_BINARY_HEADER_VERSION_ONE_EXT",
]
outFile.writeLine "type"
for edef in enums.values():
  if edef.values.len > 0:
    outFile.writeLine &"  {edef.name}* {{.size: 4.}} = enum"
    for ee in edef.values:
      # due to the nim identifier-system, there might be collisions between typenames and enum-member names
      if ee.name in nameCollisions:
        outFile.writeLine &"    {ee.name}_VALUE = {ee.value}"
      else:
        outFile.writeLine &"    {ee.name} = {ee.value}"

outFile.writeLine ""

# generate types ===============================================================================
for t in types:
  let category = t.attr("category")
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
    let n = t.attr("name")
    outFile.writeLine &"  {n} = {a}"
  elif category == "bitmask":
    if t.len > 0 and t[0].text.startsWith("typedef"):
      outFile.writeLine &"  {t[2][0].text} = distinct {t[1][0].text}"
  elif category == "union":
    let n = t.attr("name")
    outFile.writeLine &"  {n}* {{.union.}} = object"
    for member in t.findAll("member"):
      outFile.writeLine &"    {member.memberDecl()}"
  elif category == "handle":
    outFile.writeLine &"  {t[2][0].text} = distinct pointer"
  elif category == "struct":
    let n = t.attr("name")
    outFile.writeLine &"  {n}* = object"
    for member in t.findAll("member"):
      if member.attr("api") == "vulkansc":
        continue
      outFile.writeLine &"    {member.memberDecl()}"
  elif category == "funcpointer":
    #[
    <type category="funcpointer">typedef void* (VKAPI_PTR *<name>PFN_vkAllocationFunction</name>)(
      <type>void</type>*                                       pUserData,
      <type>size_t</type>                                      size,
      <type>size_t</type>                                      alignment,
      <type>VkSystemAllocationScope</type>                     allocationScope);
    </type>
    PFN_vkAllocationFunction* = proc(
      pUserData: pointer,
      size: csize_t,
      alignment: csize_t,
      allocationScope: VkSystemAllocationScope,
    ): pointer {.cdecl.}
    ]#
    assert t[0].text.startsWith("typedef ")
    outFile.writeLine &"  {t[1][0].text}* = proc()"
  else:
    doAssert category in ["", "basetype", "enum"], "unknown type category: " & category
outFile.writeLine ""

outFile.writeLine """
when defined(linux):
  include ../semicongine/rendering/vulkan/platform/xlib
when defined(windows):
  include ../semicongine/rendering/vulkan/platform/win32
"""

outFile.close()

assert execCmd("nim c " & outPath) == 0
