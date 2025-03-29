import std/options
import std/unicode
import std/tables

import ../../thirdparty/x11/xlib
import ../../thirdparty/x11/xutil
import ../../thirdparty/x11/x as x11
import ../../thirdparty/x11/xkblib

const REQUIRED_PLATFORM_EXTENSIONS = @["VK_KHR_xlib_surface"]

# got values (keycodes) from xev
const KeyTypeMap = {
  9: Escape,
  67: F1,
  68: F2,
  69: F3,
  70: F4,
  71: F5,
  72: F6,
  73: F7,
  74: F8,
  75: F9,
  76: F10,
  95: F11,
  96: F12,
  49: NumberRowExtra1,
  10: `1`,
  11: `2`,
  12: `3`,
  13: `4`,
  14: `5`,
  15: `6`,
  16: `7`,
  17: `8`,
  18: `9`,
  19: `0`,
  20: NumberRowExtra2,
  21: NumberRowExtra3,
  24: Q,
  25: W,
  26: E,
  27: Key.R,
  28: T,
  29: Key.Y,
  30: U,
  31: I,
  32: Key.O,
  33: P,
  38: A,
  39: S,
  40: D,
  41: Key.F,
  42: Key.G,
  43: H,
  44: J,
  45: K,
  46: L,
  52: Key.Z,
  53: Key.X,
  54: C,
  55: V,
  56: Key.B,
  57: N,
  58: M,
  23: Tab,
  66: CapsLock,
  50: ShiftL,
  62: ShiftR,
  37: CtrlL,
  105: CtrlR,
  133: SuperL,
  134: SuperR,
  64: AltL,
  108: AltR,
  65: Space,
  36: Enter,
  22: Backspace,
  34: LetterRow1Extra1,
  35: LetterRow1Extra2,
  47: LetterRow2Extra1,
  48: LetterRow2Extra2,
  51: LetterRow2Extra3,
  59: LetterRow3Extra1,
  60: LetterRow3Extra2,
  61: LetterRow3Extra3,
  111: Up,
  116: Down,
  113: Key.Left,
  114: Key.Right,
  112: PageUp,
  117: PageDown,
  110: Home,
  115: End,
  118: Insert,
  119: Delete,
  107: PrintScreen,
  78: ScrollLock,
  127: Pause,
}.toTable

const MouseButtonTypeMap = {
  x11.Button1: MouseButton.Mouse1,
  x11.Button2: MouseButton.Mouse2,
  x11.Button3: MouseButton.Mouse3,
}.toTable

var deleteMessage* {.hint[GlobalVar]: off.}: Atom # one internal use, not serious

template checkXlibResult(call: untyped) =
  let value = call
  if value == 0:
    raise
      newException(Exception, "Xlib error: " & astToStr(call) & " returned " & $value)

proc XErrorLogger(display: PDisplay, event: PXErrorEvent): cint {.cdecl.} =
  logging.error &"Xlib: {event[]}"

proc createWindow*(title: string): NativeWindow =
  checkXlibResult XInitThreads()
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
  checkXlibResult display.XGetWindowAttributes(rootWindow, addr(attribs))

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
  checkXlibResult display.XSetStandardProperties(
    window, title, "window", 0, nil, 0, nil
  )
  # get an input context, to allow encoding of key-events to characters

  let im = XOpenIM(display, nil, nil, nil)
  assert im != nil
  let ic = im.XCreateIC(XNInputStyle, XIMPreeditNothing or XIMStatusNothing, nil)
  assert ic != nil

  checkXlibResult display.XMapWindow(window)

  deleteMessage = display.XInternAtom("WM_DELETE_WINDOW", XBool(false))
  checkXlibResult display.XSetWMProtocols(window, addr(deleteMessage), 1)

  var data = "\0".cstring
  var pixmap = display.XCreateBitmapFromData(window, data, 1, 1)
  var color: XColor
  var empty_cursor =
    display.XCreatePixmapCursor(pixmap, pixmap, addr(color), addr(color), 0, 0)
  checkXlibResult display.XFreePixmap(pixmap)

  discard display.XSync(0)

  # wait until window is shown
  var ev: XEvent
  while ev.theType != MapNotify:
    discard display.XNextEvent(addr(ev))

  return
    NativeWindow(display: display, window: window, emptyCursor: empty_cursor, ic: ic)

proc destroyWindow*(window: NativeWindow) =
  checkXlibResult XDestroyWindow(window.display, window.window)

