import std/sugar
import std/tables
import std/math
import std/sequtils
import std/algorithm

import ./core/matrix

type
  Ease* = enum
    None
    Linear
    Pow2
    Pow3
    Pow4
    Pow5
    Expo
    Sine
    Circ
  AnimationTime* = 0'f32 .. 1'f32
  Direction* = enum
    Forward
    Backward
    Alternate
  Keyframe[T] = object
    timestamp: AnimationTime
    value: T
    easeIn: Ease
    easeOut: Ease
  Animation*[T] = object
    animationFunction: (t: AnimationTime) -> T
    duration: float32
    direction: Direction
    iterations: int
  AnimationPlayer*[T] = object
    animation*: Animation[T]
    currentTime*: float32
    playing*: bool
    currentDirection: int
    currentIteration: int
    currentValue*: T

func easeConst(x: float32): float32 = 0
func easeLinear(x: float32): float32 = x
func easePow2(x: float32): float32 = x * x
func easePow3(x: float32): float32 = x * x * x
func easePow4(x: float32): float32 = x * x * x * x
func easePow5(x: float32): float32 = x * x * x * x * x
func easeExpo(x: float32): float32 = (if x == 0: 0'f32 else: pow(2'f32, 10'f32 * x - 10'f32))
func easeSine(x: float32): float32 = 1'f32 - cos((x * PI) / 2'f32)
func easeCirc(x: float32): float32 = 1'f32 - sqrt(1'f32 - pow(x, 2'f32))

const EASEFUNC_MAP = {
    None: easeConst,
    Linear: easeLinear,
    Pow2: easePow2,
    Pow3: easePow3,
    Pow4: easePow4,
    Pow5: easePow5,
    Expo: easeExpo,
    Sine: easeSine,
    Circ: easeCirc,
}.toTable()

func makeEaseOut(f: proc(x: float32): float32 {.noSideEffect.}): auto =
  func wrapper(x: float32): float32 =
    1 - f(1 - x)
  return wrapper

func combine(f1: proc(x: float32): float32 {.noSideEffect.}, f2: proc(x: float32): float32 {.noSideEffect.}): auto =
  func wrapper(x: float32): float32 =
    if x < 0.5: f1(x * 2) * 0.5
    else: f2((x - 0.5) * 2) * 0.5 + 0.5
  return wrapper

func interpol(keyframe: Keyframe, t: float32): float32 =
  if keyframe.easeOut == None:
    return EASEFUNC_MAP[keyframe.easeIn](t)
  elif keyframe.easeIn == None:
    return EASEFUNC_MAP[keyframe.easeOut](t)
  else:
    return combine(EASEFUNC_MAP[keyframe.easeIn], makeEaseOut(EASEFUNC_MAP[keyframe.easeOut]))(t)

func keyframe*[T](timestamp: AnimationTime, value: T, easeIn = Linear, easeOut = None): Keyframe[T] =
  Keyframe[T](timestamp: timestamp, value: value, easeIn: easeIn, easeOut: easeOut)

func newAnimation*[T](keyframes: openArray[Keyframe[T]], duration: float32, direction = Forward, iterations = 1): Animation[T] =
  assert keyframes.len >= 2, "An animation needs at least 2 keyframes"
  assert keyframes[0].timestamp == 0, "An animation's first keyframe needs to have timestamp=0"
  assert keyframes[^1].timestamp == 1, "An animation's last keyframe needs to have timestamp=1"
  var last = keyframes[0].timestamp
  for kf in keyframes[1 .. ^1]:
    assert kf.timestamp > last, "Succeding keyframes must have increasing timestamps"
    last = kf.timestamp

  let theKeyframes = keyframes.toSeq

  proc animationFunc(t: AnimationTime): T =
    var i = 0
    while i < theKeyframes.len - 1:
      if theKeyframes[i].timestamp > t:
        break
      inc i

    let
      keyFrameDist = theKeyframes[i].timestamp - theKeyframes[i - 1].timestamp
      timestampDist = t - theKeyframes[i - 1].timestamp
      x = timestampDist / keyFrameDist

    let value = theKeyframes[i - 1].interpol(x)
    return theKeyframes[i].value * value + theKeyframes[i - 1].value * (1 - value)

  Animation[T](
    animationFunction: animationFunc,
    duration: duration,
    direction: direction,
    iterations: iterations
  )

func newAnimation*[T](fun: (t: AnimationTime) -> T, duration: float32, direction = Forward, iterations = 1): Animation[T] =
  Animation[T](
    animationFunction: fun,
    duration: duration,
    direction: direction,
    iterations: iterations
  )

proc reset*(player: var AnimationPlayer) =
  player.currentValue = player.animation.animationFunction(0)
  player.currentTime = 0
  player.currentDirection = if player.animation.direction == Backward: -1 else: 1
  player.currentIteration = player.animation.iterations


proc newAnimationPlayer*[T](animation: Animation[T]): AnimationPlayer[T] =
  result = AnimationPlayer[T](animation: animation, playing: false)
  result.reset()

proc newAnimationPlayer*[T](value: T = default(T)): AnimationPlayer[T] =
  newAnimationPlayer[T](newAnimation[T]((t: AnimationTime) => value, 0))

func start*(player: var AnimationPlayer) =
  player.playing = true

func stop*(player: var AnimationPlayer) =
  player.playing = false

proc advance*[T](player: var AnimationPlayer[T], dt: float32): T =
  # TODO: check this function, not 100% correct I think
  if player.playing:
    player.currentTime += float32(player.currentDirection) * dt
    if not (0 <= player.currentTime and player.currentTime < player.animation.duration):
      dec player.currentIteration
      # last iteration reached
      if player.currentIteration <= 0 and player.animation.iterations != 0:
        player.stop()
      # more iterations
      else:
        case player.animation.direction:
          of Forward:
            player.currentTime = player.currentTime - player.animation.duration
          of Backward:
            player.currentTime = player.currentTime + player.animation.duration
          of Alternate:
            player.currentDirection = -player.currentDirection
            player.currentTime += float32(player.currentDirection) * dt * 2'f32

    player.currentValue = player.animation.animationFunction(
      max(low(AnimationTime), min(player.currentTime / player.animation.duration, high(AnimationTime)))
    )
  return player.currentValue
