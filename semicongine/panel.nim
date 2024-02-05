import ./core

const
  SHADER_ATTRIB_PREFIX = "semicon_text_"
  MAX_TEXT_MATERIALS = 10

var instanceCounter = 0

type
  Panel* = object
    position: Vec2f
    size: Vec2f
    color*: Vec4f

    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    aspect_ratio: float32
    texture: Vec4f
    dirty: bool
    mesh: Mesh

proc position*(panel: Panel): Vec2f =
  panel.position
proc `position=`*(panel: var Panel, value: Vec2f) =
  if value != panel.position:
    panel.position = value
    panel.dirty = true

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
