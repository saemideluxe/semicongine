import std/streams
import std/endians

import ../core/audiotypes

type
  Encoding {.size: sizeof(uint32).} = enum
    # Unspecified = 0
    # Uint8Ulaw = 1
    # Int8 = 2
    Int16 = 3
    # Int24 = 4
    # Int32 = 5
    # Float32 = 6
    # Float64 = 7

  AuHeader = object
    magicNumber: uint32
    dataOffset: uint32
    dataSize: uint32
    encoding: Encoding
    sampleRate: uint32
    channels: uint32

proc readSample(stream: Stream, encoding: Encoding, channels: int): Sample =
  result[0] = stream.readint16()
  swapEndian16(addr result[0], addr result[0])

  if channels == 2:
    result[1] = stream.readint16()
    swapEndian16(addr result[1], addr result[1])
  else:
    result[1] = result[0]



# https://en.wikipedia.org/wiki/Au_file_format
proc readAU*(stream: Stream): Sound =
  var header: AuHeader

  for name, value in fieldPairs(header):
    var bytes: array[4, uint8]
    stream.read(bytes)
    swap(bytes[0], bytes[3])
    swap(bytes[1], bytes[2])
    value = cast[typeof(value)](bytes)

  assert header.magicNumber == 0x2e736e64
  if header.sampleRate != AUDIO_SAMPLE_RATE:
    raise newException(Exception, "Only support sample rate of 48000 Hz but got " & $header.sampleRate & " Hz, please resample (e.g. ffmpeg -i {infile} -ar 48000 {outfile})")
  if not (header.channels in [1'u32, 2'u32]):
    raise newException(Exception, "Only support mono and stereo audio at the moment (1 or 2 channels), but found " & $header.channels)

  var annotation: string
  stream.read(annotation)

  result = new Sound
  stream.setPosition(int(header.dataOffset))
  while not stream.atEnd():
    result[].add stream.readSample(header.encoding, int(header.channels))
