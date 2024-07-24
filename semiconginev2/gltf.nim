type
  GLTFMesh*[TMesh, TMaterial] = object
    scenes*: seq[seq[int]] # each scene has a seq of node indices
    nodes*: seq[seq[int]]  # each node has a seq of mesh indices
    meshes*: seq[TMesh]
    materials*: seq[TMaterial]
    textures*: seq[Image[BGRA]]
  glTFHeader = object
    magic: uint32
    version: uint32
    length: uint32
  glTFData = object
    structuredContent: JsonNode
    binaryBufferData: seq[uint8]

  MaterialAttributeNames = object
    # pbr
    baseColorTexture: string
    baseColorTextureUv: string
    baseColorFactor: string
    metallicRoughnessTexture: string
    metallicRoughnessTextureUv: string
    metallicFactor: string
    roughnessFactor: string

    # other
    normalTexture: string
    normalTextureUv: string
    occlusionTexture: string
    occlusionTextureUv: string
    emissiveTexture: string
    emissiveTextureUv: string
    emissiveFactor: string

#[
static:
  let TypeIds = {
    int8: 5120,
    uint8: 5121,
    int16: 5122,
    uint16: 5123,
    uint32: 5125,
    float32: 5126,
  }.toTable
]#

const
  HEADER_MAGIC = 0x46546C67
  JSON_CHUNK = 0x4E4F534A
  BINARY_CHUNK = 0x004E4942
  #[
  ACCESSOR_TYPE_MAP = {
    5120: Int8,
    5121: UInt8,
    5122: Int16,
    5123: UInt16,
    5125: UInt32,
    5126: Float32,
  }.toTable
  ]#
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
    10497: VK_SAMPLER_ADDRESS_MODE_REPEAT
  }.toTable

#[
proc getGPUType(accessor: JsonNode, attribute: string): DataType =
  # TODO: no full support for all datatypes that glTF may provide
  # semicongine/core/gpu_data should maybe generated with macros to allow for all combinations
  let componentType = ACCESSOR_TYPE_MAP[accessor["componentType"].getInt()]
  let theType = accessor["type"].getStr()
  case theType
  of "SCALAR":
    return componentType
  of "VEC2":
    case componentType
    of UInt32: return Vec2U32
    of Float32: return Vec2F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
  of "VEC3":
    case componentType
    of UInt32: return Vec3U32
    of Float32: return Vec3F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
  of "VEC4":
    case componentType
    of UInt32: return Vec4U32
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
  of "MAT2":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
  of "MAT3":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
  of "MAT4":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type for attribute '{attribute}': {componentType} {theType}")
]#

proc getBufferViewData(bufferView: JsonNode, mainBuffer: seq[uint8], baseBufferOffset = 0): seq[uint8] =
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  result = newSeq[uint8](bufferView["byteLength"].getInt())
  let bufferOffset = bufferView["byteOffset"].getInt() + baseBufferOffset
  var dstPointer = addr result[0]

  if bufferView.hasKey("byteStride"):
    raise newException(Exception, "Unsupported feature: byteStride in buffer view")
  copyMem(dstPointer, addr mainBuffer[bufferOffset], result.len)

#[
proc getAccessorData(root: JsonNode, accessor: JsonNode, mainBuffer: seq[uint8]): DataList =
  result = InitDataList(thetype = accessor.getGPUType("??"))
  result.SetLen(accessor["count"].getInt())

  let bufferView = root["bufferViews"][accessor["bufferView"].getInt()]
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  if accessor.hasKey("sparse"):
    raise newException(Exception, "Sparce accessors are currently not implemented")

  let accessorOffset = if accessor.hasKey("byteOffset"): accessor["byteOffset"].getInt() else: 0
  let length = bufferView["byteLength"].getInt()
  let bufferOffset = bufferView["byteOffset"].getInt() + accessorOffset
  var dstPointer = result.GetPointer()

  if bufferView.hasKey("byteStride"):
    warn "Congratulations, you try to test a feature (loading buffer data with stride attributes) that we have no idea where it is used and how it can be tested (need a coresponding *.glb file)."
    # we don't support stride, have to convert stuff here... does this even work?
    for i in 0 ..< int(result.len):
      copyMem(dstPointer, addr mainBuffer[bufferOffset + i * bufferView["byteStride"].getInt()], int(result.thetype.Size))
      dstPointer = cast[pointer](cast[uint](dstPointer) + result.thetype.Size)
  else:
    copyMem(dstPointer, addr mainBuffer[bufferOffset], length)
]#

