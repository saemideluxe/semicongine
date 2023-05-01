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
 
proc openSoundDevice*(sampleRate: uint32, bufferSize: uint32): NativeSoundDevice =
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

proc updateSoundBuffer*(soundDevice: NativeSoundDevice, buffer: var SoundData) =
  var data = WAVEHDR(
    lpData: cast[cstring](addr buffer[0]),
    dwBufferLength: DWORD(buffer.len * sizeof(Sample)),
    dwBytesRecorded: 0,
    dwUser: DWORD_PTR(0),
    dwFlags: 0,
    dwLoops: 1,
    lpNext: nil,
    reserved: DWORD_PTR(0)
  )
  checkWinMMResult waveOutPrepareHeader(soundDevice.handle, addr data, UINT(sizeof(WAVEHDR)))
  checkWinMMResult waveOutWrite(soundDevice.handle, addr data, UINT(sizeof(WAVEHDR)))

proc closeSoundDevice*(soundDevice: NativeSoundDevice) =
  waveOutClose(soundDevice.handle)
