import std/os
import std/sugar
import std/algorithm
import std/strformat
import std/strutils
import std/sequtils
import std/streams
import std/tables
import httpClient
import std/xmlparser
import std/xmltree

type
  FileContent = seq[string]

const
  TYPEMAP = {
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
    "VK_DEFINE_HANDLE": "VkHandle",
    "VK_DEFINE_NON_DISPATCHABLE_HANDLE": "VkNonDispatchableHandle",
  }.toTable
  PLATFORM_HEADER_MAP = {
    "X11/Xlib.h": "xlib",
    "X11/extensions/Xrandr.h": "xlib_xrandr",
    "wayland-client.h": "wayland",
    "windows.h": "win32",
    "xcb/xcb.h": "xcb",
    "directfb.h": "directfb",
    "zircon/types.h": "fuchsia",
    "ggp_c/vulkan_types.h": "ggp",
    "screen/screen.h": "screen",
    "nvscisync.h": "nvidia",
    "nvscibuf.h": "nvidia",
    "vk_video/vulkan_video_codec_h264std.h": "vk_video",
    "vk_video/vulkan_video_codec_h264std_decode.h": "vk_video",
    "vk_video/vulkan_video_codec_h264std_encode.h": "vk_video",
    "vk_video/vulkan_video_codec_h265std.h": "vk_video",
    "vk_video/vulkan_video_codec_h265std_decode.h": "vk_video",
    "vk_video/vulkan_video_codec_h265std_encode.h": "vk_video",
  }.toTable
  MAP_KEYWORD = {
    "object": "theobject",
    "type": "thetype",
  }.toTable

# helpers
func mapType(typename: string): auto =
  TYPEMAP.getOrDefault(typename.strip(), typename.strip()).strip(chars={'_'})
func mapName(thename: string): auto =
  MAP_KEYWORD.getOrDefault(thename.strip(), thename.strip()).strip(chars={'_'})
func smartParseInt(value: string): int =
  if value.startsWith("0x"):
    parseHexInt(value)
  else:
    parseInt(value)
func hasAttr(node: XmlNode, attr: string): bool = node.attr(attr) != ""
func tableSorted(table: Table[int, string]): seq[(int, string)] =
  result = toSeq(table.pairs)
  result.sort((a, b) => cmp(a[0], b[0]))

