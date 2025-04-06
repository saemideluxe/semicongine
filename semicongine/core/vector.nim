type
  TVec1*[T: SomeNumber] = distinct array[1, T]
  TVec2*[T: SomeNumber] = distinct array[2, T]
  TVec3*[T: SomeNumber] = distinct array[3, T]
  TVec4*[T: SomeNumber] = distinct array[4, T]
  TVec* = TVec1 | TVec2 | TVec3 | TVec4
  Vec1f* = TVec1[float32]
  Vec2f* = TVec2[float32]
  Vec3f* = TVec3[float32]
  Vec4f* = TVec4[float32]
  Vec1i* = TVec1[int32]
  Vec2i* = TVec2[int32]
  Vec3i* = TVec3[int32]
  Vec4i* = TVec4[int32]
  Vec1u* = TVec1[uint32]
  Vec2u* = TVec2[uint32]
  Vec3u* = TVec3[uint32]
  Vec4u* = TVec4[uint32]

  # support for shorts
  Vec1i8* = TVec1[int8]
  Vec1u8* = TVec1[uint8]
  Vec2i8* = TVec2[int8]
  Vec2u8* = TVec2[uint8]
  Vec3i8* = TVec3[int8]
  Vec3u8* = TVec3[uint8]

# stuff to allow working like an array, despite 'distinct'

converter toArray*[T](v: TVec1[T]): array[1, T] =
  array[1, T](v)

converter toArray*[T](v: TVec2[T]): array[2, T] =
  array[2, T](v)

converter toArray*[T](v: TVec3[T]): array[3, T] =
  array[3, T](v)

converter toArray*[T](v: TVec4[T]): array[4, T] =
  array[4, T](v)

template `[]`*[T](v: TVec1[T], i: Ordinal): T =
  (array[1, T](v))[i]

template `[]`*[T](v: TVec2[T], i: Ordinal): T =
  (array[2, T](v))[i]

template `[]`*[T](v: TVec3[T], i: Ordinal): T =
  (array[3, T](v))[i]

template `[]`*[T](v: TVec4[T], i: Ordinal): T =
  (array[4, T](v))[i]

template `[]=`*[T](v: TVec1[T], i: Ordinal, a: T) =
  (array[1, T](v))[i] = a

template `[]=`*[T](v: TVec2[T], i: Ordinal, a: T) =
  (array[2, T](v))[i] = a

template `[]=`*[T](v: TVec3[T], i: Ordinal, a: T) =
  (array[3, T](v))[i] = a

template `[]=`*[T](v: TVec4[T], i: Ordinal, a: T) =
  (array[4, T](v))[i] = a

template `==`*[T](a, b: TVec1[T]): bool =
  `==`(array[1, T](a), array[1, T](b))

template `==`*[T](a, b: TVec2[T]): bool =
  `==`(array[2, T](a), array[2, T](b))

template `==`*[T](a, b: TVec3[T]): bool =
  `==`(array[3, T](a), array[3, T](b))

template `==`*[T](a, b: TVec4[T]): bool =
  `==`(array[4, T](a), array[4, T](b))

func len*(v: TVec1): int =
  1
func len*(v: TVec2): int =
  2
func len*(v: TVec3): int =
  3
func len*(v: TVec4): int =
  4

func `$`*[T](v: TVec1[T]): string =
  `$`(array[1, T](v))
func `$`*[T](v: TVec2[T]): string =
  `$`(array[2, T](v))
func `$`*[T](v: TVec3[T]): string =
  `$`(array[3, T](v))
func `$`*[T](v: TVec4[T]): string =
  `$`(array[4, T](v))

func sum*[T](v: TVec1[T]): T =
  sum(array[1, T](v))
func sum*[T](v: TVec2[T]): T =
  sum(array[2, T](v))
func sum*[T](v: TVec3[T]): T =
  sum(array[3, T](v))
func sum*[T](v: TVec4[T]): T =
  sum(array[4, T](v))

func hash*[T](v: TVec1[T]): Hash =
  hash(array[1, T](v))
func hash*[T](v: TVec2[T]): Hash =
  hash(array[2, T](v))
func hash*[T](v: TVec3[T]): Hash =
  hash(array[3, T](v))
func hash*[T](v: TVec4[T]): Hash =
  hash(array[4, T](v))

iterator items*[T](v: TVec1[T]): T =
  yield v[0]

iterator items*[T](v: TVec2[T]): T =
  yield v[0]
  yield v[1]

iterator items*[T](v: TVec3[T]): T =
  yield v[0]
  yield v[1]
  yield v[2]

iterator items*[T](v: TVec4[T]): T =
  yield v[0]
  yield v[1]
  yield v[2]
  yield v[3]

func toVec1*[T: SomeNumber](orig: TVec3[T] | TVec4[T]): TVec1[T] =
  TVec1[T]([orig[0]])

