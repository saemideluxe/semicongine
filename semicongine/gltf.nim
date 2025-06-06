import std/json
import std/logging
import std/streams
import std/strutils
import std/tables
import std/typetraits

import ./core
import ./images
import ./resources

type
  # === public ===
  GltfData*[TMesh, TMaterial] = object
    scenes*: seq[seq[int]] # each scene has a seq of node indices
    nodes*: seq[GltfNode] # each node has a seq of mesh indices
    meshes*: seq[GltfMesh[TMesh]]
    materials*: seq[TMaterial]
    textures*: seq[Image[BGRA]]

  GltfNode* = object
    name*: string
    properties*: JsonNode
    children*: seq[int]
    mesh*: int = -1
    transform*: Mat4 = Unit4

  GltfMesh*[TMesh] = object
    primitives*: seq[GltfPrimitive[TMesh]]

  GltfPrimitive*[TMesh] = object
    data*: TMesh
    topology*: VkPrimitiveTopology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    material*: int

  MaterialAttributeNames* = object # pbr
    baseColorTexture*: string
    baseColorTextureUv*: string
    baseColorFactor*: string
    metallicRoughnessTexture*: string
    metallicRoughnessTextureUv*: string
    metallicFactor*: string
    roughnessFactor*: string

    # other
    normalTexture*: string
    normalTextureUv*: string
    occlusionTexture*: string
    occlusionTextureUv*: string
    emissiveTexture*: string
    emissiveTextureUv*: string
    emissiveFactor*: string

  MeshAttributeNames* = object
    POSITION*: string
    NORMAL*: string
    TANGENT*: string
    TEXCOORD*: seq[string]
    COLOR*: seq[string]
    JOINTS*: seq[string]
    WEIGHTS*: seq[string]
    indices*: string
    material*: string

  # === internal ===
  glTFHeader = object
    magic: uint32
    version: uint32
    length: uint32

  glTFData = object
    structuredContent: JsonNode
    binaryBufferData: seq[uint8]

proc `=copy`[M](dest: var GltfPrimitive[M], source: GltfPrimitive[M]) {.error.}
proc `=copy`[M](dest: var GltfMesh[M], source: GltfMesh[M]) {.error.}
proc `=copy`(dest: var GltfNode, source: GltfNode) {.error.}
proc `=copy`[S, T](dest: var GltfData[S, T], source: GltfData[S, T]) {.error.}

proc `=copy`(dest: var glTFHeader, source: glTFHeader) {.error.}
proc `=copy`(dest: var glTFData, source: glTFData) {.error.}

const
  HEADER_MAGIC = 0x46546C67
  JSON_CHUNK = 0x4E4F534A
  BINARY_CHUNK = 0x004E4942
  SAMPLER_FILTER_MODE_MAP = {
    9728: VK_FILTER_NEAREST,
    9729: VK_FILTER_LINEAR,
    9984: VK_FILTER_NEAREST,
    9985: VK_FILTER_LINEAR,
    9986: VK_FILTER_NEAREST,
    9987: VK_FILTER_LINEAR,
  }.toTable
  SAMPLER_WRAP_MODE_MAP = {
    33071: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    33648: VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
    10497: VK_SAMPLER_ADDRESS_MODE_REPEAT,
  }.toTable
  PRIMITIVE_MODE_MAP = [
    0: VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
    1: VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
    2: VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
      # not correct, as mode 2 would be a loo, but vulkan has no concept of this
    3: VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
    4: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    5: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP,
    6: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN,
  ]

proc getBufferViewData(
    bufferView: JsonNode, mainBuffer: seq[uint8], baseBufferOffset = 0
): seq[uint8] =
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  result = newSeq[uint8](bufferView["byteLength"].getInt())
  let bufferOffset = bufferView["byteOffset"].getInt() + baseBufferOffset
  var dstPointer = addr result[0]

  if bufferView.hasKey("byteStride"):
    raise newException(Exception, "Unsupported feature: byteStride in buffer view")
  copyMem(dstPointer, addr mainBuffer[bufferOffset], result.len)

