import std/math
import std/macros
import std/random
import std/strutils
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
  TMat22*[T: SomeNumber] = object
    data*: array[4, T]
  TMat23*[T: SomeNumber] = object
    data*: array[6, T]
  TMat32*[T: SomeNumber] = object
    data*: array[6, T]
  TMat33*[T: SomeNumber] = object
    data*: array[9, T]
  TMat34*[T: SomeNumber] = object
    data*: array[12, T]
  TMat43*[T: SomeNumber] = object
    data*: array[12, T]
  TMat44*[T: SomeNumber] = object
    data*: array[16, T]
  TMat* = TMat22|TMat33|TMat44|TMat23|TMat32|TMat34|TMat43
  Mat22 = TMat22[float32]
  Mat23 = TMat22[float32]
  Mat32 = TMat22[float32]
  Mat33 = TMat22[float32]
  Mat34 = TMat22[float32]
  Mat43 = TMat22[float32]
  Mat44 = TMat22[float32]

func unit22[T: SomeNumber](): auto {.compiletime.} = TMat22[T](data:[
  T(1), T(0),
  T(0), T(1),
])
func unit33[T: SomeNumber](): auto {.compiletime.} = TMat33[T](data:[
  T(1), T(0), T(0),
  T(0), T(1), T(0),
  T(0), T(0), T(1),
])
func unit44[T: SomeNumber](): auto {.compiletime.} = TMat44[T](data: [
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
      postfix(ident("Unit22" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("unit22"), ident(theType)))
    ))
    result.add(newConstStmt(
      postfix(ident("Unit33" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("unit33"), ident(theType)))
    ))
    result.add(newConstStmt(
      postfix(ident("Unit44" & typename), "*"),
      newCall(nnkBracketExpr.newTree(ident("unit44"), ident(theType)))
    ))

generateAllConsts()

const Unit22* = unit22[float]()
const Unit33* = unit33[float]()
const Unit44* = unit44[float]()

template rowCount*(m: typedesc): int =
  when m is TMat22: 2
  elif m is TMat23: 2
  elif m is TMat32: 3
  elif m is TMat33: 3
  elif m is TMat34: 3
  elif m is TMat43: 4
  elif m is TMat44: 4
template columnCount*(m: typedesc): int =
  when m is TMat22: 2
  elif m is TMat23: 3
  elif m is TMat32: 2
  elif m is TMat33: 3
  elif m is TMat34: 4
  elif m is TMat43: 3
  elif m is TMat44: 4


func toString[T](value: T): string =
  var
    strvalues: seq[string]
    maxwidth = 0

  for n in value.data:
    let strval = $n
    strvalues.add(strval)
    if strval.len > maxwidth:
      maxwidth = strval.len

  for i in 0 ..< strvalues.len:
    let filler = " ".repeat(maxwidth - strvalues[i].len)
    if i mod T.columnCount == T.columnCount - 1:
      result &= filler & strvalues[i] & "\n"
    else:
      if i mod T.columnCount == 0:
        result &= "  "
      result &= filler & strvalues[i] & "  "
  result = $T & "\n" & result

func `$`*(v: TMat22[SomeNumber]): string = toString[TMat22[SomeNumber]](v)
func `$`*(v: TMat23[SomeNumber]): string = toString[TMat23[SomeNumber]](v)
func `$`*(v: TMat32[SomeNumber]): string = toString[TMat32[SomeNumber]](v)
func `$`*(v: TMat33[SomeNumber]): string = toString[TMat33[SomeNumber]](v)
func `$`*(v: TMat34[SomeNumber]): string = toString[TMat34[SomeNumber]](v)
func `$`*(v: TMat43[SomeNumber]): string = toString[TMat43[SomeNumber]](v)
func `$`*(v: TMat44[SomeNumber]): string = toString[TMat44[SomeNumber]](v)

func `[]`*[T: TMat](m: T, row, col: int): auto = m.data[col + row * T.columnCount]
proc `[]=`*[T: TMat, U](m: var T, row, col: int, value: U) = m.data[col + row * T.columnCount] = value

func row*[T: TMat22](m: T, i: 0..1): auto = TVec2([m[i, 0], m[i, 1]])
func row*[T: TMat32](m: T, i: 0..2): auto = TVec2([m[i, 0], m[i, 1]])
func row*[T: TMat23](m: T, i: 0..1): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat33](m: T, i: 0..2): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat43](m: T, i: 0..3): auto = TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat34](m: T, i: 0..2): auto = TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])
func row*[T: TMat44](m: T, i: 0..3): auto = TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])