func toVec2*[T: SomeNumber](orig: TVec3[T] | TVec4[T]): TVec2[T] =
  TVec2[T]([orig[0], orig[1]])

func toVec3*[T: SomeNumber](orig: TVec4[T]): TVec3[T] =
  TVec3[T]([orig[0], orig[1], orig[2]])

func toVec4*[T: SomeNumber](orig: TVec3[T], value: T = default(T)): TVec4[T] =
  TVec4[T]([orig[0], orig[1], orig[2], value])
func toVec3*[T: SomeNumber](orig: TVec2[T], value: T = default(T)): TVec3[T] =
  TVec3[T]([orig[0], orig[1], value])
func toVec2*[T: SomeNumber](orig: TVec1[T], value: T = default(T)): TVec2[T] =
  TVec2[T]([orig[0], value])

# shortcuts Vec3f
func vec1*[T: SomeNumber](x: T): Vec1f =
  Vec1f([float32(x)])
func vec2*[T, S: SomeNumber](x: T, y: S): Vec2f =
  Vec2f([float32(x), float32(y)])
func vec2*[T: SomeNumber](x: T): Vec2f =
  vec2(x, 0)
func vec2*(): Vec2f =
  vec2(0, 0)
func vec3*[T, S, U: SomeNumber](x: T, y: S, z: U): Vec3f =
  Vec3f([float32(x), float32(y), float32(z)])
func vec3*[T, S: SomeNumber](x: T, y: S): Vec3f =
  vec3(x, y, 0)
func vec3*[T: SomeNumber](x: T): Vec3f =
  vec3(x, 0, 0)
func vec3*(): Vec3f =
  vec3(0, 0, 0)
func vec4*[T, S, U, V: SomeNumber](x: T, y: S, z: U, w: V): Vec4f =
  Vec4f([float32(x), float32(y), float32(z), float32(w)])
func vec4*[T, S, U: SomeNumber](x: T, y: S, z: U): Vec4f =
  vec4(x, y, z, 0)
func vec4*[T, S: SomeNumber](x: T, y: S): Vec4f =
  vec4(x, y, 0, 0)
func vec4*[T: SomeNumber](x: T): Vec4f =
  vec4(x, 0, 0, 0)
func vec4*(): Vec4f =
  vec4(0, 0, 0, 0)

# shortcuts Vec3i
func vec1i*[T: SomeInteger](x: T): Vec1i =
  Vec1i([int32(x)])
func vec2i*[T, S: SomeInteger](x: T, y: S): Vec2i =
  Vec2i([int32(x), int32(y)])
func vec2i*[T: SomeInteger](x: T): Vec2i =
  vec2i(x, 0)
func vec2i*(): Vec2i =
  vec2i(0, 0)
func vec3i*[T, S, U: SomeInteger](x: T, y: S, z: U): Vec3i =
  Vec3i([int32(x), int32(y), int32(z)])
func vec3i*[T, S: SomeInteger](x: T, y: S): Vec3i =
  vec3i(x, y, 0)
func vec3i*[T: SomeInteger](x: T): Vec3i =
  vec3i(x, 0, 0)
func vec3i*(): Vec3i =
  vec3i(0, 0, 0)
func vec4i*[T, S, U, V: SomeInteger](x: T, y: S, z: U, w: V): Vec4i =
  Vec4i([int32(x), int32(y), int32(z), int32(w)])
func vec4i*[T, S, U: SomeInteger](x: T, y: S, z: U): Vec4i =
  vec4i(x, y, z, 0)
func vec4i*[T, S: SomeInteger](x: T, y: S): Vec4i =
  vec4i(x, y, 0, 0)
func vec4i*[T: SomeInteger](x: T): Vec4i =
  vec4i(x, 0, 0, 0)
func vec4i*(): Vec4i =
  vec4i(0, 0, 0, 0)

# shortcuts Vec3i8
func vec1i8*[T: SomeInteger](x: T): Vec1i8 =
  Vec1i8([int8(x)])
func vec1i8*(): Vec1i8 =
  vec1i8(0)
func vec1u8*[T: SomeInteger](x: T): Vec1u8 =
  Vec1u8([uint8(x)])
func vec1u8*(): Vec1u8 =
  vec1u8(0)

# missing: unsigned ones
func vec2i8*[T, S: SomeInteger](x: T, y: S): Vec2i8 =
  Vec2i8([int8(x), int8(y)])
func vec2i8*[T: SomeInteger](x: T): Vec2i8 =
  vec2i8(x, 0)
func vec2i8*(): Vec2i8 =
  vec2i8(0, 0)

func vec3i8*[T, S, U: SomeInteger](x: T, y: S, z: U): Vec3i8 =
  Vec3i8([int8(x), int8(y), int8(z)])
func vec3i8*[T, S: SomeInteger](x: T, y: S): Vec3i8 =
  vec3i8(x, y, 0)
func vec3i8*[T: SomeInteger](x: T): Vec3i8 =
  vec3i8(x, 0, 0)
