import std/strformat
import std/tables

import ./core
import ./mesh
import ./material
import ./vulkan/shader

const
  # font shader
  SHADER_ATTRIB_PREFIX = "semicon_panel_"
  MAX_PANEL_MATERIALS = 10
  POSITION_ATTRIB = SHADER_ATTRIB_PREFIX & "position"
  UV_ATTRIB = SHADER_ATTRIB_PREFIX & "uv"
  PANEL_MATERIAL_TYPE* = MaterialType(
    name: "default-panel-material-type",
    vertexAttributes: {TRANSFORM_ATTRIB: Mat4F32, POSITION_ATTRIB: Vec3F32, UV_ATTRIB: Vec2F32}.toTable,
    attributes: {"panelTexture": TextureType, "color": Vec4F32}.toTable,
  )
  PANEL_SHADER* = createShaderConfiguration(
    inputs = [
      attr[Mat4](TRANSFORM_ATTRIB, memoryPerformanceHint = PreferFastWrite, perInstance = true),
      attr[Vec3f](POSITION_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      attr[Vec2f](UV_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      attr[uint16](MATERIALINDEX_ATTRIBUTE, memoryPerformanceHint = PreferFastRead, perInstance = true),
    ],
    intermediates = [
      attr[Vec2f]("uvFrag"),
      attr[uint16]("materialIndexOut", noInterpolation = true)
    ],
    outputs = [attr[Vec4f]("color")],
    uniforms = [attr[Vec4f]("color", arrayCount = MAX_PANEL_MATERIALS)],
    samplers = [attr[Texture]("panelTexture", arrayCount = MAX_PANEL_MATERIALS)],
    vertexCode = &"""
  gl_Position = vec4({POSITION_ATTRIB}, 1.0) * {TRANSFORM_ATTRIB};
  uvFrag = {UV_ATTRIB};
  materialIndexOut = {MATERIALINDEX_ATTRIBUTE};
  """,
    fragmentCode = &"""color = Uniforms.color[materialIndexOut] * texture(panelTexture[materialIndexOut], uvFrag);"""
  )

var instanceCounter = 0

type
  Panel* = object
    position: Vec2f
    size: Vec2f

    texture: Texture
    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    aspect_ratio: float32
    dirty: bool
    mesh: Mesh

proc `$`*(panel: Panel): string =
  &"Panel {panel.position} (size {panel.size})"

proc refresh*(panel: var Panel) =
  if not panel.dirty:
    return

  var
    offsetX = case panel.horizontalAlignment
      of Left: panel.size.x / 2
      of Center: 0
      of Right: -panel.size.x / 2
    offsetY = case panel.verticalAlignment
      of Top: panel.size.y / 2
      of Center: 0
      of Bottom: -panel.size.y / 2

  panel.mesh[POSITION_ATTRIB, 0] = newVec3f(
    panel.position.x - panel.size.x / 2 + offsetX,
    (panel.position.y - panel.size.y / 2 + offsetY) * panel.aspect_ratio
  )
  panel.mesh[POSITION_ATTRIB, 1] = newVec3f(
    panel.position.x + panel.size.x / 2 + offsetX,
    (panel.position.y - panel.size.y / 2 + offsetY) * panel.aspect_ratio
  )
  panel.mesh[POSITION_ATTRIB, 2] = newVec3f(
    panel.position.x + panel.size.x / 2 + offsetX,
    (panel.position.y + panel.size.y / 2 + offsetY) * panel.aspect_ratio
  )
  panel.mesh[POSITION_ATTRIB, 3] = newVec3f(
    panel.position.x - panel.size.x / 2 + offsetX,
    (panel.position.y + panel.size.y / 2 + offsetY) * panel.aspect_ratio
  )

  panel.dirty = false

proc initPanel*(position = newVec2f(), size = newVec2f(), color = newVec4f(1, 1, 1, 1), texture = EMPTY_TEXTURE, horizontalAlignment = HorizontalAlignment.Center, verticalAlignment = VerticalAlignment.Center): Panel =

  result = Panel(position: position, size: size, texture: texture, horizontalAlignment: horizontalAlignment, verticalAlignment: verticalAlignment, aspect_ratio: 1)

  result.mesh = newMesh(
    positions = newSeq[Vec3f](4),
    indices = @[
      [uint16(0), uint16(1), uint16(2)],
      [uint16(2), uint16(3), uint16(0)],
    ],
    uvs = @[newVec2f(0, 1), newVec2f(1, 1), newVec2f(1, 0), newVec2f(0, 0)], name = &"panel-{instanceCounter}"
  )
  result.mesh[].renameAttribute("position", POSITION_ATTRIB)
  result.mesh[].renameAttribute("uv", UV_ATTRIB)
  result.mesh.material = initMaterialData(
    theType = PANEL_MATERIAL_TYPE,
    name = "Panel material",
    attributes = {"panelTexture": initDataList(@[texture]), "color": initDataList(@[color])},
  )
  inc instanceCounter
  result.refresh()

proc position*(panel: Panel): Vec2f =
  panel.position
proc `position=`*(panel: var Panel, value: Vec2f) =
  if value != panel.position:
    panel.position = value
    panel.dirty = true

proc color*(panel: Panel): Vec4f =
  panel.mesh.material["color", 0, Vec4f]
proc `color=`*(panel: var Panel, value: Vec4f) =
  if value != panel.color:
    panel.mesh.material["color", 0] = value

proc size*(panel: Panel): Vec2f =
  panel.size
proc `size=`*(panel: var Panel, value: Vec2f) =
  if value != panel.size:
    panel.size = value
    panel.dirty = true

proc horizontalAlignment*(panel: Panel): HorizontalAlignment =
  panel.horizontalAlignment
proc `horizontalAlignment=`*(panel: var Panel, value: HorizontalAlignment) =
  if value != panel.horizontalAlignment:
    panel.horizontalAlignment = value
    panel.dirty = true

proc verticalAlignment*(panel: Panel): VerticalAlignment =
  panel.verticalAlignment
proc `verticalAlignment=`*(panel: var Panel, value: VerticalAlignment) =
  if value != panel.verticalAlignment:
    panel.verticalAlignment = value
    panel.dirty = true

proc aspect_ratio*(panel: Panel): float32 =
  panel.aspect_ratio
proc `aspect_ratio=`*(panel: var Panel, value: float32) =
  if value != panel.aspect_ratio:
    panel.aspect_ratio = value
    panel.dirty = true
