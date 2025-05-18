import std/sequtils
import std/enumutils
import std/tables
import std/strutils
import std/logging
import std/os

include ./vkapi

# =============================================================================
# UTILS =======================================================================
# =============================================================================

if not defined(release):
  addHandler(newConsoleLogger())
  addHandler(newFileLogger("svk.log"))

# log level
when defined(release):
  const LOGLEVEL {.strdefine.}: string = "Warn"
else:
  const LOGLEVEL {.strdefine.}: string = "Debug"
setLogFilter(parseEnum[Level]("lvl" & LOGLEVEL))

template debugAssert(arg: untyped): untyped =
  when not defined(release):
    assert arg

# we will support vulkan 1.2 for maximum portability
const VULKAN_VERSION = VK_MAKE_API_VERSION(0, 1, 2, 0)

iterator items*[T: HoleyEnum](E: typedesc[T]): T =
  for a in enumFullRange(E):
    yield a

template checkVkResult*(call: untyped) =
  when defined(release):
    discard call
  else:
    # yes, a bit cheap, but this is only for nice debug output
    var callstr = astToStr(call).replace("\n", "")
    while callstr.find("  ") >= 0:
      callstr = callstr.replace("  ", " ")
    debug "Calling vulkan: ", callstr
    let value = call
    if value != VK_SUCCESS:
      error "Vulkan error: ", astToStr(call), " returned ", $value
      raise newException(
        Exception, "Vulkan error: " & astToStr(call) & " returned " & $value
      )

# =============================================================================
# PLATFORM TYPES ==============================================================
# =============================================================================

when defined(windows):
  type NativeWindow* = object
    hinstance*: HINSTANCE
    hwnd*: HWND
    g_wpPrev*: WINDOWPLACEMENT
else:
  type NativeWindow* = object
    display*: ptr Display
    window*: Window
    emptyCursor*: Cursor
    ic*: XIC




# =============================================================================
# VULKAN INSTANCE =============================================================
# =============================================================================

type SVkInstance* = object
  vkInstance: VkInstance
  debugMessenger: VkDebugUtilsMessengerEXT
  window: NativeWindow
  vkSurface*: VkSurfaceKHR

proc createWindow(title: string): NativeWindow

proc `=copy`(a: var SVkInstance, b: SVkInstance) {.error.}

proc `=destroy`(a: SVkInstance) =
  debugAssert a.vkInstance.pointer == nil
  debugAssert a.vkSurface.pointer == nil
  debugAssert a.debugMessenger.pointer == nil

proc destroy*(a: var SVkInstance) =
  if a.vkInstance.pointer != nil:
    if a.debugMessenger.pointer != nil:
      vkDestroyDebugUtilsMessengerEXT(a.vkInstance, a.debugMessenger, nil)
      a.debugMessenger = VkDebugUtilsMessengerEXT(nil)
    vkDestroySurfaceKHR(a.vkInstance, a.vkSurface, nil)
    a.vkSurface = VkSurfaceKHR(nil)
    a.vkInstance.vkDestroyInstance(nil)
    a.vkInstance = VkInstance(nil)

proc debugCallback(
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT,
    userData: pointer,
): VkBool32 {.cdecl.} =
  const LOG_LEVEL_MAPPING = {
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT: lvlDebug,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT: lvlInfo,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT: lvlWarn,
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT: lvlError,
  }.toTable
  log LOG_LEVEL_MAPPING[messageSeverity], "SVK-LOG: ", $pCallbackData.pMessage
  if messageSeverity == VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT:
    let errorMsg = $pCallbackData.pMessage & ": " & getStackTrace()
    raise newException(Exception, errorMsg)
  return VK_FALSE

