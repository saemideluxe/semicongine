import std/math
import std/macros
import std/random
import std/strutils
import std/typetraits

import ./vector

type
  # layout is row-first
  # having an object instead of directly aliasing the array seems a bit ugly at
  # first, but is necessary to be able to work correctly with distinguished
  # types (i.e. Mat23 and Mat32 would be an alias for the same type array[6, T]
  # which prevents the type system from identifying the correct type at times)
  #
  # Though, great news is that objects have zero overhead!
  Mat22*[T: SomeNumber] = object
    data: array[4, T]
  Mat23*[T: SomeNumber] = object
    data: array[6, T]
  Mat32*[T: SomeNumber] = object
    data: array[6, T]
  Mat33*[T: SomeNumber] = object
    data: array[9, T]
  Mat34*[T: SomeNumber] = object
    data: array[12, T]
  Mat43*[T: SomeNumber] = object
    data: array[12, T]
  Mat44*[T: SomeNumber] = object
    data: array[16, T]
  MatMM* = Mat22|Mat33|Mat44
  MatMN* = Mat23|Mat32|Mat34|Mat43
  Mat* = MatMM|MatMN
  IntegerMat = Mat22[SomeInteger]|Mat33[SomeInteger]|Mat44[SomeInteger]|Mat23[SomeInteger]|Mat32[SomeInteger]|Mat34[SomeInteger]|Mat43[SomeInteger]
  FloatMat = Mat22[SomeFloat]|Mat33[SomeFloat]|Mat44[SomeFloat]|Mat23[SomeFloat]|Mat32[SomeFloat]|Mat34[SomeFloat]|Mat43[SomeFloat]

func unit22[T: SomeNumber](): auto {.compiletime.} = Mat22[T](data:[
  T(1), T(0),
  T(0), T(1),
])
func unit33[T: SomeNumber](): auto {.compiletime.} = Mat33[T](data:[
  T(1), T(0), T(0),
  T(0), T(1), T(0),
  T(0), T(0), T(1),
])
func unit44[T: SomeNumber](): auto {.compiletime.} = Mat44[T](data: [
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
  when m is Mat22: 2
  elif m is Mat23: 2
  elif m is Mat32: 3
  elif m is Mat33: 3
  elif m is Mat34: 3
  elif m is Mat43: 4
  elif m is Mat44: 4
template columnCount*(m: typedesc): int =
  when m is Mat22: 2
  elif m is Mat23: 3
  elif m is Mat32: 2
  elif m is Mat33: 3
  elif m is Mat34: 4
  elif m is Mat43: 3
  elif m is Mat44: 4


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

func `$`*(v: Mat22[SomeNumber]): string = toString[Mat22[SomeNumber]](v)
func `$`*(v: Mat23[SomeNumber]): string = toString[Mat23[SomeNumber]](v)
func `$`*(v: Mat32[SomeNumber]): string = toString[Mat32[SomeNumber]](v)
func `$`*(v: Mat33[SomeNumber]): string = toString[Mat33[SomeNumber]](v)
func `$`*(v: Mat34[SomeNumber]): string = toString[Mat34[SomeNumber]](v)
func `$`*(v: Mat43[SomeNumber]): string = toString[Mat43[SomeNumber]](v)
func `$`*(v: Mat44[SomeNumber]): string = toString[Mat44[SomeNumber]](v)

func `[]`*[T: Mat](m: T, row, col: int): auto = m.data[col + row * T.columnCount]
proc `[]=`*[T: Mat, U](m: var T, row, col: int, value: U) = m.data[col + row * T.columnCount] = value

func row*[T: Mat22](m: T, i: 0..1): auto = Vec2([m[i, 0], m[i, 1]])
func row*[T: Mat32](m: T, i: 0..2): auto = Vec2([m[i, 0], m[i, 1]])
func row*[T: Mat23](m: T, i: 0..1): auto = Vec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: Mat33](m: T, i: 0..2): auto = Vec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: Mat43](m: T, i: 0..3): auto = Vec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: Mat34](m: T, i: 0..2): auto = Vec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])
func row*[T: Mat44](m: T, i: 0..3): auto = Vec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])

func col*[T: Mat22](m: T, i: 0..1): auto = Vec2([m[0, i], m[1, i]])
func col*[T: Mat23](m: T, i: 0..2): auto = Vec2([m[0, i], m[1, i]])
func col*[T: Mat32](m: T, i: 0..1): auto = Vec3([m[0, i], m[1, i], m[2, i]])
func col*[T: Mat33](m: T, i: 0..2): auto = Vec3([m[0, i], m[1, i], m[2, i]])
func col*[T: Mat34](m: T, i: 0..3): auto = Vec3([m[0, i], m[1, i], m[2, i]])
func col*[T: Mat43](m: T, i: 0..2): auto = Vec4([m[0, i], m[1, i], m[2, i], m[3, i]])
func col*[T: Mat44](m: T, i: 0..3): auto = Vec4([m[0, i], m[1, i], m[2, i], m[3, i]])

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
   