proc componentTypeId(t: typedesc): int =
  if t is int8:
    return 5120
  elif t is uint8:
    return 5121
  elif t is int16:
    return 5122
  elif t is uint16:
    return 5123
  elif t is uint32:
    return 5125
  elif t is float32:
    return 5126

proc componentTypeName(id: int): string =
  if id == 5120:
    return int8.name
  elif id == 5121:
    return uint8.name
  elif id == 5122:
    return int16.name
  elif id == 5123:
    return uint16.name
  elif id == 5125:
    return uint32.name
  elif id == 5126:
    return float32.name

proc getAccessorData[T](
    root: JsonNode, accessor: JsonNode, mainBuffer: seq[uint8]
): seq[T] =
  if accessor.hasKey("sparse"):
    raise newException(Exception, "Sparce accessors are currently not supported")

  let componentType = accessor["componentType"].getInt()
  let itemType = accessor["type"].getStr()

  when T is TVec or T is TMat:
    assert componentTypeId(elementType(default(T))) == componentType,
      "Requested type '" & name(elementType(default(T))) &
        $componentTypeId(elementType(default(T))) & "' but actual type is '" &
        componentTypeName(componentType) & "'"
  else:
    assert componentTypeId(T) == componentType,
      "Requested type '" & name(T) & "' but actual type is '" &
        componentTypeName(componentType) & "'"

  when T is TVec:
    when len(default(T)) == 2:
      assert itemType == "VEC2"
    elif len(default(T)) == 3:
      assert itemType == "VEC3"
    elif len(default(T)) == 4:
      assert itemType == "VEC4"
  elif T is TMat:
    when T is Mat2:
      assert itemType == "MAT2"
    elif T is Mat3:
      assert itemType == "MAT3"
    elif T is Mat4:
      assert itemType == "MAT4"
  else:
    assert itemType == "SCALAR"

  result.setLen(accessor["count"].getInt())

  let bufferView = root["bufferViews"][accessor["bufferView"].getInt()]
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"
  let accessorOffset =
    if accessor.hasKey("byteOffset"):
      accessor["byteOffset"].getInt()
    else:
      0
  let bufferOffset =
    (if "byteOffset" in bufferView: bufferView["byteOffset"].getInt()
    else: 0) + accessorOffset
  var dstPointer = result.ToCPointer()

  if bufferView.hasKey("byteStride"):
    warn "Congratulations, you try to test a feature (loading buffer data with stride attributes) that we have no idea where it is used and how it can be tested (need a coresponding *.glb file)."
    # we don't support stride, have to convert stuff here... does this even work?
    for i in 0 ..< result.len:
      copyMem(
        dstPointer,
        addr(mainBuffer[bufferOffset + i * bufferView["byteStride"].getInt()]),
        sizeof(T),
      )
      dstPointer = cast[typeof(dstPointer)](cast[uint](dstPointer) + sizeof(T).uint)
  else:
    copyMem(dstPointer, addr(mainBuffer[bufferOffset]), result.len * sizeof(T))

proc loadTexture(
    root: JsonNode, textureNode: JsonNode, mainBuffer: seq[uint8]
): Image[BGRA] =
  let imageIndex = textureNode["source"].getInt()

  if root["images"][imageIndex].hasKey("uri"):
    raise newException(
      Exception, "Unsupported feature: Cannot load images from external files"
    )

  let bufferView =
    root["bufferViews"][root["images"][imageIndex]["bufferView"].getInt()]
  let img = loadImageData[BGRA](getBufferViewData(bufferView, mainBuffer))
  result = Image[BGRA](width: img.width, height: img.height, data: img.data)

  if textureNode.hasKey("sampler"):
    let sampler = root["samplers"][textureNode["sampler"].getInt()]
    if sampler.hasKey("magFilter"):
      result.magInterpolation = SAMPLER_FILTER_MODE_MAP[sampler["magFilter"].getInt()]
    if sampler.hasKey("minFilter"):
      result.minInterpolation = SAMPLER_FILTER_MODE_MAP[sampler["minFilter"].getInt()]
    if sampler.hasKey("wrapS"):
      result.wrapU = SAMPLER_WRAP_MODE_MAP[sampler["wrapS"].getInt()]
    if sampler.hasKey("wrapT"):
      result.wrapV = SAMPLER_WRAP_MODE_MAP[sampler["wrapT"].getInt()]

