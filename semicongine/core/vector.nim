
type
  TVec1*[T: SomeNumber] = array[1, T]
  TVec2*[T: SomeNumber] = array[2, T]
  TVec3*[T: SomeNumber] = array[3, T]
  TVec4*[T: SomeNumber] = array[4, T]
  TVec* = TVec1|TVec2|TVec3|TVec4
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

converter ToVec1*[T: SomeNumber](orig: TVec3[T]|TVec4[T]): TVec1[T] =
  TVec1[T]([orig[0]])
converter ToVec2*[T: SomeNumber](orig: TVec3[T]|TVec4[T]): TVec2[T] =
  TVec2[T]([orig[0], orig[1]])
converter ToVec3*[T: SomeNumber](orig: TVec4[T]): TVec3[T] =
  TVec3[T]([orig[0], orig[1], orig[2]])

func ToVec4*[T: SomeNumber](orig: TVec3[T], value: T = default(T)): TVec4[T] =
  TVec4[T]([orig[0], orig[1], orig[2], value])
func ToVec3*[T: SomeNumber](orig: TVec2[T], value: T = default(T)): TVec3[T] =
  TVec3[T]([orig[0], orig[1], value])
func ToVec2*[T: SomeNumber](orig: TVec1[T], value: T = default(T)): TVec2[T] =
  TVec2[T]([orig[0], value])

# shortcuts Vec3f
func vec1*[T: SomeNumber](x: T): Vec1f =
  Vec1f([float32(x)])
func vec2*[T, S: SomeNumber](x: T, y: S): Vec2f =
  Vec2f([float32(x), float32(y)])
func vec2*[T: SomeNumber](x: T): Vec2f = vec2(x, 0)
func vec2*(): Vec2f = vec2(0, 0)
func vec3*[T, S, U: SomeNumber](x: T, y: S, z: U): Vec3f =
  Vec3f([float32(x), float32(y), float32(z)])
func vec3*[T, S: SomeNumber](x: T, y: S): Vec3f = vec3(x, y, 0)
func vec3*[T: SomeNumber](x: T): Vec3f = vec3(x, 0, 0)
func vec3*(): Vec3f = vec3(0, 0, 0)
func vec4*[T, S, U, V: SomeNumber](x: T, y: S, z: U, w: V): Vec4f =
  Vec4f([float32(x), float32(y), float32(z), float32(w)])
func vec4*[T, S, U: SomeNumber](x: T, y: S, z: U): Vec4f = vec4(x, y, z, 0)
func vec4*[T, S: SomeNumber](x: T, y: S): Vec4f = vec4(x, y, 0, 0)
func vec4*[T: SomeNumber](x: T): Vec4f = vec4(x, 0, 0, 0)
func vec4*(): Vec4f = vec4(0, 0, 0, 0)

# shortcuts Vec3i
func vec1i*[T: SomeInteger](x: T): Vec1i = Vec1i([int32(x)])
func vec2i*[T, S: SomeInteger](x: T, y: S): Vec2i = Vec2i([int32(x), int32(y)])
func vec2i*[T: SomeInteger](x: T): Vec2i = vec2i(x, 0)
func vec2i*(): Vec2i = vec2i(0, 0)
func vec3i*[T, S, U: SomeInteger](x: T, y: S, z: U): Vec3i = Vec3i([int32(x), int32(y), int32(z)])
func vec3i*[T, S: SomeInteger](x: T, y: S): Vec3i = vec3i(x, y, 0)
func vec3i*[T: SomeInteger](x: T): Vec3i = vec3i(x, 0, 0)
func vec3i*(): Vec3i = vec3i(0, 0, 0)
func vec4i*[T, S, U, V: SomeInteger](x: T, y: S, z: U, w: V): Vec4i = Vec4i([int32(x), int32(y), int32(z), int32(w)])
func vec4i*[T, S, U: SomeInteger](x: T, y: S, z: U): Vec4i = vec4i(x, y, z, 0)
func vec4i*[T, S: SomeInteger](x: T, y: S): Vec4i = vec4i(x, y, 0, 0)
func vec4i*[T: SomeInteger](x: T): Vec4i = vec4i(x, 0, 0, 0)
func vec4i*(): Vec4i = vec4i(0, 0, 0, 0)

# shortcuts color
func toVec*(value: string): Vec4f =
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
  return vec4(r, g, b, a)


