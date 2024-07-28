import ../../thirdparty/x11/xlib
import ../../thirdparty/x11/xutil
import ../../thirdparty/x11/keysym
import ../../thirdparty/x11/x as x11
import ../../thirdparty/x11/xkblib

const REQUIRED_PLATFORM_EXTENSIONS = @["VK_KHR_xlib_surface"]

# got values (keycodes) from xev
const KeyTypeMap = {
  9: Escape, 67: F1, 68: F2, 69: F3, 70: F4, 71: F5, 72: F6, 73: F7, 74: F8,
  75: F9, 76: F10, 95: F11, 96: F12,
  49: NumberRowExtra1, 10: `1`, 11: `2`, 12: `3`, 13: `4`, 14: `5`, 15: `6`,
  16: `7`, 17: `8`, 18: `9`, 19: `0`, 20: NumberRowExtra2, 21: NumberRowExtra3,
  24: Q, 25: W, 26: E, 27: R, 28: T, 29: Y, 30: U, 31: I, 32: O, 33: P, 38: A,
  39: S, 40: D, 41: Key.F, 42: G, 43: H, 44: J, 45: K, 46: L, 52: Z, 53: X,
  54: C, 55: V, 56: B, 57: N, 58: M,

  23: Tab, 66: CapsLock, 50: ShiftL, 62: ShiftR, 37: CtrlL, 105: CtrlR,
  133: SuperL, 134: SuperR,
  64: AltL, 108: AltR,
  65: Space, 36: Enter, 22: Backspace,
  34: LetterRow1Extra1, 35: LetterRow1Extra2,
  47: LetterRow2Extra1, 48: LetterRow2Extra2, 51: LetterRow2Extra3,
  59: LetterRow3Extra1, 60: LetterRow3Extra2, 61: LetterRow3Extra3,
  111: Up, 116: Down, 113: Left, 114: Right,
  112: PageUp, 117: PageDown, 110: Home, 115: End, 118: Insert, 119: Delete,
  107: PrintScreen, 78: ScrollLock, 127: Pause,
}.toTable

const MouseButtonTypeMap = {
  x11.Button1: MouseButton.Mouse1,
  x11.Button2: MouseButton.Mouse2,
  x11.Button3: MouseButton.Mouse3,
}.toTable

var deleteMessage*: Atom

type
  NativeWindow* = object
    display*: ptr xlib.Display
    window*: x11.Window
    emptyCursor: Cursor

template checkXlibResult(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Xlib error: " & astToStr(call) &
        " returned " & $value)

proc XErrorLogger(display: PDisplay, event: PXErrorEvent): cint {.cdecl.} =
  logging.error &"Xlib: {event[]}"

proc CreateWindow*(title: string): NativeWindow =
  checkXlibResult XInitThreads()
  let display = XOpenDisplay(nil)
  if display == nil:
    quit "Failed to open display"
  discard XSetErrorHandler(XErrorLogger)

  let rootWindow = display.XDefaultRootWindow()
  discard display.XkbSetDetectableAutoRepeat(true, nil)
  var
    attribs: XWindowAttributes
    width = cuint(800)
    height = cuint(600)
  checkXlibResult display.XGetWindowAttributes(rootWindow, addr(attribs))

  var attrs = XSetWindowAttributes()
  let window = XCreateWindow(
    display,
    rootWindow,
    (attribs.width - cint(width)) div 2, (attribs.height - cint(height)) div 2,
    width, height,
    0,
    CopyFromParent,
    InputOutput,
    cast[PVisual](CopyFromParent),
    0, # CWOverrideRedirect,
    addr attrs,
    # foregroundColor, backgroundColor
  )
  checkXlibResult XSetStandardProperties(display, window, title, "window", 0, nil, 0, nil)
  checkXlibResult XSelectInput(display, window, PointerMotionMask or ButtonPressMask or ButtonReleaseMask or KeyPressMask or KeyReleaseMask or ExposureMask or FocusChangeMask)
  checkXlibResult XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", XBool(false))
  checkXlibResult XSetWMProtocols(display, window, addr(deleteMessage), 1)

  var data = "\0".cstring
  var pixmap = display.XCreateBitmapFromData(window, data, 1, 1)
  var color: XColor
  var empty_cursor = display.XCreatePixmapCursor(pixmap, pixmap, addr(color), addr(color), 0, 0)
  checkXlibResult display.XFreePixmap(pixmap)
  return NativeWindow(display: display, window: window, emptyCursor: empty_cursor)

