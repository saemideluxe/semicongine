import std/math
import std/hashes

import ../../core

proc randomGradient(pos: Vec2f, seed: int32 = 0): Vec2f =
  let randomAngle: float32 = TAU * (float32(int(hash((pos.x, pos.y, seed)))) / float32(high(int)))
  return vec2(cos(randomAngle), sin(randomAngle))

proc interpolate(a: float32, b: float32, weight: float32): float32 =
  # with Smootherstep
  (b - a) * ((weight * (weight * 6.0 - 15.0) + 10.0) * weight * weight * weight) + a;

proc perlin*(pos: Vec2f, seed: int32 = 0): float32 =
  let
    # grid coordinates around target point
    topleft = vec2(trunc(pos.x), trunc(pos.y))
    topright = topleft + vec2(1, 0)
    bottomleft = topleft + vec2(0, 1)
    bottomright = topleft + vec2(1, 1)
    # products for weights
    topleft_dot = topleft.randomGradient(seed).dot((pos - topleft))
    topright_dot = topright.randomGradient(seed).dot((pos - topright))
    bottomleft_dot = bottomleft.randomGradient(seed).dot((pos - bottomleft))
    bottomright_dot = bottomright.randomGradient(seed).dot((pos - bottomright))
    xinterpol = pos.x - topleft.x
    yinterpol = pos.y - topleft.y

  return interpolate(
    interpolate(topleft_dot, bottomleft_dot, yinterpol),
    interpolate(topright_dot, bottomright_dot, yinterpol),
    xinterpol
  )
