import random
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


func rowCount*(m: Mat22): int = 2
func columnCount*(m: Mat22): int = 2
func rowCount*(m: Mat23): int = 2
func columnCount*(m: Mat23): int = 3
func rowCount*(m: Mat32): int = 3
func columnCount*(m: Mat32): int = 2
func rowCount*(m: Mat33): int = 3
func columnCount*(m: Mat33): int = 3
func rowCount*(m: Mat34): int = 3
func columnCount*(m: Mat34): int = 4
func rowCount*(m: Mat43): int = 4
func columnCount*(m: Mat43): int = 3
func rowCount*(m: Mat44): int = 4
func columnCount*(m: Mat44): int = 4


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
    if i mod value.columnCount == value.columnCount - 1:
      result &= filler & strvalues[i] & "\n"
    else:
      if i mod value.columnCount == 0:
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

func `[]`*[T: Mat](m: T, row, col: int): auto = m.data[col + row * m.columnCount]
proc `[]=`*[T: Mat, U](m: var T, row, col: int, value: U) = m.data[col + row * m.columnCount] = value

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

# call e.g. Mat32[int]().initRandom() to get a random matrix
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
