import random
import math

import semicongine/math/vector
import semicongine/math/matrix


proc echoInfo(v: TVec) =
  echo v
  echo "  Length: ", v.length
  echo "  Normlized: ", v.normalized
  echo "  negated: ", -v

proc echoAdd[T, U](v1: T, v2: U) =
  echo v1, " + ", v2, " = ", v1 + v2
proc echoSub[T, U](v1: T, v2: U) =
  echo v1, " - ", v2, " = ", v1 - v2
proc echoMul[T, U](v1: T, v2: U) =
  echo v1, " * ", v2, " = ", v1 * v2
proc echoDiv[T, U](v1: T, v2: U) =
  echo v1, " / ", v2, " = ", v1 / v2
proc echoDot[T, U](v1: T, v2: U) =
  echo v1, " o ", v2, " = ", v1.dot(v2)
proc echoCross[T, U](v1: T, v2: U) =
  echo v1, " x ", v2, " = ", v1.cross(v2)

proc randVec2I(): auto = newVec2(rand(1 .. 10), rand(1 .. 10))
proc randVec2F(): auto = newVec2(rand(10'f) + 0.01, rand(10'f) + 0.01)
proc randVec3I(): auto = newVec3(rand(1 .. 10), rand(1 .. 10), rand(1 .. 10))
proc randVec3F(): auto = newVec3(rand(10'f) + 0.01, rand(10'f) + 0.01, rand(10'f) + 0.01)
proc randVec4I(): auto = newVec4(rand(1 .. 10), rand(1 .. 10), rand(1 .. 10), rand(1 .. 10))
proc randVec4F(): auto = newVec4(rand(10'f) + 0.01, rand(10'f) + 0.01, rand(10'f) + 0.01, rand(10'f) + 0.01)


template withAllIntegerMats(stuff: untyped) =
  stuff(TMat22[int32])
  stuff(TMat23[int32])
  stuff(TMat32[int32])
  stuff(TMat33[int32])
  stuff(TMat34[int32])
  stuff(TMat43[int32])
  stuff(TMat44[int32])
  stuff(TMat22[int64])
  stuff(TMat23[int64])
  stuff(TMat32[int64])
  stuff(TMat33[int64])
  stuff(TMat34[int64])
  stuff(TMat43[int64])
  stuff(TMat44[int64])

template withAllFloatMats(stuff: untyped) =
  stuff(TMat22[float32])
  stuff(TMat23[float32])
  stuff(TMat32[float32])
  stuff(TMat33[float32])
  stuff(TMat34[float32])
  stuff(TMat43[float32])
  stuff(TMat44[float32])
  stuff(TMat22[float64])
  stuff(TMat23[float64])
  stuff(TMat32[float64])
  stuff(TMat33[float64])
  stuff(TMat34[float64])
  stuff(TMat43[float64])
  stuff(TMat44[float64])

template withAllMats(stuff: untyped) =
  stuff(TMat22[int])
  stuff(TMat23[int])
  stuff(TMat32[int])
  stuff(TMat33[int])
  stuff(TMat34[int])
  stuff(TMat43[int])
  stuff(TMat44[int])
  stuff(TMat22[float])
  stuff(TMat23[float])
  stuff(TMat32[float])
  stuff(TMat33[float])
  stuff(TMat34[float])
  stuff(TMat43[float])
  stuff(TMat44[float])

template testTranspose(t: typedesc) =
  echo "testTranspose: ", t
  let m = t().randomized()
  assert m == m.transposed().transposed()

template testAssignI(t: typedesc) =
  echo "testAssignI: ", t
  var m = t()
  for i in 0 ..< t.data.len:
    m[rand(0 ..< t.rowCount), rand(0 ..< t.columnCount)] = rand(0'i32 .. 100'i32)

template testAssignF(t: typedesc) =
  echo "testAssignF: ", t
  var m = t()
  for i in 0 ..< t.data.len:
    m[rand(0 ..< t.rowCount), rand(0 ..< t.columnCount)] = rand(100'f)

template testRowCols(t: typedesc) =
  echo "testRowCols: ", t
  var m = t().randomized()
  for i in 0 ..< t.rowCount:
    echo m.row(i)
  for i in 0 ..< t.columnCount:
    echo m.col(i)


proc testMatrix() =
  withAllMats(testTranspose)
  withAllIntegerMats(testAssignI)
  withAllFloatMats(testAssignF)
  withAllMats(testRowCols)

  echo Unit22
  echo Unit22i
  echo Unit22i8
  echo Unit22i16
  echo Unit22i32
  echo Unit22i64

  echo Unit33
  echo Unit33i
  echo Unit33i8
  echo Unit33i16
  echo Unit33i32
  echo Unit33i64

  echo Unit44
  echo Unit44i
  echo Unit44i8
  echo Unit44i16
  echo Unit44i32
  echo Unit44i64

  echo TMat22[float]().randomized() * One2.randomized()
  echo TMat33[float]().randomized() * One3.randomized()
  echo TMat44[float]().randomized() * One4.randomized()

randomize()
testMatrix()
