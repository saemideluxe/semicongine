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

proc `=copy`(dest: var FontObj, source: FontObj) {.error.}

include ./text/font
include ./text/textbox
