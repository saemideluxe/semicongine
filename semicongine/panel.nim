import std/strformat
import std/tables

import ./core
import ./mesh
import ./material
import ./vulkan/shader
import ./events

const
  # font shader
  SHADER_ATTRIB_PREFIX = "semicon_panel_"
  MAX_PANEL_MATERIALS = 10
  POSITION_ATTRIB = SHADER_ATTRIB_PREFIX & "position"
  UV_ATTRIB = SHADER_ATTRIB_PREFIX & "uv"
  PANEL_MATERIAL_TYPE* = MaterialType(
    name: "default-panel-material-type",
    vertexAttributes: {POSITION_ATTRIB: Vec3F32, UV_ATTRIB: Vec2F32}.toTable,
    instanceAttributes: {TRANSFORM_ATTRIB: Mat4F32, MATERIALINDEX_ATTRIBUTE: UInt16}.toTable,
    attributes: {"panelTexture": TextureType, "color": Vec4F32}.toTable,
  )
  PANEL_SHADER* = createShaderConfiguration(
    name = "panel shader",
    inputs = [
      Attr[Mat4](TRANSFORM_ATTRIB, memoryPerformanceHint = PreferFastWrite, perInstance = true),
      Attr[Vec3f](POSITION_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      Attr[Vec2f](UV_ATTRIB, memoryPerformanceHint = PreferFastWrite),
      Attr[uint16](MATERIALINDEX_ATTRIBUTE, memoryPerformanceHint = PreferFastRead, perInstance = true),
    ],
    intermediates = [
      Attr[Vec2f]("uvFrag"),
      Attr[uint16]("materialIndexOut", noInterpolation = true)
    ],
    outputs = [Attr[Vec4f]("color")],
    uniforms = [Attr[Vec4f]("color", arrayCount = MAX_PANEL_MATERIALS), Attr[float32](ASPECT_RATIO_ATTRIBUTE)],
    samplers = [Attr[Texture]("panelTexture", arrayCount = MAX_PANEL_MATERIALS)],
    vertexCode = &"""
  gl_Position = vec4({POSITION_ATTRIB}.x, {POSITION_ATTRIB}.y * Uniforms.{ASPECT_RATIO_ATTRIBUTE}, {POSITION_ATTRIB}.z, 1.0) * {TRANSFORM_ATTRIB};
  uvFrag = {UV_ATTRIB};
  materialIndexOut = {MATERIALINDEX_ATTRIBUTE};
  """,
    fragmentCode = &"""color = Uniforms.color[materialIndexOut] * texture(panelTexture[materialIndexOut], uvFrag);"""
  )

var instanceCounter = 0

type
  Panel* = object
    texture: Texture
    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    dirty: bool
    mesh*: Mesh
    # input handling
    onMouseDown*: proc(panel: var Panel, buttons: set[MouseButton])
    onMouseUp*: proc(panel: var Panel, buttons: set[MouseButton])
    onMouseEnter*: proc(panel: var Panel)
    onMouseMove*: proc(panel: var Panel)
    onMouseLeave*: proc(panel: var Panel)
    hasMouse*: bool

proc `$`*(panel: Panel): string =
  &"Panel {panel.mesh}"

proc Refresh*(panel: var Panel) =
  if not panel.dirty:
    return

  var
    offsetX = case panel.horizontalAlignment
      of Left: 0.5
      of Center: 0
      of Right: -0.5
    offsetY = case panel.verticalAlignment
      of Top: 0.5
      of Center: 0
      of Bottom: -0.5

  panel.mesh[POSITION_ATTRIB, 0] = NewVec3f(-0.5 + offsetX, -0.5 + offsetY)
  panel.mesh[POSITION_ATTRIB, 1] = NewVec3f(+0.5 + offsetX, -0.5 + offsetY)
  panel.mesh[POSITION_ATTRIB, 2] = NewVec3f(+0.5 + offsetX, +0.5 + offsetY)
  panel.mesh[POSITION_ATTRIB, 3] = NewVec3f(-0.5 + offsetX, +0.5 + offsetY)

  panel.dirty = false

proc InitPanel*(
  transform = Unit4,
  color = NewVec4f(1, 1, 1, 1),
  texture = EMPTY_TEXTURE,
  horizontalAlignment = HorizontalAlignment.Center,
  verticalAlignment = VerticalAlignment.Center,
  onMouseDown: proc(panel: var Panel, buttons: set[MouseButton]) = nil,
  onMouseUp: proc(panel: var Panel, buttons: set[MouseButton]) = nil,
  onMouseEnter: proc(panel: var Panel) = nil,
  onMouseMove: proc(panel: var Panel) = nil,
  onMouseLeave: proc(panel: var Panel) = nil,
): Panel =

  result = Panel(
    texture: texture,
    horizontalAlignment: horizontalAlignment,
    verticalAlignment: verticalAlignment,
    onMouseDown: onMouseDown,
    onMouseUp: onMouseUp,
    onMouseEnter: onMouseEnter,
    onMouseMove: onMouseMove,
    onMouseLeave: onMouseLeave,
    dirty: true,
  )

  result.mesh = newMesh(
    name = &"panel-{instanceCounter}",
    positions = newSeq[Vec3f](4),
    indices = @[
      [uint16(0), uint16(1), uint16(2)],
      [uint16(2), uint16(3), uint16(0)],
    ],
    uvs = @[NewVec2f(0, 1), NewVec2f(1, 1), NewVec2f(1, 0), NewVec2f(0, 0)],
    transform = transform
  )
  result.mesh[].renameAttribute("position", POSITION_ATTRIB)
  result.mesh[].renameAttribute("uv", UV_ATTRIB)
  result.mesh.material = initMaterialData(
    theType = PANEL_MATERIAL_TYPE,
    name = "Panel material",
    attributes = {"panelTexture": InitDataList(@[texture]), "color": InitDataList(@[color])},
  )
  inc instanceCounter
  result.refresh()

proc Color*(panel: Panel): Vec4f =
  panel.mesh.material["color", 0, Vec4f]
proc `color=`*(panel: var Panel, value: Vec4f) =
  if value != panel.color:
    panel.mesh.material["color", 0] = value

proc HorizontalAlignment*(panel: Panel): HorizontalAlignment =
  panel.horizontalAlignment
proc `horizontalAlignment=`*(panel: var Panel, value: HorizontalAlignment) =
  if value != panel.horizontalAlignment:
    panel.horizontalAlignment = value
    panel.dirty = true

proc VerticalAlignment*(panel: Panel): VerticalAlignment =
  panel.verticalAlignment
proc `verticalAlignment=`*(panel: var Panel, value: VerticalAlignment) =
  if value != panel.verticalAlignment:
    panel.verticalAlignment = value
    panel.dirty = true

proc Contains*(panel: Panel, p: Vec2f, aspectRatio: float32): bool =
  let
    cursor = panel.mesh.transform.Inversed * p.ToVec3
    p1 = panel.mesh[POSITION_ATTRIB, 0, Vec3f]
    p2 = panel.mesh[POSITION_ATTRIB, 2, Vec3f]
    left = min(p1.x, p2.x)
    right = max(p1.x, p2.x)
    top = min(p1.y * aspectRatio, p2.y * aspectRatio)
    bottom = max(p1.y * aspectRatio, p2.y * aspectRatio)
  return left <= cursor.x and cursor.x <= right and top <= cursor.y and cursor.y <= bottom
