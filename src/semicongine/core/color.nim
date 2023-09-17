import std/parseutils
import std/strformat

import ./vector


func colorToHex*(color: Vec3f): string =
  &"{int(color.r * 255):02X}{int(color.g * 255):02X}{int(color.b * 255):02X}"

func colorToHex*(color: Vec4f): string =
  &"{int(color.r * 255):02X}{int(color.g * 255):02X}{int(color.b * 255):02X}{int(color.a * 255):02X}"

func asPixel*(color: Vec3f): array[4, uint8] =
  [uint8(color.r * 255), uint8(color.g * 255), uint8(color.b * 255), 255'u8]
func asPixel*(color: Vec4f): array[4, uint8] =
  [uint8(color.r * 255), uint8(color.g * 255), uint8(color.b * 255), uint8(color.a * 255)]

func toRGBA*(value: string): Vec4f =
  assert value != ""
  var hex = value
  if hex[0] == '#':
    hex = hex[1 .. ^1]
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
  return Vec4f([float32(r), float32(g), float32(b), float32(a)]) / 255'f

func gamma*[T: Vec3f|Vec4f](color: T, gamma: float32): T =
  return pow(color, gamma)

const
  Black* = toRGBA "#000000FF"
  Silver* = toRGBA "#C0C0C0FF"
  Gray* = toRGBA "#808080FF"
  White* = toRGBA "#FFFFFFFF"
  Maroon* = toRGBA "#800000FF"
  Red* = toRGBA "#FF0000FF"
  Purple* = toRGBA "#800080FF"
  Fuchsia* = toRGBA "#FF00FFFF"
  Green* = toRGBA "#008000FF"
  Lime* = toRGBA "#00FF00FF"
  Olive* = toRGBA "#808000FF"
  Yellow* = toRGBA "#FFFF00FF"
  Navy* = toRGBA "#000080FF"
  Blue* = toRGBA "#0000FFFF"
  Teal* = toRGBA "#008080FF"
  Aqua* = toRGBA "#00FFFFFF"
