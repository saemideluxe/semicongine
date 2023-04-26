when defined(linux):
  include ./linux/window
elif defined(windows):
  include ./windows/window

export window
