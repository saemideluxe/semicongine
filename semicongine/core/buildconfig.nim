const ENGINENAME = "semiconginev2"

# checks required build options:
static:
  if defined(linux):
    assert defined(VK_USE_PLATFORM_XLIB_KHR),
      ENGINENAME & " requires --d:VK_USE_PLATFORM_XLIB_KHR for linux builds"
  elif defined(windows):
    assert defined(VK_USE_PLATFORM_WIN32_KHR),
      ENGINENAME & " requires --d:VK_USE_PLATFORM_WIN32_KHR for windows builds"
  else:
    assert false, "trying to build on unsupported platform"

# build configuration
# =====================

# log level
when not defined(release):
  const LOGLEVEL {.strdefine.}: string = "Debug"
else:
  const LOGLEVEL {.strdefine.}: string = "Warn"

const ENGINE_LOGLEVEL* = parseEnum[Level]("lvl" & LOGLEVEL)
addHandler(newConsoleLogger())
setLogFilter(ENGINE_LOGLEVEL)

# resource bundleing settings, need to be configured per project
const DEFAULT_PACKAGE* = "default"
const PACKAGETYPE* {.strdefine.}: string = "exe" # dir, zip, exe
static:
  assert PACKAGETYPE in ["dir", "zip", "exe"],
    ENGINENAME &
      " requires one of -d:PACKAGETYPE=dir -d:PACKAGETYPE=zip -d:PACKAGETYPE=exe"