func col*[T: TMat22](m: T, i: 0..1): auto = TVec2([m[0, i], m[1, i]])
func col*[T: TMat23](m: T, i: 0..2): auto = TVec2([m[0, i], m[1, i]])
func col*[T: TMat32](m: T, i: 0..1): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat33](m: T, i: 0..2): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat34](m: T, i: 0..3): auto = TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat43](m: T, i: 0..2): auto = TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])
func col*[T: TMat44](m: T, i: 0..3): auto = TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])

proc createMatMatMultiplicationOperator(leftType: typedesc, rightType: typedesc, outType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< rowCount(leftType):
    for j in 0 ..< rightType.columnCount:
      data.add(newCall(
        ident("sum"),
        infix(
          newCall(newDotExpr(ident("a"), ident("row")), newLit(i)),
          "*",
          newCall(newDotExpr(ident("b"), ident("col")), newLit(j))
        )
      ))

  return newProc(
    postfix(nnkAccQuoted.newTree(ident("*")), "*"),
    params=[
      ident("auto"),
      newIdentDefs(ident("a"), ident(leftType.name)),
      newIdentDefs(ident("b"), ident(rightType.name))
    ],
    body=nnkObjConstr.newTree(ident(outType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType=nnkFuncDef,
  )

proc createVecMatMultiplicationOperator(matType: typedesc, vecType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< matType.rowCount:
    data.add(newCall(
      ident("sum"),
      infix(
        ident("v"),
        "*",
        newCall(newDotExpr(ident("m"), ident("row")), newLit(i))
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
  for i in 0 ..< matType.rowCount * matType.columnCount:
    data.add(infix(nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)), op, ident("b")))
  result.add(newProc(
    postfix(nnkAccQuoted.newTree(ident(op)), "*"),
    params=[
      ident("auto"),
      newIdentDefs(ident("a"), ident(matType.name)),
      newIdentDefs(ident("b"), ident("SomeNumber")),
    ],
    body=nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType=nnkFuncDef,
  ))
  result.add(newProc(
    postfix(nnkAccQuoted.newTree(ident(op)), "*"),
    params=[
      ident("auto"),
      newIdentDefs(ident("b"), ident("SomeNumber")),
      newIdentDefs(ident("a"), ident(matType.name)),
    ],
    body=nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)),
    procType=nnkFuncDef,
  ))
  if op == "-":
    var data2 = nnkBracket.newTree()
    for i in 0 ..< matType.rowCount * matType.columnCount:
      data2.add(prefix(nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)), op))
    result.add(newProc(
      postfix(nnkAccQuoted.newTree(ident(op)), "*"),
      params=[
        ident("auto"),
        newIdentDefs(ident("a"), ident(matType.name)),
      ],
      body=nnkObjConstr.newTree(ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data2)),
      procType=nnkFuncDef,
    ))

macro createAllMultiplicationOperators() =
  result = newStmtList()

  for op in ["+", "-", "*", "/"]:
    result.add(createMatScalarOperator(TMat22, op))
    result.add(createMatScalarOperator(TMat23, op))
    result.add(createMatScalarOperator(TMat32, op))
    result.add(createMatScalarOperator(TMat33, op))
    result.add(createMatScalarOperator(TMat34, op))
    result.add(createMatScalarOperator(TMat43, op))
    result.add(createMatScalarOperator(TMat44, op))

  result.add(createMatMatMultiplicationOperator(TMat22, TMat22, TMat22))
  result.add(createMatMatMultiplicationOperator(TMat22, TMat23, TMat23))
  result.add(createMatMatMultiplicationOperator(TMat23, TMat32, TMat22))
  result.add(createMatMatMultiplicationOperator(TMat23, TMat33, TMat23))
  result.add(createMatMatMultiplicationOperator(TMat32, TMat22, TMat32))
  result.add(createMatMatMultiplicationOperator(TMat32, TMat23, TMat33))
  result.add(createMatMatMultiplicationOperator(TMat33, TMat32, TMat32))
  result.add(createMatMatMultiplicationOperator(TMat33, TMat33, TMat33))
  result.add(createMatMatMultiplicationOperator(TMat33, TMat34, TMat34))
  result.add(createMatMatMultiplicationOperator(TMat43, TMat33, TMat43))
  result.add(createMatMatMultiplicationOperator(TMat43, TMat34, TMat44))
  result.add(createMatMatMultiplicationOperator(TMat44, TMat43, TMat43))
  result.add(createMatMatMultiplicationOperator(TMat44, TMat44, TMat44))

  result.add(createVecMatMultiplicationOperator(TMat22, TVec2))
  result.add(createVecMatMultiplicationOperator(TMat33, TVec3))
  result.add(createVecMatMultiplicationOperator(TMat44, TVec4))