proc loadTexture(root: JsonNode, textureNode: JsonNode, mainBuffer: seq[uint8]): Image[BGRA] =

  let imageIndex = textureNode["source"].getInt()

  if root["images"][imageIndex].hasKey("uri"):
    raise newException(Exception, "Unsupported feature: Cannot load images from external files")
  let imageType = root["images"][imageIndex]["mimeType"].getStr()
  assert imageType == "image/png", "glTF loader currently only supports PNG"

  let bufferView = root["bufferViews"][root["images"][imageIndex]["bufferView"].getInt()]
  result = LoadImage[BGRA](getBufferViewData(bufferView, mainBuffer))

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
  NewVec4f(node[0].getFloat(), node[1].getFloat(), node[2].getFloat(), node[3].getFloat())

proc loadMaterial[TMaterial](
  root: JsonNode,
  materialNode: JsonNode,
  mainBuffer: seq[uint8],
  mapping: static MaterialAttributeNames
): TMaterial =
  result = TMaterial()

  let pbr = materialNode["pbrMetallicRoughness"]
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


#[

proc loadMesh(meshname: string, root: JsonNode, primitiveNode: JsonNode, materials: seq[MaterialData], mainBuffer: seq[uint8]): Mesh =
  if primitiveNode.hasKey("mode") and primitiveNode["mode"].getInt() != 4:
    raise newException(Exception, "Currently only TRIANGLE mode is supported for geometry mode")

  var indexType = None
  let indexed = primitiveNode.hasKey("indices")
  if indexed:
    # TODO: Tiny indices
    var indexCount = root["accessors"][primitiveNode["indices"].getInt()]["count"].getInt()
    if indexCount < int(high(uint16)):
      indexType = Small
    else:
      indexType = Big

  result = Mesh(
    instanceTransforms: @[Unit4F32],
    indexType: indexType,
    name: meshname,
    vertexCount: 0,
  )

  for attribute, accessor in primitiveNode["attributes"].pairs:
    let data = root.getAccessorData(root["accessors"][accessor.getInt()], mainBuffer)
    if result.vertexCount == 0:
      result.vertexCount = data.len
    assert data.len == result.vertexCount
    result[].InitVertexAttribute(attribute.toLowerAscii, data)

  if primitiveNode.hasKey("material"):
    let materialId = primitiveNode["material"].getInt()
    result[].material = materials[materialId]
  else:
    result[].material = EMPTY_MATERIAL.InitMaterialData()

  if primitiveNode.hasKey("indices"):
    assert result[].indexType != None
    let data = root.getAccessorData(root["accessors"][primitiveNode["indices"].getInt()], mainBuffer)
    var tri: seq[int]
    case data.thetype
      of UInt16:
        for entry in data[uint16][]:
          tri.add int(entry)
          if tri.len == 3:
            # FYI gltf uses counter-clockwise indexing
            result[].AppendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      of UInt32:
        for entry in data[uint32][]:
          tri.add int(entry)
          if tri.len == 3:
            # FYI gltf uses counter-clockwise indexing
            result[].AppendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      else:
        raise newException(Exception, &"Unsupported index data type: {data.thetype}")
  # TODO: getting from gltf to vulkan system is still messed up somehow, see other TODO
  Transform[Vec3f](result[], "position", Scale(1, -1, 1))


proc loadNode(root: JsonNode, node: JsonNode, materials: seq[MaterialData], mainBuffer: var seq[uint8]): MeshTree =
  result = MeshTree()
  # mesh
  if node.hasKey("mesh"):
    let mesh = root["meshes"][node["mesh"].getInt()]
    for primitive in mesh["primitives"]:
      result.children.add MeshTree(mesh: loadMesh(mesh["name"].getStr(), root, primitive, materials, mainBuffer))

  # transformation
  if node.hasKey("matrix"):
    var mat: Mat4
    for i in 0 ..< node["matrix"].len:
      mat[i] = node["matrix"][i].getFloat()
    result.transform = mat
  else:
    var (t, r, s) = (Unit4F32, Unit4F32, Unit4F32)
    if node.hasKey("translation"):
      t = Translate(
        float32(node["translation"][0].getFloat()),
        float32(node["translation"][1].getFloat()),
        float32(node["translation"][2].getFloat())
      )
    if node.hasKey("rotation"):
      t = Rotate(
        float32(node["rotation"][3].getFloat()),
        NewVec3f(
          float32(node["rotation"][0].getFloat()),
          float32(node["rotation"][1].getFloat()),
          float32(node["rotation"][2].getFloat())
        )
      )
    if node.hasKey("scale"):
      t = Scale(
        float32(node["scale"][0].getFloat()),
        float32(node["scale"][1].getFloat()),
        float32(node["scale"][2].getFloat())
      )
    result.transform = t * r * s
  result.transform = Scale(1, -1, 1) * result.transform

  # children
  if node.hasKey("children"):
    for childNode in node["children"]:
      result.children.add loadNode(root, root["nodes"][childNode.getInt()], materials, mainBuffer)

