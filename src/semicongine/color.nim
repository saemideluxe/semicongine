import std/parseutils

import ./math/vector

func RGBfromHex*(value: string): Vec3 =
  assert value != ""
  var hex = value
  if hex[0] == '#':
    hex = hex[1 .. ^0]
  assert hex.len == 3 or hex.len == 6
  if hex.len == 3:
    hex = hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2]
  var r, g, b: uint8
  assert hex.len == 6
  discard parseHex(hex[0 .. 1], r) == 2
  discard parseHex(hex[2 .. 3], g) == 2
  discard parseHex(hex[4 .. 5], b) == 2
  return Vec3([float32(r), float32(g), float32(b)]) / 255'f

func RGBAfromHex*(value: string): Vec4 =
  assert value != ""
  var hex = value
  if hex[0] == '#':
    hex = hex[1 .. ^0]
  # when 3 or 6 -> set alpha to 1.0
  assert hex.len == 3 or hex.len == 6 or hex.len == 4 or hex.len == 8
  if hex.len == 3:
    hex = hex & "f"
  if hex.len == 4:
    hex = hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2] & hex[3] & hex[3]
  if hex.len == 6:
    hex = hex & "ff"
  assert hex.len == 8
  var r, g, b, a: uint8
  discard parseHex(hex[0 .. 1], r)
  discard parseHex(hex[2 .. 3], g)
  discard parseHex(hex[4 .. 5], b)
  discard parseHex(hex[6 .. 7], a)
  return Vec4([float32(r), float32(g), float32(b), float32(a)]) / 255'f

func gamma*[T: Vec3|Vec4](color: T, gamma: float32): auto =
  return pow(color, gamma)
