import std/algorithm
import std/logging
import std/os
import std/sequtils
import std/streams
import std/strformat
import std/strutils
import std/tables
import std/unicode

import ./core
import ./resources
import ./rendering
import ./rendering/vulkan/api
import ./image
import ./contrib/algorithms/texture_packing

const
  NEWLINE = Rune('\n')
  SPACE = Rune(' ')

type
  GlyphInfo* = object
    uvs*: array[4, Vec2f]
    dimension*: Vec2f
    topOffset*: float32
    leftOffset*: float32
    advance*: float32

  FontObj* = object
    glyphs*: Table[Rune, GlyphInfo]
    fontAtlas*: Image[Gray]
    maxHeight*: int
    kerning*: Table[(Rune, Rune), float32]
    fontscale*: float32
    lineHeight*: float32
    lineAdvance*: float32
    capHeight*: float32
    xHeight*: float32

  Font = ref FontObj

  TextboxData = object
    color: Vec4f
    position: Vec3f
    tmp: float32
    scale: Vec2f

  DefaultFontShader*[T] = object
    position {.VertexAttribute.}: Vec3f
    uv {.VertexAttribute.}: Vec2f
      # TODO: maybe we can keep the uvs in a uniform buffer and just pass an index
    fragmentUv {.Pass.}: Vec2f
    color {.ShaderOutput.}: Vec4f
    textbox {.PushConstant.}: TextboxData
    descriptorSets {.DescriptorSet: 0.}: T
    vertexCode* =
      """void main() {
  gl_Position = vec4(position * vec3(textbox.scale, 1) + textbox.position, 1.0);
  fragmentUv = uv;
}  """
    fragmentCode* =
      """void main() {
    float v = texture(fontAtlas, fragmentUv).r;
    // CARFULL: This can lead to rough edges at times
    if(v == 0) {
      discard;
    }
    color = vec4(textbox.color.rgb, textbox.color.a * v);
}"""

  Glyphs* = object
    position*: GPUArray[Vec3f, VertexBufferMapped]
    color*: GPUArray[Vec4f, VertexBufferMapped]
    scale*: GPUArray[float32, VertexBufferMapped]
    glyphIndex*: GPUArray[uint16, VertexBufferMapped]

  GlyphData[N: static int] = object
    pos: array[N, Vec4f] # [left, bottom, right, top]
    uv: array[N, Vec4f] # [left, bottom, right, top]

  GlyphDescriptorSet*[N: static int] = object
    fontAtlas*: Image[Gray]
    glyphData*: GPUValue[GlyphData[N], StorageBuffer]

  GlyphShader*[N: static int] = object
    position {.InstanceAttribute.}: Vec3f
    color {.InstanceAttribute.}: Vec4f
    scale {.InstanceAttribute.}: float32
    glyphIndex {.InstanceAttribute.}: uint16

    fragmentUv {.Pass.}: Vec2f
    fragmentColor {.PassFlat.}: Vec4f
    outColor {.ShaderOutput.}: Vec4f
    glyphData {.DescriptorSet: 0.}: GlyphDescriptorSet[N]
    vertexCode* =
      """
const int[6] indices = int[](0, 1, 2, 2, 3, 0);
const int[4] i_x = int[](0, 0, 2, 2);
const int[4] i_y = int[](1, 3, 3, 1);
const float epsilon = 0.000000000000001;
// const float epsilon = 0.1;

void main() {
  int vertexI = indices[gl_VertexIndex];
  vec3 pos = vec3(
    glyphData.pos[glyphIndex][i_x[vertexI]] * scale,
    glyphData.pos[glyphIndex][i_y[vertexI]] * scale,
    gl_VertexIndex * epsilon
  );
  vec2 uv = vec2(glyphData.uv[glyphIndex][i_x[vertexI]], glyphData.uv[glyphIndex][i_y[vertexI]]);
  gl_Position = vec4(pos + position, 1.0);
  fragmentUv = uv;
  fragmentColor = color;
}  """
    fragmentCode* =
      """void main() {
    float v = texture(fontAtlas, fragmentUv).r;
    // CARFULL: This can lead to rough edges at times
    // if(v == 0) {
      // discard;
    // }
    // outColor = vec4(fragmentColor.rgb, fragmentColor.a * v);
    // outColor = fragmentColor;
    outColor = vec4(1, 1, 1, v);
}"""

proc `=copy`(dest: var FontObj, source: FontObj) {.error.}

include ./text/font
include ./text/textbox

proc glyphDescriptorSet*(
    font: Font, maxGlyphs: static int
): (DescriptorSetData[GlyphDescriptorSet[maxGlyphs]], Table[Rune, uint16]) =
  assert font.glyphs.len <= maxGlyphs,
    "font has " & $font.glyphs.len & " glyphs but shader is only configured for " &
      $maxGlyphs

  var glyphData = GlyphData[maxGlyphs]()
  var glyphTable: Table[Rune, uint16]

  var i = 0'u16
  for rune, info in font.glyphs.pairs():
    let
      left = -info.leftOffset
      right = -info.leftOffset + info.dimension.x
      top = font.lineHeight + info.topOffset
      bottom = font.lineHeight + info.topOffset - info.dimension.y
    glyphData.pos[i] = vec4(left, bottom, right, top) * 0.005'f32
    assert info.uvs[0].x == info.uvs[1].x,
      "Currently only axis aligned rectangles are allowed for info boxes in font texture maps"
    assert info.uvs[0].y == info.uvs[3].y,
      "Currently only axis aligned rectangles are allowed for info boxes in font texture maps"
    assert info.uvs[2].x == info.uvs[3].x,
      "Currently only axis aligned rectangles are allowed for info boxes in font texture maps"
    assert info.uvs[1].y == info.uvs[2].y,
      "Currently only axis aligned rectangles are allowed for info boxes in font texture maps"
    glyphData.uv[i] = vec4(info.uvs[0].x, info.uvs[0].y, info.uvs[2].x, info.uvs[2].y)
    glyphTable[rune] = i
    inc i

  (
    asDescriptorSetData(
      GlyphDescriptorSet[maxGlyphs](
        fontAtlas: font.fontAtlas.copy(),
        glyphData: asGPUValue(glyphData, StorageBuffer),
      )
    ),
    glyphTable,
  )
