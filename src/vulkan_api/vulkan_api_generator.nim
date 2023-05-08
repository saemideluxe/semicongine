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
    "X11/Xlib.h": @["xlib", "xlib_xrandr"],
    "X11/extensions/Xrandr.h": @["xlib_xrandr"],
    "wayland-client.h": @["wayland"],
    "windows.h": @["win32"],
    "xcb/xcb.h": @["xcb"],
    "directfb.h": @["directfb"],
    "zircon/types.h": @["fuchsia"],
    "ggp_c/vulkan_types.h": @["ggp"],
    "screen/screen.h": @["screen"],
    "nvscisync.h": @["sci"],
    "nvscibuf.h": @["sci"],
    "vk_video/vulkan_video_codec_h264std.h": @["provisional"],
    "vk_video/vulkan_video_codec_h264std_decode.h": @["provisional"],
    "vk_video/vulkan_video_codec_h264std_encode.h": @["provisional"],
    "vk_video/vulkan_video_codec_h265std.h": @["provisional"],
    "vk_video/vulkan_video_codec_h265std_decode.h": @["provisional"],
    "vk_video/vulkan_video_codec_h265std_encode.h": @["provisional"],
  }.toTable
  MAP_KEYWORD = {
    "object": "theobject",
    "type": "thetype",
  }.toTable
  SPECIAL_DEPENDENCIES = {
    "VK_NV_ray_tracing": "VK_KHR_ray_tracing_pipeline",
  }.toTable
  # will be directly loaded at startup
  IGNORED_COMMANDS = @["vkGetInstanceProcAddr"]
  # can be loaded without a vulkan instance
  GLOBAL_COMMANDS = @[
    "vkEnumerateInstanceVersion",
    "vkEnumerateInstanceExtensionProperties",
    "vkEnumerateInstanceLayerProperties",
    "vkCreateInstance",
  ]

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
func findType(declNode: XmlNode): string =
  # examples:
  # char** -> cstringArray
  # void* -> pointer
  # char* -> cstring
  #
  # int* -> ptr int
  # void** -> ptr pointer
  # int** -> ptr ptr int
  var basetype = ""
  var apointer = ""
  var arraylen = ""
  for child in declNode:
    if child.kind == xnText:
        if "[" in child.text:
          if "[" in child.text and "]" in child.text:
            arraylen = child.text.strip(chars={'[', ']'}).replace("][", "*")
          else:
            arraylen = declNode.child("enum")[0].text
        else:
          for i in 0 ..< child.text.count('*'):
            apointer = apointer & "ptr "
    elif child.tag == "type":
      basetype = mapType(child[0].text)
  if basetype == "void":
    if apointer.count("ptr ") > 0:
      basetype = "pointer"
      apointer = apointer[0 ..< ^4]
  elif basetype == "char":
    if apointer.count("ptr ") == 1:
      basetype = "cstring"
      apointer = ""
    elif apointer.count("ptr ") == 2:
      basetype = "cstringArray"
      apointer = ""
    elif apointer.count("ptr ") > 2:
      basetype = "cstringArray"
      apointer = apointer[0 ..< ^8]

  result = &"{apointer}{basetype}"
  if arraylen != "":
    result = &"array[{arraylen}, {result}]"

