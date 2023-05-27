import std/strutils
import std/options
import std/json
import std/logging
import std/tables
import std/sequtils
import std/strformat
import std/streams

import ../scene
import ../mesh
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
  glTFMaterial = object
    color: Vec4f
    colorTexture: Option[Texture]
    colorTextureIndex: uint32
    metallic: float32
    roughness: float32
    metallicRoughnessTexture: Option[Texture]
    metallicRoughnessTextureIndex: uint32
    normalTexture: Option[Texture]
    normalTextureIndex: uint32
    occlusionTexture: Option[Texture]
    occlusionTextureIndex: uint32
    emissiveTexture: Option[Texture]
    emissiveTextureIndex: uint32
    emissiveFactor: Vec3f

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

func getGPUType(accessor: JsonNode): DataType =
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
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")
  of "VEC3":
    case componentType
    of UInt32: return Vec3U32
    of Float32: return Vec3F32
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")
  of "VEC4":
    case componentType
    of UInt32: return Vec4U32
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")
  of "MAT2":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")
  of "MAT3":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")
  of "MAT4":
    case componentType
    of Float32: return Vec4F32
    else: raise newException(Exception, &"Unsupported data type: {componentType} {theType}")

proc getBufferViewData(bufferView: JsonNode, mainBuffer: var seq[uint8], baseBufferOffset=0): seq[uint8] =
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  result = newSeq[uint8](bufferView["byteLength"].getInt())
  let bufferOffset = bufferView["byteOffset"].getInt() + baseBufferOffset
  var dstPointer = addr result[0]

  if bufferView.hasKey("byteStride"):
    raise newException(Exception, "Unsupported feature: byteStride in buffer view")
  copyMem(dstPointer, addr mainBuffer[bufferOffset], result.len)

proc getAccessorData(root: JsonNode, accessor: JsonNode, mainBuffer: var seq[uint8]): DataList =
  result = newDataList(thetype=accessor.getGPUType())
  result.initData(uint32(accessor["count"].getInt()))

  let bufferView = root["bufferViews"][accessor["bufferView"].getInt()]
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  if accessor.hasKey("sparse"):
    raise newException(Exception, "Sparce accessors are currently not implemented")

  let accessorOffset = if accessor.hasKey("byteOffset"): accessor["byteOffset"].getInt() else: 0
  let length = bufferView["byteLength"].getInt()
  let bufferOffset = bufferView["byteOffset"].getInt() + accessorOffset
  var dstPointer = result.getRawData()[0]

  if bufferView.hasKey("byteStride"):
    warn "Congratulations, you try to test a feature (loading buffer data with stride attributes) that we have no idea where it is used and how it can be tested (need a coresponding *.glb file)."
    # we don't support stride, have to convert stuff here... does this even work?
    for i in 0 ..< int(result.len):
      copyMem(dstPointer, addr mainBuffer[bufferOffset + i * bufferView["byteStride"].getInt()], int(result.thetype.size))
      dstPointer = cast[pointer](cast[uint64](dstPointer) + result.thetype.size)
  else:
    copyMem(dstPointer, addr mainBuffer[bufferOffset], length)

proc addPrimitive(mesh: var Mesh, root: JsonNode, primitiveNode: JsonNode, mainBuffer: var seq[uint8]) =
  if primitiveNode.hasKey("mode") and primitiveNode["mode"].getInt() != 4:
    raise newException(Exception, "Currently only TRIANGLE mode is supported for geometry mode")

  var vertexCount = 0'u32
  for attribute, accessor in primitiveNode["attributes"].pairs:
    let data = root.getAccessorData(root["accessors"][accessor.getInt()], mainBuffer)
    mesh.appendMeshData(attribute.toLowerAscii, data)
    vertexCount = data.len

  var materialId = 0'u8
  if primitiveNode.hasKey("material"):
    materialId = uint8(primitiveNode["material"].getInt())
  mesh.appendMeshData("material", newSeqWith[uint8](int(vertexCount), materialId))

  if primitiveNode.hasKey("indices"):
    assert mesh.indexType != None
    let data = root.getAccessorData(root["accessors"][primitiveNode["indices"].getInt()], mainBuffer)
    let baseIndex = mesh.indicesCount
    var tri: seq[uint32]
    case data.thetype
      of UInt16:
        for entry in getValues[uint16](data)[]:
          tri.add uint32(entry) + baseIndex
          if tri.len == 3:
            mesh.appendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      of UInt32:
        for entry in getValues[uint32](data)[]:
          tri.add uint32(entry)
          if tri.len == 3:
            mesh.appendIndicesData(tri[0], tri[1], tri[2])
            tri.setLen(0)
      else:
        raise newException(Exception, &"Unsupported index data type: {data.thetype}")

