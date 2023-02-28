when defined(linux):
  import ../platform/linux/surface
elif defined(windows):
  import ../platform/windows/surface

export surface