proc svkCreateInstance*(
    applicationName: string,
    enabledLayers: openArray[string] = [],
    enabledExtensions: openArray[string] =
      if defined(release):
        if defined(windows):
          @["VK_KHR_surface", "VK_KHR_win32_surface"]
        else:
          @["VK_KHR_surface", "VK_KHR_xlib_surface"]
      else:
        if defined(windows):
          @["VK_KHR_surface", "VK_EXT_debug_utils", "VK_KHR_win32_surface"]
        else:
          @["VK_KHR_surface", "VK_EXT_debug_utils", "VK_KHR_xlib_surface"],
    engineName = "semicongine",
): SVkInstance =
  putEnv("VK_LOADER_LAYERS_ENABLE", "*validation")
  putEnv(
    "VK_LAYER_ENABLES",
    "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT",
  )
  initVulkanLoader()

  var allLayers = @enabledLayers
  when not defined(release):
    allLayers.add "VK_LAYER_KHRONOS_validation"

  let
    appinfo = VkApplicationInfo(
      pApplicationName: applicationName,
      pEngineName: engineName,
      apiVersion: VULKAN_VERSION,
    )
    enabledLayersC = allocCStringArray(allLayers)
    enabledExtensionsC = allocCStringArray(enabledExtensions)
    createinfo = VkInstanceCreateInfo(
      pApplicationInfo: addr appinfo,
      enabledLayerCount: allLayers.len.uint32,
      ppEnabledLayerNames: enabledLayersC,
      enabledExtensionCount: enabledExtensions.len.uint32,
      ppEnabledExtensionNames: enabledExtensionsC,
    )
  checkVkResult vkCreateInstance(addr createinfo, nil, addr result.vkInstance)

  enabledLayersC.deallocCStringArray()
  enabledExtensionsC.deallocCStringArray()

  # only support up to vulkan 1.2 for maximum portability
  load_VK_VERSION_1_0(result.vkInstance)
  load_VK_VERSION_1_1(result.vkInstance)
  load_VK_VERSION_1_2(result.vkInstance)

  for extension in enabledExtensions:
    loadExtension(result.vkInstance, extension)
  load_VK_KHR_swapchain(result.vkInstance)

  var allTypes: VkDebugUtilsMessageTypeFlagsEXT
  for t in VkDebugUtilsMessageTypeFlagBitsEXT:
    allTypes = allTypes or t
  when not defined(release):
    var debugMessengerCreateInfo = VkDebugUtilsMessengerCreateInfoEXT(
      messageSeverity: VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT or VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT or VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT or VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
      messageType: VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT or VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT or VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
      pfnUserCallback: debugCallback,
    )
    checkVkResult vkCreateDebugUtilsMessengerEXT(
      result.vkInstance, addr debugMessengerCreateInfo, nil, addr result.debugMessenger
    )


  result.window = createWindow(applicationName)
  when defined(windows):
    var surfaceCreateInfo = VkWin32SurfaceCreateInfoKHR(hinstance: window.hinstance, hwnd: window.hwnd)
    checkVkResult vkCreateWin32SurfaceKHR(instance, addr surfaceCreateInfo, nil, addr result.vkSurface)
  else:
    var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(dpy: result.window.display, window: result.window.window)
    checkVkResult result.vkInstance.vkCreateXlibSurfaceKHR(addr surfaceCreateInfo, nil, addr result.vkSurface)



# =============================================================================
# PHYSICAL DEVICES ============================================================
# =============================================================================

type
  SVkMemoryType* = object
    size: uint64
    deviceLocal: bool # fast for gpu access
    hostCached: bool # fast for host access
    hostVisible: bool # can use vkMapMemory
    hostCohorent: bool # does *not* require vkFlushMappedMemoryRanges and vkInvalidateMappedMemoryRanges 
  SVkQueueFamilies* = object
    count: int
    hasGraphics: bool # implies "hasTransfer"
    hasCompute: bool # implies "hasTransfer"

  SVkPhysicalDevice* = object
    name*: string
    vkPhysicalDevice*: VkPhysicalDevice
    vkPhysicalDeviceFeatures*: VkPhysicalDeviceFeatures
    vkPhysicalDeviceProperties*: VkPhysicalDeviceProperties
    memoryTypes*: seq[SVkMemoryType]
    queueFamily*: uint32

proc getUsablePhysicalDevices*(instance: SVkInstance): seq[SVkPhysicalDevice] =
  var nDevices: uint32
  checkVkResult instance.vkInstance.vkEnumeratePhysicalDevices(addr nDevices, nil)
  var devices = newSeq[VkPhysicalDevice](nDevices)
  checkVkResult instance.vkInstance.vkEnumeratePhysicalDevices(addr nDevices, addr devices[0])
  for d in devices:
    var dev = SVkPhysicalDevice(vkPhysicalDevice: d)
    d.vkGetPhysicalDeviceFeatures(addr dev.vkPhysicalDeviceFeatures)
    d.vkGetPhysicalDeviceProperties(addr dev.vkPhysicalDeviceProperties)

    if dev.vkPhysicalDeviceProperties.deviceType notin [VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU, VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU]:
      continue
    dev.name = $cast[cstring](addr dev.vkPhysicalDeviceProperties.deviceName[0])

    var memoryProperties: VkPhysicalDeviceMemoryProperties
    d.vkGetPhysicalDeviceMemoryProperties(addr memoryProperties)
    for i in 0 ..< memoryProperties.memoryTypeCount:
      let heapI = memoryProperties.memoryTypes[i].heapIndex
      dev.memoryTypes.add SVkMemoryType(
        size: memoryProperties.memoryHeaps[heapI].size.uint64,
        deviceLocal: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT in memoryProperties.memoryTypes[i].propertyFlags,
        hostCached: VK_MEMORY_PROPERTY_HOST_CACHED_BIT in memoryProperties.memoryTypes[i].propertyFlags,
        hostVisible: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT in memoryProperties.memoryTypes[i].propertyFlags,
        hostCohorent: VK_MEMORY_PROPERTY_HOST_COHERENT_BIT  in memoryProperties.memoryTypes[i].propertyFlags,
      )
      

    var familyQueueCount: uint32
    var vkQueueFamilyProperties: seq[VkQueueFamilyProperties]
    d.vkGetPhysicalDeviceQueueFamilyProperties(addr familyQueueCount, nil)
    vkQueueFamilyProperties.setLen(familyQueueCount)
    d.vkGetPhysicalDeviceQueueFamilyProperties(addr familyQueueCount, addr vkQueueFamilyProperties[0])
    dev.queueFamily = high(uint32)
    for i in 0 ..< familyQueueCount:
      let hasGraphics = VK_QUEUE_GRAPHICS_BIT in vkQueueFamilyProperties[i].queueFlags
      let hasCompute = VK_QUEUE_COMPUTE_BIT in vkQueueFamilyProperties[i].queueFlags
      let hasPresentation = VK_FALSE
      checkVkResult dev.vkPhysicalDevice.vkGetPhysicalDeviceSurfaceSupportKHR(i, instance.vkSurface, addr hasPresentation)

      if hasGraphics and hasCompute and bool(hasPresentation):
        dev.queueFamily = i
        break
    if dev.queueFamily == high(uint32):
      raise newException(Exception, "Did not find queue family with graphics and compute support!")

    result.add dev

