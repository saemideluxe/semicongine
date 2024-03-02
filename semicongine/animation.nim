{.experimental: "notnil".}

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
    animationFunction: (state: AnimationState[T], dt: float32) -> T
    duration: float32
    direction: Direction
    iterations: int
  AnimationState*[T] = object
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

  proc animationFunc(state: AnimationState[T], dt: float32): T =
    var i = 0
    while i < theKeyframes.len - 1:
      if theKeyframes[i].timestamp > state.t:
        break
      inc i

    let
      keyFrameDist = theKeyframes[i].timestamp - theKeyframes[i - 1].timestamp
      timestampDist = state.t - theKeyframes[i - 1].timestamp
      x = timestampDist / keyFrameDist

    let value = theKeyframes[i - 1].interpol(x)
    return theKeyframes[i].value * value + theKeyframes[i - 1].value * (1 - value)

  Animation[T](
    animationFunction: animationFunc,
    duration: duration,
    direction: direction,
    iterations: iterations
  )

func newAnimation*[T](fun: (state: AnimationState[T], dt: float32) -> T, duration: float32, direction = Forward, iterations = 1): Animation[T] =
  assert fun != nil, "Animation function cannot be nil"
  Animation[T](
    animationFunction: fun,
    duration: duration,
    direction: direction,
    iterations: iterations
  )

proc resetState*[T](state: var AnimationState[T], initial: T) =
  state.currentValue = initial
  state.currentTime = 0
  state.currentDirection = if state.animation.direction == Backward: -1 else: 1
  state.currentIteration = state.animation.iterations

proc t*(state: AnimationState): AnimationTime =
  max(low(AnimationTime), min(state.currentTime / state.animation.duration, high(AnimationTime)))

proc newAnimationState*[T](animation: Animation[T], initial = default(T)): AnimationState[T] =
  result = AnimationState[T](animation: animation, playing: false)
  result.resetState(initial)

proc newAnimationState*[T](value: T = default(T)): AnimationState[T] =
  newAnimationState[T](newAnimation[T]((state: AnimationState[T], dt: float32) => value, 0), initial = value)

func start*(state: var AnimationState) =
  state.playing = true

func stop*(state: var AnimationState) =
  state.playing = false

proc advance*[T](state: var AnimationState[T], dt: float32): T =
  # TODO: check this function, not 100% correct I think
  if state.playing:
    state.currentTime += float32(state.currentDirection) * dt
    if not (0 <= state.currentTime and state.currentTime < state.animation.duration):
      dec state.currentIteration
      # last iteration reached
      if state.currentIteration <= 0 and state.animation.iterations != 0:
        state.stop()
      # more iterations
      else:
        case state.animation.direction:
          of Forward:
            state.currentTime = state.currentTime - state.animation.duration
          of Backward:
            state.currentTime = state.currentTime + state.animation.duration
          of Alternate:
            state.currentDirection = -state.currentDirection
            state.currentTime += float32(state.currentDirection) * dt * 2'f32

    assert state.animation.animationFunction != nil, "Animation func cannot be nil"
    state.currentValue = state.animation.animationFunction(state, dt)
  return state.currentValue