proc SetTitle*(window: NativeWindow, title: string) =
  checkXlibResult XSetStandardProperties(window.display, window.window, title, "window", 0, nil, 0, nil)

proc SetFullscreen*(window: var NativeWindow, enable: bool) =
  var
    wm_state = window.display.XInternAtom("_NET_WM_STATE", 0)
    wm_fullscreen = window.display.XInternAtom("_NET_WM_STATE_FULLSCREEN", 0)
  var
    xev: XEvent
  xev.xclient = XClientMessageEvent(
    message_type: wm_state,
    format: 32,
    window: window.window,
    data: XClientMessageData(
      l: [
        int(not enable) xor 1,
        clong(wm_fullscreen),
        0,
        0,
        0
    ]
  )
  )
  xev.theType = ClientMessage

  checkXlibResult window.display.XSendEvent(
    window.display.DefaultRootWindow(),
    0,
    SubstructureRedirectMask or SubstructureNotifyMask,
    addr xev
  )
  checkXlibResult window.display.XFlush()

proc ShowSystemCursor*(window: NativeWindow, value: bool) =
  if value == true:
    checkXlibResult XUndefineCursor(window.display, window.window)
    checkXlibResult window.display.XFlush()
  else:
    checkXlibResult XDefineCursor(window.display, window.window, window.emptyCursor)
    checkXlibResult window.display.XFlush()

proc Destroy*(window: NativeWindow) =
  checkXlibResult window.display.XFreeCursor(window.emptyCursor)
  checkXlibResult window.display.XDestroyWindow(window.window)
  discard window.display.XCloseDisplay() # always returns 0

proc Size*(window: NativeWindow): (int, int) =
  var attribs: XWindowAttributes
  checkXlibResult XGetWindowAttributes(window.display, window.window, addr(attribs))
  return (int(attribs.width), int(attribs.height))

proc PendingEvents*(window: NativeWindow): seq[Event] =
  var event: XEvent
  while window.display.XPending() > 0:
    discard window.display.XNextEvent(addr(event))
    case event.theType
    of ClientMessage:
      if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
        result.add(Event(eventType: Quit))
    of KeyPress:
      let keyevent = cast[PXKeyEvent](addr(event))
      let xkey = int(keyevent.keycode)
      result.add Event(eventType: KeyPressed, key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN))
    of KeyRelease:
      let keyevent = cast[PXKeyEvent](addr(event))
      let xkey = int(keyevent.keycode)
      result.add Event(eventType: KeyReleased, key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN))
    of ButtonPress:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      if button == Button4:
        result.add Event(eventType: MouseWheel, amount: 1'f32)
      elif button == Button5:
        result.add Event(eventType: MouseWheel, amount: -1'f32)
      else:
        result.add Event(eventType: MousePressed, button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of ButtonRelease:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      result.add Event(eventType: MouseReleased, button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of MotionNotify:
      let motion = cast[PXMotionEvent](addr(event))
      result.add Event(eventType: MouseMoved, x: motion.x, y: motion.y)
    of FocusIn:
      result.add Event(eventType: GotFocus)
    of FocusOut:
      result.add Event(eventType: LostFocus)
    of ConfigureNotify, Expose:
      result.add Event(eventType: ResizedWindow)
    else:
      discard


proc GetMousePosition*(window: NativeWindow): Option[Vec2f] =
  var
    root: x11.Window
    win: x11.Window
    rootX: cint
    rootY: cint
    winX: cint
    winY: cint
    mask: cuint
    onscreen = XQueryPointer(
      window.display,
      window.window,
      addr(root),
      addr(win),
      addr(rootX),
      addr(rootY),
      addr(winX),
      addr(winY),
      addr(mask),
    )
  if onscreen != 0:
    result = some(Vec2f([float32(winX), float32(winY)]))

proc SetMousePosition*(window: NativeWindow, x, y: int) =
  checkXlibResult XWarpPointer(
    window.display,
    default(x11.Window),
    window.window,
    0, 0, 0, 0,
    x.cint,
    y.cint,
  )
  checkXlibResult XSync(window.display, false.XBool)

proc CreateNativeSurface(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr Display](window.display),
    window: cast[Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