const
  X* = vec3(1, 0, 0)
  Y* = vec3(0, 1, 0)
  Z* = vec3(0, 0, 1)
  R* = vec4(1, 0, 0, 1)
  G* = vec4(1, 0, 0, 1)
  B* = vec4(1, 0, 0, 1)
  Xi* = vec3i(1, 0, 0)
  Yi* = vec3i(0, 1, 0)
  Zi* = vec3i(0, 0, 1)

func to*[T](v: TVec1): auto = TVec1([T(v[0])])
func to*[T](v: TVec2): auto = TVec2([T(v[0]), T(v[1])])
func to*[T](v: TVec3): auto = TVec3([T(v[0]), T(v[1]), T(v[2])])
func to*[T](v: TVec4): auto = TVec4([T(v[0]), T(v[1]), T(v[2]), T(v[3])])

func f32*(v: TVec1): auto = to[float32](v)
func f32*(v: TVec2): auto = to[float32](v)
func f32*(v: TVec3): auto = to[float32](v)
func f32*(v: TVec4): auto = to[float32](v)

func i32*(v: TVec1): auto = to[int32](v)
func i32*(v: TVec2): auto = to[int32](v)
func i32*(v: TVec3): auto = to[int32](v)
func i32*(v: TVec4): auto = to[int32](v)

func toVecString[T: TVec](value: T): string =
  var items: seq[string]
  for item in value:
    when elementType(value) is SomeFloat:
      items.add(&"{item:.5f}")
    else:
      items.add(&"{item}")
  & "(" & join(items, "  ") & ")"

func `$`*(v: TVec1[SomeNumber]): string = toVecString[TVec1[SomeNumber]](v)
func `$`*(v: TVec2[SomeNumber]): string = toVecString[TVec2[SomeNumber]](v)
func `$`*(v: TVec3[SomeNumber]): string = toVecString[TVec3[SomeNumber]](v)
func `$`*(v: TVec4[SomeNumber]): string = toVecString[TVec4[SomeNumber]](v)

func length*(vec: TVec1): auto = vec[0]
func length*(vec: TVec2[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1])
func length*(vec: TVec2[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1]))
func length*(vec: TVec3[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2])
func length*(vec: TVec3[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]))
func length*(vec: TVec4[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3])
func length*(vec: TVec4[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]))

func normal*[T: SomeFloat](vec: TVec2[T]): auto =
  TVec2[T]([vec[1], -vec[0]])

func normalized*[T: SomeFloat](vec: TVec1[T]): auto =
  return T(1)
func normalized*[T: SomeFloat](vec: TVec2[T]): auto =
  let l = vec.length
  if l == 0: vec
  else: TVec2[T]([vec[0] / l, vec[1] / l])
func normalized*[T: SomeFloat](vec: TVec3[T]): auto =
  let l = vec.length
  if l == 0: return vec
  else: TVec3[T]([vec[0] / l, vec[1] / l, vec[2] / l])
func normalized*[T: SomeFloat](vec: TVec4[T]): auto =
  let l = vec.length
  if l == 0: return vec
  else: TVec4[T]([vec[0] / l, vec[1] / l, vec[2] / l, vec[3] / l])

# scalar operations
func `+`*(a: TVec1, b: SomeNumber): auto = TVec1([a[0] + b])
func `+`*(a: TVec2, b: SomeNumber): auto = TVec2([a[0] + b, a[1] + b])
func `+`*(a: TVec3, b: SomeNumber): auto = TVec3([a[0] + b, a[1] + b, a[2] + b])
func `+`*(a: TVec4, b: SomeNumber): auto = TVec4([a[0] + b, a[1] + b, a[2] + b, a[3] + b])
func `-`*(a: TVec1, b: SomeNumber): auto = TVec1([a[0] - b])
func `-`*(a: TVec2, b: SomeNumber): auto = TVec2([a[0] - b, a[1] - b])
func `-`*(a: TVec3, b: SomeNumber): auto = TVec3([a[0] - b, a[1] - b, a[2] - b])
func `-`*(a: TVec4, b: SomeNumber): auto = TVec4([a[0] - b, a[1] - b, a[2] - b,
    a[3] - b])
func `*`*(a: TVec1, b: SomeNumber): auto = TVec1([a[0] * b])
func `*`*(a: TVec2, b: SomeNumber): auto = TVec2([a[0] * b, a[1] * b])
func `*`*(a: TVec3, b: SomeNumber): auto = TVec3([a[0] * b, a[1] * b, a[2] * b])
func `*`*(a: TVec4, b: SomeNumber): auto = TVec4([a[0] * b, a[1] * b, a[2] * b,
    a[3] * b])