proc getVec4f(node: JsonNode): Vec4f =
  vec4(node[0].getFloat(), node[1].getFloat(), node[2].getFloat(), node[3].getFloat())

proc loadMaterial[TMaterial](
    root: JsonNode,
    materialNode: JsonNode,
    mapping: static MaterialAttributeNames,
    mainBuffer: seq[uint8],
): TMaterial =
  result = TMaterial()

  let pbr {.hint[XDeclaredButNotUsed]: off.} = materialNode["pbrMetallicRoughness"]
  for name, value in fieldPairs(result):
    for gltfAttribute, mappedName in fieldPairs(mapping):
      when gltfAttribute != "" and name == mappedName:
        if pbr.hasKey(gltfAttribute):
          when gltfAttribute.endsWith("Texture"):
            value = typeof(value)(pbr[gltfAttribute]["index"].getInt())
          elif gltfAttribute.endsWith("TextureUv"):
            value = typeof(pbr[gltfAttribute[0 ..< ^2]]["index"].getInt())
          elif gltfAttribute in ["baseColorFactor", "emissiveFactor"]:
            value = pbr[gltfAttribute].getVec4f()
          elif gltfAttribute in ["metallicFactor", "roughnessFactor"]:
            value = pbr[gltfAttribute].getFloat()
          else:
            {.error: "Unsupported gltf material attribute".}

proc loadPrimitive[TMesh](
    root: JsonNode,
    primitive: JsonNode,
    mapping: static MeshAttributeNames,
    mainBuffer: seq[uint8],
): GltfPrimitive[TMesh] =
  result = GltfPrimitive[TMesh](data: TMesh())

  if primitive.hasKey("mode"):
    result.topology = PRIMITIVE_MODE_MAP[primitive["mode"].getInt()]

  if primitive.hasKey("material"):
    result.material = primitive["material"].getInt()

  if primitive.hasKey("indices"):
    doAssert mapping.indices != "", "Mesh requires indices"

  for resultFieldName, resultValue in fieldPairs(result.data):
    for gltfAttribute, mappedName in fieldPairs(mapping):
      when typeof(mappedName) is seq:
        when resultFieldName in mappedName:
          var i = 0
          for mappedIndexName in mappedName:
            if gltfAttribute != "" and resultFieldName == mappedIndexName:
              assert resultValue is GPUData,
                "Attribute " & resultFieldName & " must be of type GPUData"
              let gltfAttributeIndexed = gltfAttribute & "_" & $i
              if primitive["attributes"].hasKey(gltfAttributeIndexed):
                let accessor = primitive["attributes"][gltfAttributeIndexed].getInt()
                resultValue.data = getAccessorData[elementType(resultValue.data)](
                  root, root["accessors"][accessor], mainBuffer
                )
          inc i
      elif typeof(mappedName) is string:
        when resultFieldName == mappedName:
          assert resultValue is GPUData or gltfAttribute == "material",
            "Attribute " & resultFieldName & " must be of type GPUData"
          when gltfAttribute == "indices":
            if primitive.hasKey(gltfAttribute):
              let accessor = primitive[gltfAttribute].getInt()
              resultValue.data = getAccessorData[elementType(resultValue.data)](
                root, root["accessors"][accessor], mainBuffer
              )
          elif gltfAttribute == "material":
            if primitive.hasKey(gltfAttribute):
              # assuming here that materials IDs are a normal field on the mesh, not GPUData
              resultValue = typeof(resultValue)(primitive[gltfAttribute].getInt())
          else:
            if primitive["attributes"].hasKey(gltfAttribute):
              let accessor = primitive["attributes"][gltfAttribute].getInt()
              resultValue.data = getAccessorData[elementType(resultValue.data)](
                root, root["accessors"][accessor], mainBuffer
              )