func vec3i8*(): Vec3i8 =
  vec3i8(0, 0, 0)

# shortcuts color
func toVec*(value: string, gamma = 2.2'f32): Vec4f =
  # converts hex-string to color, also applies gamma of 2.2
  assert value != ""
  var hex = value
  if hex[0] == '#':
    hex = hex[1 .. ^1]
  # when 3 or 6 -> set alpha to 1.0
  assert hex.len == 3 or hex.len == 6 or hex.len == 4 or hex.len == 8
  if hex.len == 3:
    hex = hex & "f"
  if hex.len == 4:
    hex = hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2] & hex[3] & hex[3]
  if hex.len == 6:
    hex = hex & "ff"
  assert hex.len == 8
  let
    r = parseHexInt(hex[0 .. 1]).float32 / 255'f32
    g = parseHexInt(hex[2 .. 3]).float32 / 255'f32
    b = parseHexInt(hex[4 .. 5]).float32 / 255'f32
    a = parseHexInt(hex[6 .. 7]).float32 / 255'f32
  return vec4(pow(r, gamma), pow(g, gamma), pow(b, gamma), a)

const
  R* = vec4(1, 0, 0, 1)
  G* = vec4(1, 0, 0, 1)
  B* = vec4(1, 0, 0, 1)

  O* = vec3(0, 0, 0)
  X* = vec3(1, 0, 0)
  Y* = vec3(0, 1, 0)
  Z* = vec3(0, 0, 1)
  XY* = vec3(1, 1, 0)
  XZ* = vec3(1, 0, 1)
  YZ* = vec3(0, 1, 1)
  XYZ* = vec3(1, 1, 1)

  Oi* = vec3i(0, 0, 0)
  Xi* = vec3i(1, 0, 0)
  Yi* = vec3i(0, 1, 0)
  Zi* = vec3i(0, 0, 1)
  XYi* = vec3i(1, 1, 0)
  XZi* = vec3i(1, 0, 1)
  YZi* = vec3i(0, 1, 1)
  XYZi* = vec3i(1, 1, 1)

  Oi8* = vec3i8(0, 0, 0)
  Xi8* = vec3i8(1, 0, 0)
  Yi8* = vec3i8(0, 1, 0)
  Zi8* = vec3i8(0, 0, 1)
  XYi8* = vec3i8(1, 1, 0)
  XZi8* = vec3i8(1, 0, 1)
  YZi8* = vec3i8(0, 1, 1)
  XYZi8* = vec3i8(1, 1, 1)

func to*[T](v: TVec1): auto =
  TVec1([T(v[0])])
func to*[T](v: TVec2): auto =
  TVec2([T(v[0]), T(v[1])])
func to*[T](v: TVec3): auto =
  TVec3([T(v[0]), T(v[1]), T(v[2])])
func to*[T](v: TVec4): auto =
  TVec4([T(v[0]), T(v[1]), T(v[2]), T(v[3])])

func f32*(v: TVec1): auto =
  to[float32](v)
func f32*(v: TVec2): auto =
  to[float32](v)
func f32*(v: TVec3): auto =
  to[float32](v)
func f32*(v: TVec4): auto =
  to[float32](v)

func i32*(v: TVec1): auto =
  to[int32](v)
func i32*(v: TVec2): auto =
  to[int32](v)
func i32*(v: TVec3): auto =
  to[int32](v)
func i32*(v: TVec4): auto =
  to[int32](v)

func i8*(v: TVec1): auto =
  to[int8](v)
func i8*(v: TVec2): auto =
  to[int8](v)
func i8*(v: TVec3): auto =
  to[int8](v)
func i8*(v: TVec4): auto =
  to[int8](v)

func toVecString[T: TVec](value: T): string =
  var items: seq[string]
  for item in value:
    when elementType(value) is SomeFloat:
      items.add(&"{item:.5f}")
    else:
      items.add(&"{item}")
  &"(" & join(items, "  ") & ")"

func `$`*(v: TVec1[SomeNumber]): string =
  toVecString[TVec1[SomeNumber]](v)
func `$`*(v: TVec2[SomeNumber]): string =
  toVecString[TVec2[SomeNumber]](v)
func `$`*(v: TVec3[SomeNumber]): string =
  toVecString[TVec3[SomeNumber]](v)
func `$`*(v: TVec4[SomeNumber]): string =
  toVecString[TVec4[SomeNumber]](v)

func length*(vec: TVec1): auto =
  vec[0]
func length*(vec: TVec2[SomeFloat]): auto =
  sqrt(vec[0] * vec[0] + vec[1] * vec[1])
func length*(vec: TVec2[SomeInteger]): auto =
  sqrt(float(vec[0] * vec[0] + vec[1] * vec[1]))
func length*(vec: TVec3[SomeFloat]): auto =
  sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2])
func length*(vec: TVec3[SomeInteger]): auto =
  sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]))
