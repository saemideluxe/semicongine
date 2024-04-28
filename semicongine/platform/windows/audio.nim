import std/os

import ../../thirdparty/winim/winim
import ../../thirdparty/winim/winim/extra

import ../../core/audiotypes

template checkWinMMResult*(call: untyped) =
  let value = call
  if value < 0:
    raise newException(Exception, "Windows multimedia error: " & astToStr(call) &
      " returned " & $value)
type
  NativeSoundDevice* = object
    handle: HWAVEOUT
    buffers: seq[WAVEHDR]

proc openSoundDevice*(sampleRate: uint32, buffers: seq[ptr SoundData]): NativeSoundDevice =
  var format = WAVEFORMATEX(
    wFormatTag: WAVE_FORMAT_PCM,
    nChannels: 2,
    nSamplesPerSec: DWORD(sampleRate),
    nAvgBytesPerSec: DWORD(sampleRate) * 4,
    nBlockAlign: 4,
    wBitsPerSample: 16,
    cbSize: 0,
  )
  checkWinMMResult waveOutOpen(addr result.handle, WAVE_MAPPER, addr format, DWORD_PTR(0), DWORD_PTR(0), CALLBACK_NULL)

  for i in 0 ..< buffers.len:
    result.buffers.add WAVEHDR(
      lpData: cast[cstring](addr buffers[i][][0]),
      dwBufferLength: DWORD(buffers[i][].len * sizeof(Sample)),
      dwLoops: 1,
    )
  for i in 0 ..< result.buffers.len:
    checkWinMMResult waveOutPrepareHeader(result.handle, addr result.buffers[i], UINT(sizeof(WAVEHDR)))
    checkWinMMResult waveOutWrite(result.handle, addr result.buffers[i], UINT(sizeof(WAVEHDR)))

proc writeSoundData*(soundDevice: var NativeSoundDevice, buffer: int) =
  while (soundDevice.buffers[buffer].dwFlags and WHDR_DONE) == 0:
    sleep(1)
  checkWinMMResult waveOutWrite(soundDevice.handle, addr soundDevice.buffers[buffer], UINT(sizeof(WAVEHDR)))

proc closeSoundDevice*(soundDevice: var NativeSoundDevice) =
  for i in 0 ..< soundDevice.buffers.len:
    discard waveOutUnprepareHeader(soundDevice.handle, addr soundDevice.buffers[i], UINT(sizeof(WAVEHDR)))
  waveOutClose(soundDevice.handle)
