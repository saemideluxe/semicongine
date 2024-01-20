import std/strutils
import std/json
import std/logging
import std/tables
import std/strformat
import std/streams

import ../mesh
import ../material
import ../core

import ./image

type
  glTFHeader = object
    magic: uint32
    version: uint32
    length: uint32
  glTFData = object
    structuredContent: JsonNode
    binaryBufferData: seq[uint8]

const
  JSON_CHUNK = 0x4E4F534A
  BINARY_CHUNK = 0x004E4942
  ACCESSOR_TYPE_MAP = {
    5120: Int8,
    5121: UInt8,
    5122: Int16,
    5123: UInt16,
    5125: UInt32,
    5126: Float32,
  }.toTable
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
  GLTF_MATERIAL_MAPPING = {
    "color": "baseColorFactor",
    "emissiveColor": "emissiveFactor",
    "metallic": "metallicFactor",
    "roughness", "roughnessFactor",
    "baseTexture": "baseColorTexture",
    "metallicRoughnessTexture": "metallicRoughnessTexture",
    "normalTexture": "normalTexture",
    "occlusionTexture": "occlusionTexture",
    "emissiveTexture": "emissiveTexture",
  }.toTable

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

proc getBufferViewData(bufferView: JsonNode, mainBuffer: seq[uint8], baseBufferOffset=0): seq[uint8] =
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  result = newSeq[uint8](bufferView["byteLength"].getInt())
  let bufferOffset = bufferView["byteOffset"].getInt() + baseBufferOffset
  var dstPointer = addr result[0]

  if bufferView.hasKey("byteStride"):
    raise newException(Exception, "Unsupported feature: byteStride in buffer view")
  copyMem(dstPointer, addr mainBuffer[bufferOffset], result.len)

proc getAccessorData(root: JsonNode, accessor: JsonNode, mainBuffer: seq[uint8]): DataList =
  result = initDataList(thetype=accessor.getGPUType("??"))
  result.setLen(accessor["count"].getInt())

  let bufferView = root["bufferViews"][accessor["bufferView"].getInt()]
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  if accessor.hasKey("sparse"):
    raise newException(Exception, "Sparce accessors are currently not implemented")

  let accessorOffset = if accessor.hasKey("byteOffset"): accessor["byteOffset"].getInt() else: 0
  let length = bufferView["byteLength"].getInt()
  let bufferOffset = bufferView["byteOffset"].getInt() + accessorOffset
  var dstPointer = result.getPointer()

  if bufferView.hasKey("byteStride"):
    warn "Congratulations, you try to test a feature (loading buffer data with stride attributes) that we have no idea where it is used and how it can be tested (need a coresponding *.glb file)."
    # we don't support stride, have to convert stuff here... does this even work?
    for i in 0 ..< int(result.len):
      copyMem(dstPointer, addr mainBuffer[bufferOffset + i * bufferView["byteStride"].getInt()], int(result.thetype.size))
      dstPointer = cast[pointer](cast[int](dstPointer) + result.thetype.size)
  else:
    copyMem(dstPointer, addr mainBuffer[bufferOffset], length)

proc loadImage(root: JsonNode, imageIndex: int, mainBuffer: seq[uint8]): Image[RGBAPixel] =
  if root["images"][imageIndex].hasKey("uri"):
    raise newException(Exception, "Unsupported feature: Load images from external files")

  let bufferView = root["bufferViews"][root["images"][imageIndex]["bufferView"].getInt()]
  let imgData = newStringStream(cast[string](getBufferViewData(bufferView, mainBuffer)))

  let imageType = root["images"][imageIndex]["mimeType"].getStr()
  case imageType
  of "image/bmp":
    result = readBMP(imgData)
  of "image/png":
    result = readPNG(imgData)
  else:
    raise newException(Exception, "Unsupported feature: Load image of type " & imageType)

