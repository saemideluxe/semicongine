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

  TMat* = TMat2 | TMat3 | TMat4 | TMat23 | TMat32 | TMat34 | TMat43
  TSquareMat = TMat2 | TMat3 | TMat4
  Mat2* = TMat2[float32]
  Mat23* = TMat23[float32]
  Mat32* = TMat32[float32]
  Mat3* = TMat3[float32]
  Mat34* = TMat34[float32]
  Mat43* = TMat43[float32]
  Mat4* = TMat4[float32]

func makeUnit2[T: SomeNumber](): auto {.compiletime.} =
  TMat2[T](data: [T(1), T(0), T(0), T(1)])
func makeUnit3[T: SomeNumber](): auto {.compiletime.} =
  TMat3[T](data: [T(1), T(0), T(0), T(0), T(1), T(0), T(0), T(0), T(1)])
func makeUnit4[T: SomeNumber](): auto {.compiletime.} =
  TMat4[T](
    data: [
      T(1),
      T(0),
      T(0),
      T(0),
      T(0),
      T(1),
      T(0),
      T(0),
      T(0),
      T(0),
      T(1),
      T(0),
      T(0),
      T(0),
      T(0),
      T(1),
    ]
  )

# generates constants: Unit
# Also for Y, Z, R, G, B
# not sure if this is necessary or even a good idea...
macro generateAllMatrixConsts() =
  result = newStmtList()
  for theType in [
    "int", "int8", "int16", "int32", "int64", "float", "float32", "float64"
  ]:
    var typename = theType[0 .. 0]
    if theType[^2].isDigit:
      typename = typename & theType[^2]
    if theType[^1].isDigit:
      typename = typename & theType[^1]
    result.add(
      newConstStmt(
        postfix(ident("Unit2" & typename), "*"),
        newCall(nnkBracketExpr.newTree(ident("makeUnit2"), ident(theType))),
      )
    )
    result.add(
      newConstStmt(
        postfix(ident("Unit3" & typename), "*"),
        newCall(nnkBracketExpr.newTree(ident("makeUnit3"), ident(theType))),
      )
    )
    result.add(
      newConstStmt(
        postfix(ident("Unit4" & typename), "*"),
        newCall(nnkBracketExpr.newTree(ident("makeUnit4"), ident(theType))),
      )
    )

generateAllMatrixConsts()

const Unit2* = makeUnit2[float32]()
const Unit3* = makeUnit3[float32]()
const Unit4* = makeUnit4[float32]()

template RowCount*(m: typedesc): int =
  when m is TMat2:
    2
  elif m is TMat23:
    2
  elif m is TMat32:
    3
  elif m is TMat3:
    3
  elif m is TMat34:
    3
  elif m is TMat43:
    4
  elif m is TMat4:
    4

template ColumnCount*(m: typedesc): int =
  when m is TMat2:
    2
  elif m is TMat23:
    3
  elif m is TMat32:
    2
  elif m is TMat3:
    3
  elif m is TMat34:
    4
  elif m is TMat43:
    3
  elif m is TMat4:
    4

template matlen(m: typedesc): int =
  when m is TMat2:
    4
  elif m is TMat23:
    6
  elif m is TMat32:
    6
  elif m is TMat3:
    9
  elif m is TMat34:
    12
  elif m is TMat43:
    12
  elif m is TMat4:
    16

func toMatString[T: TMat](value: T): string =
  var
    strvalues: seq[string]
    maxwidth = 0

  for n in value.data:
    let strval = &"{float(n):.4f}"
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

func `$`*(v: TMat2[SomeNumber]): string =
  toMatString[TMat2[SomeNumber]](v)
func `$`*(v: TMat23[SomeNumber]): string =
  toMatString[TMat23[SomeNumber]](v)
func `$`*(v: TMat32[SomeNumber]): string =
  toMatString[TMat32[SomeNumber]](v)
func `$`*(v: TMat3[SomeNumber]): string =
  toMatString[TMat3[SomeNumber]](v)
