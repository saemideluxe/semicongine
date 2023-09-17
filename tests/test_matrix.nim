import random
import math

import semicongine


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
  stuff(TMat2[int32])
  stuff(TMat23[int32])
  stuff(TMat32[int32])
  stuff(TMat3[int32])
  stuff(TMat34[int32])
  stuff(TMat43[int32])
  stuff(TMat4[int32])
  stuff(TMat2[int64])
  stuff(TMat23[int64])
  stuff(TMat32[int64])
  stuff(TMat3[int64])
  stuff(TMat34[int64])
  stuff(TMat43[int64])
  stuff(TMat4[int64])

template withAllFloatMats(stuff: untyped) =
  stuff(TMat2[float32])
  stuff(TMat23[float32])
  stuff(TMat32[float32])
  stuff(TMat3[float32])
  stuff(TMat34[float32])
  stuff(TMat43[float32])
  stuff(TMat4[float32])
  stuff(TMat2[float64])
  stuff(TMat23[float64])
  stuff(TMat32[float64])
  stuff(TMat3[float64])
  stuff(TMat34[float64])
  stuff(TMat43[float64])
  stuff(TMat4[float64])

template withAllMats(stuff: untyped) =
  stuff(TMat2[int])
  stuff(TMat23[int])
  stuff(TMat32[int])
  stuff(TMat3[int])
  stuff(TMat34[int])
  stuff(TMat43[int])
  stuff(TMat4[int])
  stuff(TMat2[float])
  stuff(TMat23[float])
  stuff(TMat32[float])
  stuff(TMat3[float])
  stuff(TMat34[float])
  stuff(TMat43[float])
  stuff(TMat4[float])

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

  echo Unit2
  echo Unit2i
  echo Unit2i8
  echo Unit2i16
  echo Unit2i32
  echo Unit2i64

  echo Unit3
  echo Unit3i
  echo Unit3i8
  echo Unit3i16
  echo Unit3i32
  echo Unit3i64

  echo Unit4
  echo Unit4i
  echo Unit4i8
  echo Unit4i16
  echo Unit4i32
  echo Unit4i64

  echo TMat2[float32]().randomized() * One2.randomized()
  echo TMat3[float32]().randomized() * One3.randomized()
  echo TMat4[float32]().randomized() * One4.randomized()

  echo float32(rand(1'f32)) * TMat2[float32]().randomized()
  echo TMat2[float]().randomized() * rand(1'f)
  echo TMat2[float]().randomized() * rand(1'f)
  echo TMat23[float]().randomized() * rand(1'f)
  echo TMat23[float]().randomized() * rand(1'f)
  echo TMat3[float]().randomized() * rand(1'f)
  echo TMat34[float]().randomized() * rand(1'f)
  echo TMat43[float]().randomized() * rand(1'f)
  echo TMat4[float]().randomized() * rand(1'f)

randomize()
testMatrix()
