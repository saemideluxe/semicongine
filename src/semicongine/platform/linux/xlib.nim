import
  x11/xlib,
  x11/xutil,
  x11/keysym,
  x11/xinput,
  x11/xinput2
import x11/x

import ../../events

import ./symkey_map

export keysym

var deleteMessage*: Atom

type
  NativeWindow* = object
    display*: PDisplay
    window*: Window
    emptyCursor: Cursor

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
  checkXlibResult XSelectInput(display, window, PointerMotionMask or ButtonPressMask or ButtonReleaseMask or KeyPressMask or KeyReleaseMask or ExposureMask)
  checkXlibResult XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", XBool(false))
  checkXlibResult XSetWMProtocols(display, window, addr(deleteMessage), 1)

  # quite a lot of work to hide the cursor...
  var data = "\0".cstring
  var pixmap = XCreateBitmapFromData(display, window, data, 1, 1)
  var color: XColor
  var empty_cursor = XCreatePixmapCursor(display, pixmap, pixmap, addr(color), addr(color), 0, 0)
  checkXlibResult XFreePixmap(display, pixmap)
  checkXlibResult XDefineCursor(display, window, empty_cursor)

  return NativeWindow(display: display, window: window, emptyCursor: empty_cursor)

proc trash*(window: NativeWindow) =
  checkXlibResult window.display.XFreeCursor(window.emptyCursor)
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
      let xkey = int(cast[PXKeyEvent](addr(event)).keycode)
      result.add Event(eventType: KeyPressed, key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN))
    of KeyRelease:
      let xkey = int(cast[PXKeyEvent](addr(event)).keycode)
      result.add Event(eventType: KeyReleased, key: KeyTypeMap.getOrDefault(xkey, Key.UNKNOWN))
    of ButtonPress:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      result.add Event(eventType: MousePressed, button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of ButtonRelease:
      let button = int(cast[PXButtonEvent](addr(event)).button)
      result.add Event(eventType: MouseReleased, button: MouseButtonTypeMap.getOrDefault(button, MouseButton.UNKNOWN))
    of MotionNotify:
      let motion = cast[PXMotionEvent](addr(event))
      result.add Event(eventType: MouseMoved, x: motion.x, y: motion.y)
    of ConfigureNotify:
      result.add Event(eventType: ResizedWindow)
    else:
      discard
