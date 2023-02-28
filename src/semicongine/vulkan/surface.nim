import ./api
import ./instance

import ../platform/window
import ../platform/surface

type
  Surface* = object
    vk*: VkSurfaceKHR
    instance: Instance

proc createSurface*(instance: Instance, window: NativeWindow): Surface =
  assert instance.vk.valid
  result.instance = instance
  result.vk = instance.createNativeSurface(window)

proc destroy*(surface: var Surface) =
  assert surface.vk.valid
  assert surface.instance.vk.valid
  surface.instance.vk.vkDestroySurfaceKHR(surface.vk, nil)
  surface.vk.reset
