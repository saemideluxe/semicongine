import ../../thirdparty/x11/xlib
import ../../thirdparty/x11/x as x11

type NativeWindow* = object
  display*: ptr xlib.Display
  window*: x11.Window
  emptyCursor*: Cursor

# alsa API
type
  OpenMode* {.size: sizeof(culong).} = enum
    SND_PCM_BLOCK = 0x00000000 # added by semicongine, for clarity
    SND_PCM_NONBLOCK = 0x00000001

  StreamMode* {.size: sizeof(cint).} = enum
    SND_PCM_STREAM_PLAYBACK = 0

  AccessMode* {.size: sizeof(cint).} = enum
    SND_PCM_ACCESS_RW_INTERLEAVED = 3

  PCMFormat* {.size: sizeof(cint).} = enum
    SND_PCM_FORMAT_S16_LE = 2

  snd_pcm_p* = ptr object
  snd_pcm_hw_params_p* = ptr object
  snd_pcm_uframes_t* = culong
  snd_pcm_sframes_t* = clong

type NativeSoundDevice* = object
  handle*: snd_pcm_p
  buffers*: seq[ptr SoundData]
