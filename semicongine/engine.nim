import std/compilesettings
import std/algorithm
import std/monotimes
import std/options
import std/strformat
import std/sequtils
import std/logging
import std/os

import ./platform/window

import ./core
import ./vulkan/instance
import ./vulkan/device
import ./vulkan/physicaldevice
import ./vulkan/shader

import ./scene
import ./material
import ./renderer
import ./audio
import ./input
import ./text
import ./panel

import ./steam

const COUNT_N_RENDERTIMES = 199

type
  EngineState* = enum
    Starting
    Running
    Shutdown
  Engine* = object
    applicationName: string
    debug: bool
    showFps: bool
    device: Device
    debugger: Debugger
    instance: Instance
    window: NativeWindow
    renderer: Option[Renderer]
    fullscreen: bool
    lastNRenderTimes: array[COUNT_N_RENDERTIMES, int64]
    currentRenderTimeI: int = 0

# forward declarations
func getAspectRatio*(engine: Engine): float32

proc destroy*(engine: var Engine) =
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  if engine.renderer.isSome:
    engine.renderer.get.destroy()
  engine.device.destroy()
  if engine.debugger.messenger.valid:
    engine.debugger.destroy()
  engine.window.destroy()
  engine.instance.destroy()
  if SteamAvailable():
    SteamShutdown()


proc initEngine*(
  applicationName = querySetting(projectName),
  debug = DEBUG,
  showFps = DEBUG,
  vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
  vulkanLayers: openArray[string] = [],
): Engine =
  echo "Set log level to ", ENGINE_LOGLEVEL
  setLogFilter(ENGINE_LOGLEVEL)

  TrySteamInit()
  if SteamAvailable():
    echo "Starting with Steam"
  else:
    echo "Starting without Steam"

  result.applicationName = applicationName
  result.debug = debug
  result.showFps = showFps
  result.window = createWindow(result.applicationName)

  var
    layers = @vulkanLayers
    instanceExtensions: seq[string]

  if result.debug:
    instanceExtensions.add "VK_EXT_debug_utils"
    layers.add "VK_LAYER_KHRONOS_validation"
    # This stuff might be usefull if we one day to smart GPU memory allocation,
    # but right now it just clobbers up the console log:
    # putEnv("VK_LAYER_ENABLES", "VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT")
    putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")

  result.instance = result.window.createInstance(
    vulkanVersion = vulkanVersion,
    instanceExtensions = instanceExtensions,
    layers = layers.deduplicate(),
  )
  if result.debug:
    result.debugger = result.instance.createDebugMessenger()
  # create devices
  let selectedPhysicalDevice = result.instance.getPhysicalDevices().filterBestGraphics()
  result.device = result.instance.createDevice(
    selectedPhysicalDevice,
    enabledExtensions = @[],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )
  startMixerThread()

proc initRenderer*(
  engine: var Engine,
  shaders: openArray[(MaterialType, ShaderConfiguration)],
  clearColor = newVec4f(0, 0, 0, 0),
  backFaceCulling = true,
  vSync = false,
  inFlightFrames = 2,
) =

  assert not engine.renderer.isSome
  var allShaders = @shaders
  if not shaders.mapIt(it[0]).contains(EMPTY_MATERIAL):
    allShaders.add (EMPTY_MATERIAL, EMPTY_SHADER)
  if not shaders.mapIt(it[0]).contains(PANEL_MATERIAL_TYPE):
    allShaders.add (PANEL_MATERIAL_TYPE, PANEL_SHADER)
  if not shaders.mapIt(it[0]).contains(TEXT_MATERIAL_TYPE):
    allShaders.add (TEXT_MATERIAL_TYPE, TEXT_SHADER)
  engine.renderer = some(engine.device.initRenderer(
    shaders = allShaders,
    clearColor = clearColor,
    backFaceCulling = backFaceCulling,
    vSync = vSync,
    inFlightFrames = inFlightFrames,
  ))

