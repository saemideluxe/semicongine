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
  GlyphQuad[N: static int] = object
    pos: array[N, Vec4f] # vertex offsets to glyph center: [left, bottom, right, top]
    uv: array[N, Vec4f] # [left, bottom, right, top]

  GlyphDescriptorSet*[N: static int] = object
    fontAtlas*: Image[Gray]
    glyphquads*: GPUValue[GlyphQuad[N], StorageBuffer]

  FontObj*[N: static int] = object
    advance*: Table[Rune, float32]
    kerning*: Table[(Rune, Rune), float32]
    lineAdvance*: float32
    descriptorSet*: DescriptorSetData[GlyphDescriptorSet[N]]
    descriptorGlyphIndex: Table[Rune, uint16]
    fallbackCharacter: Rune

  Font*[N: static int] = ref FontObj[N]

  Glyphs*[N: static int] = object
    cursor: int
    font: Font[N]
    baseScale*: float32
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
    glyphquads.pos[glyphIndex][i_x[vertexI]] * scale / textRendering.aspectRatio,
    glyphquads.pos[glyphIndex][i_y[vertexI]] * scale,
    1 - (gl_InstanceIndex + 1) * epsilon // allows overlapping glyphs to make proper depth test
  );
  vec3 offset = vec3(
    (position.x - textRendering.aspectRatio + 1) / textRendering.aspectRatio,
    position.y,
    position.z
  );
  gl_Position = vec4(pos + offset, 1.0);
  vec2 uv = vec2(glyphquads.uv[glyphIndex][i_x[vertexI]], glyphquads.uv[glyphIndex][i_y[vertexI]]);
  fragmentUv = uv;
  fragmentColor = color;
}  """
    fragmentCode* =
      """void main() {
    float a = texture(fontAtlas, fragmentUv).r;
    outColor = vec4(fragmentColor.rgb, fragmentColor.a * a);
}"""

proc `=copy`[N: static int](dest: var FontObj[N], source: FontObj[N]) {.error.}
proc `=copy`[N: static int](dest: var Glyphs[N], source: Glyphs[N]) {.error.}

include ./text/font

func initGlyphs*[N: static int](
    font: Font[N], count: int, baseScale = 1'f32
): Glyphs[N] =
  result.cursor = 0
  result.font = font
  result.baseScale = baseScale
  result.position.data.setLen(count)
  result.scale.data.setLen(count)
  result.color.data.setLen(count)
  result.glyphIndex.data.setLen(count)

proc add*(
    glyphs: var Glyphs,
    text: seq[Rune],
    position: Vec3f,
    scale = 1'f32,
    color = vec4(1, 1, 1, 1),
) =
  assert text.len <= glyphs.position.len,
    &"Set {text.len} but Glyphs-object only supports {glyphs.position.len}"
  var origin =
    vec3(position.x * 2'f32 - 1'f32, -(position.y * 2'f32 - 1'f32), position.z)
  let s = scale * glyphs.baseScale
  var cursorPos = origin
  for i in 0 ..< text.len:
    if text[i] == Rune('\n'):
      cursorPos.x = origin.x
      cursorPos.y = cursorPos.y - glyphs.font.lineAdvance * s
    else:
      if not text[i].isWhitespace():
        glyphs.position[glyphs.cursor] = cursorPos
        glyphs.scale[glyphs.cursor] = s
        glyphs.color[glyphs.cursor] = color
        if text[i] in glyphs.font.descriptorGlyphIndex:
          glyphs.glyphIndex[glyphs.cursor] = glyphs.font.descriptorGlyphIndex[text[i]]
        else:
          glyphs.glyphIndex[glyphs.cursor] =
            glyphs.font.descriptorGlyphIndex[glyphs.font.fallbackCharacter]
        inc glyphs.cursor

      if text[i] in glyphs.font.advance:
        cursorPos.x = cursorPos.x + glyphs.font.advance[text[i]] * s
      else:
        cursorPos.x =
          cursorPos.x + glyphs.font.advance[glyphs.font.fallbackCharacter] * s

      if i < text.len - 1:
        cursorPos.x =
          cursorPos.x + glyphs.font.kerning.getOrDefault((text[i], text[i + 1]), 0) * s

proc reset*(glyphs: var Glyphs) =
  glyphs.cursor = 0

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
    fixedInstanceCount = glyphs.cursor,
  )
