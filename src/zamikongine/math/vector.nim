import std/random
import std/math
import std/strutils
import std/macros
import std/typetraits
import std/tables


type
  Vec2*[T: SomeNumber] = array[2, T]
  Vec3*[T: SomeNumber] = array[3, T]
  Vec4*[T: SomeNumber] = array[4, T]
  Vec* = Vec2|Vec3|Vec4

converter toVec2*[T: SomeNumber](orig: Vec3[T]|Vec4[T]): Vec2[T] =
  Vec2[T]([orig[0], orig[1]])
converter toVec3*[T: SomeNumber](orig: Vec4[T]): Vec3[T] =
  Vec2[T]([orig[0], orig[1], orig[2]])

# define some often used constants
func ConstOne2[T: SomeNumber](): auto {.compiletime.} = Vec2[T]([T(1), T(1)])
func ConstOne3[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(1), T(1), T(1)])
func ConstOne4[T: SomeNumber](): auto {.compiletime.} = Vec4[T]([T(1), T(1), T(1), T(1)])
func ConstX[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(1), T(0), T(0)])
func ConstY[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(0), T(1), T(0)])
func ConstZ[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(0), T(0), T(1)])
func ConstR[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(1), T(0), T(0)])
func ConstG[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(0), T(1), T(0)])
func ConstB[T: SomeNumber](): auto {.compiletime.} = Vec3[T]([T(0), T(0), T(1)])

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

const X* = ConstX[float]()
const Y* = ConstY[float]()
const Z* = ConstZ[float]()
const One2* = ConstOne2[float]()
const One3* = ConstOne3[float]()
const One4* = ConstOne4[float]()

func newVec2*[T](x, y: T): auto = Vec2([x, y])
func newVec3*[T](x, y, z: T): auto = Vec3([x, y, z])
func newVec4*[T](x, y, z, w: T): auto = Vec4([x, y, z, w])

func to*[T](v: Vec2): auto = Vec2([T(v[0]), T(v[1])])
func to*[T](v: Vec3): auto = Vec3([T(v[0]), T(v[1]), T(v[2])])
func to*[T](v: Vec4): auto = Vec4([T(v[0]), T(v[1]), T(v[2]), T(v[3])])

func toString[T](value: T): string =
  var items: seq[string]
  for item in value:
    items.add($item)
  $T & "(" & join(items, "  ") & ")"

func `$`*(v: Vec2[SomeNumber]): string = toString[Vec2[SomeNumber]](v)
func `$`*(v: Vec3[SomeNumber]): string = toString[Vec3[SomeNumber]](v)
func `$`*(v: Vec4[SomeNumber]): string = toString[Vec4[SomeNumber]](v)

func length*(vec: Vec2[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1])
func length*(vec: Vec2[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1]))
func length*(vec: Vec3[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2])
func length*(vec: Vec3[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]))
func length*(vec: Vec4[SomeFloat]): auto = sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3])
func length*(vec: Vec4[SomeInteger]): auto = sqrt(float(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]))

func normalized*[T](vec: Vec2[T]): auto =
  let l = vec.length
  when T is SomeFloat:
    Vec2[T]([vec[0] / l, vec[1] / l])
  else:
    Vec2[float]([float(vec[0]) / l, float(vec[1]) / l])
func normalized*[T](vec: Vec3[T]): auto =
  let l = vec.length
  when T is SomeFloat:
    Vec3[T]([vec[0] / l, vec[1] / l, vec[2] / l])
  else:
    Vec3[float]([float(vec[0]) / l, float(vec[1]) / l, float(vec[2]) / l])
func normalized*[T](vec: Vec4[T]): auto =
  let l = vec.length
  when T is SomeFloat:
    Vec4[T]([vec[0] / l, vec[1] / l, vec[2] / l, vec[3] / l])
  else:
    Vec4[float]([float(vec[0]) / l, float(vec[1]) / l, float(vec[2]) / l, float(vec[3]) / l])

