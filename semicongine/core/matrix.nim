import std/math
import std/macros
import std/random
import std/strutils
import std/strformat
import std/typetraits

import ./vector

export math

type
  # layout is row-first
  # having an object instead of directly aliasing the array seems a bit ugly at
  # first, but is necessary to be able to work correctly with distinguished
  # types (i.e. TMat23 and TMat32 would be an alias for the same type array[6, T]
  # which prevents the type system from identifying the correct type at times)
  #
  # Though, great news is that objects have zero overhead!
  TMat2*[T: SomeNumber] = object
    data*: array[4, T]
  TMat23*[T: SomeNumber] = object
    data*: array[6, T]
  TMat32*[T: SomeNumber] = object
    data*: array[6, T]
  TMat3*[T: SomeNumber] = object
    data*: array[9, T]
  TMat34*[T: SomeNumber] = object
    data*: array[12, T]
  TMat43*[T: SomeNumber] = object
    data*: array[12, T]
  TMat4*[T: SomeNumber] = object
    data*: array[16, T]
  TMat* = TMat2|TMat3|TMat4|TMat23|TMat32|TMat34|TMat43
  Mat2* = TMat2[float32]
  Mat23* = TMat23[float32]
  Mat32* = TMat32[float32]
  Mat3* = TMat3[float32]
  Mat34* = TMat34[float32]
  Mat43* = TMat43[float32]
  Mat4* = TMat4[float32]

func MakeUnit2*[T: SomeNumber](): auto {.compiletime.} = TMat2[T](data: [
  T(1), T(0),
  T(0), T(1),
])
func MakeUnit3*[T: SomeNumber](): auto {.compiletime.} = TMat3[T](data: [
  T(1), T(0), T(0),
  T(0), T(1), T(0),
  T(0), T(0), T(1),
])
func MakeUnit4*[T: SomeNumber](): auto {.compiletime.} = TMat4[T](data: [
  T(1), T(0), T(0), T(0),
  T(0), T(1), T(0), T(0),
  T(0), T(0), T(1), T(0),
  T(0), T(0), T(0), T(1),
])

# generates constants: Unit
# Also for Y, Z, R, G, B
# not sure if this is necessary or even a good idea...
macro generateAllConsts() =
  result = newStmtList()
  for theType in ["int", "int8", "int16", "int32", "int64", "float", "float32", "float64"]:
    var typename = theType[0 .. 0]
    if theType[^2].isDigit:
      typename = typename & theType[^2]
    if theType[^1].isDigit:
      typename = typename & theType[^1]
    result.add(newConstStmt(
      postfix(ident("Unit2" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("MakeUnit2"), ident(theType)))
    ))
    result.add(newConstStmt(
      postfix(ident("Unit3" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("MakeUnit3"), ident(theType)))
    ))
    result.add(newConstStmt(
      postfix(ident("Unit4" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("MakeUnit4"), ident(theType)))
    ))

generateAllConsts()

const Unit2* = MakeUnit2[float32]()
const Unit3* = MakeUnit3[float32]()
const Unit4* = MakeUnit4[float32]()

template RowCount*(m: typedesc): int =
  when m is TMat2: 2
  elif m is TMat23: 2
  elif m is TMat32: 3
  elif m is TMat3: 3
  elif m is TMat34: 3
  elif m is TMat43: 4
  elif m is TMat4: 4
template ColumnCount*(m: typedesc): int =
  when m is TMat2: 2
  elif m is TMat23: 3
  elif m is TMat32: 2
  elif m is TMat3: 3
  elif m is TMat34: 4
  elif m is TMat43: 3
  elif m is TMat4: 4
template matlen(m: typedesc): int =
  when m is TMat2: 4
  elif m is TMat23: 6
  elif m is TMat32: 6
  elif m is TMat3: 9
  elif m is TMat34: 12
  elif m is TMat43: 12
  elif m is TMat4: 16


func toString[T](value: T): string =
  var
    strvalues: seq[string]
    maxwidth = 0

  for n in value.data:
    let strval = &"{n:.4f}"
    strvalues.add(strval)
    if strval.len > maxwidth:
      maxwidth = strval.len

  for i in 0 ..< strvalues.len:
    let filler = " ".repeat(maxwidth - strvalues[i].len)
    if i mod T.ColumnCount == T.ColumnCount - 1:
      result &= filler & strvalues[i] & "\n"
    else:
      if i mod T.ColumnCount == 0:
        result &= "  "
      result &= filler & strvalues[i] & "  "