proc setTitle*(window: NativeWindow, title: string) =
  discard XSetStandardProperties(
    window.display, window.window, title, "window", 0, nil, 0, nil
  )

proc setFullscreen*(window: var NativeWindow, enable: bool) =
  var
    wm_state = window.display.XInternAtom("_NET_WM_STATE", 0)
    wm_fullscreen = window.display.XInternAtom("_NET_WM_STATE_FULLSCREEN", 0)
  var xev: XEvent
  xev.xclient = XClientMessageEvent(
    message_type: wm_state,
    format: 32,
    window: window.window,
    data: XClientMessageData(l: [int(not enable) xor 1, clong(wm_fullscreen), 0, 0, 0]),
  )
  xev.theType = ClientMessage

  checkXlibResult window.display.XSendEvent(
    window.display.DefaultRootWindow(),
    0,
    SubstructureRedirectMask or SubstructureNotifyMask,
    addr xev,
  )
  checkXlibResult window.display.XFlush()

proc showSystemCursor*(window: NativeWindow, value: bool) =
  if value == true:
    checkXlibResult XUndefineCursor(window.display, window.window)
    checkXlibResult window.display.XFlush()
  else:
    checkXlibResult XDefineCursor(window.display, window.window, window.emptyCursor)
    checkXlibResult window.display.XFlush()

proc destroy*(window: NativeWindow) =
  checkXlibResult window.display.XFreeCursor(window.emptyCursor)
  checkXlibResult window.display.XDestroyWindow(window.window)
  discard window.display.XCloseDisplay() # always returns 0

proc size*(window: NativeWindow): Vec2i =
  var attribs: XWindowAttributes
  discard XGetWindowAttributes(window.display, window.window, addr(attribs))
  vec2i(attribs.width, attribs.height)

# buffer to save utf8-data from keyboard events
var unicodeData = newString(64)

proc pendingEvents*(window: NativeWindow): seq[Event] =
  var event: XEvent

  while window.display.XPending() > 0:
    discard window.display.XNextEvent(addr(event))

    if XFilterEvent(addr(event), None) != 0:
      continue

    case event.theType
    of ClientMessage:
      if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
        result.add(Event(eventType: Quit))
    of KeyPress:
      var e = Event(
        eventType: KeyPressed,
        key: KeyTypeMap.getOrDefault(int(event.xkey.keycode), Key.UNKNOWN),
      )
      var status: Status
      let len = window.ic.Xutf8LookupString(
        addr(event.xkey), unicodeData.cstring, unicodeData.len.cint, nil, addr(status)
      )
      if len > 0:
        unicodeData[len] = '\0'
        for r in unicodeData.runes():
          e.char = r
          break
      result.add e
    of KeyRelease:
      result.add Event(
        eventType: KeyReleased,
        key: KeyTypeMap.getOrDefault(int(event.xkey.keycode), Key.UNKNOWN),
      )
    of ButtonPress:
      let button = int(event.xbutton.button)
      if button == Button4:
        result.add Event(eventType: MouseWheel, amount: 1'f32)
      elif button == Button5:
        result.add Event(eventType: MouseWheel, amount: -1'f32)
      else:
        result.add Event(
          eventType: MousePressed,
          button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN),
        )
    of ButtonRelease:
      let button = int(event.xbutton.button)
      result.add Event(
        eventType: MouseReleased,
        button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN),
      )
    of FocusIn:
      window.ic.XSetICFocus()
      result.add Event(eventType: GotFocus)
    of FocusOut:
      window.ic.XUnsetICFocus()
      result.add Event(eventType: LostFocus)
    of ConfigureNotify, Expose:
      result.add Event(eventType: ResizedWindow)
    else:
      discard

  discard window.display.XFlush()

proc getMousePosition*(window: NativeWindow): Vec2i =
  var
    root: x11.Window
    win: x11.Window
    rootX: cint
    rootY: cint
    winX: cint
    winY: cint
    mask: cuint
  discard XQueryPointer(
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
  vec2i(winX, winY)

proc setMousePosition*(window: NativeWindow, pos: Vec2i) =
  discard XWarpPointer(
    window.display,
    default(x11.Window),
    window.window,
    0,
    0,
    0,
    0,
    pos.x.cint,
    pos.y.cint,
  )

proc createNativeSurface(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr core.Display](window.display),
    window: cast[core.Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(
    instance, addr(surfaceCreateInfo), nil, addr(result)
  )
