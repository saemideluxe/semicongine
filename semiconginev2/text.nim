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
    name*: string
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
    scale: float32
  TextboxDescriptorSet = object
    textbox: GPUValue[TextboxData, UniformBufferMapped]
    fontAtlas: Image[Gray]

  DefaultFontShader* = object
    position {.VertexAttribute.}: Vec3f
    uv {.VertexAttribute.}: Vec2f # TODO: maybe we can keep the uvs in a uniform buffer and just pass an index
    fragmentUv {.Pass.}: Vec2f
    color {.ShaderOutput.}: Vec4f
    descriptorSets {.DescriptorSets.}: (TextboxDescriptorSet, )
    vertexCode = &"""
  gl_Position = vec4(position * textbox.scale + textbox.position, 1.0);
  fragmentUv = uv;
  """
    fragmentCode = &"""color = vec4(textbox.color.rgb, textbox.color.rgb.a * texture(fontAtlas, fragmentUv).r);"""


include ./text/font
include ./text/textbox
