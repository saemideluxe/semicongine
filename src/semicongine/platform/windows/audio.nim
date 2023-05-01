import winim
import winim/extra

import ../../audiotypes

template checkWinMMResult*(call: untyped) =
  let value = call
  if value < 0:
    raise newException(Exception, "Windows multimedia error: " & astToStr(call) &
      " returned " & $value)
type
  NativeSoundDevice* = object
    handle: HWAVEOUT
    buffer: WAVEHDR
 
proc openSoundDevice*(sampleRate: uint32, buffer: ptr SoundData): NativeSoundDevice =
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
  result.buffer = WAVEHDR(
    lpData: cast[cstring](addr buffer[][0]),
    dwBufferLength: DWORD(buffer[].len * sizeof(Sample)),
    dwBytesRecorded: 0,
    dwUser: DWORD_PTR(0),
    dwFlags: 0,
    dwLoops: 1,
    lpNext: nil,
    reserved: DWORD_PTR(0)
  )
  checkWinMMResult waveOutPrepareHeader(result.handle, addr result.buffer, UINT(sizeof(WAVEHDR)))

proc writeSoundData*(soundDevice: var NativeSoundDevice) =
  checkWinMMResult waveOutWrite(soundDevice.handle, addr soundDevice.buffer, UINT(sizeof(WAVEHDR)))
  while (soundDevice.buffer.dwFlags and WHDR_DONE) != 1:
    discard

proc closeSoundDevice*(soundDevice: var NativeSoundDevice) =
  checkWinMMResult waveOutUnprepareHeader(soundDevice.handle, addr soundDevice.buffer, UINT(sizeof(WAVEHDR)))
  waveOutClose(soundDevice.handle)