proc initRenderer*(engine: var Engine, clearColor = newVec4f(0, 0, 0, 0), vSync = false) =
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  engine.initRenderer(@[], clearColor, vSync = vSync)
  checkVkResult engine.device.vk.vkDeviceWaitIdle()

proc loadScene*(engine: var Engine, scene: var Scene) =
  debug &"start loading scene '{scene.name}'"
  assert engine.renderer.isSome
  assert not scene.loaded
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  scene.addShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.getAspectRatio)
  engine.renderer.get.setupDrawableBuffers(scene)
  engine.renderer.get.updateMeshData(scene, forceAll = true)
  engine.renderer.get.updateUniformData(scene, forceAll = true)
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  debug &"done loading scene '{scene.name}'"

proc unloadScene*(engine: var Engine, scene: Scene) =
  debug &"unload scene '{scene.name}'"
  engine.renderer.get.destroy(scene)

proc renderScene*(engine: var Engine, scene: var Scene) =
  assert engine.renderer.isSome, "Renderer has not yet been initialized, call 'engine.initRenderer' first"
  assert engine.renderer.get.hasScene(scene), &"Scene '{scene.name}' has not been loaded yet"
  let t0 = getMonoTime()

  engine.renderer.get.startNewFrame()
  scene.setShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.getAspectRatio)
  engine.renderer.get.updateMeshData(scene)
  engine.renderer.get.updateUniformData(scene)
  engine.renderer.get.render(scene)

  if engine.showFps:
    let nanoSecs = getMonoTime().ticks - t0.ticks
    engine.lastNRenderTimes[engine.currentRenderTimeI] = nanoSecs
    inc engine.currentRenderTimeI
    if engine.currentRenderTimeI >= engine.lastNRenderTimes.len:
      engine.currentRenderTimeI = 0
      engine.lastNRenderTimes.sort
      let
        min = float(engine.lastNRenderTimes[0]) / 1_000_000
        median = float(engine.lastNRenderTimes[engine.lastNRenderTimes.len div 2]) / 1_000_000
        max = float(engine.lastNRenderTimes[^1]) / 1_000_000
      engine.window.setTitle(&"{engine.applicationName} ({min:.2}, {median:.2}, {max:.2})")


# wrappers for internal things
func gpuDevice*(engine: Engine): Device = engine.device
func getWindow*(engine: Engine): auto = engine.window
func getAspectRatio*(engine: Engine): float32 = engine.getWindow().size[0] / engine.getWindow().size[1]
func showSystemCursor*(engine: Engine) = engine.window.showSystemCursor()
func hideSystemCursor*(engine: Engine) = engine.window.hideSystemCursor()
func fullscreen*(engine: Engine): bool = engine.fullscreen
proc `fullscreen=`*(engine: var Engine, enable: bool) =
  if enable != engine.fullscreen:
    engine.fullscreen = enable
    engine.window.fullscreen(engine.fullscreen)

func limits*(engine: Engine): VkPhysicalDeviceLimits =
  engine.gpuDevice().physicalDevice.properties.limits

proc updateInputs*(engine: Engine): bool =
  updateInputs(engine.window.pendingEvents())

proc processEvents*(engine: Engine, panel: var Panel) =
  let hasMouseNow = panel.contains(mousePositionNormalized(engine.window.size), engine.getAspectRatio)

  # enter/leave events
  if hasMouseNow:
    if panel.hasMouse:
      if panel.onMouseMove != nil: panel.onMouseMove(panel)
    else:
      if panel.onMouseEnter != nil: panel.onMouseEnter(panel)
  else:
    if panel.hasMouse:
      if panel.onMouseLeave != nil: panel.onMouseLeave(panel)

  # button events
  if hasMouseNow:
    if input.mouseWasPressed():
      if panel.onMouseDown != nil: panel.onMouseDown(panel, input.mousePressedButtons())
    if input.mouseWasReleased():
      if panel.onMouseUp != nil: panel.onMouseUp(panel, input.mouseReleasedButtons())

  panel.hasMouse = hasMouseNow