# serializers
# return values and whether this is a bitfield
func serializeEnum(node: XmlNode, api: XmlNode): (seq[string], string) =
  let name = node.attr("name")
  if name == "":
    return result

  var reservedNames: seq[string]
  for t in api.findAll("type"):
    reservedNames.add t.attr("name").replace("_", "").toLower()

  # find additional enum defintion in feature definitions
  var values: Table[int, string]
  for feature in api.findAll("feature"):
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
  for extension in api.findAll("extension"):
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
      result[0].add "  " & name & "* {.size: sizeof(cint).} = enum"
      for (value, name) in tableSorted(values):
        var thename = name
        if name.replace("_", "").toLower() in reservedNames:
          thename = thename & "_ENUM"
        let enumEntry = &"    {thename} = {value}"
        result[0].add enumEntry

  # generate bitsets (normal enums in the C API, but bitfield-enums in Nim)
  elif node.attr("type") == "bitmask":
    var predefined_enum_sets: seq[string]
    for value in node.findAll("enum"):
      if value.hasAttr("bitpos"):
        values[smartParseInt(value.attr("bitpos"))] = value.attr("name")
      elif node.attr("name") == "VkVideoEncodeRateControlModeFlagBitsKHR": # special exception, for some reason this has values instead of bitpos
        values[smartParseInt(value.attr("value"))] = value.attr("name")
      elif value.hasAttr("value"): # create a const that has multiple bits set
        predefined_enum_sets.add &"  {value.attr(\"name\")}* = {value.attr(\"value\")}"

    if values.len > 0:
      let cApiName = name.replace("FlagBits", "Flags")
      result[1] = cApiName
      if node.hasAttr("bitwidth"):
        result[0].add "  " & name & "* {.size: 8.} = enum"
      else:
        result[0].add "  " & name & "* {.size: sizeof(cint).} = enum"
      for (bitpos, enumvalue) in tableSorted(values):
        var value = "00000000000000000000000000000000"# makes the bit mask nicely visible
        if node.hasAttr("bitwidth"): # assumes this is always 64
          value = value & value
        value[^(bitpos + 1)] = '1'
        let enumEntry = &"    {enumvalue} = 0b{value}"
        if not (enumEntry in result[0]): # the specs define duplicate entries for backwards compat
          result[0].add enumEntry
      if node.hasAttr("bitwidth"): # assuming this attribute is always 64
        if values.len > 0:
          result[0].add &"""func toBits*(flags: openArray[{name}]): {cApiName} =
    for flag in flags:
      result = {cApiName}(uint64(result) or uint64(flag))"""
          result[0].add &"""func toEnums*(number: {cApiName}): seq[{name}] =
    for value in {name}.items:
      if (cast[uint64](value) and uint64(number)) > 0:
        result.add value"""
          result[0].add &"proc `==`*(a, b: {cApiName}): bool = uint64(a) == uint64(b)"
      else:
        if values.len > 0:
          result[0].add &"""func toBits*(flags: openArray[{name}]): {cApiName} =
    for flag in flags:
      result = {cApiName}(uint(result) or uint(flag))"""
          result[0].add &"""func toEnums*(number: {cApiName}): seq[{name}] =
    for value in {name}.items:
      if (value.ord and cint(number)) > 0:
        result.add value"""
          result[0].add &"proc `==`*(a, b: {cApiName}): bool = cint(a) == cint(b)"
      if predefined_enum_sets.len > 0:
        result[0].add "const"
        result[0].add predefined_enum_sets
      result[0].add "type"


func serializeStruct(node: XmlNode): seq[string] =
  let name = node.attr("name")
  var union = ""
  if node.attr("category") == "union":
    union = "{.union.} "
  result.add &"  {name}* {union}= object"
  for member in node.findAll("member"):
    if not member.hasAttr("api") or member.attr("api") == "vulkan":
      let fieldname = member.child("name")[0].text.strip(chars={'_'})
      result.add &"    {mapName(fieldname)}*: {findType(member)}"

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
      result.add(&"  {name}* = proc({paramsstr}): {returntype} {{.cdecl.}}")

func serializeConsts(api: XmlNode): seq[string] =
  result = @["const"]
  for enums in api.findAll("enums"):
    if enums.attr("name") == "API Constants":
      for theenum in enums.findAll("enum"):
        if theenum.hasAttr("alias"):
          result.add &"  {theenum.attr(\"name\")}* = {theenum.attr(\"alias\")}"
        else:
          var value = theenum.attr("value").strip(chars={'(', ')'})
          if value.endsWith("U"):
            value = value[0..^2] & "'u32"
          elif value.endsWith("ULL"):
            value = value[0..^4] & "'u64"
          if value[0] == '~':
            value = "not " & value[1..^1]
          result.add &"  {theenum.attr(\"name\")}*: {mapType(theenum.attr(\"type\"))} = {value}"

func serializeType(node: XmlNode, headerTypes: Table[string, string]): Table[string, seq[string]] =
  if node.attrsLen == 0:
    return
  if node.attr("requires") == "vk_platform" or node.attr("category") == "include":
    return
  result["basetypes"] = @[]
  result["enums"] = @[]

  # include-defined types (in platform headers)
  if node.attr("name") in headerTypes:
    for platform in PLATFORM_HEADER_MAP[node.attr("requires")]:
      let platformfile = "platform/" & platform
      if not result.hasKey(platformfile):
        result[platformfile] = @[]
      result[platformfile].add "  " & node.attr("name").strip(chars={'_'}) & " *{.header: \"" & node.attr("requires") & "\".} = object"
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