func length*(vec: TVec4[SomeFloat]): auto =
  sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3])
func length*(vec: TVec4[SomeInteger]): auto =
  sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]))

func abs*[T](vec: TVec1[T]): auto =
  TVec1([abs(vec[0])])
func abs*[T](vec: TVec2[T]): auto =
  TVec2([abs(vec[0]), abs(vec[1])])
func abs*[T](vec: TVec3[T]): auto =
  TVec3([abs(vec[0]), abs(vec[1]), abs(vec[2])])
func abs*[T](vec: TVec4[T]): auto =
  TVec4([abs(vec[0]), abs(vec[1]), abs(vec[2]), abs(vec[3])])

func round*[T](vec: TVec1[T]): auto =
  TVec1([round(vec[0])])
func round*[T](vec: TVec2[T]): auto =
  TVec2([round(vec[0]), round(vec[1])])
func round*[T](vec: TVec3[T]): auto =
  TVec3([round(vec[0]), round(vec[1]), round(vec[2])])
func round*[T](vec: TVec4[T]): auto =
  TVec4([round(vec[0]), round(vec[1]), round(vec[2]), round(vec[3])])

func floor*[T](vec: TVec1[T]): auto =
  TVec1([floor(vec[0])])
func floor*[T](vec: TVec2[T]): auto =
  TVec2([floor(vec[0]), floor(vec[1])])
func floor*[T](vec: TVec3[T]): auto =
  TVec3([floor(vec[0]), floor(vec[1]), floor(vec[2])])
func floor*[T](vec: TVec4[T]): auto =
  TVec4([floor(vec[0]), floor(vec[1]), floor(vec[2]), floor(vec[3])])

func ceil*[T](vec: TVec1[T]): auto =
  TVec1([ceil(vec[0])])
func ceil*[T](vec: TVec2[T]): auto =
  TVec2([ceil(vec[0]), ceil(vec[1])])
func ceil*[T](vec: TVec3[T]): auto =
  TVec3([ceil(vec[0]), ceil(vec[1]), ceil(vec[2])])
func ceil*[T](vec: TVec4[T]): auto =
  TVec4([ceil(vec[0]), ceil(vec[1]), ceil(vec[2]), ceil(vec[3])])

func clamp*[T, S: SomeNumber](vec: TVec1[T], a, b: S): auto =
  TVec1([clamp(vec[0], a, b)])
func clamp*[T, S: SomeNumber](vec: TVec2[T], a, b: S): auto =
  TVec2([clamp(vec[0], a, b), clamp(vec[1], a, b)])
func clamp*[T, S: SomeNumber](vec: TVec3[T], a, b: S): auto =
  TVec3([clamp(vec[0], a, b), clamp(vec[1], a, b), clamp(vec[2], a, b)])
func clamp*[T, S: SomeNumber](vec: TVec4[T], a, b: S): auto =
  TVec4(
    [clamp(vec[0], a, b), clamp(vec[1], a, b), clamp(vec[2], a, b), clamp(vec[3], a, b)]
  )
func clamp*[T, S: SomeNumber](vec: TVec1[T], a, b: TVec1[S]): auto =
  TVec1[T]([clamp(vec[0], a[0], b[0])])
func clamp*[T, S: SomeNumber](vec: TVec2[T], a, b: TVec2[S]): auto =
  TVec2[T]([clamp(vec[0], a[0], b[0]), clamp(vec[1], a[1], b[1])])
func clamp*[T, S: SomeNumber](vec: TVec3[T], a, b: TVec3[S]): auto =
  TVec3[T](
    [clamp(vec[0], a[0], b[0]), clamp(vec[1], a[1], b[1]), clamp(vec[2], a[2], b[2])]
  )
func clamp*[T, S: SomeNumber](vec: TVec4[T], a, b: TVec4[S]): auto =
  TVec4[T](
    [
      clamp(vec[0], a[0], b[0]),
      clamp(vec[1], a[1], b[1]),
      clamp(vec[2], a[2], b[2]),
      clamp(vec[3], a[3], b[3]),
    ]
  )

func manhattan*(vec: TVec1): auto =
  abs(vec[0])
func manhattan*(vec: TVec2): auto =
  abs(vec[0]) + abs(vec[1])
func manhattan*(vec: TVec3): auto =
  abs(vec[0]) + abs(vec[1]) + abs(vec[2])
func manhattan*(vec: TVec4): auto =
  abs(vec[0]) + abs(vec[1]) + abs(vec[2]) + abs(vec[3])

func normal*[T: SomeFloat](vec: TVec2[T]): auto =
  TVec2[T]([vec[1], -vec[0]])

func normalized*[T: SomeFloat](vec: TVec1[T]): auto =
  return T(1)
func normalized*[T: SomeFloat](vec: TVec2[T]): auto =
  let l = vec.length
  if l == 0:
    vec
  else:
    TVec2[T]([vec[0] / l, vec[1] / l])
