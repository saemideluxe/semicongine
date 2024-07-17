when defined(linux):
  include ./linux/vulkan_extensions
elif defined(windows):
  include ./windows/vulkan_extensions
else:
  {.error: "Unsupported platform".}

