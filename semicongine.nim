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

import ./semicongine/events
import ./semicongine/rendering
import ./semicongine/rendering/vulkan/api
export events
export rendering
export api

import ./semicongine/storage
import ./semicongine/input
export storage
export input

import ./semicongine/audio
export audio

# texture packing is required for font atlas
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