proc loadScene(root: JsonNode, scenenode: JsonNode, materials: seq[MaterialData], mainBuffer: var seq[uint8]): MeshTree =
  result = MeshTree()
  for nodeId in scenenode["nodes"]:
    result.children.add loadNode(root, root["nodes"][nodeId.getInt()], materials, mainBuffer)
  # TODO: getting from gltf to vulkan system is still messed up somehow (i.e. not consistent for different files), see other TODO
  # result.transform = Scale(1, -1, 1)
  result.updateTransforms()

  ]#

proc ReadglTF*[TMesh, TMaterial](
  stream: Stream,
  baseColorFactor: static string = "",
  emissiveFactor: static string = "",
  metallicFactor: static string = "",
  roughnessFactor: static string = "",
  baseColorTexture: static string = "",
  metallicRoughnessTexture: static string = "",
  normalTexture: static string = "",
  occlusionTexture: static string = "",
  emissiveTexture: static string = "",
): GLTFMesh[TMesh, TMaterial] =
  const mapping = MaterialAttributeNames(
    baseColorFactor: baseColorFactor,
    emissiveFactor: emissiveFactor,
    metallicFactor: metallicFactor,
    roughnessFactor: roughnessFactor,
    baseColorTexture: baseColorTexture,
    metallicRoughnessTexture: metallicRoughnessTexture,
    normalTexture: normalTexture,
    occlusionTexture: occlusionTexture,
    emissiveTexture: emissiveTexture,
  )
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
  assert stream.readData(addr data.binaryBufferData[0], int(chunkLength)) == int(chunkLength)

  # check that the refered buffer is the same as the binary chunk
  # external binary buffers are not supported
  assert data.structuredContent["buffers"].len == 1
  assert not data.structuredContent["buffers"][0].hasKey("uri")
  let bufferLenDiff = int(chunkLength) - data.structuredContent["buffers"][0]["byteLength"].getInt()
  assert 0 <= bufferLenDiff and bufferLenDiff <= 3 # binary buffer may be aligned to 4 bytes

  debug "Loading mesh: ", data.structuredContent.pretty

  if "materials" in data.structuredContent:
    for materialnode in items(data.structuredContent["materials"]):
      result.materials.add loadMaterial[TMaterial](data.structuredContent, materialnode, data.binaryBufferData, mapping)

  if "textures" in data.structuredContent:
    for texturenode in items(data.structuredContent["textures"]):
      result.textures.add loadTexture(data.structuredContent, texturenode, data.binaryBufferData)

  echo result
  # for scenedata in data.structuredContent["scenes"]:
    # result.add data.structuredContent.loadScene(scenedata, materials, data.binaryBufferData)
    #
proc LoadMeshes*[TMesh, TMaterial](
  path: string,
  baseColorFactor: static string = "",
  emissiveFactor: static string = "",
  metallicFactor: static string = "",
  roughnessFactor: static string = "",
  baseColorTexture: static string = "",
  metallicRoughnessTexture: static string = "",
  normalTexture: static string = "",
  occlusionTexture: static string = "",
  emissiveTexture: static string = "",
  package = DEFAULT_PACKAGE
): GLTFMesh[TMesh, TMaterial] =
  ReadglTF[TMesh, TMaterial](
    stream = loadResource_intern(path, package = package),
    baseColorFactor = baseColorFactor,
    emissiveFactor = emissiveFactor,
    metallicFactor = metallicFactor,
    roughnessFactor = roughnessFactor,
    baseColorTexture = baseColorTexture,
    metallicRoughnessTexture = metallicRoughnessTexture,
    normalTexture = normalTexture,
    occlusionTexture = occlusionTexture,
    emissiveTexture = emissiveTexture,
  )