func `/`*[T: SomeInteger](a: TVec1[T], b: SomeInteger): auto = TVec1([a[0] div b])
func `/`*[T: SomeFloat](a: TVec1[T], b: SomeFloat): auto = TVec1([a[0] / b])
func `/`*[T: SomeInteger](a: TVec2[T], b: SomeInteger): auto = TVec2([a[0] div b, a[1] div b])
func `/`*[T: SomeFloat](a: TVec2[T], b: SomeFloat): auto = TVec2([a[0] / b, a[1] / b])
func `/`*[T: SomeInteger](a: TVec3[T], b: SomeInteger): auto = TVec3([a[0] div b, a[1] div b, a[2] div b])
func `/`*[T: SomeFloat](a: TVec3[T], b: SomeFloat): auto = TVec3([a[0] / b, a[1] / b, a[2] / b])
func `/`*[T: SomeInteger](a: TVec4[T], b: SomeInteger): auto = TVec4([a[0] div b, a[1] div b, a[2] div b, a[3] div b])
func `/`*[T: SomeFloat](a: TVec4[T], b: SomeFloat): auto = TVec4([a[0] / b, a[1] / b, a[2] / b, a[3] / b])

func `+`*(a: SomeNumber, b: TVec1): auto = TVec1([a + b[0]])
func `+`*(a: SomeNumber, b: TVec2): auto = TVec2([a + b[0], a + b[1]])
func `+`*(a: SomeNumber, b: TVec3): auto = TVec3([a + b[0], a + b[1], a + b[2]])
func `+`*(a: SomeNumber, b: TVec4): auto = TVec4([a + b[0], a + b[1], a + b[2], a + b[3]])
func `-`*(a: SomeNumber, b: TVec1): auto = TVec1([a - b[0]])
func `-`*(a: SomeNumber, b: TVec2): auto = TVec2([a - b[0], a - b[1]])
func `-`*(a: SomeNumber, b: TVec3): auto = TVec3([a - b[0], a - b[1], a - b[2]])
func `-`*(a: SomeNumber, b: TVec4): auto = TVec4([a - b[0], a - b[1], a - b[2], a - b[3]])
func `*`*(a: SomeNumber, b: TVec1): auto = TVec1([a * b[0]])
func `*`*(a: SomeNumber, b: TVec2): auto = TVec2([a * b[0], a * b[1]])
func `*`*(a: SomeNumber, b: TVec3): auto = TVec3([a * b[0], a * b[1], a * b[2]])
func `*`*(a: SomeNumber, b: TVec4): auto = TVec4([a * b[0], a * b[1], a * b[2], a * b[3]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec1[T]): auto = TVec1([a div b[0]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec1[T]): auto = TVec1([a / b[0]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec2[T]): auto = TVec2([a div b[0], a div b[1]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec2[T]): auto = TVec2([a / b[0], a / b[1]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec3[T]): auto = TVec3([a div b[0], a div b[1], a div b[2]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec3[T]): auto = TVec3([a / b[0], a / b[1], a / b[2]])
func `/`*[T: SomeInteger](a: SomeInteger, b: TVec4[T]): auto = TVec4([a div b[
    0], a div b[1], a div b[2], a div b[3]])
func `/`*[T: SomeFloat](a: SomeFloat, b: TVec4[T]): auto = TVec4([a / b[0], a /
    b[1], a / b[2], a / b[3]])

# compontent-wise operations
func `+`*(a, b: TVec1): auto = TVec1([a[0] + b[0]])
func `+`*(a, b: TVec2): auto = TVec2([a[0] + b[0], a[1] + b[1]])
func `+`*(a, b: TVec3): auto = TVec3([a[0] + b[0], a[1] + b[1], a[2] + b[2]])
func `+`*(a, b: TVec4): auto = TVec4([a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]])
func `-`*(a: TVec1): auto = TVec1([-a[0]])
func `-`*(a: TVec2): auto = TVec2([-a[0], -a[1]])
func `-`*(a: TVec3): auto = TVec3([-a[0], -a[1], -a[2]])
func `-`*(a: TVec4): auto = TVec4([-a[0], -a[1], -a[2], -a[3]])
func `-`*(a, b: TVec1): auto = TVec1([a[0] - b[0]])
func `-`*(a, b: TVec2): auto = TVec2([a[0] - b[0], a[1] - b[1]])
func `-`*(a, b: TVec3): auto = TVec3([a[0] - b[0], a[1] - b[1], a[2] - b[2]])
func `-`*(a, b: TVec4): auto = TVec4([a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]])
func `*`*(a, b: TVec1): auto = TVec1([a[0] * b[0]])
func `*`*(a, b: TVec2): auto = TVec2([a[0] * b[0], a[1] * b[1]])
func `*`*(a, b: TVec3): auto = TVec3([a[0] * b[0], a[1] * b[1], a[2] * b[2]])
func `*`*(a, b: TVec4): auto = TVec4([a[0] * b[0], a[1] * b[1], a[2] * b[2], a[3] * b[3]])
func `/`*[T: SomeInteger](a, b: TVec1[T]): auto = TVec1([a[0] div b[0]])
func `/`*[T: SomeFloat](a, b: TVec1[T]): auto = TVec1([a[0] / b[0]])
func `/`*[T: SomeInteger](a, b: TVec2[T]): auto = TVec2([a[0] div b[0], a[1] div b[1]])
func `/`*[T: SomeFloat](a, b: TVec2[T]): auto = TVec2([a[0] / b[0], a[1] / b[1]])
func `/`*[T: SomeInteger](a, b: TVec3[T]): auto = TVec3([a[0] div b[0], a[1] div b[1], a[2] div b[2]])
func `/`*[T: SomeFloat](a, b: TVec3[T]): auto = TVec3([a[0] / b[0], a[1] / b[1], a[2] / b[2]])
func `/`*[T: SomeInteger](a, b: TVec4[T]): auto = TVec4([a[0] div b[0], a[1] div b[1], a[2] div b[2], a[3] div b[3]])
func `/`*[T: SomeFloat](a, b: TVec4[T]): auto = TVec4([a[0] / b[0], a[1] / b[1], a[2] / b[2], a[3] / b[3]])

# assignment operations, scalar
func `+=`*(a: var TVec1, b: SomeNumber) = a = a + b
func `+=`*(a: var TVec2, b: SomeNumber) = a = a + b
func `+=`*(a: var TVec3, b: SomeNumber) = a = a + b
func `+=`*(a: var TVec4, b: SomeNumber) = a = a + b
func `-=`*(a: var TVec1, b: SomeNumber) = a = a - b
func `-=`*(a: var TVec2, b: SomeNumber) = a = a - b
func `-=`*(a: var TVec3, b: SomeNumber) = a = a - b
func `-=`*(a: var TVec4, b: SomeNumber) = a = a - b
func `*=`*(a: var TVec1, b: SomeNumber) = a = a * b
func `*=`*(a: var TVec2, b: SomeNumber) = a = a * b
func `*=`*(a: var TVec3, b: SomeNumber) = a = a * b
func `*=`*(a: var TVec4, b: SomeNumber) = a = a * b
func `/=`*(a: var TVec1, b: SomeNumber) = a = a / b
func `/=`*(a: var TVec2, b: SomeNumber) = a = a / b
func `/=`*(a: var TVec3, b: SomeNumber) = a = a / b
func `/=`*(a: var TVec4, b: SomeNumber) = a = a / b
# assignment operations, vector
func `+=`*(a: var TVec1, b: TVec1) = a = a + b
func `+=`*(a: var TVec2, b: TVec2) = a = a + b
func `+=`*(a: var TVec3, b: TVec3) = a = a + b
func `+=`*(a: var TVec4, b: TVec4) = a = a + b
func `-=`*(a: var TVec1, b: TVec1) = a = a - b
func `-=`*(a: var TVec2, b: TVec2) = a = a - b
func `-=`*(a: var TVec3, b: TVec3) = a = a - b
func `-=`*(a: var TVec4, b: TVec4) = a = a - b
func `*=`*(a: var TVec1, b: TVec1) = a = a * b
func `*=`*(a: var TVec2, b: TVec2) = a = a * b
func `*=`*(a: var TVec3, b: TVec3) = a = a * b
func `*=`*(a: var TVec4, b: TVec4) = a = a * b
func `/=`*(a: var TVec1, b: TVec1) = a = a / b
func `/=`*(a: var TVec2, b: TVec2) = a = a / b
func `/=`*(a: var TVec3, b: TVec3) = a = a / b
func `/=`*(a: var TVec4, b: TVec4) = a = a / b


# special operations
func pow*(a: TVec1, b: SomeNumber): auto =
  TVec1([pow(a[0], b)])
func pow*(a: TVec2, b: SomeNumber): auto =
  TVec2([pow(a[0], b), pow(a[1], b)])
func pow*(a: TVec3, b: SomeNumber): auto =
  TVec3([pow(a[0], b), pow(a[1], b), pow(a[2], b)])
func pow*(a: TVec4, b: SomeNumber): auto =
  TVec4([pow(a[0], b), pow(a[1], b), pow(a[2], b), pow(a[3], b)])
func dot*(a, b: TVec1): auto = a[0] * b[0]
func dot*(a, b: TVec2): auto = a[0] * b[0] + a[1] * b[1]
func dot*(a, b: TVec3): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
func dot*(a, b: TVec4): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
func cross*(a, b: TVec3): auto = TVec3([
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
])


# macro to allow creation of new vectors by specifying vector components as attributes
# e.g. myVec.xxy will return a new Vec3 that contains the components x, x an y of the original vector
# (instead of x, y, z for a simple copy)
proc vectorAttributeAccessor(accessor: string): seq[NimNode] =
  const ACCESSOR_INDICES = {
    'x': 0,
    'y': 1,
    'z': 2,
    'w': 3,
    'r': 0,
    'g': 1,
    'b': 2,
    'a': 3,
  }.toTable
  var getterCode, setterCode: NimNode
  let accessorvalue = accessor

  if accessorvalue.len == 0:
    raise newException(Exception, "empty attribute")
  elif accessorvalue.len == 1:
    getterCode = nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[accessorvalue[0]]))
    setterCode = nnkStmtList.newTree(
      nnkAsgn.newTree(
        nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[accessorvalue[0]])), ident("value"))
    )
  if accessorvalue.len > 1:
    var attrs = nnkBracket.newTree()
    for attrname in accessorvalue:
      attrs.add(nnkBracketExpr.newTree(ident("vec"), newLit(ACCESSOR_INDICES[attrname])))
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
    params = [ident("auto"), nnkIdentDefs.newTree(ident("vec"), ident("TVec"), newEmptyNode())],
    body = newStmtList(getterCode),
    procType = nnkFuncDef,
  )

  result.add nnkFuncDef.newTree(
    nnkPostfix.newTree(
      newIdentNode("*"),
      nnkAccQuoted.newTree(newIdentNode(accessor), newIdentNode("="))
    ),
    newEmptyNode(),
    nnkGenericParams.newTree(nnkIdentDefs.newTree(newIdentNode("T"), newEmptyNode(), newEmptyNode())),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(newIdentNode("vec"), nnkVarTy.newTree(newIdentNode("TVec")), newEmptyNode()),
      nnkIdentDefs.newTree(newIdentNode("value"), newIdentNode("T"), newEmptyNode())
    ),
    newEmptyNode(),
    newEmptyNode(),
    setterCode
  )

