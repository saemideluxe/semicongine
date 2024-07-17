import std/os
import std/streams
import std/strformat
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
proc ReadAU*(stream: Stream): Sound =
  var header: AuHeader

  for name, value in fieldPairs(header):
    var bytes: array[4, uint8]
    stream.read(bytes)
    swap(bytes[0], bytes[3])
    swap(bytes[1], bytes[2])
    value = cast[typeof(value)](bytes)

  assert header.magicNumber == 0x2e736e64
  if header.sampleRate != AUDIO_SAMPLE_RATE:
    raise newException(Exception, &"Only support sample rate of {AUDIO_SAMPLE_RATE} Hz but got {header.sampleRate} Hz, please resample (e.g. ffmpeg -i <infile> -ar {AUDIO_SAMPLE_RATE} <outfile>)")
  if not (header.channels in [1'u32, 2'u32]):
    raise newException(Exception, "Only support mono and stereo audio at the moment (1 or 2 channels), but found " & $header.channels)

  var annotation: string
  stream.read(annotation)

  result = new Sound
  stream.setPosition(int(header.dataOffset))
  while not stream.atEnd():
    result[].add stream.readSample(header.encoding, int(header.channels))

{.compile: currentSourcePath.parentDir() & "/stb_vorbis.c".}

proc stb_vorbis_decode_memory(mem: pointer, len: cint, channels: ptr cint, sample_rate: ptr cint, output: ptr ptr cshort): cint {.importc.}
proc free(p: pointer) {.importc.}

proc ReadVorbis*(stream: Stream): Sound =
  var
    data = stream.readAll()
    channels: cint
    sampleRate: cint
    output: ptr cshort

  var nSamples = stb_vorbis_decode_memory(addr data[0], cint(data.len), addr channels, addr sampleRate, addr output)

  if nSamples < 0:
    raise newException(Exception, &"Unable to read ogg/vorbis sound file, error code: {nSamples}")
  if sampleRate != AUDIO_SAMPLE_RATE:
    raise newException(Exception, &"Only support sample rate of {AUDIO_SAMPLE_RATE} Hz but got {sampleRate} Hz, please resample (e.g. ffmpeg -i <infile> -acodec libvorbis -ar {AUDIO_SAMPLE_RATE} <outfile>)")

  result = new Sound
  if channels == 2:
    result[].setLen(int(nSamples))
    copyMem(addr result[][0], output, nSamples * sizeof(Sample))
    free(output)
  elif channels == 1:
    for i in 0 ..< nSamples:
      let value = cast[ptr UncheckedArray[int16]](output)[i]
      result[].add [value, value]
    free(output)
  else:
    free(output)
    raise newException(Exception, "Only support mono and stereo audio at the moment (1 or 2 channels), but found " & $channels)