# scalar operations
func `+`*(a: Vec2, b: SomeNumber): auto = Vec2([a[0] + b, a[1] + b])
func `+`*(a: Vec3, b: SomeNumber): auto = Vec3([a[0] + b, a[1] + b, a[2] + b])
func `+`*(a: Vec4, b: SomeNumber): auto = Vec4([a[0] + b, a[1] + b, a[2] + b, a[3] + b])
func `-`*(a: Vec2, b: SomeNumber): auto = Vec2([a[0] - b, a[1] - b])
func `-`*(a: Vec3, b: SomeNumber): auto = Vec3([a[0] - b, a[1] - b, a[2] - b])
func `-`*(a: Vec4, b: SomeNumber): auto = Vec4([a[0] - b, a[1] - b, a[2] - b, a[3] - b])
func `*`*(a: Vec2, b: SomeNumber): auto = Vec2([a[0] * b, a[1] * b])
func `*`*(a: Vec3, b: SomeNumber): auto = Vec3([a[0] * b, a[1] * b, a[2] * b])
func `*`*(a: Vec4, b: SomeNumber): auto = Vec4([a[0] * b, a[1] * b, a[2] * b, a[3] * b])
func `/`*[T: SomeInteger](a: Vec2[T], b: SomeInteger): auto = Vec2([a[0] div b, a[1] div b])
func `/`*[T: SomeFloat](a: Vec2[T], b: SomeFloat): auto = Vec2([a[0] / b, a[1] / b])
func `/`*[T: SomeInteger](a: Vec3[T], b: SomeInteger): auto = Vec3([a[0] div b, a[1] div b, a[2] div b])
func `/`*[T: SomeFloat](a: Vec3[T], b: SomeFloat): auto = Vec3([a[0] / b, a[1] / b, a[2] / b])
func `/`*[T: SomeInteger](a: Vec4[T], b: SomeInteger): auto = Vec4([a[0] div b, a[1] div b, a[2] div b, a[3] div b])
func `/`*[T: SomeFloat](a: Vec4[T], b: SomeFloat): auto = Vec4([a[0] / b, a[1] / b, a[2] / b, a[3] / b])

func `+`*(a: SomeNumber, b: Vec2): auto = Vec2([a + b[0], a + b[1]])
func `+`*(a: SomeNumber, b: Vec3): auto = Vec3([a + b[0], a + b[1], a + b[2]])
func `+`*(a: SomeNumber, b: Vec4): auto = Vec4([a + b[0], a + b[1], a + b[2], a + b[3]])
func `-`*(a: SomeNumber, b: Vec2): auto = Vec2([a - b[0], a - b[1]])
func `-`*(a: SomeNumber, b: Vec3): auto = Vec3([a - b[0], a - b[1], a - b[2]])
func `-`*(a: SomeNumber, b: Vec4): auto = Vec4([a - b[0], a - b[1], a - b[2], a - b[3]])
func `*`*(a: SomeNumber, b: Vec2): auto = Vec2([a * b[0], a * b[1]])
func `*`*(a: SomeNumber, b: Vec3): auto = Vec3([a * b[0], a * b[1], a * b[2]])
func `*`*(a: SomeNumber, b: Vec4): auto = Vec4([a * b[0], a * b[1], a * b[2], a * b[3]])
func `/`*[T: SomeInteger](a: SomeInteger, b: Vec2[T]): auto = Vec2([a div b[0], a div b[1]])
func `/`*[T: SomeFloat](a: SomeFloat, b: Vec2[T]): auto = Vec2([a / b[0], a / b[1]])
func `/`*[T: SomeInteger](a: SomeInteger, b: Vec3[T]): auto = Vec3([a div b[0], a div b[1], a div b[2]])
func `/`*[T: SomeFloat](a: SomeFloat, b: Vec3[T]): auto = Vec3([a / b[0], a / b[1], a / b[2]])
func `/`*[T: SomeInteger](a: SomeInteger, b: Vec4[T]): auto = Vec4([a div b[0], a div b[1], a div b[2], a div b[3]])
func `/`*[T: SomeFloat](a: SomeFloat, b: Vec4[T]): auto = Vec4([a / b[0], a / b[1], a / b[2], a / b[3]])