proc loadTexture(root: JsonNode, textureIndex: int, mainBuffer: seq[uint8]): Texture =
  let textureNode = root["textures"][textureIndex]
  result = Texture(isGrayscale: false)
  result.colorImage = loadImage(root, textureNode["source"].getInt(), mainBuffer)
  result.name = root["images"][textureNode["source"].getInt()]["name"].getStr()
  if result.name == "":
    result.name = &"Texture{textureIndex}"

  if textureNode.hasKey("sampler"):
    let sampler = root["samplers"][textureNode["sampler"].getInt()]
    if sampler.hasKey("magFilter"):
      result.sampler.magnification = SAMPLER_FILTER_MODE_MAP[sampler["magFilter"].getInt()]
    if sampler.hasKey("minFilter"):
      result.sampler.minification = SAMPLER_FILTER_MODE_MAP[sampler["minFilter"].getInt()]
    if sampler.hasKey("wrapS"):
      result.sampler.wrapModeS = SAMPLER_WRAP_MODE_MAP[sampler["wrapS"].getInt()]
    if sampler.hasKey("wrapT"):
      result.sampler.wrapModeT = SAMPLER_WRAP_MODE_MAP[sampler["wrapS"].getInt()]


proc loadMaterial(root: JsonNode, materialNode: JsonNode, defaultMaterial: MaterialType, mainBuffer: seq[uint8]): MaterialData =
  let pbr = materialNode["pbrMetallicRoughness"]
  var attributes: Table[string, DataList]

  # color
  if defaultMaterial.attributes.contains("color"):
    attributes["color"] = initDataList(thetype=Vec4F32)
    if pbr.hasKey(GLTF_MATERIAL_MAPPING["color"]):
      attributes["color"] = @[newVec4f(
        pbr[GLTF_MATERIAL_MAPPING["color"]][0].getFloat(),
        pbr[GLTF_MATERIAL_MAPPING["color"]][1].getFloat(),
        pbr[GLTF_MATERIAL_MAPPING["color"]][2].getFloat(),
        pbr[GLTF_MATERIAL_MAPPING["color"]][3].getFloat(),
      )]
    else:
      attributes["color"] = @[newVec4f(1, 1, 1, 1)]

    # pbr material values
    for factor in ["metallic", "roughness"]:
      if defaultMaterial.attributes.contains(factor):
        attributes[factor] = initDataList(thetype=Float32)
        if pbr.hasKey(GLTF_MATERIAL_MAPPING[factor]):
          attributes[factor] = @[float32(pbr[GLTF_MATERIAL_MAPPING[factor]].getFloat())]
        else:
          attributes[factor] = @[0.5'f32]

  # pbr material textures
  for texture in ["baseTexture", "metallicRoughnessTexture"]:
    if defaultMaterial.attributes.contains(texture):
      attributes[texture] = initDataList(thetype=TextureType)
      # attributes[texture & "Index"] = initDataList(thetype=UInt8)
      if pbr.hasKey(GLTF_MATERIAL_MAPPING[texture]):
        attributes[texture] = @[loadTexture(root, pbr[GLTF_MATERIAL_MAPPING[texture]]["index"].getInt(), mainBuffer)]
      else:
        attributes[texture] = @[EMPTY_TEXTURE]

  # generic material textures
  for texture in ["normalTexture", "occlusionTexture", "emissiveTexture"]:
    if defaultMaterial.attributes.contains(texture):
      attributes[texture] = initDataList(thetype=TextureType)
      # attributes[texture & "Index"] = initDataList(thetype=UInt8)
      if materialNode.hasKey(GLTF_MATERIAL_MAPPING[texture]):
        attributes[texture] = @[loadTexture(root, materialNode[texture]["index"].getInt(), mainBuffer)]
      else:
        attributes[texture] = @[EMPTY_TEXTURE]

  # emissiv color
  if defaultMaterial.attributes.contains("emissiveColor"):
    attributes["emissiveColor"] = initDataList(thetype=Vec3F32)
    if materialNode.hasKey(GLTF_MATERIAL_MAPPING["emissiveColor"]):
      attributes["emissiveColor"] = @[newVec3f(
        materialNode[GLTF_MATERIAL_MAPPING["emissiveColor"]][0].getFloat(),
        materialNode[GLTF_MATERIAL_MAPPING["emissiveColor"]][1].getFloat(),
        materialNode[GLTF_MATERIAL_MAPPING["emissiveColor"]][2].getFloat(),
      )]
    else:
      attributes["emissiveColor"] = @[newVec3f(1'f32, 1'f32, 1'f32)]

  result = initMaterialData(theType=defaultMaterial, name=materialNode["name"].getStr(), attributes=attributes)

proc loadMesh(meshname: string, root: JsonNode, primitiveNode: JsonNode, defaultMaterial: MaterialType, mainBuffer: seq[uint8]): Mesh =
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
    result[].initVertexAttribute(attribute.toLowerAscii, data)

  if primitiveNode.hasKey("material"):
    let materialId = primitiveNode["material"].getInt()
    result[].material = loadMaterial(root, root["materials"][materialId], defaultMaterial, mainBuffer)
  else:
    result[].material = EMPTY_MATERIAL.initMaterialData()

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
            result[].appendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      of UInt32:
        for entry in data[uint32][]:
          tri.add int(entry)
          if tri.len == 3:
            # FYI gltf uses counter-clockwise indexing
            result[].appendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      else:
        raise newException(Exception, &"Unsupported index data type: {data.thetype}")
  # TODO: getting from gltf to vulkan system is still messed up somehow, see other TODO
  transform[Vec3f](result[], "position", scale(1, -1, 1))

proc loadNode(root: JsonNode, node: JsonNode, defaultMaterial: MaterialType, mainBuffer: var seq[uint8]): MeshTree =
  result = MeshTree()
  # mesh
  if node.hasKey("mesh"):
    let mesh = root["meshes"][node["mesh"].getInt()]
    for primitive in mesh["primitives"]:
      result.children.add MeshTree(mesh: loadMesh(mesh["name"].getStr(), root, primitive, defaultMaterial, mainBuffer))

  # transformation
  if node.hasKey("matrix"):
    var mat: Mat4
    for i in 0 ..< node["matrix"].len:
      mat[i] = node["matrix"][i].getFloat()
    result.transform = mat
  else:
    var (t, r, s) = (Unit4F32, Unit4F32, Unit4F32)
    if node.hasKey("translation"):
      t = translate(
        float32(node["translation"][0].getFloat()),
        float32(node["translation"][1].getFloat()),
        float32(node["translation"][2].getFloat())
      )
    if node.hasKey("rotation"):
      t = rotate(
        float32(node["rotation"][3].getFloat()),
        newVec3f(
          float32(node["rotation"][0].getFloat()),
          float32(node["rotation"][1].getFloat()),
          float32(node["rotation"][2].getFloat())
        )
      )
    if node.hasKey("scale"):
      t = scale(
        float32(node["scale"][0].getFloat()),
        float32(node["scale"][1].getFloat()),
        float32(node["scale"][2].getFloat())
      )
    result.transform =  t * r * s
  result.transform =  scale(1, -1, 1) * result.transform

  # children
  if node.hasKey("children"):
    for childNode in node["children"]:
      result.children.add loadNode(root, root["nodes"][childNode.getInt()], defaultMaterial, mainBuffer)

proc loadMeshTree(root: JsonNode, scenenode: JsonNode, defaultMaterial: MaterialType, mainBuffer: var seq[uint8]): MeshTree =
  result = MeshTree()
  for nodeId in scenenode["nodes"]:
    result.children.add loadNode(root, root["nodes"][nodeId.getInt()], defaultMaterial, mainBuffer)
  # TODO: getting from gltf to vulkan system is still messed up somehow (i.e. not consistent for different files), see other TODO
  # result.transform = scale(1, -1, 1)
  result.updateTransforms()


proc readglTF*(stream: Stream, defaultMaterial: MaterialType): seq[MeshTree] =
  var
    header: glTFHeader
    data: glTFData

  for name, value in fieldPairs(header):
    stream.read(value)

  assert header.magic == 0x46546C67
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
  assert 0 <= bufferLenDiff <= 3 # binary buffer may be aligned to 4 bytes

  debug "Loading mesh: ", data.structuredContent.pretty

  for scenedata in data.structuredContent["scenes"]:
    result.add data.structuredContent.loadMeshTree(scenedata, defaultMaterial, data.binaryBufferData)