func `$`*(v: TMat34[SomeNumber]): string =
  toMatString[TMat34[SomeNumber]](v)
func `$`*(v: TMat43[SomeNumber]): string =
  toMatString[TMat43[SomeNumber]](v)
func `$`*(v: TMat4[SomeNumber]): string =
  toMatString[TMat4[SomeNumber]](v)

func `[]`*[T: TMat](m: T, row, col: int): auto =
  m.data[col + row * T.ColumnCount]
func `[]=`*[T: TMat, U](m: var T, row, col: int, value: U) =
  m.data[col + row * T.ColumnCount] = value
func `[]`*[T: TMat](m: T, i: int): auto =
  m.data[i]
func `[]=`*[T: TMat, U](m: var T, i: int, value: U) =
  m.data[i] = value

func row*[T: TMat2](m: T, i: 0 .. 1): auto =
  TVec2([m[i, 0], m[i, 1]])
func row*[T: TMat32](m: T, i: 0 .. 2): auto =
  TVec2([m[i, 0], m[i, 1]])
func row*[T: TMat23](m: T, i: 0 .. 1): auto =
  TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat3](m: T, i: 0 .. 2): auto =
  TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat43](m: T, i: 0 .. 3): auto =
  TVec3([m[i, 0], m[i, 1], m[i, 2]])
func row*[T: TMat34](m: T, i: 0 .. 2): auto =
  TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])
func row*[T: TMat4](m: T, i: 0 .. 3): auto =
  TVec4([m[i, 0], m[i, 1], m[i, 2], m[i, 3]])

func col*[T: TMat2](m: T, i: 0 .. 1): auto =
  TVec2([m[0, i], m[1, i]])
func col*[T: TMat23](m: T, i: 0 .. 2): auto =
  TVec2([m[0, i], m[1, i]])
func col*[T: TMat32](m: T, i: 0 .. 1): auto =
  TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat3](m: T, i: 0 .. 2): auto =
  TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat34](m: T, i: 0 .. 3): auto =
  TVec3([m[0, i], m[1, i], m[2, i]])
func col*[T: TMat43](m: T, i: 0 .. 2): auto =
  TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])
func col*[T: TMat4](m: T, i: 0 .. 3): auto =
  TVec4([m[0, i], m[1, i], m[2, i], m[3, i]])

proc createMatMatMultiplicationOperator(
    leftType: typedesc, rightType: typedesc, outType: typedesc
): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< RowCount(leftType):
    for j in 0 ..< rightType.ColumnCount:
      data.add(
        newCall(
          ident("sum"),
          infix(
            newCall(newDotExpr(ident("a"), ident("row")), newLit(i)),
            "*",
            newCall(newDotExpr(ident("b"), ident("col")), newLit(j)),
          ),
        )
      )

  return newProc(
    postfix(nnkAccQuoted.newTree(ident("*")), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("a"), ident(leftType.name)),
      newIdentDefs(ident("b"), ident(rightType.name)),
    ],
    body = nnkObjConstr.newTree(
      ident(outType.name), nnkExprColonExpr.newTree(ident("data"), data)
    ),
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
      )
    )

  return newProc(
    postfix(nnkAccQuoted.newTree(ident("+")), "*"),
    params = [
      ident("auto"),
      newIdentDefs(ident("a"), ident(theType.name)),
      newIdentDefs(ident("b"), ident(theType.name)),
    ],
    body = nnkObjConstr.newTree(
      ident(theType.name), nnkExprColonExpr.newTree(ident("data"), data)
    ),
    procType = nnkFuncDef,
  )

proc createVecMatMultiplicationOperator(matType: typedesc, vecType: typedesc): NimNode =
  var data = nnkBracket.newTree()
  for i in 0 ..< matType.RowCount:
    data.add(
      newCall(
        ident("sum"),
        infix(ident("v"), "*", newCall(newDotExpr(ident("m"), ident("row")), newLit(i))),
      )
    )

  let resultVec = newCall(nnkBracketExpr.newTree(ident(vecType.name), ident("T")), data)
  let name = postfix(nnkAccQuoted.newTree(ident("*")), "*")
  let genericParams = nnkGenericParams.newTree(
    nnkIdentDefs.newTree(ident("T"), ident("SomeNumber"), newEmptyNode())
  )
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
    resultVec,
  )