# compontent-wise operations
func `+`*(a, b: Vec2): auto = Vec2([a[0] + b[0], a[1] + b[1]])
func `+`*(a, b: Vec3): auto = Vec3([a[0] + b[0], a[1] + b[1], a[2] + b[2]])
func `+`*(a, b: Vec4): auto = Vec4([a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]])
func `-`*(a: Vec2): auto = Vec2([-a[0], -a[1]])
func `-`*(a: Vec3): auto = Vec3([-a[0], -a[1], -a[2]])
func `-`*(a: Vec4): auto = Vec4([-a[0], -a[1], -a[2], -a[3]])
func `-`*(a, b: Vec2): auto = Vec2([a[0] - b[0], a[1] - b[1]])
func `-`*(a, b: Vec3): auto = Vec3([a[0] - b[0], a[1] - b[1], a[2] - b[2]])
func `-`*(a, b: Vec4): auto = Vec4([a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]])
func `*`*(a, b: Vec2): auto = Vec2([a[0] * b[0], a[1] * b[1]])
func `*`*(a, b: Vec3): auto = Vec3([a[0] * b[0], a[1] * b[1], a[2] * b[2]])
func `*`*(a, b: Vec4): auto = Vec4([a[0] * b[0], a[1] * b[1], a[2] * b[2], a[3] * b[3]])
func `/`*[T: SomeInteger](a, b: Vec2[T]): auto = Vec2([a[0] div b[0], a[1] div b[1]])
func `/`*[T: SomeFloat](a, b: Vec2[T]): auto = Vec2([a[0] / b[0], a[1] / b[1]])
func `/`*[T: SomeInteger](a, b: Vec3[T]): auto = Vec3([a[0] div b[0], a[1] div b[1], a[2] div b[2]])
func `/`*[T: SomeFloat](a, b: Vec3[T]): auto = Vec3([a[0] / b[0], a[1] / b[1], a[2] / b[2]])
func `/`*[T: SomeInteger](a, b: Vec4[T]): auto = Vec4([a[0] div b[0], a[1] div b[1], a[2] div b[2], a[3] div b[3]])
func `/`*[T: SomeFloat](a, b: Vec4[T]): auto = Vec4([a[0] / b[0], a[1] / b[1], a[2] / b[2], a[3] / b[3]])

# special operations
func dot*(a, b: Vec2): auto = a[0] * b[0] + a[1] * b[1]
func dot*(a, b: Vec3): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
func dot*(a, b: Vec4): auto = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
func cross*(a, b: Vec3): auto = Vec3([
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
])


# macro to allow creation of new vectors by specifying vector components as attributes
# e.g. myVec.xxy will return a new Vec3 that contains the components x, x an y of the original vector
# (instead of x, y, z for a simple copy)
proc vectorAttributeAccessor(accessor: string): NimNode =
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
  var ret: NimNode
  let accessorvalue = accessor

  if accessorvalue.len == 0:
    raise newException(Exception, "empty attribute")
  elif accessorvalue.len == 1:
    ret = nnkBracket.newTree(ident("value"), newLit(ACCESSOR_INDICES[accessorvalue[0]]))
  if accessorvalue.len > 1:
    var attrs = nnkBracket.newTree()
    for attrname in accessorvalue:
      attrs.add(nnkBracketExpr.newTree(ident("value"), newLit(ACCESSOR_INDICES[attrname])))
    ret = nnkCall.newTree(ident("Vec" & $accessorvalue.len), attrs)

  newProc(
    name=nnkPostfix.newTree(ident("*"), ident(accessor)),
    params=[ident("auto"), nnkIdentDefs.newTree(ident("value"), ident("Vec"), newEmptyNode())],
    body=newStmtList(ret),
    procType = nnkFuncDef,
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
    proc randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.len:
        result[i] = rand(low(typeof(m[0])) .. high(typeof(m[0])))
    proc randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.len:
        result[i] = rand(1.0)

makeRandomInit(Vec2)
makeRandomInit(Vec3)
makeRandomInit(Vec4)
