import std/dynlib
import std/strutils
import std/logging

var
  steam_api: LibHandle
  steam_is_loaded = false

when defined(linux):
  proc dlerror(): cstring {.stdcall, importc.}
  steam_api = "libsteam_api.so".loadLib()
  if steam_api == nil:
    echo dlerror()
elif defined(windows):
  steam_api = "steam_api".loadLib()
  # TODO: maybe should get some error reporting on windows too?


# required to store reference, when calling certain APIs
type
  SteamUserStatsRef = ptr object
var userStats: SteamUserStatsRef

# load function pointers for steam API
var
  Shutdown*: proc() {.stdcall.}
  Init: proc(msg: ptr array[1024, char]): cint {.stdcall.}
  SteamUserStats: proc(): SteamUserStatsRef {.stdcall.}
  RequestCurrentStats: proc(self: SteamUserStatsRef): bool {.stdcall.} # needs to be called before the achievment-stuff
  ClearAchievement: proc(self: SteamUserStatsRef, pchName: cstring): bool {.stdcall.}
  SetAchievement: proc(self: SteamUserStatsRef, pchName: cstring): bool {.stdcall.}
  StoreStats: proc(self: SteamUserStatsRef): bool {.stdcall.}          # needs to be called in order for achievments to be saved
                                                                       # dynlib-helper function
proc loadFunc[T](nimFunc: var T, dllFuncName: string) =
  nimFunc = cast[T](steam_api.checkedSymAddr(dllFuncName))
if steam_api != nil:
  loadFunc(Init, "SteamAPI_InitFlat")
  loadFunc(Shutdown, "SteamAPI_Shutdown")
  loadFunc(SteamUserStats, "SteamAPI_SteamUserStats_v012")
  loadFunc(RequestCurrentStats, "SteamAPI_ISteamUserStats_RequestCurrentStats")
  loadFunc(ClearAchievement, "SteamAPI_ISteamUserStats_ClearAchievement")
  loadFunc(SetAchievement, "SteamAPI_ISteamUserStats_SetAchievement")
  loadFunc(StoreStats, "SteamAPI_ISteamUserStats_StoreStats")


# nice wrappers for steam API

proc SteamRequestCurrentStats*(): bool =
  RequestCurrentStats(userStats)

proc SteamClearAchievement*(name: string): bool =
  userStats.ClearAchievement(name.cstring)

proc SteamSetAchievement*(name: string): bool =
  userStats.SetAchievement(name.cstring)

proc SteamStoreStats*(name: string): bool =
  userStats.StoreStats()

proc SteamShutdown*() =
  Shutdown()


# helper funcs
proc SteamAvailable*(): bool =
  steam_api != nil and steam_is_loaded

# first function that should be called
proc TrySteamInit*() =
  if steam_api != nil and not steam_is_loaded:
    var msg: array[1024, char]
    let success = Init(addr msg) == 0
    warn join(@msg, "")
    if success:
      userStats = SteamUserStats()
      steam_is_loaded = SteamRequestCurrentStats()
