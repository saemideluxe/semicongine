import std/strutils
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

proc getBufferViewData(bufferView: JsonNode, mainBuffer: seq[uint8], baseBufferOffset=0): seq[uint8] =
  assert bufferView["buffer"].getInt() == 0, "Currently no external buffers supported"

  result = newSeq[uint8](bufferView["byteLength"].getInt())
  let bufferOffset = bufferView["byteOffset"].getInt() + baseBufferOffset
  var dstPointer = addr result[0]

  if bufferView.hasKey("byteStride"):
    raise newException(Exception, "Unsupported feature: byteStride in buffer view")
  copyMem(dstPointer, addr mainBuffer[bufferOffset], result.len)

proc getAccessorData(root: JsonNode, accessor: JsonNode, mainBuffer: seq[uint8]): DataList =
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

proc loadImage(root: JsonNode, imageIndex: int, mainBuffer: seq[uint8]): Image =
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
  result.image = loadImage(root, textureNode["source"].getInt(), mainBuffer)

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


proc loadMaterial(root: JsonNode, materialNode: JsonNode, mainBuffer: seq[uint8], materialIndex: uint16): Material =
  result = Material(name: materialNode["name"].getStr())

  let pbr = materialNode["pbrMetallicRoughness"]

  # color
  result.constants["baseColorFactor"] = DataValue(thetype: Vec4F32)
  if pbr.hasKey("baseColorFactor"):
    setValue(result.constants["baseColorFactor"], newVec4f(
      pbr["baseColorFactor"][0].getFloat(),
      pbr["baseColorFactor"][1].getFloat(),
      pbr["baseColorFactor"][2].getFloat(),
      pbr["baseColorFactor"][3].getFloat(),
    ))
  else:
    setValue(result.constants["baseColorFactor"], newVec4f(1, 1, 1, 1))

  # pbr material constants
  for factor in ["metallicFactor", "roughnessFactor"]:
    result.constants[factor] = DataValue(thetype: Float32)
    if pbr.hasKey(factor):
      setValue(result.constants[factor], float32(pbr[factor].getFloat()))
    else:
      setValue(result.constants[factor], 0.5'f32)

  # pbr material textures
  for texture in ["baseColorTexture", "metallicRoughnessTexture"]:
    if pbr.hasKey(texture):
      result.textures[texture] = loadTexture(root, pbr[texture]["index"].getInt(), mainBuffer)
      result.constants[texture & "Index"] = DataValue(thetype: UInt8)
      setValue(result.constants[texture & "Index"], pbr[texture].getOrDefault("texCoord").getInt(0).uint8)
    else:
      result.textures[texture] = EMPTYTEXTURE
      result.constants[texture & "Index"] = DataValue(thetype: UInt8)
      setValue(result.constants[texture & "Index"], 0'u8)

  # generic material textures
  for texture in ["normalTexture", "occlusionTexture", "emissiveTexture"]:
    if materialNode.hasKey(texture):
      result.textures[texture] = loadTexture(root, materialNode[texture]["index"].getInt(), mainBuffer)
      result.constants[texture & "Index"] = DataValue(thetype: UInt8)
      setValue(result.constants[texture & "Index"], materialNode[texture].getOrDefault("texCoord").getInt(0).uint8)
    else:
      result.textures[texture] = EMPTYTEXTURE
      result.constants[texture & "Index"] = DataValue(thetype: UInt8)
      setValue(result.constants[texture & "Index"], 0'u8)

  # emissiv color
  result.constants["emissiveFactor"] = DataValue(thetype: Vec3F32)
  if materialNode.hasKey("emissiveFactor"):
    setValue(result.constants["emissiveFactor"], newVec3f(
      materialNode["emissiveFactor"][0].getFloat(),
      materialNode["emissiveFactor"][1].getFloat(),
      materialNode["emissiveFactor"][2].getFloat(),
    ))
  else:
    setValue(result.constants["emissiveFactor"], newVec3f(1'f32, 1'f32, 1'f32))


proc addPrimitive(mesh: var Mesh, root: JsonNode, primitiveNode: JsonNode, mainBuffer: seq[uint8]) =
  if primitiveNode.hasKey("mode") and primitiveNode["mode"].getInt() != 4:
    raise newException(Exception, "Currently only TRIANGLE mode is supported for geometry mode")

  var vertexCount = 0'u32
  for attribute, accessor in primitiveNode["attributes"].pairs:
    let data = root.getAccessorData(root["accessors"][accessor.getInt()], mainBuffer)
    mesh.appendAttributeData(attribute.toLowerAscii, data)
    vertexCount = data.len

  var materialId = 0'u16
  if primitiveNode.hasKey("material"):
    materialId = uint16(primitiveNode["material"].getInt())
  mesh.appendAttributeData("materialIndex", newSeqWith[uint8](int(vertexCount), materialId))
  let material = loadMaterial(root, root["materials"][int(materialId)], mainBuffer, materialId)
  # if mesh.material != nil and mesh.material[] != material[]:
    # raise newException(Exception, &"Only one material per mesh supported at the moment")
  mesh.material = material

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
            # FYI gltf uses counter-clockwise indexing
            mesh.appendIndicesData(tri[0], tri[2], tri[1])
            tri.setLen(0)
      of UInt32:
        for entry in getValues[uint32](data)[]:
          tri.add uint32(entry)
          if tri.len == 3:
            # FYI gltf uses counter-clockwise indexing
            mesh.appendIndicesData(tri[0], tri[2], tri[1])
            tri.setLen(0)
      else:
        raise newException(Exception, &"Unsupported index data type: {data.thetype}")

# TODO: use one mesh per primitive?? right now we are merging primitives... check addPrimitive below
proc loadMesh(root: JsonNode, meshNode: JsonNode, mainBuffer: seq[uint8]): Mesh =

  # check if and how we use indexes
  var indexCount = 0
  var indexType = None
  let indexed = meshNode["primitives"][0].hasKey("indices")
  if indexed:
    for primitive in meshNode["primitives"]:
      indexCount += root["accessors"][primitive["indices"].getInt()]["count"].getInt()
    if indexCount < int(high(uint16)):
      indexType = Small
    else:
      indexType = Big

  result = Mesh(instanceCount: 1, instanceTransforms: newSeqWith(1, Unit4F32), indexType: indexType)

  # check we have the same attributes for all primitives
  let attributes = meshNode["primitives"][0]["attributes"].keys.toSeq
  for primitive in meshNode["primitives"]:
    assert primitive["attributes"].keys.toSeq == attributes

  # prepare mesh attributes
  for attribute, accessor in meshNode["primitives"][0]["attributes"].pairs:
    result.setMeshData(attribute.toLowerAscii, newDataList(thetype=root["accessors"][accessor.getInt()].getGPUType()))
  result.setMeshData("materialIndex", newDataList(theType=UInt16))

  # add all mesh data
  for primitive in meshNode["primitives"]:
    result.addPrimitive(root, primitive, mainBuffer)

  setInstanceData(result, "transform", newSeqWith(int(result.instanceCount), Unit4F32))

proc loadNode(root: JsonNode, node: JsonNode, mainBuffer: var seq[uint8]): Entity =
  var name = "<Unknown>"
  if node.hasKey("name"):
    name = node["name"].getStr()
  result = newEntity(name)

  # transformation
  if node.hasKey("matrix"):
    var mat: Mat4
    for i in 0 ..< node["matrix"].len:
      mat[i] = node["matrix"][i].getFloat()
    result.transform = mat
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
    result["mesh"] = loadMesh(root, root["meshes"][node["mesh"].getInt()], mainBuffer)

proc loadScene(root: JsonNode, scenenode: JsonNode, mainBuffer: var seq[uint8]): Scene =
  var rootEntity = newEntity("<root>")
  for nodeId in scenenode["nodes"]:
    var node = loadNode(root, root["nodes"][nodeId.getInt()], mainBuffer)
    rootEntity.add node

  newScene(scenenode["name"].getStr(), rootEntity)


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

  debug "Loading mesh: ", data.structuredContent.pretty

  for scenedata in data.structuredContent["scenes"]:
    result.add data.structuredContent.loadScene(scenedata, data.binaryBufferData)