func `$`*(v: TMat2[SomeNumber]): string = toString[TMat2[SomeNumber]](v)
func `$`*(v: TMat23[SomeNumber]): string = toString[TMat23[SomeNumber]](v)
func `$`*(v: TMat32[SomeNumber]): string = toString[TMat32[SomeNumber]](v)
func `$`*(v: TMat3[SomeNumber]): string = toString[TMat3[SomeNumber]](v)
func `$`*(v: TMat34[SomeNumber]): string = toString[TMat34[SomeNumber]](v)
func `$`*(v: TMat43[SomeNumber]): string = toString[TMat43[SomeNumber]](v)
func `$`*(v: TMat4[SomeNumber]): string = toString[TMat4[SomeNumber]](v)

func `[]`*[T: TMat](m: T, row, col: int): auto = m.data[col + row * T.ColumnCount]
func `[]=`*[T: TMat, U](m: var T, row, col: int, value: U) = m.data[col + row * T.ColumnCount] = value
func `[]`*[T: TMat](m: T, i: int): auto = m.data[i]
func `[]=`*[T: TMat, U](m: var T, i: int, value: U) = m.data[i] = value

func Row*[T: TMat2](m: T, i: 0..1): auto = TVec2([m[i, 0], m[i, 1]])
func Row*[T: TMat32](m: T, i: 0..2): auto = TVec2([m[i, 0], m[i, 1]])
func Row*[T: TMat23](m: T, i: 0..1): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func Row*[T: TMat3](m: T, i: 0..2): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func Row*[T: TMat43](m: T, i: 0..3): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func Row*[T: TMat34](m: T, i: 0..2): auto = TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])
func Row*[T: TMat4](m: T, i: 0..3): auto = TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])

func Col*[T: TMat2](m: T, i: 0..1): auto = TVec2([m[0, i], m[1, i]])
func Col*[T: TMat23](m: T, i: 0..2): auto = TVec2([m[0, i], m[1, i]])
func Col*[T: TMat32](m: T, i: 0..1): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func Col*[T: TMat3](m: T, i: 0..2): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func Col*[T: TMat34](m: T, i: 0..3): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func Col*[T: TMat43](m: T, i: 0..2): auto = TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])
func Col*[T: TMat4](m: T, i: 0..3): auto = TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])

proc createMatMatMultiplicationOperator(leftType: typedesc, rightType: typedesc, outType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< RowCount(leftType):
    for j in 0 ..< rightType.ColumnCount:
      data.add(newCall(
        ident("sum"),
        infix(
          newCall(newDotExpr(ident("a"), ident("Row")), newLit(i)),
          "*",
          newCall(newDotExpr(ident("b"), ident("Col")), newLit(j))
        )
      ))

  return newProc(
    postfix(nnkAccQuoted.newTree(ident("*")), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("a"), ident(leftType.name)),
      newIdentDefs(ident("b"), ident(rightType.name))
    ],
    body = nnkObjConstr.newTree(ident(outType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType = nnkFuncDef,
  )

proc createMatMatAdditionOperator(theType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< matlen(theType):
    data.add(
      infix(
        nnkBracketExpr.newTree(ident("a"), newLit(i)),
        "+",
        nnkBracketExpr.newTree(ident("b"), newLit(i)),
    ))

  return newProc(
    postfix(nnkAccQuoted.newTree(ident("+")), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("a"), ident(theType.name)),
      newIdentDefs(ident("b"), ident(theType.name))
    ],
    body = nnkObjConstr.newTree(ident(theType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType = nnkFuncDef,
  )

proc createVecMatMultiplicationOperator(matType: typedesc, vecType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< matType.RowCount:
    data.add(newCall(
      ident("sum"),
      infix(
        ident("v"),
        "*",
        newCall(newDotExpr(ident("m"), ident("Row")), newLit(i))
      )
    ))

  let resultVec = newCall(
    nnkBracketExpr.newTree(ident(vecType.name), ident("T")),
    data,
  )
  let name = postfix(nnkAccQuoted.newTree(ident("*")), "*")
  let genericParams = nnkGenericParams.newTree(nnkIdentDefs.newTree(ident("T"), ident("SomeNumber"), newEmptyNode()))
  let formalParams = nnkFormalParams.newTree(
    ident("auto"),
    newIdentDefs(ident("m"), nnkBracketExpr.newTree(ident(matType.name), ident("T"))),
    newIdentDefs(ident("v"), nnkBracketExpr.newTree(ident(vecType.name), ident("T"))),
  )

  return nnkFuncDef.newTree(
    name,
    newEmptyNode(),
    genericParams,
    formalParams,
    newEmptyNode(),
    newEmptyNode(),
    resultVec
  )


proc createMatScalarOperator(matType: typedesc, op: string): NimNode =
  result = newStmtList()

  var data = nnkBracket.newTree()
  for i in 0 ..< matType.RowCount * matType.ColumnCount:
    data.add(infix(nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)), op, ident("b")))
  result.add(newProc(
    postfix(nnkAccQuoted.newTree(ident(op)), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("a"), ident(matType.name)),
      newIdentDefs(ident("b"), ident("SomeNumber")),
    ],
    body = nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType = nnkFuncDef,
  ))
  result.add(newProc(
    postfix(nnkAccQuoted.newTree(ident(op)), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("b"), ident("SomeNumber")),
      newIdentDefs(ident("a"), ident(matType.name)),
    ],
    body = nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType = nnkFuncDef,
  ))
  if op == "-":
    var data2 = nnkBracket.newTree()
    for i in 0 ..< matType.RowCount * matType.ColumnCount:
      data2.add(prefix(nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)), op))
    result.add(newProc(
      postfix(nnkAccQuoted.newTree(ident(op)), "*"),
      params = [
        ident("auto"),
        newIdentDefs(ident("a"), ident(matType.name)),
      ],
      body = nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data2)),
      procType = nnkFuncDef,
    ))

