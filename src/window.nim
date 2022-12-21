when defined(linux):
  import ./platform/linux/xlib
  export xlib
elif defined(windows):
  import ./platform/windows/win32
  export win32