func normalized*[T: SomeFloat](vec: TVec3[T]): auto =
  let l = vec.length
  if l == 0:
    return vec
  else:
    TVec3[T]([vec[0] / l, vec[1] / l, vec[2] / l])
func normalized*[T: SomeFloat](vec: TVec4[T]): auto =
  let l = vec.length
  if l == 0:
    return vec
  else:
    TVec4[T]([vec[0] / l, vec[1] / l, vec[2] / l, vec[3] / l])

# scalar operations
func `+`*[T](a: TVec1[T], b: SomeNumber): auto =
  TVec1([a[0] + T(b)])
func `+`*[T](a: TVec2[T], b: SomeNumber): auto =
  TVec2([a[0] + T(b), a[1] + T(b)])
func `+`*[T](a: TVec3[T], b: SomeNumber): auto =
  TVec3([a[0] + T(b), a[1] + T(b), a[2] + T(b)])
func `+`*[T](a: TVec4[T], b: SomeNumber): auto =
  TVec4([a[0] + T(b), a[1] + T(b), a[2] + T(b), a[3] + T(b)])
func `-`*[T](a: TVec1[T], b: SomeNumber): auto =
  TVec1([a[0] - T(b)])
func `-`*[T](a: TVec2[T], b: SomeNumber): auto =
  TVec2([a[0] - T(b), a[1] - T(b)])
func `-`*[T](a: TVec3[T], b: SomeNumber): auto =
  TVec3([a[0] - T(b), a[1] - T(b), a[2] - T(b)])
func `-`*[T](a: TVec4[T], b: SomeNumber): auto =
  TVec4([a[0] - T(b), a[1] - T(b), a[2] - T(b), a[3] - T(b)])
func `*`*[T](a: TVec1[T], b: SomeNumber): auto =
  TVec1([a[0] * T(b)])
func `*`*[T](a: TVec2[T], b: SomeNumber): auto =
  TVec2([a[0] * T(b), a[1] * T(b)])
func `*`*[T](a: TVec3[T], b: SomeNumber): auto =
  TVec3([a[0] * T(b), a[1] * T(b), a[2] * T(b)])
func `*`*[T](a: TVec4[T], b: SomeNumber): auto =
  TVec4([a[0] * T(b), a[1] * T(b), a[2] * T(b), a[3] * T(b)])
func `div`*[T, S: SomeInteger](a: TVec1[T], b: S): auto =
  TVec1[T]([a[0] div T(b)])
func `/`*[T, S: SomeFloat](a: TVec1[T], b: S): auto =
  TVec1[T]([a[0] / T(b)])
func `div`*[T, S: SomeInteger](a: TVec2[T], b: S): auto =
  TVec2([a[0] div T(b), a[1] div T(b)])
func `/`*[T, S: SomeFloat](a: TVec2[T], b: S): auto =
  TVec2[T]([a[0] / T(b), a[1] / T(b)])
func `div`*[T, S: SomeInteger](a: TVec3[T], b: S): auto =
  TVec3([a[0] div T(b), a[1] div T(b), a[2] div T(b)])
func `/`*[T, S: SomeFloat](a: TVec3[T], b: S): auto =
  TVec3[T]([a[0] / T(b), a[1] / T(b), a[2] / T(b)])
func `div`*[T, S: SomeInteger](a: TVec4[T], b: S): auto =
  TVec4([a[0] div T(b), a[1] div T(b), a[2] div T(b), a[3] div T(b)])
func `/`*[T, S: SomeFloat](a: TVec4[T], b: S): auto =
  TVec4[T]([a[0] / T(b), a[1] / T(b), a[2] / T(b), a[3] / T(b)])

func `+`*(a: SomeNumber, b: TVec1): auto =
  TVec1([a + b[0]])
func `+`*(a: SomeNumber, b: TVec2): auto =
  TVec2([a + b[0], a + b[1]])
func `+`*(a: SomeNumber, b: TVec3): auto =
  TVec3([a + b[0], a + b[1], a + b[2]])
func `+`*(a: SomeNumber, b: TVec4): auto =
  TVec4([a + b[0], a + b[1], a + b[2], a + b[3]])
func `-`*(a: SomeNumber, b: TVec1): auto =
  TVec1([a - b[0]])
func `-`*(a: SomeNumber, b: TVec2): auto =
  TVec2([a - b[0], a - b[1]])
func `-`*(a: SomeNumber, b: TVec3): auto =
  TVec3([a - b[0], a - b[1], a - b[2]])
func `-`*(a: SomeNumber, b: TVec4): auto =
  TVec4([a - b[0], a - b[1], a - b[2], a - b[3]])
func `*`*(a: SomeNumber, b: TVec1): auto =
  TVec1([a * b[0]])
func `*`*(a: SomeNumber, b: TVec2): auto =
  TVec2([a * b[0], a * b[1]])
func `*`*(a: SomeNumber, b: TVec3): auto =
  TVec3([a * b[0], a * b[1], a * b[2]])
