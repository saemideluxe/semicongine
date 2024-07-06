import std/random
import std/math
import std/strutils
import std/strformat
import std/macros
import std/typetraits
import std/tables

import ./vulkanapi

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

# define some often used constants
func ConstOne1[T: SomeNumber](): auto {.compiletime.} = TVec1[T]([T(1)])
func ConstOne2[T: SomeNumber](): auto {.compiletime.} = TVec2[T]([T(1), T(1)])
func ConstOne3[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(1), T(1), T(1)])
func ConstOne4[T: SomeNumber](): auto {.compiletime.} = TVec4[T]([T(1), T(1), T(1), T(1)])
func ConstX[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(1), T(0), T(0)])
func ConstY[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(0), T(1), T(0)])
func ConstZ[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(0), T(0), T(1)])
func ConstR[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(1), T(0), T(0)])
func ConstG[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(0), T(1), T(0)])
func ConstB[T: SomeNumber](): auto {.compiletime.} = TVec3[T]([T(0), T(0), T(1)])

func NewVec2f*(x = 0'f32, y = 0'f32): auto =
  Vec2f([x, y])
func NewVec3f*(x = 0'f32, y = 0'f32, z = 0'f32): auto =
  Vec3f([x, y, z])
func NewVec4f*(x = 0'f32, y = 0'f32, z = 0'f32, a = 0'f32): auto =
  Vec4f([x, y, z, a])
func NewVec2i*(x = 0'i32, y = 0'i32): auto =
  Vec2i([x, y])
func NewVec3i*(x = 0'i32, y = 0'i32, z = 0'i32): auto =
  Vec3i([x, y, z])
func NewVec4i*(x = 0'i32, y = 0'i32, z = 0'i32, a = 0'i32): auto =
  Vec4i([x, y, z, a])
func NewVec2u*(x = 0'u32, y = 0'u32): auto =
  Vec2u([x, y])
func NewVec3u*(x = 0'u32, y = 0'u32, z = 0'u32): auto =
  Vec3u([x, y, z])
func NewVec4u*(x = 0'u32, y = 0'u32, z = 0'u32, a = 0'u32): auto =
  Vec4u([x, y, z, a])

# generates constants: Xf, Xf32, Xf64, Xi, Xi8, Xi16, Xi32, Xi64
# Also for Y, Z, R, G, B and One
# not sure if this is necessary or even a good idea...
macro generateAllConsts() =
  result = newStmtList()
  for component in ["X", "Y", "Z", "R", "G", "B", "One2", "One3", "One4"]:
    for theType in ["int", "int8", "int16", "int32", "int64", "float", "float32", "float64"]:
      var typename = theType[0 .. 0]
      if theType[^2].isDigit:
        typename = typename & theType[^2]
      if theType[^1].isDigit:
        typename = typename & theType[^1]
      result.add(
        newConstStmt(
          postfix(ident(component & typename), "*"),
          newCall(nnkBracketExpr.newTree(ident("Const" & component), ident(theType)))
        )
      )

generateAllConsts()

const X* = ConstX[float32]()
const Y* = ConstY[float32]()
const Z* = ConstZ[float32]()
const One1* = ConstOne1[float32]()
const One2* = ConstOne2[float32]()
const One3* = ConstOne3[float32]()
const One4* = ConstOne4[float32]()

func NewVec1*[T](x: T): auto = TVec1([x])
func NewVec2*[T](x, y: T): auto = TVec2([x, y])
func NewVec3*[T](x, y, z: T): auto = TVec3([x, y, z])
func NewVec4*[T](x, y, z, w: T): auto = TVec4([x, y, z, w])

func To*[T](v: TVec1): auto = TVec1([T(v[0])])
func To*[T](v: TVec2): auto = TVec2([T(v[0]), T(v[1])])
func To*[T](v: TVec3): auto = TVec3([T(v[0]), T(v[1]), T(v[2])])
func To*[T](v: TVec4): auto = TVec4([T(v[0]), T(v[1]), T(v[2]), T(v[3])])

func toString[T](value: T): string =
  var items: seq[string]
  for item in value:
    items.add(&"{item.float:.5f}")
  & "(" & join(items, "  ") & ")"

func `$`*(v: TVec1[SomeNumber]): string = toString[TVec1[SomeNumber]](v)
func `$`*(v: TVec2[SomeNumber]): string = toString[TVec2[SomeNumber]](v)
func `$`*(v: TVec3[SomeNumber]): string = toString[TVec3[SomeNumber]](v)
func `$`*(v: TVec4[SomeNumber]): string = toString[TVec4[SomeNumber]](v)

func Length*(vec: TVec1): auto = vec[0]
func Length*(vec: TVec2[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1])
func Length*(vec: TVec2[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1]))
func Length*(vec: TVec3[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2])
func Length*(vec: TVec3[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]))
func Length*(vec: TVec4[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3])
func Length*(vec: TVec4[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]))

func Normal*[T: SomeFloat](vec: TVec2[T]): auto =
  TVec2[T]([vec[1], -vec[0]])

func Normalized*[T: SomeFloat](vec: TVec1[T]): auto =
  return T(1)
func Normalized*[T: SomeFloat](vec: TVec2[T]): auto =
  let l = vec.Length
  if l == 0: vec
  else: TVec2[T]([vec[0] / l, vec[1] / l])
func Normalized*[T: SomeFloat](vec: TVec3[T]): auto =
  let l = vec.Length
  if l == 0: return vec
  else: TVec3[T]([vec[0] / l, vec[1] / l, vec[2] / l])
func Normalized*[T: SomeFloat](vec: TVec4[T]): auto =
  let l = vec.Length
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
func Pow*(a: TVec1, b: SomeNumber): auto =
  TVec1([pow(a[0], b)])
func Pow*(a: TVec2, b: SomeNumber): auto =
  TVec2([pow(a[0], b), pow(a[1], b)])
func Pow*(a: TVec3, b: SomeNumber): auto =
  TVec3([pow(a[0], b), pow(a[1], b), pow(a[2], b)])
func Pow*(a: TVec4, b: SomeNumber): auto =
  TVec4([pow(a[0], b), pow(a[1], b), pow(a[2], b), pow(a[3], b)])
func Dot*(a, b: TVec1): auto = a[0] * b[0]
func Dot*(a, b: TVec2): auto = a[0] * b[0] + a[1] * b[1]
func Dot*(a, b: TVec3): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
func Dot*(a, b: TVec4): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
func Cross*(a, b: TVec3): auto = TVec3([
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
template makeRandomInit(mattype: typedesc) =
  proc Randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.len:
      result[i] = rand(low(typeof(m[0])) .. high(typeof(m[0])))
  proc Randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.len:
      result[i] = rand(1.0)

makeRandomInit(TVec1)
makeRandomInit(TVec2)
makeRandomInit(TVec3)
makeRandomInit(TVec4)

converter Vec2VkExtent*(vec: TVec2[uint32]): VkExtent2D = VkExtent2D(width: vec[0], height: vec[1])
converter Vec3VkExtent*(vec: TVec2[uint32]): VkExtent3D = VkExtent3D(width: vec[0], height: vec[1], depth: vec[2])

func AngleBetween*(a, b: Vec3f): float32 =
  arccos(a.Dot(b) / (a.Length * b.Length))
