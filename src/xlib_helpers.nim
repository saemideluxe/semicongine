import
  x11/xlib,
  x11/xutil,
  x11/x,
  x11/keysym

export keysym

var deleteMessage*: Atom

template checkXlibResult*(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Xlib error: " & astToStr(call) & " returned " & $value)

proc xlibInit*(): (PDisplay, Window) =
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
  checkXlibResult XSetStandardProperties(display, window, "Nim X11", "window", 0, nil, 0, nil)
  checkXlibResult XSelectInput(display, window, ButtonPressMask or KeyPressMask or ExposureMask)
  checkXlibResult XMapWindow(display, window)

  deleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", XBool(false))
  checkXlibResult XSetWMProtocols(display, window, addr(deleteMessage), 1)

  return (display, window)

proc xlibFramebufferSize*(display: PDisplay, window: Window): (int, int) =
  var attribs: XWindowAttributes
  checkXlibResult XGetWindowAttributes(display, window, addr(attribs))
  return (int(attribs.width), int(attribs.height))