func `*`*(a: SomeNumber, b: TVec4): auto =
  TVec4([a * b[0], a * b[1], a * b[2], a * b[3]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec1[T]): auto =
  TVec1([a div b[0]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec1[T]): auto =
  TVec1([a / b[0]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec2[T]): auto =
  TVec2([a div b[0], a div b[1]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec2[T]): auto =
  TVec2([a / b[0], a / b[1]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec3[T]): auto =
  TVec3([a div b[0], a div b[1], a div b[2]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec3[T]): auto =
  TVec3([a / b[0], a / b[1], a / b[2]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec4[T]): auto =
  TVec4([a div b[0], a div b[1], a div b[2], a div b[3]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec4[T]): auto =
  TVec4([a / b[0], a / b[1], a / b[2], a / b[3]])

# compontent-wise operations
func `+`*(a, b: TVec1): auto =
  TVec1([a[0] + b[0]])
func `+`*(a, b: TVec2): auto =
  TVec2([a[0] + b[0], a[1] + b[1]])
func `+`*(a, b: TVec3): auto =
  TVec3([a[0] + b[0], a[1] + b[1], a[2] + b[2]])
func `+`*(a, b: TVec4): auto =
  TVec4([a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]])
func `-`*(a: TVec1): auto =
  TVec1([-a[0]])
func `-`*(a: TVec2): auto =
  TVec2([-a[0], -a[1]])
func `-`*(a: TVec3): auto =
  TVec3([-a[0], -a[1], -a[2]])
func `-`*(a: TVec4): auto =
  TVec4([-a[0], -a[1], -a[2], -a[3]])
func `-`*(a, b: TVec1): auto =
  TVec1([a[0] - b[0]])
func `-`*(a, b: TVec2): auto =
  TVec2([a[0] - b[0], a[1] - b[1]])
func `-`*(a, b: TVec3): auto =
  TVec3([a[0] - b[0], a[1] - b[1], a[2] - b[2]])
func `-`*(a, b: TVec4): auto =
  TVec4([a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]])
func `*`*(a, b: TVec1): auto =
  TVec1([a[0] * b[0]])
func `*`*(a, b: TVec2): auto =
  TVec2([a[0] * b[0], a[1] * b[1]])
func `*`*(a, b: TVec3): auto =
  TVec3([a[0] * b[0], a[1] * b[1], a[2] * b[2]])
func `*`*(a, b: TVec4): auto =
  TVec4([a[0] * b[0], a[1] * b[1], a[2] * b[2], a[3] * b[3]])
func `div`*[T: SomeInteger](a, b: TVec1[T]): auto =
  TVec1([a[0] div b[0]])
func floorDiv*[T: SomeInteger](a, b: TVec1[T]): auto =
  TVec1([floorDiv(a[0], b[0])])
func floorMod*[T: SomeInteger](a, b: TVec1[T]): auto =
  TVec1([floorMod(a[0], b[0])])
func `/`*[T: SomeInteger](a, b: TVec1[T]): auto =
  TVec1([a[0] / b[0]])
func `/`*[T: SomeFloat](a, b: TVec1[T]): auto =
  TVec1([a[0] / b[0]])
func `div`*[T: SomeInteger](a, b: TVec2[T]): auto =
  TVec2([a[0] div b[0], a[1] div b[1]])
func floorDiv*[T: SomeInteger](a, b: TVec2[T]): auto =
  TVec2([floorDiv(a[0], b[0]), floorDiv(a[1], b[1])])
func floorMod*[T: SomeInteger](a, b: TVec2[T]): auto =
  TVec2([floorMod(a[0], b[0]), floorMod(a[1], b[1])])
func `/`*[T: SomeInteger](a, b: TVec2[T]): auto =
  TVec2([a[0] / b[0], a[1] / b[1]])
func `/`*[T: SomeFloat](a, b: TVec2[T]): auto =
  TVec2([a[0] / b[0], a[1] / b[1]])
func `div`*[T: SomeInteger](a, b: TVec3[T]): auto =
  TVec3([a[0] div b[0], a[1] div b[1], a[2] div b[2]])
func floorDiv*[T: SomeInteger](a, b: TVec3[T]): auto =
  TVec3([floorDiv(a[0], b[0]), floorDiv(a[1], b[1]), floorDiv(a[2], b[2])])
func floorMod*[T: SomeInteger](a, b: TVec3[T]): auto =
  TVec3([floorMod(a[0], b[0]), floorMod(a[1], b[1]), floorMod(a[2], b[2])])
func `/`*[T: SomeInteger](a, b: TVec3[T]): auto =
  TVec3([a[0] / b[0], a[1] / b[1], a[2] / b[2]])
func `/`*[T: SomeFloat](a, b: TVec3[T]): auto =
  TVec3([a[0] / b[0], a[1] / b[1], a[2] / b[2]])
func `div`*[T: SomeInteger](a, b: TVec4[T]): auto =
  TVec4([a[0] div b[0], a[1] div b[1], a[2] div b[2], a[3] div b[3]])
func floorDiv*[T: SomeInteger](a, b: TVec4[T]): auto =
  TVec4(
    [
      floorDiv(a[0], b[0]),
      floorDiv(a[1], b[1]),
      floorDiv(a[2], b[2]),
      floorDiv(a[3], b[3]),
    ]
  )
func floorMod*[T: SomeInteger](a, b: TVec4[T]): auto =
  TVec4(
    [
      floorMod(a[0], b[0]),
      floorMod(a[1], b[1]),
      floorMod(a[2], b[2]),
      floorMod(a[3], b[3]),
    ]
  )
func `/`*[T: SomeInteger](a, b: TVec4[T]): auto =
  TVec4([a[0] / b[0], a[1] / b[1], a[2] / b[2], a[3] / b[3]])
func `/`*[T: SomeFloat](a, b: TVec4[T]): auto =
  TVec4([a[0] / b[0], a[1] / b[1], a[2] / b[2], a[3] / b[3]])

func `mod`*[T: SomeInteger](a, b: TVec1[T]): auto =
  TVec1([a[0] mod b[0]])
func `mod`*[T: SomeInteger](a, b: TVec2[T]): auto =
  TVec2([a[0] mod b[0], a[1] mod b[1]])
func `mod`*[T: SomeInteger](a, b: TVec3[T]): auto =
  TVec3([a[0] mod b[0], a[1] mod b[1], a[2] mod b[2]])
func `mod`*[T: SomeInteger](a, b: TVec4[T]): auto =
  TVec4([a[0] mod b[0], a[1] mod b[1], a[2] mod b[2], a[3] mod b[3]])

# assignment operations, scalar
func `+=`*(a: var TVec1, b: SomeNumber) =
  a = a + b
func `+=`*(a: var TVec2, b: SomeNumber) =
  a = a + b
func `+=`*(a: var TVec3, b: SomeNumber) =
  a = a + b
func `+=`*(a: var TVec4, b: SomeNumber) =
  a = a + b
func `-=`*(a: var TVec1, b: SomeNumber) =
  a = a - b
func `-=`*(a: var TVec2, b: SomeNumber) =
  a = a - b
func `-=`*(a: var TVec3, b: SomeNumber) =
  a = a - b
func `-=`*(a: var TVec4, b: SomeNumber) =
  a = a - b
func `*=`*(a: var TVec1, b: SomeNumber) =
  a = a * b
func `*=`*(a: var TVec2, b: SomeNumber) =
  a = a * b
func `*=`*(a: var TVec3, b: SomeNumber) =
  a = a * b
func `*=`*(a: var TVec4, b: SomeNumber) =
  a = a * b
func `/=`*(a: var TVec1, b: SomeNumber) =
  a = a / b
func `/=`*(a: var TVec2, b: SomeNumber) =
  a = a / b
func `/=`*(a: var TVec3, b: SomeNumber) =
  a = a / b
func `/=`*(a: var TVec4, b: SomeNumber) =
  a = a / b
# assignment operations, vector
func `+=`*(a: var TVec1, b: TVec1) =
  a = a + b
func `+=`*(a: var TVec2, b: TVec2) =
  a = a + b
func `+=`*(a: var TVec3, b: TVec3) =
  a = a + b
func `+=`*(a: var TVec4, b: TVec4) =
  a = a + b
func `-=`*(a: var TVec1, b: TVec1) =
  a = a - b
func `-=`*(a: var TVec2, b: TVec2) =
  a = a - b
func `-=`*(a: var TVec3, b: TVec3) =
  a = a - b
func `-=`*(a: var TVec4, b: TVec4) =
  a = a - b
func `*=`*(a: var TVec1, b: TVec1) =
  a = a * b
func `*=`*(a: var TVec2, b: TVec2) =
  a = a * b
func `*=`*(a: var TVec3, b: TVec3) =
  a = a * b
func `*=`*(a: var TVec4, b: TVec4) =
  a = a * b
func `/=`*(a: var TVec1, b: TVec1) =
  a = a / b
func `/=`*(a: var TVec2, b: TVec2) =
  a = a / b
func `/=`*(a: var TVec3, b: TVec3) =
  a = a / b
func `/=`*(a: var TVec4, b: TVec4) =
  a = a / b

# special operations
func pow*(a: TVec1, b: SomeNumber): auto =
  TVec1([pow(a[0], b)])
func pow*(a: TVec2, b: SomeNumber): auto =
  TVec2([pow(a[0], b), pow(a[1], b)])
func pow*(a: TVec3, b: SomeNumber): auto =
  TVec3([pow(a[0], b), pow(a[1], b), pow(a[2], b)])
func pow*(a: TVec4, b: SomeNumber): auto =
  TVec4([pow(a[0], b), pow(a[1], b), pow(a[2], b), pow(a[3], b)])
func dot*(a, b: TVec1): auto =
  a[0] * b[0]
func dot*(a, b: TVec2): auto =
  a[0] * b[0] + a[1] * b[1]
func dot*(a, b: TVec3): auto =
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
func dot*(a, b: TVec4): auto =
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
func cross*(a, b: TVec3): auto =
  TVec3(
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  )

# macro to allow creation of new vectors by specifying vector components as attributes
# e.g. myVec.xxy will return a new Vec3 that contains the components x, x an y of the original vector
# (instead of x, y, z for a simple copy)
proc vectorAttributeAccessor(accessor: string): seq[NimNode] =
  const ACCESSOR_INDICES =
    {'x': 0, 'y': 1, 'z': 2, 'w': 3, 'r': 0, 'g': 1, 'b': 2, 'a': 3}.toTable
  var getterCode, setterCode: NimNode
  let accessorvalue = accessor

  if accessorvalue.len == 0:
    raise newException(Exception, "empty attribute")
  elif accessorvalue.len == 1:
    getterCode =
      nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[accessorvalue[0]]))
    setterCode = nnkStmtList.newTree(
      nnkAsgn.newTree(
        nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[accessorvalue[0]])),
        ident("value"),
      )
    )
  if accessorvalue.len > 1:
    var attrs = nnkBracket.newTree()
    for attrname in accessorvalue:
      attrs.add(
        nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[attrname]))
      )
    getterCode = nnkCall.newTree(ident("TVec" & $accessorvalue.len), attrs)
    setterCode = nnkStmtList.newTree()
    var i = 0
    for attrname in accessorvalue:
      setterCode.add nnkAsgn.newTree(
        nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[attrname])),
        nnkBracketExpr.newTree(ident("value"), newLit(i)),
      )
      inc i

  result.add newProc(
    name = nnkPostfix.newTree(ident("*"), ident(accessor)),
    params =
      [ident("auto"), nnkIdentDefs.newTree(ident("vec"), ident("TVec"), newEmptyNode())],
    body = newStmtList(getterCode),
    procType = nnkFuncDef,
  )

  result.add nnkFuncDef.newTree(
    nnkPostfix.newTree(
      newIdentNode("*"), nnkAccQuoted.newTree(newIdentNode(accessor), newIdentNode("="))
    ),
    newEmptyNode(),
    nnkGenericParams.newTree(
      nnkIdentDefs.newTree(newIdentNode("T"), newEmptyNode(), newEmptyNode())
    ),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(
        newIdentNode("vec"), nnkVarTy.newTree(newIdentNode("TVec")), newEmptyNode()
      ),
      nnkIdentDefs.newTree(newIdentNode("value"), newIdentNode("T"), newEmptyNode()),
    ),
    newEmptyNode(),
    newEmptyNode(),
    setterCode,
  )

