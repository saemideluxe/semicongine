import ./scene
import ./mesh
import ./core/vector
import ./core/matrix
import ./core/fonttypes

type
  TextAlignment = enum
    Left
    Center
    Right
  Textbox* = ref object of Entity
    columns*: uint32
    rows*: uint32
    text*: string
    alignment*: TextAlignment
    font*: Font
    lettermesh*: Mesh

func len*(textbox: Textbox): uint32 =
  textbox.columns * textbox.rows

proc newTextbox*(columns, rows: uint32, font: Font, text=""): Textbox =
  result = Textbox(columns: columns, rows: rows, text: text, font: font)
  result.lettermesh = newMesh(
    positions = [newVec3f(0, 0), newVec3f(0, 1), newVec3f(1, 1), newVec3f(1, 0)],
    indices = [[0'u16, 1'u16, 2'u16], [0'u16, 0'u16, 0'u16]],
    uvs = [newVec2f(0, 0), newVec2f(0, 1), newVec2f(1, 1), newVec2f(1, 0)],
    instanceCount = result.len,
  )
  var transforms = newSeq[Mat4](result.len)
  for i in 0 ..< result.len:
    transforms[i] = Unit4f32
  setInstanceData(result.lettermesh, "transform", transforms)
  result.components.add result.lettermesh
