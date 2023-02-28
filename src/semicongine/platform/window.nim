when defined(linux):
  include ./linux/xlib
elif defined(windows):
  include ./windows/win32
