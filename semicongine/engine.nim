import std/options
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
import ./events
import ./audio
import ./text
import ./panel

type
  EngineState* = enum
    Starting
    Running
    Shutdown
  Input = object
    keyIsDown: set[Key]
    keyWasPressed: set[Key]
    keyWasReleased: set[Key]
    mouseIsDown: set[MouseButton]
    mouseWasPressed: set[MouseButton]
    mouseWasReleased: set[MouseButton]
    mousePosition: Vec2f
    mouseMove: Vec2f
    eventsProcessed: uint64
    windowWasResized: bool
    mouseWheel: float32
  Engine* = object
    state*: EngineState
    device: Device
    debugger: Debugger
    instance: Instance
    window: NativeWindow
    renderer: Option[Renderer]
    input: Input
    exitHandler: proc(engine: var Engine)
    resizeHandler: proc(engine: var Engine)
    eventHandler: proc(engine: var Engine, event: Event)
    fullscreen: bool

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


proc initEngine*(
  applicationName: string,
  debug = DEBUG,
  exitHandler: proc(engine: var Engine) = nil,
  resizeHandler: proc(engine: var Engine) = nil,
  eventHandler: proc(engine: var Engine, event: Event) = nil,
  vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
  vulkanLayers: openArray[string] = [],
): Engine =
  echo "Set log level to ", ENGINE_LOGLEVEL
  setLogFilter(ENGINE_LOGLEVEL)

  result.state = Starting
  result.exitHandler = exitHandler
  result.resizeHandler = resizeHandler
  result.eventHandler = eventHandler
  result.window = createWindow(applicationName)

  var
    layers = @vulkanLayers
    instanceExtensions: seq[string]

  if debug:
    instanceExtensions.add "VK_EXT_debug_utils"
    layers.add "VK_LAYER_KHRONOS_validation"
    # This stuff might be usefull if we one day to smart GPU memory allocation,
    # but right now it just clobbers up the console log
    # putEnv("VK_LAYER_ENABLES", "VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT")
    putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")

  if defined(linux) and DEBUG:
    layers.add "VK_LAYER_MESA_overlay"
  result.instance = result.window.createInstance(
    vulkanVersion = vulkanVersion,
    instanceExtensions = instanceExtensions,
    layers = layers,
  )
  if debug:
    result.debugger = result.instance.createDebugMessenger()
  # create devices
  let selectedPhysicalDevice = result.instance.getPhysicalDevices().filterBestGraphics()
  result.device = result.instance.createDevice(
    selectedPhysicalDevice,
    enabledLayers = @[],
    enabledExtensions = @[],
    selectedPhysicalDevice.filterForGraphicsPresentationQueues()
  )
  startMixerThread()

proc initRenderer*(engine: var Engine, shaders: openArray[(MaterialType, ShaderConfiguration)], clearColor = Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32]), backFaceCulling = true) =

  assert not engine.renderer.isSome
  var allShaders = @shaders
  if not shaders.mapIt(it[0]).contains(EMPTY_MATERIAL):
    allShaders.add (EMPTY_MATERIAL, EMPTY_SHADER)
  if not shaders.mapIt(it[0]).contains(PANEL_MATERIAL_TYPE):
    allShaders.add (PANEL_MATERIAL_TYPE, PANEL_SHADER)
  if not shaders.mapIt(it[0]).contains(TEXT_MATERIAL_TYPE):
    allShaders.add (TEXT_MATERIAL_TYPE, TEXT_SHADER)
  engine.renderer = some(engine.device.initRenderer(shaders = allShaders, clearColor = clearColor, backFaceCulling = backFaceCulling))

proc initRenderer*(engine: var Engine, clearColor = Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32])) =
  engine.initRenderer(@[], clearColor)

proc loadScene*(engine: var Engine, scene: var Scene) =
  assert engine.renderer.isSome
  assert not scene.loaded
  scene.addShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.getAspectRatio)
  engine.renderer.get.setupDrawableBuffers(scene)
  engine.renderer.get.updateMeshData(scene, forceAll = true)
  engine.renderer.get.updateUniformData(scene, forceAll = true)

proc unloadScene*(engine: var Engine, scene: Scene) =
  engine.renderer.get.destroy(scene)

proc renderScene*(engine: var Engine, scene: var Scene) =
  assert engine.state == Running
  assert engine.renderer.isSome
  scene.setShaderGlobal(ASPECT_RATIO_ATTRIBUTE, engine.getAspectRatio)
  engine.renderer.get.updateMeshData(scene)
  engine.renderer.get.updateUniformData(scene)
  engine.renderer.get.render(scene)

