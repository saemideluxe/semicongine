import random
import math

import semicongine/math/vector


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


proc testVector() =
  echoInfo(randVec2I())
  echoInfo(randVec2F())
  echoInfo(randVec3I())
  echoInfo(randVec3F())
  echoInfo(randVec4I())
  echoInfo(randVec4F())

  # test math operations vector-vector
  echoAdd(randVec2I(), randVec2I())
  echoAdd(randVec2F(), randVec2F())
  echoAdd(randVec3I(), randVec3I())
  echoAdd(randVec3F(), randVec3F())
  echoAdd(randVec4I(), randVec4I())
  echoAdd(randVec4F(), randVec4F())
  echoSub(randVec2I(), randVec2I())
  echoSub(randVec2F(), randVec2F())
  echoSub(randVec3I(), randVec3I())
  echoSub(randVec3F(), randVec3F())
  echoSub(randVec4I(), randVec4I())
  echoSub(randVec4F(), randVec4F())
  echoMul(randVec2I(), randVec2I())
  echoMul(randVec2F(), randVec2F())
  echoMul(randVec3I(), randVec3I())
  echoMul(randVec3F(), randVec3F())
  echoMul(randVec4I(), randVec4I())
  echoMul(randVec4F(), randVec4F())
  echoDiv(randVec2I(), randVec2I())
  echoDiv(randVec2F(), randVec2F())
  echoDiv(randVec3I(), randVec3I())
  echoDiv(randVec3F(), randVec3F())
  echoDiv(randVec4I(), randVec4I())
  echoDiv(randVec4F(), randVec4F())
  echoDot(randVec2I(), randVec2I())
  echoDot(randVec2F(), randVec2F())
  echoDot(randVec3I(), randVec3I())
  echoDot(randVec3F(), randVec3F())
  echoDot(randVec4I(), randVec4I())
  echoDot(randVec4F(), randVec4F())
  echoCross(randVec3I(), randVec3I())
  echoCross(randVec3F(), randVec3F())


  # test math operations vector-scalar
  echoAdd(randVec2I(), rand(1 .. 10))
  echoAdd(randVec2F(), rand(10'f))
  echoAdd(randVec3I(), rand(1 .. 10))
  echoAdd(randVec3F(), rand(10'f))
  echoAdd(randVec4I(), rand(1 .. 10))
  echoAdd(randVec4F(), rand(10'f))
  echoSub(randVec2I(), rand(1 .. 10))
  echoSub(randVec2F(), rand(10'f))
  echoSub(randVec3I(), rand(1 .. 10))
  echoSub(randVec3F(), rand(10'f))
  echoSub(randVec4I(), rand(1 .. 10))
  echoSub(randVec4F(), rand(10'f))
  echoMul(randVec2I(), rand(1 .. 10))
  echoMul(randVec2F(), rand(10'f))
  echoMul(randVec3I(), rand(1 .. 10))
  echoMul(randVec3F(), rand(10'f))
  echoMul(randVec4I(), rand(1 .. 10))
  echoMul(randVec4F(), rand(10'f))
  echoDiv(randVec2I(), rand(1 .. 10))
  echoDiv(randVec2F(), rand(10'f))
  echoDiv(randVec3I(), rand(1 .. 10))
  echoDiv(randVec3F(), rand(10'f))
  echoDiv(randVec4I(), rand(1 .. 10))
  echoDiv(randVec4F(), rand(10'f))

  # test math operations scalar-vector
  echoAdd(rand(1 .. 10), randVec2I())
  echoAdd(rand(10'f), randVec2F())
  echoAdd(rand(1 .. 10), randVec3I())
  echoAdd(rand(10'f), randVec3F())
  echoAdd(rand(1 .. 10), randVec4I())
  echoAdd(rand(10'f), randVec4F())
  echoSub(rand(1 .. 10), randVec2I())
  echoSub(rand(10'f), randVec2F())
  echoSub(rand(1 .. 10), randVec3I())
  echoSub(rand(10'f), randVec3F())
  echoSub(rand(1 .. 10), randVec4I())
  echoSub(rand(10'f), randVec4F())
  echoMul(rand(1 .. 10), randVec2I())
  echoMul(rand(10'f), randVec2F())
  echoMul(rand(1 .. 10), randVec3I())
  echoMul(rand(10'f), randVec3F())
  echoMul(rand(1 .. 10), randVec4I())
  echoMul(rand(10'f), randVec4F())
  echoDiv(rand(1 .. 10), randVec2I())
  echoDiv(rand(10'f), randVec2F())
  echoDiv(rand(1 .. 10), randVec3I())
  echoDiv(rand(10'f), randVec3F())
  echoDiv(rand(1 .. 10), randVec4I())
  echoDiv(rand(10'f), randVec4F())

  # test attribute syntax sugar
  echo "float2int ", to[int](randVec2F())
  echo "int2float ", to[float](randVec2I())
  echo "float2int ", to[int](randVec3F())
  echo "int2float ", to[float](randVec3I())
  echo "float2int ", to[int](randVec3F())
  echo "int2float ", to[float](randVec3I())

  echo "V2I.xx: ", randVec2I().xx
  echo "V2I.yx: ", randVec2I().xy
  echo "V2F.xx: ", randVec2F().xx
  echo "V2F.yx: ", randVec2F().yx
  echo "V2I.rr: ", randVec2I().rr
  echo "V2I.gr: ", randVec2I().gr
  echo "V2F.rr: ", randVec2F().rr
  echo "V2F.gr: ", randVec2F().gr

  echo "V3I.yyy: ", randVec3I().yyy
  echo "V3I.yxz: ", randVec3I().xyz
  echo "V3F.yyy: ", randVec3F().yyy
  echo "V3F.yxz: ", randVec3F().yxz
  echo "V3I.ggg: ", randVec3I().ggg
  echo "V3I.grb: ", randVec3I().grb
  echo "V3F.ggg: ", randVec3F().ggg
  echo "V3F.grb: ", randVec3F().grb

  echo "V4I.zzzz: ", randVec4I().zzzz
  echo "V4I.yxzw: ", randVec4I().xyzw
  echo "V4F.zzzz: ", randVec4F().zzzz
  echo "V4F.yxzw: ", randVec4F().yxzw
  echo "V4I.bbbb: ", randVec4I().bbbb
  echo "V4I.grba: ", randVec4I().grba
  echo "V4F.bbbb: ", randVec4F().bbbb
  echo "V4F.grba: ", randVec4F().grba

  echo "X: ", X
  echo "Y: ", Y
  echo "Z: ", Z
  echo "X: ", Xi
  echo "Y: ", Yi
  echo "Z: ", Zi


randomize()
testVector()
