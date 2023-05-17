import std/json
import std/tables
import std/sequtils
import std/strformat
import std/streams

import ../entity
import ../mesh
import ../core


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
  VERTEX_ATTRIBUTE_DATA = 34962
  INSTANCE_ATTRIBUTE_DATA = 34963

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
    raise newException(Exception, "Congratulations, you try to test a feature (loading buffer data with stride attributes) that we have no idea where it is used and how it can be tested (need a coresponding *.glb file). Please open an issue so we can finish the implementation.")
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
    mesh.appendMeshData(attribute, data)
    vertexCount = data.len
    if attribute == "POSITION":
      transform[Vec3f](mesh, "POSITION", scale3d(1'f32, -1'f32, 1'f32))

  let materialId = uint8(primitiveNode["material"].getInt())
  mesh.appendMeshData("material", newSeqWith[uint8](int(vertexCount), materialId))

  if primitiveNode.hasKey("indices"):
    assert mesh.indexType != None
    let data = root.getAccessorData(root["accessors"][primitiveNode["indices"].getInt()], mainBuffer)
    var tri: seq[uint32]
    case data.thetype
      of UInt16:
        for entry in getValues[uint16](data)[]:
          tri.add uint32(entry)
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
    result.setMeshData(attribute, newDataList(thetype=root["accessors"][accessor.getInt()].getGPUType()))
  result.setMeshData("material", newDataList(thetype=getDataType[uint8]()))

  # add all mesh data
  for primitive in meshNode["primitives"]:
    result.addPrimitive(root, primitive, mainBuffer)

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
    rootEntity.add loadNode(root, root["nodes"][nodeId.getInt()], mainBuffer)

  newScene(scenenode["name"].getStr(), rootEntity)

proc getMaterialsData(root: JsonNode): seq[Vec4f] =
  for materialNode in root["materials"]:
    let pbr = materialNode["pbrMetallicRoughness"]
    var baseColor = newVec4f(0, 0, 0, 1)
    baseColor[0] = pbr["baseColorFactor"][0].getFloat() * 255
    baseColor[1] = pbr["baseColorFactor"][1].getFloat() * 255
    baseColor[2] = pbr["baseColorFactor"][2].getFloat() * 255
    baseColor[3] = pbr["baseColorFactor"][3].getFloat() * 255
    result.add baseColor
    # TODO: pbr["baseColorTexture"]
    # TODO: pbr["metallicRoughnessTexture"]
    # TODO: pbr["metallicFactor"]
    # TODO: pbr["roughnessFactor"]
    # TODO: materialNode["normalTexture"]
    # TODO: materialNode["occlusionTexture"]
    # TODO: materialNode["emissiveTexture"]
    # TODO: materialNode["emissiveFactor"]

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

  for scene in data.structuredContent["scenes"]:
    var scene = data.structuredContent.loadScene(scene, data.binaryBufferData)
    echo getMaterialsData(data.structuredContent)
    scene.addShaderGlobalArray("material_colors", getMaterialsData(data.structuredContent))
    result.add scene

