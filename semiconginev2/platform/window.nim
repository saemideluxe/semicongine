when defined(linux):
  include ./linux/window
elif defined(windows):
  include ./windows/window
else:
  {.error: "Unsupported platform".}

