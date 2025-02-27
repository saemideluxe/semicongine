import ../../thirdparty/winim/winim/inc/[windef, winuser, wincon, winbase, mmsystem]

type NativeWindow* = object
  hinstance*: HINSTANCE
  hwnd*: HWND
  g_wpPrev*: WINDOWPLACEMENT

type NativeSoundDevice* = object
  handle*: HWAVEOUT
  buffers*: seq[WAVEHDR]