proc loadMesh(root: JsonNode, meshNode: JsonNode, mainBuffer: var seq[uint8]): Mesh =
  result = new Mesh
  result.instanceCount = 1

  # check if and how we use indexes
  var indexCount = 0
  let indexed = meshNode["primitives"][0].hasKey("indices")
  if indexed:
    for primitive in meshNode["primitives"]:
      indexCount += root["accessors"][primitive["indices"].getInt()]["count"].getInt()
    if indexCount < int(high(uint16)):
      result.indexType = Small
    else:
      result.indexType = Big
  else:
    result.indexType = None

  # check we have the same attributes for all primitives
  let attributes = meshNode["primitives"][0]["attributes"].keys.toSeq
  for primitive in meshNode["primitives"]:
    assert primitive["attributes"].keys.toSeq == attributes

  # prepare mesh attributes
  for attribute, accessor in meshNode["primitives"][0]["attributes"].pairs:
    result.setMeshData(attribute.toLowerAscii, newDataList(thetype=root["accessors"][accessor.getInt()].getGPUType()))
  result.setMeshData("material", newDataList(thetype=getDataType[uint8]()))

  # add all mesh data
  for primitive in meshNode["primitives"]:
    result.addPrimitive(root, primitive, mainBuffer)

  # gld uses +y up, but we (vulkan) don't 

proc loadNode(root: JsonNode, node: JsonNode, mainBuffer: var seq[uint8]): Entity =
  var name = "<Unknown>"
  if node.hasKey("name"):
    name = node["name"].getStr()
  result = newEntity(name)

  # transformation
  if node.hasKey("matrix"):
    for i in 0 .. node["matrix"].len:
      result.transform.data[i] = node["matrix"][i].getFloat()
  else:
    var (t, r, s) = (Unit4F32, Unit4F32, Unit4F32)
    if node.hasKey("translation"):
      t = translate3d(
        float32(node["translation"][0].getFloat()),
        float32(node["translation"][1].getFloat()),
        float32(node["translation"][2].getFloat())
      )
    if node.hasKey("rotation"):
      t = rotate3d(
        float32(node["rotation"][3].getFloat()),
        newVec3f(
          float32(node["rotation"][0].getFloat()),
          float32(node["rotation"][1].getFloat()),
          float32(node["rotation"][2].getFloat())
        )
      )
    if node.hasKey("scale"):
      t = scale3d(
        float32(node["scale"][0].getFloat()),
        float32(node["scale"][1].getFloat()),
        float32(node["scale"][2].getFloat())
      )
    result.transform = t * r * s

  # children
  if node.hasKey("children"):
    for childNode in node["children"]:
      result.add loadNode(root, root["nodes"][childNode.getInt()], mainBuffer)

  # mesh
  if node.hasKey("mesh"):
    result.add loadMesh(root, root["meshes"][node["mesh"].getInt()], mainBuffer)

