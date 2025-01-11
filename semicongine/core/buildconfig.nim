const ENGINENAME = "semiconginev2"

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
