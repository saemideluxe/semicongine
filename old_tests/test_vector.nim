import random

import semicongine


proc echoInfo[T](v: TVec2[T] or TVec3[T] or TVec4[T]) =
  echo v
  echo "  Length: ", v.Length
  when T is SomeFloat:
    echo "  Normlized: ", v.Normalized
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
  echo v1, " o ", v2, " = ", v1.Dot(v2)
proc echoCross[T, U](v1: T, v2: U) =
  echo v1, " x ", v2, " = ", v1.Cross(v2)

proc randVec2I(): auto = NewVec2(rand(1 .. 10), rand(1 .. 10))
proc randVec2F(): auto = NewVec2(rand(10'f) + 0.01, rand(10'f) + 0.01)
proc randVec3I(): auto = NewVec3(rand(1 .. 10), rand(1 .. 10), rand(1 .. 10))
proc randVec3F(): auto = NewVec3(rand(10'f) + 0.01, rand(10'f) + 0.01, rand(
    10'f) + 0.01)
proc randVec4I(): auto = NewVec4(rand(1 .. 10), rand(1 .. 10), rand(1 .. 10),
    rand(1 .. 10))
proc randVec4F(): auto = NewVec4(rand(10'f) + 0.01, rand(10'f) + 0.01, rand(
    10'f) + 0.01, rand(10'f) + 0.01)


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
  echo "float2int ", To[int](randVec2F())
  echo "int2float ", To[float](randVec2I())
  echo "float2int ", To[int](randVec3F())
  echo "int2float ", To[float](randVec3I())
  echo "float2int ", To[int](randVec3F())
  echo "int2float ", To[float](randVec3I())

  echo "V3I.x: ", randVec3I().x
  echo "V3I.y: ", randVec3I().y
  echo "V3F.z: ", randVec3F().z
  echo "V3I.r: ", randVec3I().r
  echo "V3I.g: ", randVec3I().g
  echo "V3F.b: ", randVec3F().b

  # test setters
  var v1 = randVec2I(); v1.x = 1; v1.y = 2; v1.r = 3; v1.g = 4
  v1.xy = randVec2I(); v1.yx = randVec2I(); v1.rg = randVec2I(); v1.gr = randVec2I()
  var v2 = randVec2F(); v2.x = 1.0; v2.y = 2.0; v2.r = 3.0; v2.g = 4.0
  v2.xy = randVec2F(); v2.yx = randVec2F(); v2.rg = randVec2F(); v2.gr = randVec2F()

  var v3 = randVec3I(); v3.x = 1; v3.y = 2; v3.z = 3; v3.r = 4; v3.g = 5; v3.b = 6
  v3.xyz = randVec3I(); v3.rgb = randVec3I()
  var v4 = randVec3F(); v4.x = 1.0; v4.y = 2.0; v4.z = 3.0; v4.r = 4.0; v4.g = 5.0; v4.b = 6.0
  v4.xyz = randVec3F(); v4.rgb = randVec3F()

  var v5 = randVec4I(); v5.x = 1; v5.y = 2; v5.z = 3; v5.w = 4; v5.r = 5; v5.g = 6; v5.b = 7; v5.a = 8
  v5.xyzw = randVec4I(); v5.rgba = randVec4I()
  var v6 = randVec4F(); v6.x = 1.0; v6.y = 2.0; v6.z = 3.0; v6.w = 4.0; v6.r = 5.0; v6.g = 6.0; v6.b = 7.0; v6.a = 8.0
  v6.xyzw = randVec4F(); v6.rgba = randVec4F()

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
