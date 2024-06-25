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
func GetAspectRatio*(engine: Engine): float32

proc Destroy*(engine: var Engine) =
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  if engine.renderer.isSome:
    engine.renderer.get.Destroy()
  engine.device.Destroy()
  if engine.debugger.messenger.Valid:
    engine.debugger.Destroy()
  engine.window.Destroy()
  engine.instance.Destroy()
  if SteamAvailable():
    SteamShutdown()


proc InitEngine*(
  applicationName = querySetting(projectName),
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
  result.showFps = showFps
  result.window = CreateWindow(result.applicationName)

  var
    layers = @vulkanLayers
    instanceExtensions: seq[string]

  if DEBUG:
    instanceExtensions.add "VK_EXT_debug_utils"
    layers.add "VK_LAYER_KHRONOS_validation"
    # This stuff might be usefull if we one day to smart GPU memory allocation,
    # but right now it just clobbers up the console log:
    # putEnv("VK_LAYER_ENABLES", "VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT")
    putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")

  result.instance = result.window.CreateInstance(
    vulkanVersion = vulkanVersion,
    instanceExtensions = instanceExtensions,
    layers = layers.deduplicate(),
  )
  if DEBUG:
    result.debugger = result.instance.CreateDebugMessenger()
  # create devices
  let selectedPhysicalDevice = result.instance.GetPhysicalDevices().FilterBestGraphics()
  result.device = result.instance.CreateDevice(
    selectedPhysicalDevice,
    enabledExtensions = @[],
    selectedPhysicalDevice.FilterForGraphicsPresentationQueues()
  )
  StartMixerThread()

proc InitRenderer*(
  engine: var Engine,
  shaders: openArray[(MaterialType, ShaderConfiguration)],
  clearColor = NewVec4f(0, 0, 0, 0),
  backFaceCulling = true,
  vSync = false,
  inFlightFrames = 2,
  samples = VK_SAMPLE_COUNT_1_BIT,
) =

  assert not engine.renderer.isSome
  var allShaders = @shaders
  if not shaders.mapIt(it[0]).contains(EMPTY_MATERIAL):
    allShaders.add (EMPTY_MATERIAL, EMPTY_SHADER)
  if not shaders.mapIt(it[0]).contains(PANEL_MATERIAL_TYPE):
    allShaders.add (PANEL_MATERIAL_TYPE, PANEL_SHADER)
  if not shaders.mapIt(it[0]).contains(TEXT_MATERIAL_TYPE):
    allShaders.add (TEXT_MATERIAL_TYPE, TEXT_SHADER)
  engine.renderer = some(engine.device.InitRenderer(
    shaders = allShaders,
    clearColor = clearColor,
    backFaceCulling = backFaceCulling,
    vSync = vSync,
    inFlightFrames = inFlightFrames,
    samples = samples,
  ))

proc InitRenderer*(engine: var Engine, clearColor = NewVec4f(0, 0, 0, 0), vSync = false) =
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  engine.InitRenderer(@[], clearColor, vSync = vSync)
  checkVkResult engine.device.vk.vkDeviceWaitIdle()

proc LoadScene*(engine: var Engine, scene: var Scene) =
  debug &"start loading scene '{scene.name}'"
  assert engine.renderer.isSome
  assert not scene.loaded
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  scene.AddShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.GetAspectRatio)
  engine.renderer.get.SetupDrawableBuffers(scene)
  engine.renderer.get.UpdateMeshData(scene, forceAll = true)
  engine.renderer.get.UpdateUniformData(scene, forceAll = true)
  checkVkResult engine.device.vk.vkDeviceWaitIdle()
  debug &"done loading scene '{scene.name}'"

proc UnloadScene*(engine: var Engine, scene: Scene) =
  debug &"unload scene '{scene.name}'"
  engine.renderer.get.Destroy(scene)

proc RenderScene*(engine: var Engine, scene: var Scene) =
  if WindowIsMinimized():
    return
  assert engine.renderer.isSome, "Renderer has not yet been initialized, call 'engine.InitRenderer' first"
  assert engine.renderer.get.HasScene(scene), &"Scene '{scene.name}' has not been loaded yet"
  let t0 = getMonoTime()

  if engine.renderer.get.StartNewFrame():
    scene.SetShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.GetAspectRatio)
    engine.renderer.get.UpdateMeshData(scene)
    engine.renderer.get.UpdateUniformData(scene)
    engine.renderer.get.Render(scene)

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
      engine.window.SetTitle(&"{engine.applicationName} ({min:.2}, {median:.2}, {max:.2})")


# wrappers for internal things
func GpuDevice*(engine: Engine): Device = engine.device
func GetWindow*(engine: Engine): auto = engine.window
func GetAspectRatio*(engine: Engine): float32 = engine.GetWindow().Size[0] / engine.GetWindow().Size[1]
proc ShowSystemCursor*(engine: Engine) = engine.window.ShowSystemCursor()
proc HideSystemCursor*(engine: Engine) = engine.window.HideSystemCursor()
func Fullscreen*(engine: Engine): bool = engine.fullscreen
proc `Fullscreen=`*(engine: var Engine, enable: bool) =
  if enable != engine.fullscreen:
    engine.fullscreen = enable
    engine.window.Fullscreen(engine.fullscreen)

func Limits*(engine: Engine): VkPhysicalDeviceLimits =
  engine.device.physicalDevice.properties.limits

proc UpdateInputs*(engine: Engine): bool =
  UpdateInputs(engine.window.PendingEvents())

proc ProcessEvents*(engine: Engine, panel: var Panel) =
  let hasMouseNow = panel.Contains(MousePositionNormalized(engine.window.Size), engine.GetAspectRatio)

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
    if MouseWasPressed():
      if panel.onMouseDown != nil: panel.onMouseDown(panel, MousePressedButtons())
    if MouseWasReleased():
      if panel.onMouseUp != nil: panel.onMouseUp(panel, MouseReleasedButtons())

  panel.hasMouse = hasMouseNow
