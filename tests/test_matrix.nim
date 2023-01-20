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
  stuff(Mat22[int32])
  stuff(Mat23[int32])
  stuff(Mat32[int32])
  stuff(Mat33[int32])
  stuff(Mat34[int32])
  stuff(Mat43[int32])
  stuff(Mat44[int32])
  stuff(Mat22[int64])
  stuff(Mat23[int64])
  stuff(Mat32[int64])
  stuff(Mat33[int64])
  stuff(Mat34[int64])
  stuff(Mat43[int64])
  stuff(Mat44[int64])

template withAllFloatMats(stuff: untyped) =
  stuff(Mat22[float32])
  stuff(Mat23[float32])
  stuff(Mat32[float32])
  stuff(Mat33[float32])
  stuff(Mat34[float32])
  stuff(Mat43[float32])
  stuff(Mat44[float32])
  stuff(Mat22[float64])
  stuff(Mat23[float64])
  stuff(Mat32[float64])
  stuff(Mat33[float64])
  stuff(Mat34[float64])
  stuff(Mat43[float64])
  stuff(Mat44[float64])

template withAllMats(stuff: untyped) =
  stuff(Mat22[int])
  stuff(Mat23[int])
  stuff(Mat32[int])
  stuff(Mat33[int])
  stuff(Mat34[int])
  stuff(Mat43[int])
  stuff(Mat44[int])
  stuff(Mat22[float])
  stuff(Mat23[float])
  stuff(Mat32[float])
  stuff(Mat33[float])
  stuff(Mat34[float])
  stuff(Mat43[float])
  stuff(Mat44[float])

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

  echo Mat22[float]().randomized() * One2.randomized()
  echo Mat33[float]().randomized() * One3.randomized()
  echo Mat44[float]().randomized() * One4.randomized()

randomize()
testMatrix()
