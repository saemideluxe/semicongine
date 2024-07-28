proc sinewave(f: float): proc(x: float): float =
  proc ret(x: float): float =
    sin(x * 2 * Pi * f)
  result = ret

proc SineSoundData*(f: float, len: float, rate: int, amplitude = 0.5'f32): SoundData =
  let dt = 1'f / float(rate)
  var sine = sinewave(f)
  for i in 0 ..< int(float(rate) * len):
    let t = dt * float(i)
    let value = int16(sine(t) * float(high(int16)) * amplitude)
    result.add [value, value]