func serializeCommand(node: XmlNode): (string, string) =
  let
    proto = node.child("proto")
    resulttype = mapType(proto.child("type")[0].text)
    name = proto.child("name")[0].text
  var params: seq[string]
  for param in node:
    if param.tag == "param" and param.attr("api") in ["", "vulkan"]:
      let fieldname = param.child("name")[0].text.strip(chars={'_'})
      params.add &"{mapName(fieldname)}: {findType(param)}"
  let allparams = params.join(", ")
  return (name, &"proc({allparams}): {resulttype} {{.stdcall.}}")


proc update(a: var Table[string, seq[string]], b: Table[string, seq[string]]) =
  for k, v in b.pairs:
    if not a.hasKey(k):
      a[k] = @[]
    a[k].add v


proc main() =
  let file = getTempDir() / "vk.xml"
  if not os.fileExists(file):
    let client = newHttpClient()
    let glUrl = "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/main/xml/vk.xml"
    client.downloadFile(glUrl, file)

  let api = loadXml(file)

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
        platformTypes[thetype.attr("name")] = "provisional"
      for command in extension.findAll("command"):
        platformTypes[command.attr("name")] = "provisional"

  var outputFiles = {
    "basetypes": @[
      "import std/dynlib",
      "import std/tables",
      "import std/strutils",
      "import std/logging",
      "import std/typetraits",
      "import std/macros",
      "import std/private/digitsutils",
      "type",
      "  VkHandle* = distinct uint",
      "  VkNonDispatchableHandle* = distinct uint",
      "when defined(linux):",
      "  let vulkanLib* = loadLib(\"libvulkan.so.1\")",
      "when defined(windows):",
      "  let vulkanLib* = loadLib(\"vulkan-1.dll\")",
      "if vulkanLib == nil:",
      "  raise newException(Exception, \"Unable to load vulkan library\")",
      "func VK_MAKE_API_VERSION*(variant: uint32, major: uint32, minor: uint32, patch: uint32): uint32 {.compileTime.} =",
      "  (variant shl 29) or (major shl 22) or (minor shl 12) or patch",
      "",
      """template checkVkResult*(call: untyped) =
  when defined(release):
    discard call
  else:
    # yes, a bit cheap, but this is only for nice debug output
    var callstr = astToStr(call).replace("\n", "")
    while callstr.find("  ") >= 0:
      callstr = callstr.replace("  ", " ")
    debug "CALLING vulkan: ", callstr
    let value = call
    if value != VK_SUCCESS:
      error "Vulkan error: ", astToStr(call), " returned ", $value
      raise newException(Exception, "Vulkan error: " & astToStr(call) &
          " returned " & $value)""",
    """
# custom enum iteration (for enum values > 2^16)
macro enumFullRange(a: typed): untyped =
  newNimNode(nnkBracket).add(a.getType[1][1..^1])

iterator items*[T: HoleyEnum](E: typedesc[T]): T =
  for a in enumFullRange(E): yield a""",
    ],
    "structs": @["type"],
    "enums": @["type"],
    "commands": @[],
  }.toTable
  outputFiles["basetypes"].add serializeConsts(api)
  outputFiles["basetypes"].add "type"

  # enums
  for thetype in api.findAll("type"):
    if thetype.attr("category") == "bitmask" and not thetype.hasAttr("alias") and (not thetype.hasAttr("api") or thetype.attr("api") == "vulkan"):
      let name = thetype.child("name")[0].text
      outputFiles["enums"].add &"  {name}* = distinct VkFlags"

  var bitfields: Table[string, string]
  outputFiles["enums"].add "let vkGetInstanceProcAddr = cast[proc(instance: VkInstance, name: cstring): pointer {.stdcall.}](checkedSymAddr(vulkanLib, \"vkGetInstanceProcAddr\"))"
  outputFiles["enums"].add "type"
  for theenum in api.findAll("enums"):
    let (enums, bitFieldName) = serializeEnum(theenum, api)
    outputFiles["enums"].add enums
    if bitFieldName != "":
      bitfields[theenum.attr("name")] = bitFieldName

  # bitmask-to-string functions
  for thetype in api.findAll("type"):
    if thetype.attr("name") in bitfields:
      let name = bitfields[thetype.attr("name")]
      let stringfunc = &"proc `$`*(bitset: {name}): string = $toEnums(bitset)"
      if not (stringfunc in outputFiles["enums"]):
        outputFiles["enums"].add stringfunc
  outputFiles["enums"].add "type"

  # structs and function types need to be in same "type" block to avoid forward-declarations
  outputFiles["structs"].add serializeFunctiontypes(api)
  for thetype in api.findAll("type"):
    if thetype.attr("category") == "struct" or thetype.attr("category") == "union":
      var outfile = "structs"
      if thetype.attr("name") in platformTypes:
        outfile = "platform/" & platformTypes[thetype.attr("name")]
      if not (outfile in outputFiles):
        outputFiles[outfile] = @[]
      outputFiles[outfile].add serializeStruct(thetype)

  # types
  var headerTypes: Table[string, string]
  for types in api.findAll("types"):
    for thetype in types.findAll("type"):
      if thetype.attrsLen == 2 and thetype.hasAttr("requires") and thetype.hasAttr("name") and thetype.attr("requires") != "vk_platform":
        let name = thetype.attr("name")
        let incld = thetype.attr("requires")
        headerTypes[name] = &"{name} {{.header: \"{incld}\".}} = object"

  for typesgroup in api.findAll("types"):
    for thetype in typesgroup.findAll("type"):
      outputFiles.update serializeType(thetype, headerTypes)

  for typesgroup in api.findAll("types"):
    for node in typesgroup.findAll("type"):
      if node.attr("category") == "handle":
        if not node.hasAttr("alias"):
          let name = node.child("name")[0].text
          outputFiles["basetypes"].add &"proc `$`*(handle: {name}): string = \"{name}(\" & $(uint(handle)) & \")\""
          outputFiles["basetypes"].add &"proc valid*(handle: {name}): bool = uint(handle) != 0"
          outputFiles["basetypes"].add &"proc reset*(handle: var {name}) = handle = {name}(0)"
          outputFiles["basetypes"].add &"proc `==`*(a, b: {name}): bool = uint(a) == uint(b)"
          

  # commands aka functions
  var varDecls: Table[string, string]
  var procLoads: Table[string, string] # procloads need to be packed into feature/extension loader procs
  for commands in api.findAll("commands"):
    for command in commands.findAll("command"):
      if command.attr("api") != "vulkansc" and not (command.attr("name") in IGNORED_COMMANDS):
        if command.hasAttr("alias"):
          let name = command.attr("name")
          let alias = command.attr("alias")
          let thetype = varDecls[alias].split(":", 1)[1].strip()
          varDecls[name] = &"  {name}*: {thetype}"
          procLoads[name] = &"  {name} = {alias}"
        else:
          let (name, thetype) = serializeCommand(command)
          varDecls[name] = &"  {name}*: {thetype}"
          procLoads[name] = &"  {name} = cast[{thetype}](vkGetInstanceProcAddr(instance, \"{name}\"))"
  var declared: seq[string]
  var featureloads: seq[string]
  for feature in api.findAll("feature"):
    if feature.attr("api") in ["vulkan", "vulkan,vulkansc"]:
      let name = feature.attr("name")
      outputFiles["commands"].add &"# feature {name}"
      outputFiles["commands"].add "var"
      for command in feature.findAll("command"):
        if not (command.attr("name") in declared) and not (command.attr("name") in IGNORED_COMMANDS):
          outputFiles["commands"].add varDecls[command.attr("name")]
          declared.add command.attr("name")
      featureloads.add &"load{name}"
      outputFiles["commands"].add &"proc load{name}*(instance: VkInstance) ="
      for command in feature.findAll("command"):
        if not (command.attr("name") in IGNORED_COMMANDS & GLOBAL_COMMANDS):
          outputFiles["commands"].add procLoads[command.attr("name")]
    outputFiles["commands"].add ""
  outputFiles["commands"].add ["proc loadVulkan*(instance: VkInstance) ="]
  for l in featureloads:
    outputFiles["commands"].add [&"  {l}(instance)"]
  outputFiles["commands"].add ""

  # for promoted extensions, dependants need to call the load-function of the promoted feature/extension
  # use table to store promotions
  var promotions: Table[string, string]
  for extensions in api.findAll("extensions"):
    for extension in extensions.findAll("extension"):
      if extension.hasAttr("promotedto"):
        promotions[extension.attr("name")] = extension.attr("promotedto")

  var extensionDependencies: Table[string, (seq[string], XmlNode)]
  var features: seq[string]
  for feature in api.findAll("feature"):
    features.add feature.attr("name")
  for extensions in api.findAll("extensions"):
    for extension in extensions.findAll("extension"):
      let name = extension.attr("name")
      extensionDependencies[name] = (@[], extension)
      if extension.hasAttr("depends"):
        extensionDependencies[name] = (extension.attr("depends").split("+"), extension)
        if extension.attr("depends").startsWith("("): # no need for full tree parser, only single place where we can use a feature
          let dependencies = extension.attr("depends").rsplit({')'}, 1)[1][1 .. ^1].split("+")
          extensionDependencies[name] = (dependencies, extension)
      if name in SPECIAL_DEPENDENCIES:
        extensionDependencies[name][0].add SPECIAL_DEPENDENCIES[name]

  # order dependencies to generate them in correct order
  var dependencyOrderedExtensions: OrderedTable[string, XmlNode]
  while extensionDependencies.len > 0:
    var delkeys: seq[string]
    for extensionName, (dependencies, extension) in extensionDependencies.pairs:
      var missingExtension = false
      for dep in dependencies:
        let realdep = promotions.getOrDefault(dep, dep)
        if not (realdep in dependencyOrderedExtensions) and not (realdep in features):
          missingExtension = true
          break
      if not missingExtension:
        dependencyOrderedExtensions[extensionName] = extension
        delkeys.add extensionName
    for key in delkeys:
      extensionDependencies.del key

  var extensionLoaderMap: Table[string, Table[string, string]]
  for extension in dependencyOrderedExtensions.values:
    if extension.hasAttr("promotedto"): # will be loaded in promoted place
      continue
    if extension.attr("supported") in ["", "vulkan", "vulkan,vulkansc"]:
      var file = "commands"
      var platform = extension.attr("platform")
      if extension.attr("name").startsWith("VK_KHR_video"):
        platform = "provisional"
      if platform != "":
        file = "platform/" & platform
      let name = extension.attr("name")
      if extension.findAll("command").len > 0:
        outputFiles[file].add &"# extension {name}"
        outputFiles[file].add "var"
        for command in extension.findAll("command"):
          if not (command.attr("name") in declared) and not (command.attr("name") in IGNORED_COMMANDS):
            outputFiles[file].add varDecls[command.attr("name")]
            declared.add command.attr("name")
      outputFiles[file].add &"proc load{name}*(instance: VkInstance) ="
      if not (platform in extensionLoaderMap):
        extensionLoaderMap[platform] = Table[string, string]()
      extensionLoaderMap[platform][name] = &"load{name}"
      var addedFunctionBody = false
      if extension.hasAttr("depends"):
        for dependency in extension.attr("depends").split("+"):
          # need to check since some extensions have no commands and therefore no load-function
          outputFiles[file].add &"  load{promotions.getOrDefault(dependency, dependency)}(instance)"
          addedFunctionBody = true
      for command in extension.findAll("command"):
        outputFiles[file].add procLoads[command.attr("name")]
        addedFunctionBody = true
      if not addedFunctionBody:
        outputFiles[file].add "  discard"
      outputFiles[file].add ""

  var mainout: seq[string]
  for section in ["basetypes", "enums", "structs", "commands"]:
    mainout.add outputFiles[section]
  mainout.add "var EXTENSION_LOADERS = {"
  for extension, loader in extensionLoaderMap[""].pairs:
    mainout.add &"  \"{extension}\": {loader},"
  mainout.add "}.toTable"
  for platform in api.findAll("platform"):
    mainout.add &"when defined({platform.attr(\"protect\")}):"
    mainout.add &"  ../vulkan/include platform/{platform.attr(\"name\")}"
    if platform.attr("name") in extensionLoaderMap:
      for extension, loader in extensionLoaderMap[platform.attr("name")].pairs:
        mainout.add &"  EXTENSION_LOADERS[\"{extension}\"] = {loader}"

  mainout.add ""
  mainout.add "proc loadExtension*(instance: VkInstance, extension: string) = EXTENSION_LOADERS[extension](instance)"
  mainout.add ""
  mainout.add "# load global functions immediately"
  mainout.add "block globalFunctions:"
  mainout.add "  let instance = VkInstance(0)"
  for l in GLOBAL_COMMANDS:
    mainout.add procLoads[l]
  mainout.add ""
  mainout.add "converter VkBool2NimBool*(a: VkBool32): bool = a > 0"
  mainout.add "converter NimBool2VkBool*(a: bool): VkBool32 = VkBool32(a)"
  mainout.add "proc `$`*(x: uint32): string {.raises: [].} = addInt(result, x)"

  writeFile outdir / &"api.nim", mainout.join("\n")


  for filename, filecontent in outputFiles.pairs:
    if filename.startsWith("platform/"):
      writeFile outdir / &"{filename}.nim", (@[
      "type"
      ] & filecontent).join("\n")

when isMainModule:
  main()