proc updateInputs*(engine: var Engine): EngineState =
  assert engine.state in [Starting, Running]

  # reset input states
  engine.input.keyWasPressed = {}
  engine.input.keyWasReleased = {}
  engine.input.mouseWasPressed = {}
  engine.input.mouseWasReleased = {}
  engine.input.mouseWheel = 0
  engine.input.mouseMove = newVec2f()
  engine.input.windowWasResized = false

  if engine.state == Starting:
    engine.input.windowWasResized = true
    var mpos = engine.window.getMousePosition()
    if mpos.isSome:
      engine.input.mousePosition = mpos.get

  var killed = false
  for event in engine.window.pendingEvents():
    inc engine.input.eventsProcessed
    if engine.eventHandler != nil:
      engine.eventHandler(engine, event)
    case event.eventType:
      of Quit:
        killed = true
      of ResizedWindow:
        engine.input.windowWasResized = true
      of KeyPressed:
        engine.input.keyWasPressed.incl event.key
        engine.input.keyIsDown.incl event.key
      of KeyReleased:
        engine.input.keyWasReleased.incl event.key
        engine.input.keyIsDown.excl event.key
      of MousePressed:
        engine.input.mouseWasPressed.incl event.button
        engine.input.mouseIsDown.incl event.button
      of MouseReleased:
        engine.input.mouseWasReleased.incl event.button
        engine.input.mouseIsDown.excl event.button
      of MouseMoved:
        let newPos = newVec2(float32(event.x), float32(event.y))
        engine.input.mouseMove = newPos - engine.input.mousePosition
        engine.input.mousePosition = newPos
      of MouseWheel:
        engine.input.mouseWheel = event.amount
  if engine.state == Starting:
    engine.state = Running
  if killed:
    engine.state = Shutdown
    if engine.exitHandler != nil:
      engine.exitHandler(engine)
  if engine.input.windowWasResized and engine.resizeHandler != nil:
    engine.resizeHandler(engine)
  return engine.state

# wrappers for internal things
func keyIsDown*(engine: Engine, key: Key): auto = key in engine.input.keyIsDown
func keyWasPressed*(engine: Engine, key: Key): auto = key in engine.input.keyWasPressed
func keyWasPressed*(engine: Engine): auto = engine.input.keyWasPressed.len > 0
func keyWasReleased*(engine: Engine, key: Key): auto = key in engine.input.keyWasReleased
func mouseIsDown*(engine: Engine, button: MouseButton): auto = button in engine.input.mouseIsDown
func mouseWasPressed*(engine: Engine, button: MouseButton): auto = button in engine.input.mouseWasPressed
func mouseWasReleased*(engine: Engine, button: MouseButton): auto = button in engine.input.mouseWasReleased
func mousePosition*(engine: Engine): auto = engine.input.mousePosition
func mousePositionNormalized*(engine: Engine): Vec2f =
  result.x = (engine.input.mousePosition.x / float32(engine.window.size[0])) * 2.0 - 1.0
  result.y = (engine.input.mousePosition.y / float32(engine.window.size[1])) * 2.0 - 1.0
func mouseMove*(engine: Engine): auto = engine.input.mouseMove
func mouseWheel*(engine: Engine): auto = engine.input.mouseWheel
func eventsProcessed*(engine: Engine): auto = engine.input.eventsProcessed
func framesRendered*(engine: Engine): uint64 = (if engine.renderer.isSome: engine.renderer.get.framesRendered else: 0)
func gpuDevice*(engine: Engine): Device = engine.device
func getWindow*(engine: Engine): auto = engine.window
func getAspectRatio*(engine: Engine): float32 = engine.getWindow().size[0] / engine.getWindow().size[1]
func windowWasResized*(engine: Engine): auto = engine.input.windowWasResized
func showSystemCursor*(engine: Engine) = engine.window.showSystemCursor()
func hideSystemCursor*(engine: Engine) = engine.window.hideSystemCursor()
func fullscreen*(engine: Engine): bool = engine.fullscreen
proc `fullscreen=`*(engine: var Engine, enable: bool) =
  if enable != engine.fullscreen:
    engine.fullscreen = enable
    engine.window.fullscreen(engine.fullscreen)

func limits*(engine: Engine): VkPhysicalDeviceLimits =
  engine.gpuDevice().physicalDevice.properties.limits

proc processEvents*(engine: Engine, panel: var Panel) =
  let hasMouseNow = panel.contains(engine.mousePositionNormalized, engine.getAspectRatio)

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
    if engine.input.mouseWasPressed.len > 0:
      if panel.onMouseDown != nil: panel.onMouseDown(panel, engine.input.mouseWasPressed)
    if engine.input.mouseWasReleased.len > 0:
      if panel.onMouseUp != nil: panel.onMouseUp(panel, engine.input.mouseWasReleased)

  panel.hasMouse = hasMouseNow