proc loadNode(node: JsonNode): GltfNode =
  result = GltfNode()
  if "name" in node:
    result.name = node["name"].getStr()
  if "extras" in node:
    result.properties = node["extras"]
  if "mesh" in node:
    result.mesh = node["mesh"].getInt()
  if "children" in node:
    for child in items(node["children"]):
      result.children.add child.getInt()
  if "matrix" in node:
    for i in 0 ..< node["matrix"].len:
      result.transform[i] = node["matrix"][i].getFloat()
    result.transform = result.transform.transposed()
  else:
    var (t, r, s) = (Unit4, Unit4, Unit4)
    if "translation" in node:
      t = translate(
        float32(node["translation"][0].getFloat()),
        float32(node["translation"][1].getFloat()),
        float32(node["translation"][2].getFloat()),
      )
    if "rotation" in node:
      t = rotate(
        float32(node["rotation"][3].getFloat()),
        vec3(
          float32(node["rotation"][0].getFloat()),
          float32(node["rotation"][1].getFloat()),
          float32(node["rotation"][2].getFloat()),
        ),
      )
    if "scale" in node:
      t = scale(
        float32(node["scale"][0].getFloat()),
        float32(node["scale"][1].getFloat()),
        float32(node["scale"][2].getFloat()),
      )

    result.transform = t * r * s

proc ReadglTF*[TMesh, TMaterial](
    stream: Stream,
    meshAttributesMapping: static MeshAttributeNames,
    materialAttributesMapping: static MaterialAttributeNames,
): GltfData[TMesh, TMaterial] =
  var
    header: glTFHeader
    data: glTFData

  for name, value in fieldPairs(header):
    stream.read(value)

  assert header.magic == HEADER_MAGIC
  assert header.version == 2

  var chunkLength = stream.readUint32()
  assert stream.readUint32() == JSON_CHUNK
  data.structuredContent = parseJson(stream.readStr(int(chunkLength)))

  chunkLength = stream.readUint32()
  assert stream.readUint32() == BINARY_CHUNK
  data.binaryBufferData.setLen(chunkLength)
  assert stream.readData(addr data.binaryBufferData[0], int(chunkLength)) ==
    int(chunkLength)

  # check that the refered buffer is the same as the binary chunk
  # external binary buffers are not supported
  assert data.structuredContent["buffers"].len == 1
  assert not data.structuredContent["buffers"][0].hasKey("uri")
  let bufferLenDiff =
    int(chunkLength) - data.structuredContent["buffers"][0]["byteLength"].getInt()
  assert 0 <= bufferLenDiff and bufferLenDiff <= 3
    # binary buffer may be aligned to 4 bytes

  debug "Loading mesh: ", data.structuredContent.pretty

  if "materials" in data.structuredContent:
    for materialnode in items(data.structuredContent["materials"]):
      result.materials.add loadMaterial[TMaterial](
        data.structuredContent, materialnode, materialAttributesMapping,
        data.binaryBufferData,
      )

  if "textures" in data.structuredContent:
    for texturenode in items(data.structuredContent["textures"]):
      result.textures.add loadTexture(
        data.structuredContent, texturenode, data.binaryBufferData
      )

  if "meshes" in data.structuredContent:
    for mesh in items(data.structuredContent["meshes"]):
      var meshObj: GltfMesh[TMesh]
      for primitive in items(mesh["primitives"]):
        meshObj.primitives.add loadPrimitive[TMesh](
          data.structuredContent, primitive, meshAttributesMapping,
          data.binaryBufferData,
        )
      result.meshes.add meshObj

  if "nodes" in data.structuredContent:
    for node in items(data.structuredContent["nodes"]):
      result.nodes.add loadNode(node)

  if "scenes" in data.structuredContent:
    for scene in items(data.structuredContent["scenes"]):
      if "nodes" in scene:
        var nodes: seq[int]
        for nodeId in items(scene["nodes"]):
          nodes.add nodeId.getInt()
        result.scenes.add nodes

proc loadMeshes*[TMesh, TMaterial](
    path: string,
    meshAttributesMapping: static MeshAttributeNames,
    materialAttributesMapping: static MaterialAttributeNames,
    package = DEFAULT_PACKAGE,
): GltfData[TMesh, TMaterial] {.gcsafe.} =
  ReadglTF[TMesh, TMaterial](
    stream = loadResource_intern(path, package = package),
    meshAttributesMapping = meshAttributesMapping,
    materialAttributesMapping = materialAttributesMapping,
  )
