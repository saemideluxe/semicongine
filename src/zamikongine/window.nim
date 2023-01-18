when defined(linux):
  include ./platform/linux/xlib
elif defined(windows):
  include ./platform/windows/win32
