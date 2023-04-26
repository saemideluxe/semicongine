when defined(linux):
  include ./linux/audio
elif defined(windows):
  include ./windows/audio

export audio