proc loadScene(root: JsonNode, scenenode: JsonNode, mainBuffer: var seq[uint8]): Scene =
  var rootEntity = newEntity("<root>")
  for nodeId in scenenode["nodes"]:
    let node = loadNode(root, root["nodes"][nodeId.getInt()], mainBuffer)
    node.transform = node.transform * scale3d(1'f32, -1'f32, 1'f32)
    rootEntity.add node

  newScene(scenenode["name"].getStr(), rootEntity)

proc loadImage(root: JsonNode, imageIndex: int, mainBuffer: var seq[uint8]): Image =
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

proc loadTexture(root: JsonNode, textureIndex: int, mainBuffer: var seq[uint8]): Texture =
  let textureNode = root["textures"][textureIndex]
  result.image = loadImage(root, textureNode["source"].getInt(), mainBuffer)
  result.sampler = DefaultSampler()

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

proc loadMaterial(root: JsonNode, materialNode: JsonNode, mainBuffer: var seq[uint8]): glTFMaterial =
  let defaultMaterial = glTFMaterial(color: newVec4f(1, 1, 1, 1))
  result = defaultMaterial
  let pbr = materialNode["pbrMetallicRoughness"]
  if pbr.hasKey("baseColorFactor"):
    result.color[0] = pbr["baseColorFactor"][0].getFloat()
    result.color[1] = pbr["baseColorFactor"][1].getFloat()
    result.color[2] = pbr["baseColorFactor"][2].getFloat()
    result.color[3] = pbr["baseColorFactor"][3].getFloat()
  if pbr.hasKey("baseColorTexture"):
    result.colorTexture = some(loadTexture(root, pbr["baseColorTexture"]["index"].getInt(), mainBuffer))
    result.colorTextureIndex = pbr["baseColorTexture"].getOrDefault("texCoord").getInt(0).uint32
  if pbr.hasKey("metallicRoughnessTexture"):
    result.metallicRoughnessTexture = some(loadTexture(root, pbr["metallicRoughnessTexture"]["index"].getInt(), mainBuffer))
    result.metallicRoughnessTextureIndex = pbr["metallicRoughnessTexture"].getOrDefault("texCoord").getInt().uint32
  if pbr.hasKey("metallicFactor"):
    result.metallic = pbr["metallicFactor"].getFloat()
  if pbr.hasKey("roughnessFactor"):
    result.roughness= pbr["roughnessFactor"].getFloat()

  if materialNode.hasKey("normalTexture"):
    result.normalTexture = some(loadTexture(root, materialNode["normalTexture"]["index"].getInt(), mainBuffer))
    result.metallicRoughnessTextureIndex = materialNode["normalTexture"].getOrDefault("texCoord").getInt().uint32
  if materialNode.hasKey("occlusionTexture"):
    result.occlusionTexture = some(loadTexture(root, materialNode["occlusionTexture"]["index"].getInt(), mainBuffer))
    result.occlusionTextureIndex = materialNode["occlusionTexture"].getOrDefault("texCoord").getInt().uint32
  if materialNode.hasKey("emissiveTexture"):
    result.emissiveTexture = some(loadTexture(root, materialNode["emissiveTexture"]["index"].getInt(), mainBuffer))
    result.occlusionTextureIndex = materialNode["emissiveTexture"].getOrDefault("texCoord").getInt().uint32
  if materialNode.hasKey("roughnessFactor"):
    result.roughness = materialNode["roughnessFactor"].getFloat()
  if materialNode.hasKey("emissiveFactor"):
    let em = materialNode["emissiveFactor"]
    result.emissiveFactor = newVec3f(em[0].getFloat(), em[1].getFloat(), em[2].getFloat())

proc readglTF*(stream: Stream): seq[Scene] =
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

  debug data.structuredContent.pretty

  for scene in data.structuredContent["scenes"]:
    var scene = data.structuredContent.loadScene(scene, data.binaryBufferData)
    var
      color: seq[Vec4f]
      colorTexture: seq[Texture]
      colorTextureIndex: seq[uint32]
      metallic: seq[float32]
      roughness: seq[float32]
      metallicRoughnessTexture: seq[Texture]
      metallicRoughnessTextureIndex: seq[uint32]
      normalTexture: seq[Texture]
      normalTextureIndex: seq[uint32]
      occlusionTexture: seq[Texture]
      occlusionTextureIndex: seq[uint32]
      emissiveTexture: seq[Texture]
      emissiveTextureIndex: seq[uint32]
      emissiveFactor: seq[Vec3f]
    for materialNode in data.structuredContent["materials"]:
      let m = loadMaterial(data.structuredContent, materialNode, data.binaryBufferData)
      color.add m.color
      if not m.colorTexture.isSome:
        colorTexture.add m.colorTexture.get
        colorTextureIndex.add m.colorTextureIndex
      metallic.add m.metallic
      roughness.add m.roughness
      if not m.metallicRoughnessTexture.isSome:
        metallicRoughnessTexture.add m.metallicRoughnessTexture.get
        metallicRoughnessTextureIndex.add m.metallicRoughnessTextureIndex
      if not m.normalTexture.isSome:
        normalTexture.add m.normalTexture.get
        normalTextureIndex.add m.normalTextureIndex
      if not m.occlusionTexture.isSome:
        occlusionTexture.add m.occlusionTexture.get
        occlusionTextureIndex.add m.occlusionTextureIndex
      if not m.emissiveTexture.isSome:
        emissiveTexture.add m.emissiveTexture.get
        emissiveTextureIndex.add m.emissiveTextureIndex
      emissiveFactor.add m.emissiveFactor

    # material constants
    if color.len > 0: scene.addShaderGlobalArray("material_color", color)
    if colorTextureIndex.len > 0: scene.addShaderGlobalArray("material_color_texture_index", colorTextureIndex)
    if metallic.len > 0: scene.addShaderGlobalArray("material_metallic", metallic)
    if roughness.len > 0: scene.addShaderGlobalArray("material_roughness", roughness)
    if metallicRoughnessTextureIndex.len > 0: scene.addShaderGlobalArray("material_metallic_roughness_texture_index", metallicRoughnessTextureIndex)
    if normalTextureIndex.len > 0: scene.addShaderGlobalArray("material_normal_texture_index", normalTextureIndex)
    if occlusionTextureIndex.len > 0: scene.addShaderGlobalArray("material_occlusion_texture_index", occlusionTextureIndex)
    if emissiveTextureIndex.len > 0: scene.addShaderGlobalArray("material_emissive_texture_index", emissiveTextureIndex)
    if emissiveFactor.len > 0: scene.addShaderGlobalArray("material_emissive_factor", emissiveFactor)

    # texture
    if colorTexture.len > 0: scene.addTextures("material_color_texture", colorTexture)
    if metallicRoughnessTexture.len > 0: scene.addTextures("material_metallic_roughness_texture", metallicRoughnessTexture)
    if normalTexture.len > 0: scene.addTextures("material_normal_texture", normalTexture)
    if occlusionTexture.len > 0: scene.addTextures("material_occlusion_texture", occlusionTexture)
    if emissiveTexture.len > 0: scene.addTextures("material_emissive_texture", emissiveTexture)

    result.add scene