proc createMatScalarOperator(matType: typedesc, op: string): NimNode =
  result = newStmtList()

  var data = nnkBracket.newTree()
  for i in 0 ..< matType.RowCount * matType.ColumnCount:
    data.add(
      infix(
        nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)),
        op,
        ident("b"),
      )
    )
  result.add(
    newProc(
      postfix(nnkAccQuoted.newTree(ident(op)), "*"),
      params = [
        ident("auto"),
        newIdentDefs(ident("a"), ident(matType.name)),
        newIdentDefs(ident("b"), ident("SomeNumber")),
      ],
      body = nnkObjConstr.newTree(
        ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)
      ),
      procType = nnkFuncDef,
    )
  )
  result.add(
    newProc(
      postfix(nnkAccQuoted.newTree(ident(op)), "*"),
      params = [
        ident("auto"),
        newIdentDefs(ident("b"), ident("SomeNumber")),
        newIdentDefs(ident("a"), ident(matType.name)),
      ],
      body = nnkObjConstr.newTree(
        ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data)
      ),
      procType = nnkFuncDef,
    )
  )
  if op == "-":
    var data2 = nnkBracket.newTree()
    for i in 0 ..< matType.RowCount * matType.ColumnCount:
      data2.add(
        prefix(
          nnkBracketExpr.newTree(newDotExpr(ident("a"), ident("data")), newLit(i)), op
        )
      )
    result.add(
      newProc(
        postfix(nnkAccQuoted.newTree(ident(op)), "*"),
        params = [ident("auto"), newIdentDefs(ident("a"), ident(matType.name))],
        body = nnkObjConstr.newTree(
          ident(matType.name), nnkExprColonExpr.newTree(ident("data"), data2)
        ),
        procType = nnkFuncDef,
      )
    )

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

proc `+=`*[T1: TSquareMat, T2: TSquareMat | SomeNumber](a: var T1, b: T2) =
  a = a + b

proc `-=`*[T1: TSquareMat, T2: TSquareMat | SomeNumber](a: var T1, b: T2) =
  a = a + b

proc `*=`*[T1: TSquareMat, T2: TSquareMat | SomeNumber](a: var T1, b: T2) =
  a = a * b

func `*`*(mat: Mat4, vec: Vec3f): Vec3f =
  (mat * vec.ToVec4(1)).ToVec3

func `*`*(mat: Mat3, vec: Vec2f): Vec2f =
  (mat * vec.ToVec3(1)).ToVec2

func transposed*[T](m: TMat2[T]): TMat2[T] =
  TMat2[T](data: [m[0, 0], m[1, 0], m[0, 1], m[1, 1]])
func transposed*[T](m: TMat23[T]): TMat32[T] =
  TMat32[T](data: [m[0, 0], m[1, 0], m[0, 1], m[1, 1], m[0, 2], m[1, 2]])
func transposed*[T](m: TMat32[T]): TMat23[T] =
  TMat23[T](data: [m[0, 0], m[1, 0], m[2, 0], m[0, 1], m[1, 1], m[2, 1]])
func transposed*[T](m: TMat3[T]): TMat3[T] =
  TMat3[T](
    data:
      [m[0, 0], m[1, 0], m[2, 0], m[0, 1], m[1, 1], m[2, 1], m[0, 2], m[1, 2], m[2, 2]]
  )
func transposed*[T](m: TMat43[T]): TMat34[T] =
  TMat34[T](
    data: [
      m[0, 0],
      m[1, 0],
      m[2, 0],
      m[3, 0],
      m[0, 1],
      m[1, 1],
      m[2, 1],
      m[3, 1],
      m[0, 2],
      m[1, 2],
      m[2, 2],
      m[3, 2],
    ]
  )