macro createAllMultiplicationOperators() =
  result = newStmtList()

  for op in ["+", "-", "*", "/"]:
    result.add(createMatScalarOperator(TMat2, op))
    result.add(createMatScalarOperator(TMat23, op))
    result.add(createMatScalarOperator(TMat32, op))
    result.add(createMatScalarOperator(TMat3, op))
    result.add(createMatScalarOperator(TMat34, op))
    result.add(createMatScalarOperator(TMat43, op))
    result.add(createMatScalarOperator(TMat4, op))

  result.add(createMatMatMultiplicationOperator(TMat2, TMat2, TMat2))
  result.add(createMatMatMultiplicationOperator(TMat2, TMat23, TMat23))
  result.add(createMatMatMultiplicationOperator(TMat23, TMat32, TMat2))
  result.add(createMatMatMultiplicationOperator(TMat23, TMat3, TMat23))
  result.add(createMatMatMultiplicationOperator(TMat32, TMat2, TMat32))
  result.add(createMatMatMultiplicationOperator(TMat32, TMat23, TMat3))
  result.add(createMatMatMultiplicationOperator(TMat3, TMat32, TMat32))
  result.add(createMatMatMultiplicationOperator(TMat3, TMat3, TMat3))
  result.add(createMatMatMultiplicationOperator(TMat3, TMat34, TMat34))
  result.add(createMatMatMultiplicationOperator(TMat43, TMat3, TMat43))
  result.add(createMatMatMultiplicationOperator(TMat43, TMat34, TMat4))
  result.add(createMatMatMultiplicationOperator(TMat4, TMat43, TMat43))
  result.add(createMatMatMultiplicationOperator(TMat4, TMat4, TMat4))

  result.add(createMatMatAdditionOperator(TMat2))
  result.add(createMatMatAdditionOperator(TMat23))
  result.add(createMatMatAdditionOperator(TMat32))
  result.add(createMatMatAdditionOperator(TMat3))
  result.add(createMatMatAdditionOperator(TMat34))
  result.add(createMatMatAdditionOperator(TMat43))
  result.add(createMatMatAdditionOperator(TMat4))

  result.add(createVecMatMultiplicationOperator(TMat2, TVec2))
  result.add(createVecMatMultiplicationOperator(TMat3, TVec3))
  result.add(createVecMatMultiplicationOperator(TMat4, TVec4))

createAllMultiplicationOperators()

func `*`*(mat: Mat4, vec: Vec3f): Vec3f =
  (mat * vec.ToVec4(1)).ToVec3

func Transposed*[T](m: TMat2[T]): TMat2[T] = TMat2[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
])
func Transposed*[T](m: TMat23[T]): TMat32[T] = TMat32[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
  m[0, 2], m[1, 2],
])
func Transposed*[T](m: TMat32[T]): TMat23[T] = TMat23[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
])
func Transposed*[T](m: TMat3[T]): TMat3[T] = TMat3[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
])
func Transposed*[T](m: TMat43[T]): TMat34[T] = TMat34[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
])
func Transposed*[T](m: TMat34[T]): TMat43[T] = TMat43[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
  m[0, 3], m[1, 3], m[2, 3],
])
func Transposed*[T](m: TMat4[T]): TMat4[T] = TMat4[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
  m[0, 3], m[1, 3], m[2, 3], m[3, 3],
])

