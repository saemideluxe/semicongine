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
    offsetX*: float32
    offsetY*: float32
    leftBearing*: float32
    advance*: float32

  GlyphData[N: static int] = object
    pos: array[N, Vec4f] # vertex offsets to glyph center: [left, bottom, right, top]
    uv: array[N, Vec4f] # [left, bottom, right, top]

  GlyphDescriptorSet*[N: static int] = object
    fontAtlas*: Image[Gray]
    glyphData*: GPUValue[GlyphData[N], StorageBuffer]

  FontObj*[N: static int] = object
    glyphs*: Table[Rune, GlyphInfo]
    fontAtlas*: Image[Gray]
    maxHeight*: int
    kerning*: Table[(Rune, Rune), float32]
    fontscale*: float32
    lineHeight*: float32
    lineAdvance*: float32
    capHeight*: float32
    xHeight*: float32
    descriptorSet*: DescriptorSetData[GlyphDescriptorSet[N]]
    descriptorGlyphIndex: Table[Rune, uint16]

  Font*[N: static int] = ref FontObj[N]

  Glyphs* = object
    position*: GPUArray[Vec3f, VertexBufferMapped]
    color*: GPUArray[Vec4f, VertexBufferMapped]
    scale*: GPUArray[float32, VertexBufferMapped]
    glyphIndex*: GPUArray[uint16, VertexBufferMapped]

  TextRendering* = object
    aspectRatio*: float32

  GlyphShader*[N: static int] = object
    position {.InstanceAttribute.}: Vec3f
    color {.InstanceAttribute.}: Vec4f
    scale {.InstanceAttribute.}: float32
    glyphIndex {.InstanceAttribute.}: uint16
    textRendering {.PushConstant.}: TextRendering

    fragmentUv {.Pass.}: Vec2f
    fragmentColor {.PassFlat.}: Vec4f
    outColor {.ShaderOutput.}: Vec4f
    glyphData {.DescriptorSet: 0.}: GlyphDescriptorSet[N]
    vertexCode* =
      """
const int[6] indices = int[](0, 1, 2, 2, 3, 0);
const int[4] i_x = int[](0, 0, 2, 2);
const int[4] i_y = int[](1, 3, 3, 1);
const float epsilon = 0.0000001;
// const float epsilon = 0.1;

void main() {
  int vertexI = indices[gl_VertexIndex];
  vec3 pos = vec3(
    glyphData.pos[glyphIndex][i_x[vertexI]] * scale,
    glyphData.pos[glyphIndex][i_y[vertexI]] * scale * textRendering.aspectRatio,
    1 - (gl_InstanceIndex + 1) * epsilon // allows overlapping glyphs to make proper depth test
  );
  gl_Position = vec4(pos + position, 1.0);
  vec2 uv = vec2(glyphData.uv[glyphIndex][i_x[vertexI]], glyphData.uv[glyphIndex][i_y[vertexI]]);
  fragmentUv = uv;
  fragmentColor = color;
}  """
    fragmentCode* =
      """void main() {
    float a = texture(fontAtlas, fragmentUv).r;
    outColor = vec4(fragmentColor.rgb, fragmentColor.a * a);
}"""

proc `=copy`[T: static int](dest: var FontObj[T], source: FontObj[T]) {.error.}
proc `=copy`(dest: var Glyphs, source: Glyphs) {.error.}

include ./text/font

#[
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
      left = info.leftBearing + info.offsetX
      right = left + info.dimension.x
      top = -info.offsetY
      bottom = top - info.dimension.y
    glyphData.pos[i] = vec4(left, bottom, right, top) * 0.001'f32
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
]#

func initGlyphs*(count: int): Glyphs =
  result.position.data.setLen(count)
  result.scale.data.setLen(count)
  result.color.data.setLen(count)
  result.glyphIndex.data.setLen(count)

func set*(
    glyphs: var Glyphs,
    font: FontObj,
    text: seq[Rune],
    position: Vec3f,
    scale = 1'f32,
    color = vec4(1, 1, 1, 1),
) =
  assert text.len <= glyphs.position.len,
    &"Set {text.len} but Glyphs-object only supports {glyphs.position.len}"
  var cursor = position
  for i in 0 ..< text.len:
    glyphs.position[i] = cursor
    glyphs.scale[i] = scale
    glyphs.color[i] = color
    glyphs.glyphIndex[i] = font.descriptorGlyphIndex[text[i]]

type EMPTY = object
const EMPTYOBJECT = EMPTY()

proc renderGlyphs*(commandBuffer: VkCommandBuffer, pipeline: Pipeline, glyphs: Glyphs) =
  renderWithPushConstant(
    commandbuffer,
    pipeline,
    EMPTYOBJECT,
    glyphs,
    pushConstant = TextRendering(aspectRatio: getAspectRatio()),
    fixedVertexCount = 6,
  )