func transposed*[T](m: TMat34[T]): TMat43[T] =
  TMat43[T](
    data: [
      m[0, 0],
      m[1, 0],
      m[2, 0],
      m[0, 1],
      m[1, 1],
      m[2, 1],
      m[0, 2],
      m[1, 2],
      m[2, 2],
      m[0, 3],
      m[1, 3],
      m[2, 3],
    ]
  )
func transposed*[T](m: TMat4[T]): TMat4[T] =
  TMat4[T](
    data: [
      m[0, 0],
      m[1, 0],
      m[2, 0],
      m[3, 0],
      m[0, 1],
      m[1, 1],
      m[2, 1],
      m[3, 1],
      m[0, 2],
      m[1, 2],
      m[2, 2],
      m[3, 2],
      m[0, 3],
      m[1, 3],
      m[2, 3],
      m[3, 3],
    ]
  )

func translate2d*[T](x, y: T): TMat3[T] =
  TMat3[T](data: [T(1), T(0), x, T(0), T(1), y, T(0), T(0), T(1)])
func scale2d*[T](sx, sy: T): TMat3[T] =
  TMat3[T](data: [sx, T(0), T(0), T(0), sy, T(0), T(0), T(0), T(1)])
func rotate2d*[T](angle: T): TMat3[T] =
  TMat3[T](
    data:
      [cos(angle), -sin(angle), T(0), sin(angle), cos(angle), T(0), T(0), T(0), T(1)]
  )