when defined(windows):
  proc createWindow(title: string): NativeWindow =
    result.hInstance = HINSTANCE(GetModuleHandle(nil))
    var
      windowClassName = T"EngineWindowClass"
      windowName = T(title)
      windowClass = WNDCLASSEX(
        cbSize: UINT(WNDCLASSEX.sizeof),
        lpfnWndProc: windowHandler,
        hInstance: result.hInstance,
        lpszClassName: windowClassName,
        hcursor: currentCursor,
      )

    if (RegisterClassEx(addr(windowClass)) == 0):
      raise newException(Exception, "Unable to register window class")

    result.hwnd = CreateWindowEx(
      DWORD(0),
      windowClassName,
      windowName,
      DWORD(WS_OVERLAPPEDWINDOW),
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      HMENU(0),
      HINSTANCE(0),
      result.hInstance,
      nil,
    )

    result.g_wpPrev.length = UINT(sizeof(WINDOWPLACEMENT))
    discard result.hwnd.ShowWindow(SW_SHOW)
    discard result.hwnd.SetForegroundWindow()
    discard result.hwnd.SetFocus()

  proc destroyWindow*(window: NativeWindow) =
    DestroyWindow(window.hwnd)

else:
  import ../semicongine/thirdparty/x11/xkblib
  import ../semicongine/thirdparty/x11/xutil

  var deleteMessage* {.hint[GlobalVar]: off.}: x.Atom # one internal use, not serious

  proc XErrorLogger(display: PDisplay, event: PXErrorEvent): cint {.cdecl.} =
    logging.error "Xlib: " & $event[]

  proc createWindow(title: string): NativeWindow =
    doAssert XInitThreads() != 0
    let display = XOpenDisplay(nil)
    if display == nil:
      quit "Failed to open display"
    discard XSetErrorHandler(XErrorLogger)

    let screen = display.XDefaultScreen()
    let rootWindow = display.XRootWindow(screen)
    let vis = display.XDefaultVisual(screen)
    discard display.XkbSetDetectableAutoRepeat(true, nil)
    var
      attribs: XWindowAttributes
      width = cuint(800)
      height = cuint(600)
    doAssert display.XGetWindowAttributes(rootWindow, addr(attribs)) != 0

    var attrs = XSetWindowAttributes(
      event_mask:
        FocusChangeMask or KeyPressMask or KeyReleaseMask or ExposureMask or
        VisibilityChangeMask or StructureNotifyMask or ButtonMotionMask or ButtonPressMask or
        ButtonReleaseMask
    )
    let window = display.XCreateWindow(
      rootWindow,
      (attribs.width - cint(width)) div 2,
      (attribs.height - cint(height)) div 2,
      width,
      height,
      0,
      display.XDefaultDepth(screen),
      InputOutput,
      vis,
      CWEventMask,
      addr(attrs),
    )
    doAssert display.XSetStandardProperties(window, title, "window", 0, nil, 0, nil) != 0
    # get an input context, to allow encoding of key-events to characters

    let im = XOpenIM(display, nil, nil, nil)
    assert im != nil
    let ic = im.XCreateIC(XNInputStyle, XIMPreeditNothing or XIMStatusNothing, nil)
    assert ic != nil

    doAssert display.XMapWindow(window) != 0

    deleteMessage = display.XInternAtom("WM_DELETE_WINDOW", XBool(false))
    doAssert display.XSetWMProtocols(window, addr(deleteMessage), 1) != 0

    var data = "\0".cstring
    var pixmap = display.XCreateBitmapFromData(window, data, 1, 1)
    var color: XColor
    var empty_cursor =
      display.XCreatePixmapCursor(pixmap, pixmap, addr(color), addr(color), 0, 0)
    doAssert display.XFreePixmap(pixmap) != 0

    discard display.XSync(0)

    # wait until window is shown
    var ev: XEvent
    while ev.theType != MapNotify:
      discard display.XNextEvent(addr(ev))

    result = NativeWindow(display: display, window: window, emptyCursor: empty_cursor, ic: ic)

  proc destroyWindow*(window: NativeWindow) =
    doAssert XDestroyWindow(window.display, window.window) != 0

