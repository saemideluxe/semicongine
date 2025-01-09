{.hint[GlobalVar]: off.}

import std/dynlib
import std/logging
import std/strutils

import ../core

# load function pointers for steam API
var
  Shutdown*: proc() {.stdcall.}
  Init: proc(msg: ptr array[1024, char]): cint {.stdcall.}
  SteamUserStats: proc(): SteamUserStatsRef {.stdcall.}
  RequestCurrentStats: proc(self: SteamUserStatsRef): bool {.stdcall.}
    # needs to be called before the achievment-stuff
  ClearAchievement: proc(self: SteamUserStatsRef, pchName: cstring): bool {.stdcall.}
  SetAchievement: proc(self: SteamUserStatsRef, pchName: cstring): bool {.stdcall.}
  StoreStats: proc(self: SteamUserStatsRef): bool {.stdcall.}
    # needs to be called in order for achievments to be saved
    # dynlib-helper function

proc loadFunc[T](steam_api: LibHandle, nimFunc: var T, dllFuncName: string) =
  nimFunc = cast[T](steam_api.checkedSymAddr(dllFuncName))

# nice wrappers for steam API

proc SteamRequestCurrentStats*(): bool =
  RequestCurrentStats(engine().userStats)

proc SteamClearAchievement*(name: string): bool =
  engine().userStats.ClearAchievement(name.cstring)

proc SteamSetAchievement*(name: string): bool =
  engine().userStats.SetAchievement(name.cstring)

proc SteamStoreStats*(): bool =
  engine().userStats.StoreStats()

proc SteamShutdown*() =
  Shutdown()

# helper funcs
proc loadSteamLib() =
  if engine().steam_api == nil:
    when defined(linux):
      engine().steam_api = "libsteam_api.so".loadLib()
    elif defined(windows):
      engine().steam_api = "steam_api".loadLib()

proc SteamAvailable*(): bool =
  loadSteamLib()
  engine().steam_api != nil and engine().steam_is_loaded

# first function that should be called
proc TrySteamInit*() =
  loadSteamLib()
  if engine().steam_api != nil and not engine().steam_is_loaded:
    loadFunc(engine().steam_api, Init, "SteamAPI_InitFlat")
    loadFunc(engine().steam_api, Shutdown, "SteamAPI_Shutdown")
    loadFunc(engine().steam_api, SteamUserStats, "SteamAPI_SteamUserStats_v012")
    loadFunc(
      engine().steam_api,
      RequestCurrentStats,
      "SteamAPI_ISteamUserStats_RequestCurrentStats",
    )
    loadFunc(
      engine().steam_api, ClearAchievement, "SteamAPI_ISteamUserStats_ClearAchievement"
    )
    loadFunc(
      engine().steam_api, SetAchievement, "SteamAPI_ISteamUserStats_SetAchievement"
    )
    loadFunc(engine().steam_api, StoreStats, "SteamAPI_ISteamUserStats_StoreStats")

    var msg: array[1024, char]
    let success = Init(addr msg) == 0
    warn join(@msg, "")
    if success:
      engine().userStats = SteamUserStats()
      engine().steam_is_loaded = SteamRequestCurrentStats()
