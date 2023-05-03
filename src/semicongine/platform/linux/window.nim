import std/options
import std/tables
import std/strformat

import
  x11/xlib,
  x11/xutil,
  x11/keysym,
  x11/x11pragma
import x11/x

echo x11pragma.libX11

import ../../events
import ../../math/vector

import ./symkey_map

export keysym

var deleteMessage*: Atom

type
  NativeWindow* = object
    display*: ptr xlib.Display
    window*: x.Window
    emptyCursor: Cursor

template checkXlibResult*(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Xlib error: " & astToStr(call) &
        " returned " & $value)


proc XErrorLogger(display: PDisplay, event: PXErrorEvent): cint {.cdecl.} =
  echo &"Xlib: {event[]}"

proc createWindow*(title: string): NativeWindow =
  checkXlibResult XInitThreads()
  let display = XOpenDisplay(nil)
  if display == nil:
    quit "Failed to open display"
  discard XSetErrorHandler(XErrorLogger)

  let rootWindow = display.XDefaultRootWindow()
  var
    attribs: XWindowAttributes
    width = cuint(800)
    height = cuint(600)
  checkXlibResult display.XGetWindowAttributes(rootWindow, addr(attribs))

  var attrs = XSetWindowAttributes(
    # override_redirect: 1
  )
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
  checkXlibResult XSelectInput(display, window, PointerMotionMask or ButtonPressMask or ButtonReleaseMask or KeyPressMask or KeyReleaseMask or ExposureMask)
  checkXlibResult XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", XBool(false))
  checkXlibResult XSetWMProtocols(display, window, addr(deleteMessage), 1)

  var data = "\0".cstring
  var pixmap = display.XCreateBitmapFromData(window, data, 1, 1)
  var color: XColor
  var empty_cursor = display.XCreatePixmapCursor(pixmap, pixmap, addr(color), addr(color), 0, 0)
  checkXlibResult display.XFreePixmap(pixmap)
  return NativeWindow(display: display, window: window, emptyCursor: empty_cursor)

proc fullscreen*(window: NativeWindow, enable: bool) =
  var WM_HINTS = XInternAtom(window.display, "_MOTIF_WM_HINTS", 1);
  var border = culong(if enable: 0 else: 1)

  type
    MWMHints = object
      flags: culong
      functions: culong
      decorations: culong
      input_mode: clong
      status: culong

  var hints = MWMHints(flags: (culong(1) shl 1), functions: 0, decorations: border, input_mode: 0, status: 0)

  checkXlibResult window.display.XChangeProperty(window.window, WM_HINTS, WM_HINTS, 32, PropModeReplace, cast[cstring](addr hints), sizeof(MWMHints) div sizeof(clong))

  var
    wm_state = window.display.XInternAtom("_NET_WM_STATE", 1)
    op = (if enable: "_NET_WM_STATE_ADD" else: "_NET_WM_STATE_REMOVE")
    wm_state_operation = window.display.XInternAtom(cstring(op), 1)
    wm_fullscreen = window.display.XInternAtom("_NET_WM_STATE_FULLSCREEN", 1)
    xev = XEvent(
      theType: ClientMessage,
      xany: XAnyEvent(theType: ClientMessage),
      xclient: XClientMessageEvent(
        message_type: wm_state,
        format: 32,
        window: window.window,
        data: XClientMessageData(
          l: [
            clong(wm_state_operation),
            clong(wm_fullscreen),
            0,
            0,
            0
          ]
        )
      )
    )

  discard window.display.XSendEvent(
    window.display.XRootWindow(window.display.XDefaultScreen()),
    0,
    SubstructureRedirectMask or SubstructureNotifyMask,
    addr xev
  )

  if enable:
    var attribs: XWindowAttributes
    checkXlibResult window.display.XGetWindowAttributes(window.display.XDefaultRootWindow(), addr(attribs))
    checkXlibResult window.display.XMoveResizeWindow(window.window, 0, 0, cuint(attribs.width), cuint(attribs.height))
  checkXlibResult window.display.XFlush()

proc hideSystemCursor*(window: NativeWindow) =
  checkXlibResult XDefineCursor(window.display, window.window, window.emptyCursor)
  checkXlibResult window.display.XFlush()

proc showSystemCursor*(window: NativeWindow) =
  checkXlibResult XUndefineCursor(window.display, window.window)
  checkXlibResult window.display.XFlush()

proc destroy*(window: NativeWindow) =
  checkXlibResult window.display.XFreeCursor(window.emptyCursor)
  checkXlibResult window.display.XDestroyWindow(window.window)
  discard window.display.XCloseDisplay() # always returns 0

proc size*(window: NativeWindow): (int, int) =
  var attribs: XWindowAttributes
  checkXlibResult XGetWindowAttributes(window.display, window.window, addr(attribs))
  return (int(attribs.width), int(attribs.height))

proc pendingEvents*(window: NativeWindow): seq[Event] =
  var
    event: XEvent
    serials: Table[culong, Table[int, seq[Event]]]
  while window.display.XPending() > 0:
    discard window.display.XNextEvent(addr(event))
    case event.theType
    of ClientMessage:
      if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
        result.add(Event(eventType: Quit))
    of KeyPress:
      let keyevent = cast[PXKeyEvent](addr(event))
      let xkey = int(keyevent.keycode)
      # ugly, but required to catch auto-repeat keys of X11
      if not (keyevent.serial in serials):
        serials[keyevent.serial] = initTable[int, seq[Event]]()
      if not (xkey in serials[keyevent.serial]):
        serials[keyevent.serial][xkey] = newSeq[Event]()
      serials[keyevent.serial][xkey].add(Event(eventType: KeyPressed,
          key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN)))
    of KeyRelease:
      let keyevent = cast[PXKeyEvent](addr(event))
      let xkey = int(keyevent.keycode)
      # ugly, but required to catch auto-repeat keys of X11
      if not (keyevent.serial in serials):
        serials[keyevent.serial] = initTable[int, seq[Event]]()
      if not (xkey in serials[keyevent.serial]):
        serials[keyevent.serial][xkey] = newSeq[Event]()
      serials[keyevent.serial][xkey].add Event(eventType: KeyReleased,
          key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN))
    of ButtonPress:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      result.add Event(eventType: MousePressed,
          button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of ButtonRelease:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      result.add Event(eventType: MouseReleased,
          button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of MotionNotify:
      let motion = cast[PXMotionEvent](addr(event))
      result.add Event(eventType: MouseMoved, x: motion.x, y: motion.y)
    of ConfigureNotify, Expose:
      result.add Event(eventType: ResizedWindow)
    else:
      discard
  # little hack to work around X11 auto-repeat keys
  for (serial, keys) in serials.pairs:
    for (key, events) in keys.pairs:
      if events.len == 1:
        result.add events[0]


proc getMousePosition*(window: NativeWindow): Option[Vec2f] =
  var
    root: x.Window
    win: x.Window
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

