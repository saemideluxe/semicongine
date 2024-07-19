type
  GlyphInfo* = object
    uvs*: array[4, Vec2f]
    dimension*: Vec2f
    topOffset*: float32
    leftOffset*: float32
    advance*: float32
  Font* = object
    name*: string # used to reference fontAtlas will be referenced in shader
    glyphs*: Table[Rune, GlyphInfo]
    fontAtlas*: Texture
    maxHeight*: int
    kerning*: Table[(Rune, Rune), float32]
    fontscale*: float32
    lineHeight*: float32
    lineAdvance*: float32
    capHeight*: float32
    xHeight*: float32
