import std/options
import std/tables
import std/strformat
import std/logging

import ../../thirdparty/x11/xlib
import ../../thirdparty/x11/xutil
import ../../thirdparty/x11/keysym
import ../../thirdparty/x11/x
import ../../thirdparty/x11/xkblib

import ../../core
import ../../events

import ./symkey_map

export keysym

var deleteMessage*: Atom

type
  NativeWindow* = object
    display*: ptr xlib.Display
    window*: x.Window
    emptyCursor: Cursor

template checkXlibResult(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Xlib error: " & astToStr(call) &
        " returned " & $value)

proc XErrorLogger(display: PDisplay, event: PXErrorEvent): cint {.cdecl.} =
  error &"Xlib: {event[]}"

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

proc SetTitle*(window: NativeWindow, title: string) =
  checkXlibResult XSetStandardProperties(window.display, window.window, title, "window", 0, nil, 0, nil)

proc Fullscreen*(window: var NativeWindow, enable: bool) =
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

proc HideSystemCursor*(window: NativeWindow) =
  checkXlibResult XDefineCursor(window.display, window.window, window.emptyCursor)
  checkXlibResult window.display.XFlush()

proc ShowSystemCursor*(window: NativeWindow) =
  checkXlibResult XUndefineCursor(window.display, window.window)
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
    of ConfigureNotify, Expose:
      result.add Event(eventType: ResizedWindow)
    else:
      discard


proc GetMousePosition*(window: NativeWindow): Option[Vec2f] =
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

