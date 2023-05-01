import std/math

# in order to generate sound files that are directly usable with the engine,
# convert an audio file to a raw PCM signed 16 bit little endian file with 2 channels and 48kHz:
#
# ffmpeg -i <infile> -f s16le -ac 2 -ar 48000 -acodec pcm_s16le <outfile>

const SAMPLERATE* = 44100
const BUFFERSIZE* = 512

type
  Level* = 0'f .. 1'f
  Sample* = (int16, int16)
  SoundData* = seq[Sample]
  Sound* = ref SoundData

proc sinewave(f: float): proc(x: float): float =
  proc ret(x: float): float =
    sin(x * 2 * Pi * f)
  result = ret

proc sineSoundData*(f: float, len: float): SoundData =
  let dt = 1'f / float(SAMPLERATE)
  var sine = sinewave(f)
  for i in 0 ..< int(SAMPLERATE * len):
    let t = dt * float(i)
    let value = int16(sine(t) * float(high(int16)))
    result.add (value, value)

proc newSound*(data: SoundData): Sound =
  result = new Sound
  result[] = data