# serializers
func serializeEnum(node: XmlNode, root: XmlNode): seq[string] =
  let name = node.attr("name")
  if name == "":
    return result

  # find additional enum defintion in feature definitions
  var values: Table[int, string]
  for feature in root.findAll("feature"):
    for require in feature.findAll("require"):
      for theenum in require.findAll("enum"):
        if theenum.attr("extends") == name:
          if theenum.hasAttr("offset"):
            let enumBase = 1000000000 + (smartParseInt(theenum.attr("extnumber")) - 1) * 1000
            var value = smartParseInt(theenum.attr("offset")) + enumBase
            if theenum.attr("dir") == "-":
              value = -value
            values[value] = theenum.attr("name")
          elif theenum.hasAttr("value"):
            var value = smartParseInt(theenum.attr("value"))
            if theenum.attr("dir") == "-":
              value = -value
            values[value] = theenum.attr("name")
          elif theenum.hasAttr("bitpos"):
            var value = smartParseInt(theenum.attr("bitpos"))
            if theenum.attr("dir") == "-":
              value = -value
            values[value] = theenum.attr("name")
          elif theenum.hasAttr("alias"):
            discard
          else:
            raise newException(Exception, &"Unknown extension value: {feature}\nvalue:{theenum}")
  # find additional enum defintion in extension definitions
  for extension in root.findAll("extension"):
    let extensionNumber = parseInt(extension.attr("number"))
    let enumBase = 1000000000 + (extensionNumber - 1) * 1000
    for require in extension.findAll("require"):
      for theenum in require.findAll("enum"):
        if theenum.attr("extends") == name:
          if theenum.hasAttr("offset"):
            if theenum.hasAttr("extnumber"):
              let otherBase = 1000000000 + (smartParseInt(theenum.attr("extnumber")) - 1) * 1000
              var value = smartParseInt(theenum.attr("offset")) + otherBase
              if theenum.attr("dir") == "-":
                value = -value
              values[value] = theenum.attr("name")
            else:
              var value = smartParseInt(theenum.attr("offset")) + enumBase
              if theenum.attr("dir") == "-":
                value = -value
              values[value] = theenum.attr("name")
          elif theenum.hasAttr("value"):
            var value = smartParseInt(theenum.attr("value"))
            if theenum.attr("dir") == "-":
              value = -value
            values[value] = theenum.attr("name")
          elif theenum.hasAttr("bitpos"):
            var value = smartParseInt(theenum.attr("bitpos"))
            if theenum.attr("dir") == "-":
              value = -value
            values[value] = theenum.attr("name")
          elif theenum.hasAttr("alias"):
            discard
          else:
            raise newException(Exception, &"Unknown extension value: {extension}\nvalue:{theenum}")

  # generate enums
  if node.attr("type") == "enum":
    for value in node.findAll("enum"):
      if value.hasAttr("alias"):
        continue
      if value.attr("value").startsWith("0x"):
        values[parseHexInt(value.attr("value"))] = value.attr("name")
      else:
        values[smartParseInt(value.attr("value"))] = value.attr("name")
    if values.len > 0:
      result.add "  " & name & "* {.size: sizeof(cint).} = enum"
      for (value, name) in tableSorted(values):
        let enumEntry = &"    {name} = {value}"
        result.add enumEntry

  # generate bitsets (normal enums in the C API, but bitfield-enums in Nim)
  elif node.attr("type") == "bitmask":
    for value in node.findAll("enum"):
      if value.hasAttr("alias") or not value.hasAttr("bitpos"):
        continue
      values[smartParseInt(value.attr("bitpos"))] = value.attr("name")
    if values.len > 0:
      if node.hasAttr("bitwidth"):
        result.add "  " & name & "* {.size: " & $(smartParseInt(node.attr("bitwidth")) div 8) & ".} = enum"
      else:
        result.add "  " & name & "* {.size: sizeof(cint).} = enum"
      for (bitpos, enumvalue) in tableSorted(values):
        var value = "00000000000000000000000000000000"# makes the bit mask nicely visible
        if node.hasAttr("bitwidth"): # assumes this is always 64
          value = value & value
        value[^(bitpos + 1)] = '1'
        let enumEntry = &"    {enumvalue} = 0b{value}"
        if not (enumEntry in result): # the specs define duplicate entries for backwards compat
          result.add enumEntry
    let cApiName = name.replace("FlagBits", "Flags")
    if node.hasAttr("bitwidth"): # assumes this is always 64
      if values.len > 0:
        result.add &"""converter BitsetToNumber*(flags: openArray[{name}]): {cApiName} =
  for flag in flags:
    result = {cApiName}(uint64(result) or uint(flag))"""
        result.add "type"
    else:
      if values.len > 0:
        result.add &"""converter BitsetToNumber*(flags: openArray[{name}]): {cApiName} =
  for flag in flags:
    result = {cApiName}(uint(result) or uint(flag))"""
        result.add "type"

func serializeStruct(node: XmlNode, root: XmlNode): seq[string] =
  let name = node.attr("name")
  var union = ""
  if node.attr("category") == "union":
    union = "{.union.}"
  result.add &"  {name}* {union} = object"
  for member in node.findAll("member"):
    if not member.hasAttr("api") or member.attr("api") == "vulkan":
      let fieldname = member.child("name")[0].text.strip(chars={'_'})
      var fieldtype = member.child("type")[0].text.strip(chars={'_'})
      if member[member.len - 2].kind == xnText and member[member.len - 2].text.strip() == "*":
        fieldtype = &"ptr {mapType(fieldtype)}"
      fieldtype = mapType(fieldtype)
      result.add &"    {mapName(fieldname)}*: {fieldtype}"

func serializeFunctiontypes(api: XmlNode): seq[string] =
  for node in api.findAll("type"):
    if node.attr("category") == "funcpointer":
      let name = node[1][0]
      let returntype = mapType(node[0].text[8 .. ^1].split('(', 1)[0])
      var params: seq[string]
      for i in countup(3, node.len - 1, 2):
        var paramname = node[i + 1].text.split(',', 1)[0].split(')', 1)[0]
        var paramtype = node[i][0].text
        if paramname[0] == '*':
          paramname = paramname.rsplit(" ", 1)[1]
          paramtype = "ptr " & paramtype
        paramname = mapName(paramname)
        params.add &"{paramname}: {mapType(paramtype)}"
      let paramsstr = params.join(", ")
      result.add(&"  {name} = proc({paramsstr}): {returntype} {{.cdecl.}}")