macro createVectorAttribAccessorFuncs() =
  const COORD_ATTRS = ["x", "y", "z", "w"]
  const COLOR_ATTRS = ["r", "g", "b", "a"]
  result = nnkStmtList.newTree()
  for attlist in [COORD_ATTRS, COLOR_ATTRS]:
    for i in attlist:
      result.add(vectorAttributeAccessor(i))
      for j in attlist:
        result.add(vectorAttributeAccessor(i & j))
        for k in attlist:
          result.add(vectorAttributeAccessor(i & j & k))
          for l in attlist:
            result.add(vectorAttributeAccessor(i & j & k & l))

createVectorAttribAccessorFuncs()

# call e.g. Vec2[int]().randomized() to get a random matrix
template makeRandomVectorInit(mattype: typedesc) =
  proc randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.len:
      result[i] = rand(low(typeof(m[0])) .. high(typeof(m[0])))
  proc randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.len:
      result[i] = rand(1.0)

makeRandomVectorInit(TVec1)
makeRandomVectorInit(TVec2)
makeRandomVectorInit(TVec3)
makeRandomVectorInit(TVec4)

converter Vec2VkExtent*(vec: TVec2[uint32]): VkExtent2D = VkExtent2D(width: vec[0], height: vec[1])
converter Vec3VkExtent*(vec: TVec2[uint32]): VkExtent3D = VkExtent3D(width: vec[0], height: vec[1], depth: vec[2])

func angleBetween*(a, b: Vec3f): float32 =
  arccos(a.dot(b) / (a.length * b.length))