func translate*(x = 0'f32, y = 0'f32, z = 0'f32): TMat4[float32] =
  Mat4(
    data: [
      1'f32, 0'f32, 0'f32, x, 0'f32, 1'f32, 0'f32, y, 0'f32, 0'f32, 1'f32, z, 0'f32,
      0'f32, 0'f32, 1'f32,
    ]
  )
func translate*[T: TVec3](v: T): TMat4[float32] =
  translate(v[0], v[1], v[2])
func scale*(x = 1'f32, y = 1'f32, z = 1'f32): Mat4 =
  Mat4(
    data: [
      x, 0'f32, 0'f32, 0'f32, 0'f32, y, 0'f32, 0'f32, 0'f32, 0'f32, z, 0'f32, 0'f32,
      0'f32, 0'f32, 1'f32,
    ]
  )
func scale*[T: TVec3](v: T): TMat4[float32] =
  scale(v[0], v[1], v[2])
func rotate*(angle: float32, a: Vec3f): Mat4 =
  let
    axis = a.normalized()
    cosa = cos(angle)
    sina = sin(angle)
    x = axis.x
    y = axis.y
    z = axis.z
  Mat4(
    data: [
      x * x * (1 - cosa) + cosa,
      y * x * (1 - cosa) - z * sina,
      z * x * (1 - cosa) + y * sina,
      0'f32,
      x * y * (1 - cosa) + z * sina,
      y * y * (1 - cosa) + cosa,
      z * y * (1 - cosa) - x * sina,
      0'f32,
      x * z * (1 - cosa) - y * sina,
      y * z * (1 - cosa) + x * sina,
      z * z * (1 - cosa) + cosa,
      0'f32,
      0'f32,
      0'f32,
      0'f32,
      1'f32,
    ]
  )

func asMat3(m: Mat4): auto =
  Mat3(
    data:
      [m[0, 0], m[0, 1], m[0, 2], m[1, 0], m[1, 1], m[1, 2], m[2, 0], m[2, 1], m[2, 2]]
  )

func inversed*(a: Mat4): Mat4 =
  # from: https://stackoverflow.com/a/9614511
  var
    s0 = a[0, 0] * a[1, 1] - a[1, 0] * a[0, 1]
    s1 = a[0, 0] * a[1, 2] - a[1, 0] * a[0, 2]
    s2 = a[0, 0] * a[1, 3] - a[1, 0] * a[0, 3]
    s3 = a[0, 1] * a[1, 2] - a[1, 1] * a[0, 2]
    s4 = a[0, 1] * a[1, 3] - a[1, 1] * a[0, 3]
    s5 = a[0, 2] * a[1, 3] - a[1, 2] * a[0, 3]
    c5 = a[2, 2] * a[3, 3] - a[3, 2] * a[2, 3]
    c4 = a[2, 1] * a[3, 3] - a[3, 1] * a[2, 3]
    c3 = a[2, 1] * a[3, 2] - a[3, 1] * a[2, 2]
    c2 = a[2, 0] * a[3, 3] - a[3, 0] * a[2, 3]
    c1 = a[2, 0] * a[3, 2] - a[3, 0] * a[2, 2]
    c0 = a[2, 0] * a[3, 1] - a[3, 0] * a[2, 1]

  # Should check for 0 determinant
  var invdet = 1.0 / (s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0)

  result[0, 0] = (a[1, 1] * c5 - a[1, 2] * c4 + a[1, 3] * c3) * invdet
  result[0, 1] = (-a[0, 1] * c5 + a[0, 2] * c4 - a[0, 3] * c3) * invdet
  result[0, 2] = (a[3, 1] * s5 - a[3, 2] * s4 + a[3, 3] * s3) * invdet
  result[0, 3] = (-a[2, 1] * s5 + a[2, 2] * s4 - a[2, 3] * s3) * invdet

  result[1, 0] = (-a[1, 0] * c5 + a[1, 2] * c2 - a[1, 3] * c1) * invdet
  result[1, 1] = (a[0, 0] * c5 - a[0, 2] * c2 + a[0, 3] * c1) * invdet
  result[1, 2] = (-a[3, 0] * s5 + a[3, 2] * s2 - a[3, 3] * s1) * invdet
  result[1, 3] = (a[2, 0] * s5 - a[2, 2] * s2 + a[2, 3] * s1) * invdet

  result[2, 0] = (a[1, 0] * c4 - a[1, 1] * c2 + a[1, 3] * c0) * invdet
  result[2, 1] = (-a[0, 0] * c4 + a[0, 1] * c2 - a[0, 3] * c0) * invdet
  result[2, 2] = (a[3, 0] * s4 - a[3, 1] * s2 + a[3, 3] * s0) * invdet
  result[2, 3] = (-a[2, 0] * s4 + a[2, 1] * s2 - a[2, 3] * s0) * invdet

  result[3, 0] = (-a[1, 0] * c3 + a[1, 1] * c1 - a[1, 2] * c0) * invdet
  result[3, 1] = (a[0, 0] * c3 - a[0, 1] * c1 + a[0, 2] * c0) * invdet
  result[3, 2] = (-a[3, 0] * s3 + a[3, 1] * s1 - a[3, 2] * s0) * invdet
  result[3, 3] = (a[2, 0] * s3 - a[2, 1] * s1 + a[2, 2] * s0) * invdet

func transformed*[T, S](points: openArray[S], mat: TMat4[T]): seq[S] =
  for p in points:
    result.add mat * p

func transform*[T, S](points: var openArray[S], mat: TMat4[T]) =
  for p in points.mitems:
    p = mat * p

func projection*(fovy, aspect, zNear, zFar: float32): Mat4 =
  let tanHalfFovy = 1 / tan(fovy / 2)
  return Mat4(
    data: [
      tanHalfFovy / aspect,
      0,
      0,
      0,
      0,
      tanHalfFovy,
      0,
      0,
      0,
      0,
      zFar / (zFar - zNear),
      -(zFar * zNear) / (zFar - zNear),
      0,
      0,
      1,
      0,
    ]
  )

func ortho*(left, right, top, bottom, zNear, zFar: float32): Mat4 =
  Mat4(
    data: [
      2 / (right - left),
      0,
      0,
      -(right + left) / (right - left),
      0,
      2 / (bottom - top),
      0,
      -(bottom + top) / (bottom - top),
      0,
      0,
      1 / (zFar - zNear),
      zNear / (zFar - zNear),
      0,
      0,
      0,
      1,
    ]
  )