func serializeType(node: XmlNode): Table[string, seq[string]] =
  if node.attrsLen == 0:
    return
  if node.attr("requires") == "vk_platform" or node.attr("category") == "include":
    return
  result["basetypes"] = @[]
  result["enums"] = @[]

  # include-defined types (in platform headers)
  if node.hasAttr("requires") and node.hasAttr("name") and node.attr("category") != "define":
    let platform = "platform/" & PLATFORM_HEADER_MAP[node.attr("requires")]
    if not result.hasKey(platform):
      result[platform] = @[]
    result[platform].add "type " & node.attr(
        "name") & " {.header: \"" & node.attr("requires") & "\".} = object"
  # generic base types
  elif node.attr("category") == "basetype":
    let typechild = node.child("type")
    let namechild = node.child("name")
    if typechild != nil and namechild != nil:
      var typename = typechild[0].text
      if node[2].kind == xnText and node[2].text.strip() == "*":
        typename = &"ptr {typename}"
      result["basetypes"].add &"  {namechild[0].text}* = {mapType(typename)}"
    elif namechild != nil:
      result["basetypes"].add &"  {namechild[0].text}* = object"
  # function pointers need to be handled with structs
  elif node.attr("category") == "funcpointer":
    discard
  # preprocessor defines, ignored
  elif node.attr("category") == "define":
    discard
  # bitmask aliases
  elif node.attr("category") == "bitmask":
    if node.hasAttr("alias"):
      let name = node.attr("name")
      let alias = node.attr("alias")
      result["enums"].add &"  {name}* = {alias}"
  # distinct resource ID types aka handles
  elif node.attr("category") == "handle":
    if not node.hasAttr("alias"):
      let name = node.child("name")[0].text
      var thetype = mapType(node.child("type")[0].text)
      result["basetypes"].add &"  {name}* = distinct {thetype}"
  # enum aliases
  elif node.attr("category") == "enum":
    if node.hasAttr("alias"):
      let name = node.attr("name")
      let alias = node.attr("alias")
      result["enums"].add &"  {name}* = {alias}"
  else:
    discard


proc update(a: var Table[string, seq[string]], b: Table[string, seq[string]]) =
  for k, v in b.pairs:
    if not a.hasKey(k):
      a[k] = @[]
    a[k].add v


proc main() =
  if not os.fileExists("vk.xml"):
    let client = newHttpClient()
    let glUrl = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/main/xml/vk.xml"
    client.downloadFile(glUrl, "vk.xml")

  let api = loadXml("vk.xml")

  const outdir = "src/vulkan_api/output"
  removeDir outdir
  createDir outdir
  createDir outdir / "platform"

  # index all names that are only available on certain platforms
  var platformTypes: Table[string, string]
  for extension in api.findAll("extension"):
    if extension.hasAttr("platform"):
      for thetype in extension.findAll("type"):
        platformTypes[thetype.attr("name")] = extension.attr("platform")
      for command in extension.findAll("command"):
        platformTypes[command.attr("name")] = extension.attr("platform")
    elif extension.attr("name").startsWith("VK_KHR_video"):
      for thetype in extension.findAll("type"):
        platformTypes[thetype.attr("name")] = "vk_video"
      for command in extension.findAll("command"):
        platformTypes[command.attr("name")] = "vk_video"

  var outputFiles = {
    "basetypes": @["type", "  VkHandle* = distinct pointer", "  VkNonDispatchableHandle* = distinct pointer"],
    "structs": @["import ./enums", "import ./basetypes", "type"],
    "enums": @["import ./basetypes", "type"],
  }.toTable

  # enums
  for thetype in api.findAll("type"):
    if thetype.attr("category") == "bitmask" and not thetype.hasAttr("alias") and (not thetype.hasAttr("api") or thetype.attr("api") == "vulkan"):
      let name = thetype.child("name")[0].text
      outputFiles["enums"].add &"  {name}* = distinct VkFlags"
  for theenum in api.findAll("enums"):
    outputFiles["enums"].add serializeEnum(theenum, api)

  # structs and function types need to be in same "type" block to avoid forward-declarations
  outputFiles["structs"].add serializeFunctiontypes(api)
  for thetype in api.findAll("type"):
    if thetype.attr("category") == "struct" or thetype.attr("category") == "union":
      var outfile = "structs"
      if thetype.attr("name") in platformTypes:
        outfile = "platform/" & platformTypes[thetype.attr("name")]
      if not (outfile in outputFiles):
        outputFiles[outfile] = @[]
      outputFiles[outfile].add "type"
      outputFiles[outfile].add serializeStruct(thetype, api)

  # types
  for typesgroup in api.findAll("types"):
    for thetype in typesgroup.findAll("type"):
      outputFiles.update serializeType(thetype)
  for filename, filecontent in outputFiles.pairs:
    writeFile outdir / &"{filename}.nim", filecontent.join("\n")

when isMainModule:
  main()
