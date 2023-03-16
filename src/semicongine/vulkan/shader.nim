import std/macros
import std/os
import std/enumerate
import std/logging
import std/hashes
import std/strformat
import std/strutils
import std/compilesettings

import ./api
import ./device

let logger = newConsoleLogger()
addHandler(logger)

type
  Shader*[InputAttributes, Uniforms] = object
    device: Device
    vk*: VkShaderModule
    entrypoint*: string
    inputs*: InputAttributes
    uniforms*: Uniforms
    binary*: seq[uint32]

# produce ast for: static shader string, inputs, uniforms, entrypoint

dumpAstGen:
  block:
    const test = 1

macro shader*(inputattributes: typed, uniforms: typed, device: Device, body: untyped): untyped =
  var shadertype: NimNode
  var entrypoint: NimNode
  var version: NimNode
  var code: NimNode
  for node in body:
    if node.kind == nnkCall and node[0].kind == nnkIdent and node[0].strVal == "shadertype":
      expectKind(node[1], nnkStmtList)
      expectKind(node[1][0], nnkIdent)
      shadertype = node[1][0]
    if node.kind == nnkCall and node[0].kind == nnkIdent and node[0].strVal == "entrypoint":
      expectKind(node[1], nnkStmtList)
      expectKind(node[1][0], nnkStrLit)
      entrypoint = node[1][0]
    if node.kind == nnkCall and node[0].kind == nnkIdent and node[0].strVal == "version":
      expectKind(node[1], nnkStmtList)
      expectKind(node[1][0], nnkIntLit)
      version = node[1][0]
    if node.kind == nnkCall and node[0].kind == nnkIdent and node[0].strVal == "code":
      expectKind(node[1], nnkStmtList)
      expectKind(node[1][0], {nnkStrLit, nnkTripleStrLit})
      code = node[1][0]
  var shadercode: seq[string]
  shadercode.add &"#version {version.intVal}"
  shadercode.add &"""void {entrypoint.strVal}(){{
{code}
}}"""
  
  return nnkBlockStmt.newTree(
    newEmptyNode(),
    nnkStmtList.newTree(
        nnkConstSection.newTree(
          nnkConstDef.newTree(
            newIdentNode("shaderbinary"),
            newEmptyNode(),
            newCall("compileGLSLToSPIRV", shadertype, newStrLitNode(shadercode.join("\n")), entrypoint)
          )
        ),
        nnkObjConstr.newTree(
          nnkBracketExpr.newTree(
            newIdentNode("Shader"),
            inputattributes,
            uniforms,
          ),
          nnkExprColonExpr.newTree(newIdentNode("device"), device),
          nnkExprColonExpr.newTree(newIdentNode("entrypoint"), entrypoint),
          nnkExprColonExpr.newTree(newIdentNode("binary"), newIdentNode("shaderbinary")),

          # vk*: VkShaderModule
          # inputs*: InputAttributes
          # uniforms*: Uniforms
        )
      )
    )

proc staticExecChecked(command: string, input = ""): string {.compileTime.} =
  let (output, exitcode) = gorgeEx(
      command = command,
      input = input)
  if exitcode != 0:
    raise newException(Exception, &"Running '{command}' produced exit code: {exitcode}" & output)
  return output

func stage2string(stage: VkShaderStageFlagBits): string {.compileTime.} =
  case stage
  of VK_SHADER_STAGE_VERTEX_BIT: "vert"
  of VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT: "tesc"
  of VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT: "tese"
  of VK_SHADER_STAGE_GEOMETRY_BIT: "geom"
  of VK_SHADER_STAGE_FRAGMENT_BIT: "frag"
  of VK_SHADER_STAGE_COMPUTE_BIT: "comp"
  else: ""

proc compileGLSLToSPIRV*(stage: static VkShaderStageFlagBits, shaderSource: static string, entrypoint: static string): seq[uint32] {.compileTime.} =
  when defined(nimcheck): # will not run if nimcheck is running
    return result
  const
    stagename = stage2string(stage)
    shaderHash = hash(shaderSource)
    # cross compilation for windows workaround, sorry computer
    shaderfile = getTempDir() / &"shader_{shaderHash}.{stagename}"
    projectPath = querySetting(projectPath)

  echo "shader of type ", stage
  for i, line in enumerate(shaderSource.splitlines()):
    echo "  ", i + 1, " ", line

  discard staticExecChecked(
      command = &"{projectPath}/glslangValidator --entry-point {entrypoint} -V --stdin -S {stagename} -o {shaderfile}",
      input = shaderSource
  )

  when defined(mingw) and defined(linux): # required for crosscompilation, path separators get messed up
    let shaderbinary = staticRead shaderfile.replace("\\", "/")
  else:
    let shaderbinary = staticRead shaderfile

  var i = 0
  while i < shaderbinary.len:
    result.add(
      (uint32(shaderbinary[i + 0]) shl 0) or
      (uint32(shaderbinary[i + 1]) shl 8) or
      (uint32(shaderbinary[i + 2]) shl 16) or
      (uint32(shaderbinary[i + 3]) shl 24)
    )
    i += 4

proc loadShaderCode*(device: Device, binary: var seq[uint32]): VkShaderModule =
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(binary.len * sizeof(uint32)),
    pCode: if binary.len > 0: addr(binary[0]) else: nil,
  )
  checkVkResult vkCreateShaderModule(device.vk, addr(createInfo), nil, addr(result))

proc getPipelineInfo*(shader: Shader): VkPipelineShaderStageCreateInfo =
  VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: VK_SHADER_STAGE_VERTEX_BIT,
    module: shader.vk,
    pName: cstring(shader.entrypoint),
  )

proc destroy*(shader: var Shader) =
  assert shader.device.vk.valid
  assert shader.vk.valid
  shader.device.vk.vkDestroyShaderModule(shader.vk, nil)
  shader.vk.reset
