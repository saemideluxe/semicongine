{.pragma: alsafunc, importc, cdecl, dynlib: "libasound.so.2".}
proc snd_pcm_open*(
  pcm_ref: ptr snd_pcm_p, name: cstring, streamMode: StreamMode, openmode: OpenMode
): cint {.alsafunc.}

proc snd_pcm_close*(pcm: snd_pcm_p): cint {.alsafunc.}
proc snd_pcm_hw_params_malloc*(
  hw_params_ptr: ptr snd_pcm_hw_params_p
): cint {.alsafunc.}

proc snd_pcm_hw_params_free*(hw_params: snd_pcm_hw_params_p) {.alsafunc.}
proc snd_pcm_hw_params_any*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p
): cint {.alsafunc.}

proc snd_pcm_hw_params_set_access*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p, mode: AccessMode
): cint {.alsafunc.}

proc snd_pcm_hw_params_set_format*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p, format: PCMFormat
): cint {.alsafunc.}

proc snd_pcm_hw_params_set_channels*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p, val: cuint
): cint {.alsafunc.}

proc snd_pcm_hw_params_set_buffer_size*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p, size: snd_pcm_uframes_t
): cint {.alsafunc.}

proc snd_pcm_hw_params_set_rate*(
  pcm: snd_pcm_p, params: snd_pcm_hw_params_p, val: cuint, dir: cint
): cint {.alsafunc.}

proc snd_pcm_hw_params*(pcm: snd_pcm_p, params: snd_pcm_hw_params_p): cint {.alsafunc.}
proc snd_pcm_writei*(
  pcm: snd_pcm_p, buffer: pointer, size: snd_pcm_uframes_t
): snd_pcm_sframes_t {.alsafunc.}

proc snd_pcm_recover*(pcm: snd_pcm_p, err: cint, silent: cint): cint {.alsafunc.}
proc snd_pcm_avail(pcm: snd_pcm_p): snd_pcm_sframes_t {.alsafunc.}
proc snd_strerror(errnum: cint): cstring {.alsafunc.}

template checkAlsaResult(call: untyped) =
  let value = call
  if value < 0:
    raise newException(
      Exception,
      "Alsa error: " & astToStr(call) & " returned " & $value & " " &
        $(snd_strerror(cint(value))),
    )

# required for engine:

proc OpenSoundDevice*(
    sampleRate: uint32, buffers: seq[ptr SoundData]
): NativeSoundDevice =
  var hw_params: snd_pcm_hw_params_p = nil
  checkAlsaResult snd_pcm_open(
    addr result.handle, "default", SND_PCM_STREAM_PLAYBACK, SND_PCM_BLOCK
  )

  # hw parameters, quiet a bit of hardcoding here
  checkAlsaResult snd_pcm_hw_params_malloc(addr hw_params)
  checkAlsaResult snd_pcm_hw_params_any(result.handle, hw_params)
  checkAlsaResult snd_pcm_hw_params_set_access(
    result.handle, hw_params, SND_PCM_ACCESS_RW_INTERLEAVED
  )
  checkAlsaResult snd_pcm_hw_params_set_format(
    result.handle, hw_params, SND_PCM_FORMAT_S16_LE
  )
  checkAlsaResult snd_pcm_hw_params_set_rate(result.handle, hw_params, sampleRate, 0)
  checkAlsaResult snd_pcm_hw_params_set_channels(result.handle, hw_params, 2)
  checkAlsaResult snd_pcm_hw_params_set_buffer_size(
    result.handle, hw_params, snd_pcm_uframes_t(buffers[0][].len)
  )
  checkAlsaResult snd_pcm_hw_params(result.handle, hw_params)
  snd_pcm_hw_params_free(hw_params)
  result.buffers = buffers

proc WriteSoundData*(soundDevice: NativeSoundDevice, buffer: int) =
  var i = 0
  let buflen = soundDevice.buffers[buffer][].len
  while i < buflen:
    let availFrames = snd_pcm_avail(soundDevice.handle)
    if availFrames < 0:
      checkAlsaResult snd_pcm_recover(soundDevice.handle, cint(availFrames), 0)
      continue
    checkAlsaResult availFrames
    let nFrames = min(availFrames, buflen - i)
    let ret = snd_pcm_writei(
      soundDevice.handle,
      addr soundDevice.buffers[buffer][][i],
      snd_pcm_uframes_t(nFrames),
    )
    if ret < 0:
      checkAlsaResult snd_pcm_recover(soundDevice.handle, cint(ret), 0)
      continue
    i += nFrames

proc CloseSoundDevice*(soundDevice: NativeSoundDevice) =
  discard snd_pcm_close(soundDevice.handle)