func Translate2d*[T](x, y: T): TMat3[T] = TMat3[T](data: [
  T(1), T(0), x,
  T(0), T(1), y,
  T(0), T(0), T(1),
])
func Scale2d*[T](sx, sy: T): TMat3[T] = TMat3[T](data: [
  sx, T(0), T(0),
  T(0), sy, T(0),
  T(0), T(0), T(1),
])
func Rotate2d*[T](angle: T): TMat3[T] = TMat3[T](data: [
  cos(angle), -sin(angle), T(0),
  sin(angle), cos(angle), T(0),
  T(0), T(0), T(1),
])
func Translate*(x = 0'f32, y = 0'f32, z = 0'f32): TMat4[float32] = Mat4(data: [
  1'f32, 0'f32, 0'f32, x,
  0'f32, 1'f32, 0'f32, y,
  0'f32, 0'f32, 1'f32, z,
  0'f32, 0'f32, 0'f32, 1'f32,
])
func Translate*[T: TVec3](v: T): TMat4[float32] = Translate(v[0], v[1], v[2])
func Scale*(x = 1'f32, y = 1'f32, z = 1'f32): Mat4 = Mat4(data: [
  x, 0'f32, 0'f32, 0'f32,
  0'f32, y, 0'f32, 0'f32,
  0'f32, 0'f32, z, 0'f32,
  0'f32, 0'f32, 0'f32, 1'f32,
])
func Scale*[T: TVec3](v: T): TMat4[float32] = Scale(v[0], v[1], v[2])
func Rotate*(angle: float32, a: Vec3f): Mat4 =
  let
    cosa = cos(angle)
    sina = sin(angle)
    x = a[0]
    y = a[1]
    z = a[2]
  Mat4(data: [
    x * x * (1 - cosa) + cosa, y * x * (1 - cosa) - z * sina, z * x * (1 - cosa) + y * sina, 0'f32,
    x * y * (1 - cosa) + z * sina, y * y * (1 - cosa) + cosa, z * y * (1 - cosa) - x * sina, 0'f32,
    x * z * (1 - cosa) - y * sina, y * z * (1 - cosa) + x * sina, z * z * (1 - cosa) + cosa, 0'f32,
    0'f32, 0'f32, 0'f32, 1'f32,
  ])

func asMat3(m: Mat4): auto =
  Mat3(data: [
    m[0, 0], m[0, 1], m[0, 2],
    m[1, 0], m[1, 1], m[1, 2],
    m[2, 0], m[2, 1], m[2, 2],
  ])


func Inversed*(m: Mat4): Mat4 =
  var m3 = m.asMat3.Transposed
  m3[0, 0] = 1'f32 / m3[0, 0]
  m3[1, 1] = 1'f32 / m3[1, 1]
  m3[2, 2] = 1'f32 / m3[2, 2]
  let col3 = -(m3 * m.Col(3).xyz)
  return Mat4(data: [
        m3[0, 0], m3[0, 1], m3[0, 2], col3.x,
        m3[1, 0], m3[1, 1], m3[1, 2], col3.y,
        m3[2, 0], m3[2, 1], m3[2, 2], col3.z,
               0, 0, 0, 1,
  ])


# call e.g. TMat32[int]().randomized() to get a random matrix
template makeRandomInit(mattype: typedesc) =
  proc Randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.data.len:
      result.data[i] = rand(low(typeof(m.data[0])) .. high(typeof(m.data[0])))
  proc Randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
    for i in 0 ..< result.data.len:
      result.data[i] = rand(T(1.0))

makeRandomInit(TMat2)
makeRandomInit(TMat23)
makeRandomInit(TMat32)
makeRandomInit(TMat3)
makeRandomInit(TMat34)
makeRandomInit(TMat43)
makeRandomInit(TMat4)

func Perspective*(fovy, aspect, zNear, zFar: float32): Mat4 =
  let tanHalfFovy = tan(fovy / 2)
  return Mat4(data: [
    1 / (aspect * tanHalfFovy), 0, 0, 0,
    0, 1 / tanHalfFovy, 0, 0,
    0, 0, zFar / (zFar - zNear), -(zFar * zNear) / (zFar - zNear),
    0, 0, 1, 1,
  ])

func Ortho*(left, right, top, bottom, zNear, zFar: float32): Mat4 =
  Mat4(data: [
    2 / (right - left), 0, 0, -(right + left) / (right - left),
    0, 2 / (bottom - top), 0, -(bottom + top) / (bottom - top),
    0, 0, 1 / (zFar - zNear), zNear / (zFar - zNear),
    0, 0, 0, 1,
  ])

# create an orthographic perspective that will map from -1 .. 1 on all axis and keep a 1:1 aspect ratio
# the smaller dimension (width or height) will always be 1 and the larger dimension will be larger, to keep the ratio
func OrthoWindowAspect*(windowAspect: float32): Mat4 =
  if windowAspect < 1:
    let space = 2 * (1 / windowAspect - 1) / 2
    Ortho(-1, 1, -1 - space, 1 + space, 0, 1)
  else:
    let space = 2 * (windowAspect - 1) / 2
    Ortho(-1 - space, 1 + space, -1, 1, 0, 1)

func Position*(mat: Mat4): Vec3f {.deprecated.} =
  mat.Col(3).ToVec3

func Scaling*(mat: Mat4): Vec3f {.deprecated.} =
  NewVec4f(mat[0, 0], mat[1, 1], mat[2, 2])