template x*[T: TVec](v: T): untyped =
  v[0]

template y*[T: TVec](v: T): untyped =
  v[1]

template z*[T: TVec](v: T): untyped =
  v[2]

template w*[T: TVec](v: T): untyped =
  v[3]

template r*[T: TVec](v: T): untyped =
  v[0]

template g*[T: TVec](v: T): untyped =
  v[1]

template b*[T: TVec](v: T): untyped =
  v[2]

template a*[T: TVec](v: T): untyped =
  v[3]

template `x=`*[T: TVec, S](v: T, a: S): untyped =
  v[0] = a

template `y=`*[T: TVec, S](v: T, a: S): untyped =
  v[1] = a

template `z=`*[T: TVec, S](v: T, a: S): untyped =
  v[2] = a

template `w=`*[T: TVec, S](v: T, a: S): untyped =
  v[3] = a

template `r=`*[T: TVec, S](v: T, a: S): untyped =
  v[0] = a

template `g=`*[T: TVec, S](v: T, a: S): untyped =
  v[1] = a

template `b=`*[T: TVec, S](v: T, a: S): untyped =
  v[2] = a

template `a=`*[T: TVec, S](v: T, a: S): untyped =
  v[3] = a

macro createVectorAttribAccessorFuncs() =
  const COORD_ATTRS = ["x", "y", "z", "w"]
  const COLOR_ATTRS = ["r", "g", "b", "a"]
  result = nnkStmtList.newTree()
  for attlist in [COORD_ATTRS, COLOR_ATTRS]:
    for i in attlist:
      for j in attlist:
        result.add(vectorAttributeAccessor(i & j))
        for k in attlist:
          result.add(vectorAttributeAccessor(i & j & k))
          for l in attlist:
            result.add(vectorAttributeAccessor(i & j & k & l))

createVectorAttribAccessorFuncs()

func angleBetween*(a, b: Vec3f): float32 =
  arccos(a.dot(b) / (a.length * b.length))

func lerp*[T](a, b: T, value: SomeFloat): T =
  (1 - value) * a + value * b