proc createVecMatMultiplicationOperator1(vecType: typedesc, matType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< matType.columnCount:
    data.add(newCall(
      ident("sum"),
      infix(
        ident("v"),
        "*",
        newCall(newDotExpr(ident("m"), ident("col")), newLit(i))
      )
    ))
  let resultVec = nnkObjConstr.newTree(
    nnkBracketExpr.newTree(ident(vecType.name), ident("float")),
    nnkExprColonExpr.newTree(ident("data"), data)
  )

  return nnkFuncDef.newTree(
    ident("test"),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    resultVec,
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
    result.add(createMatScalarOperator(Mat22, op))
    result.add(createMatScalarOperator(Mat23, op))
    result.add(createMatScalarOperator(Mat32, op))
    result.add(createMatScalarOperator(Mat33, op))
    result.add(createMatScalarOperator(Mat34, op))
    result.add(createMatScalarOperator(Mat43, op))
    result.add(createMatScalarOperator(Mat44, op))

  result.add(createMatMatMultiplicationOperator(Mat22, Mat22, Mat22))
  result.add(createMatMatMultiplicationOperator(Mat22, Mat23, Mat23))
  result.add(createMatMatMultiplicationOperator(Mat23, Mat32, Mat22))
  result.add(createMatMatMultiplicationOperator(Mat23, Mat33, Mat23))
  result.add(createMatMatMultiplicationOperator(Mat32, Mat22, Mat32))
  result.add(createMatMatMultiplicationOperator(Mat32, Mat23, Mat33))
  result.add(createMatMatMultiplicationOperator(Mat33, Mat32, Mat32))
  result.add(createMatMatMultiplicationOperator(Mat33, Mat33, Mat33))
  result.add(createMatMatMultiplicationOperator(Mat33, Mat34, Mat34))
  result.add(createMatMatMultiplicationOperator(Mat43, Mat33, Mat43))
  result.add(createMatMatMultiplicationOperator(Mat43, Mat34, Mat44))
  result.add(createMatMatMultiplicationOperator(Mat44, Mat43, Mat43))
  result.add(createMatMatMultiplicationOperator(Mat44, Mat44, Mat44))

  result.add(createVecMatMultiplicationOperator(Mat22, Vec2))
  result.add(createVecMatMultiplicationOperator(Mat33, Vec3))
  result.add(createVecMatMultiplicationOperator(Mat44, Vec4))

createAllMultiplicationOperators()


func transposed*[T](m: Mat22[T]): Mat22[T] = Mat22[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
])
func transposed*[T](m: Mat23[T]): Mat32[T] = Mat32[T](data: [
  m[0, 0], m[1, 0],
  m[0, 1], m[1, 1],
  m[0, 2], m[1, 2],
])
func transposed*[T](m: Mat32[T]): Mat23[T] = Mat23[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
])
func transposed*[T](m: Mat33[T]): Mat33[T] = Mat33[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
])
func transposed*[T](m: Mat43[T]): Mat34[T] = Mat34[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
])
func transposed*[T](m: Mat34[T]): Mat43[T] = Mat43[T](data: [
  m[0, 0], m[1, 0], m[2, 0],
  m[0, 1], m[1, 1], m[2, 1],
  m[0, 2], m[1, 2], m[2, 2],
  m[0, 3], m[1, 3], m[2, 3],
])
func transposed*[T](m: Mat44[T]): Mat44[T] = Mat44[T](data: [
  m[0, 0], m[1, 0], m[2, 0], m[3, 0],
  m[0, 1], m[1, 1], m[2, 1], m[3, 1],
  m[0, 2], m[1, 2], m[2, 2], m[3, 2],
  m[0, 3], m[1, 3], m[2, 3], m[3, 3],
])

# call e.g. Mat32[int]().randomized() to get a random matrix
template makeRandomInit(mattype: typedesc) =
    proc randomized*[T: SomeInteger](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.data.len:
        result.data[i] = rand(low(typeof(m.data[0])) .. high(typeof(m.data[0])))
    proc randomized*[T: SomeFloat](m: mattype[T]): mattype[T] =
      for i in 0 ..< result.data.len:
        result.data[i] = rand(1.0)

makeRandomInit(Mat22)
makeRandomInit(Mat23)
makeRandomInit(Mat32)
makeRandomInit(Mat33)
makeRandomInit(Mat34)
makeRandomInit(Mat43)
makeRandomInit(Mat44)
