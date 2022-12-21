import
  x11/xlib,
  x11/xutil,
  x11/keysym
import x11/x

import ../../events

import ./symkey_map

export keysym

var deleteMessage*: Atom

type
  NativeWindow* = object
    display*: PDisplay
    window*: Window

template checkXlibResult*(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Xlib error: " & astToStr(call) & " returned " & $value)

proc createWindow*(title: string): NativeWindow =
  checkXlibResult XInitThreads()
  let display = XOpenDisplay(nil)
  if display == nil:
    quit "Failed to open display"

  let
    screen = XDefaultScreen(display)
    rootWindow = XRootWindow(display, screen)
    foregroundColor = XBlackPixel(display, screen)
    backgroundColor = XWhitePixel(display, screen)

  let window = XCreateSimpleWindow(display, rootWindow, -1, -1, 800, 600, 0, foregroundColor, backgroundColor)
  checkXlibResult XSetStandardProperties(display, window, title, "window", 0, nil, 0, nil)
  checkXlibResult XSelectInput(display, window, ButtonPressMask or KeyPressMask or ExposureMask)
  checkXlibResult XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", XBool(false))
  checkXlibResult XSetWMProtocols(display, window, addr(deleteMessage), 1)

  return NativeWindow(display: display, window: window)

proc trash*(window: NativeWindow) =
  checkXlibResult window.display.XDestroyWindow(window.window)
  discard window.display.XCloseDisplay() # always returns 0

proc size*(window: NativeWindow): (int, int) =
  var attribs: XWindowAttributes
  checkXlibResult XGetWindowAttributes(window.display, window.window, addr(attribs))
  return (int(attribs.width), int(attribs.height))

proc pendingEvents*(window: NativeWindow): seq[Event] =
  var event: XEvent
  while window.display.XPending() > 0:
    discard window.display.XNextEvent(addr(event))
    case event.theType
    of ClientMessage:
      if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
        result.add(Event(eventType: Quit))
    of KeyPress:
      let xkey: KeySym = XLookupKeysym(cast[PXKeyEvent](addr(event)), 0)
      result.add(Event(eventType: KeyDown, key: KeyTypeMap.getOrDefault(xkey, UNKNOWN)))
    of KeyRelease:
      let xkey: KeySym = XLookupKeysym(cast[PXKeyEvent](addr(event)), 0)
      result.add(Event(eventType: KeyUp, key: KeyTypeMap.getOrDefault(xkey, UNKNOWN)))
    of ConfigureNotify:
      result.add(Event(eventType: ResizedWindow))
    else:
      discard