createAllMultiplicationOperators()


func transposed*[T](m: TMat22[T]): TMat22[T] = TMat22[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
])
func transposed*[T](m: TMat23[T]): TMat32[T] = TMat32[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
  m[0, 2], m[1, 2],
])
func transposed*[T](m: TMat32[T]): TMat23[T] = TMat23[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
])
func transposed*[T](m: TMat33[T]): TMat33[T] = TMat33[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
])
func transposed*[T](m: TMat43[T]): TMat34[T] = TMat34[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
])
func transposed*[T](m: TMat34[T]): TMat43[T] = TMat43[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
  m[0, 3], m[1, 3], m[2, 3],
])
func transposed*[T](m: TMat44[T]): TMat44[T] = TMat44[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
  m[0, 3], m[1, 3], m[2, 3], m[3, 3],
])

func translate2d*[T](x, y: T): TMat33[T] = TMat33[T](data: [
  T(1), T(0), x,
  T(0), T(1), y,
  T(0), T(0), T(1),
])
func scale2d*[T](sx, sy: T): TMat33[T] = TMat33[T](data: [
  sx, T(0), T(0),
  T(0), sy, T(0),
  T(0), T(0), T(1),
])
func rotate2d*[T](angle: T): TMat33[T] = TMat33[T](data: [
  cos(angle), -sin(angle), T(0),
  sin(angle), cos(angle), T(0),
  T(0), T(0), T(1),
])
func translate3d*[T](x, y, z: T): TMat44[T] = TMat44[T](data: [
  T(1), T(0), T(0), x,
  T(0), T(1), T(0), y,
  T(0), T(0), T(1), z,
  T(0), T(0), T(0), T(1),
])
func scale3d*[T](sx, sy, sz: T): TMat44[T] = TMat44[T](data: [
  sx, T(0), T(0), T(0),
  T(0), sy, T(0), T(0),
  T(0), T(0), sz, T(0),
  T(0), T(0),  T(0), T(1),
])
func rotate3d*[T](angle: T, a: TVec3[T]): TMat44[T] =
  let
    cosa = cos(angle)
    sina = sin(angle)
    x = a[0]
    y = a[1]
    z = a[2]
  TMat44[T](data: [
    x * x * (1 - cosa) + cosa,     y * x * (1 - cosa) - z * sina, z * x * (1 - cosa) + y * sina, T(0),
    x * y * (1 - cosa) + z * sina, y * y * (1 - cosa) + cosa,     z * y * (1 - cosa) - x * sina, T(0),
    x * z * (1 - cosa) - y * sina, y * z * (1 - cosa) + x * sina, z * z * (1 - cosa) + cosa,     T(0),
    T(0),                          T(0),                          T(0),                          T(1),
  ])


# call e.g. TMat32[int]().randomized() to get a random matrix
template makeRandomInit(mattype: typedesc) =
    proc randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.data.len:
        result.data[i] = rand(low(typeof(m.data[0])) .. high(typeof(m.data[0])))
    proc randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.data.len:
        result.data[i] = rand(1.0)

makeRandomInit(TMat22)
makeRandomInit(TMat23)
makeRandomInit(TMat32)
makeRandomInit(TMat33)
makeRandomInit(TMat34)
makeRandomInit(TMat43)
makeRandomInit(TMat44)

func perspective*[T: SomeFloat](fovy, aspect, zNear, zFar: T): TMat44[T] =
  let tanHalfFovy = tan(fovy / T(2))
  return TMat44[T](data:[
    T(1) / (aspect * tanHalfFovy), T(0),               T(0),                     T(0),
    T(0),                          T(1) / tanHalfFovy, T(0),                     T(0),
    T(0),                          T(0),               T(zFar / (zFar - zNear)), T(-(zFar * zNear) / (zFar - zNear)),
    T(0),                          T(0),               T(1),                     T(1),
  ])

func ortho*[T: SomeFloat](left, right, top, bottom, zNear, zFar: T): TMat44[T] =
  TMat44[T](data:[
    T(2) / (right - left), T(0),                  T(0),                  -(right + left) / (right - left),
    T(0),                  T(2) / (bottom - top), T(0),                  -(bottom + top) / (bottom - top),
    T(0),                  T(0),                  T(1) / (zFar - zNear), -zNear / (zFar - zNear),
    T(0),                  T(0),                  T(1),                   T(1),
  ])
