import ./semicongine/core
export core

import ./semicongine/resources
export resources

import ./semicongine/loaders
export loaders

import ./semicongine/background_loader
export background_loader

import ./semicongine/image
export image

import ./semicongine/rendering
export rendering

import ./semicongine/rendering/renderer
export renderer

import ./semicongine/rendering/swapchain
export swapchain

import ./semicongine/rendering/renderpasses
export renderpasses

import ./semicongine/rendering/shaders
export shaders

import ./semicongine/rendering/memory
export memory

import ./semicongine/rendering/vulkan_wrappers
export vulkan_wrappers

import ./semicongine/storage
import ./semicongine/input
export storage
export input

import ./semicongine/audio
export audio

# texture packing is required for font atlas
import ./semicongine/text/font
export font

import ./semicongine/text
export text

import ./semicongine/gltf
export gltf

when not defined(WITHOUT_CONTRIB):
  import ./semicongine/contrib/steam
  import ./semicongine/contrib/settings
  import ./semicongine/contrib/algorithms/texture_packing
  import ./semicongine/contrib/algorithms/collision
  import ./semicongine/contrib/algorithms/noise
  export steam
  export settings
  export texture_packing
  export collision
  export noise

#### Main engine object

proc initEngine*(appName: string) =
  engine_obj_internal = Engine()
  engine_obj_internal.vulkan = initVulkan(appName)

  # start audio
  engine_obj_internal.mixer = createShared(Mixer)
  engine_obj_internal.mixer[] = initMixer()
  engine_obj_internal.audiothread.createThread(audioWorker, engine_obj_internal.mixer)
  engine_obj_internal.initialized = true

  engine_obj_internal.rawLoader = initBackgroundLoader(loadBytes)
  engine_obj_internal.jsonLoader = initBackgroundLoader(loadJson)
  engine_obj_internal.configLoader = initBackgroundLoader(loadConfig)
  engine_obj_internal.grayImageLoader = initBackgroundLoader(loadImage[Gray])
  engine_obj_internal.imageLoader = initBackgroundLoader(loadImage[BGRA])
  engine_obj_internal.audioLoader = initBackgroundLoader(loadAudio)
