import std/strformat

import ./core
import ./mesh

const
  SHADER_ATTRIB_PREFIX = "semicon_panel_"
  MAX_PANEL_MATERIALS = 10

var instanceCounter = 0

type
  Panel* = object
    position: Vec2f
    size: Vec2f
    color*: Vec4f

    texture: Texture
    horizontalAlignment: HorizontalAlignment = Center
    verticalAlignment: VerticalAlignment = Center
    aspect_ratio: float32
    dirty: bool
    mesh: Mesh

proc initPanel*(position = newVec2f(), size = newVec2f(), color = newVec4f(1, 1, 1, 1), texture = EMPTY_TEXTURE, horizontalAlignment = HorizontalAlignment.Center, verticalAlignment = VerticalAlignment.Center): Panel =

  result = Panel(position: position, size: size, color: color, texture: texture, horizontalAlignment: horizontalAlignment, verticalAlignment: verticalAlignment, aspect_ratio: 1)

  inc instanceCounter
  var
    positions = newSeq[Vec3f](4)
    indices = @[
      [uint16(0), uint16(1), uint16(2)],
      [uint16(2), uint16(3), uint16(0)],
    ]
    uvs = newSeq[Vec2f](4)
  result.mesh = newMesh(positions = positions, indices = indices, uvs = uvs, name = &"panel-{instanceCounter}")

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
