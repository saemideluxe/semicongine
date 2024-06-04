import hashes
import math

import ./core/vector


proc randomGradient(pos: Vec2f, seed: int32 = 0): Vec2f =
  let randomAngle: float32 = TAU * (float32(int(hash((pos.x, pos.y, seed)))) / float32(high(int)))
  return NewVec2f(cos(randomAngle), sin(randomAngle))

proc interpolate(a: float32, b: float32, weight: float32): float32 =
  # with Smootherstep
  (b - a) * ((weight * (weight * 6.0 - 15.0) + 10.0) * weight * weight * weight) + a;

proc Perlin*(pos: Vec2f, seed: int32 = 0): float32 =
  let
    # grid coordinates around target point
    topleft = NewVec2f(trunc(pos.x), trunc(pos.y))
    topright = topleft + NewVec2f(1, 0)
    bottomleft = topleft + NewVec2f(0, 1)
    bottomright = topleft + NewVec2f(1, 1)
    # products for weights
    topleft_dot = topleft.randomGradient(seed).Dot((pos - topleft))
    topright_dot = topright.randomGradient(seed).Dot((pos - topright))
    bottomleft_dot = bottomleft.randomGradient(seed).Dot((pos - bottomleft))
    bottomright_dot = bottomright.randomGradient(seed).Dot((pos - bottomright))
    xinterpol = pos.x - topleft.x
    yinterpol = pos.y - topleft.y

  return interpolate(
    interpolate(topleft_dot, bottomleft_dot, yinterpol),
    interpolate(topright_dot, bottomright_dot, yinterpol),
    xinterpol
  )
