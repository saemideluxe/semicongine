import std/tables
import std/locks

import ./semicongine/core
export core

from ./semicongine/rendering import initVulkan
from ./semicongine/audio import audioWorker
from ./semicongine/background_loaders import initBackgroundLoader
import ./semicongine/loaders

proc initEngine*(appName: string) =
  ## Required to be called before most features of the engine can be used
  engine_obj_internal = Engine()
  engine_obj_internal.vulkan = initVulkan(appName)

  # start audio
  engine_obj_internal.mixer = createShared(Mixer)
  engine_obj_internal.mixer[] = Mixer()
  engine_obj_internal.mixer[].tracks[""] = Track(level: 1)
  engine_obj_internal.mixer[].lock.initLock()
  engine_obj_internal.audiothread.createThread(audioWorker, engine_obj_internal.mixer)

  # start background resource loaders
  engine_obj_internal.rawLoader = initBackgroundLoader(loadBytes)
  engine_obj_internal.jsonLoader = initBackgroundLoader(loadJson)
  engine_obj_internal.configLoader = initBackgroundLoader(loadConfig)
  engine_obj_internal.grayImageLoader = initBackgroundLoader(loadImage[Gray])
  engine_obj_internal.imageLoader = initBackgroundLoader(loadImage[BGRA])
  engine_obj_internal.audioLoader = initBackgroundLoader(loadAudio)

  engine_obj_internal.initialized = true
