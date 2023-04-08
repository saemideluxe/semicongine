import std/options
import winim

import ./virtualkey_map
import ../../events
import ../../math/vector

type
  NativeWindow* = object
    hinstance*: HINSTANCE
    hwnd*: HWND

# sorry, have to use module-global variable to capture windows events
var currentEvents: seq[Event]

template checkWin32Result*(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Win32 error: " & astToStr(call) & " returned " & $value)


proc MapLeftRightKeys(key: INT, lparam: LPARAM): INT =
  case key
  of VK_SHIFT:
    MapVirtualKey(UINT((lParam and 0x00ff0000) shr 16), MAPVK_VSC_TO_VK_EX)
  of VK_CONTROL:
    if (lParam and 0x01000000) == 0: VK_LCONTROL else: VK_RCONTROL
  of VK_MENU:
    if (lParam and 0x01000000) == 0: VK_LMENU else: VK_RMENU
  else:
    key

proc WindowHandler(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  case uMsg
  of WM_DESTROY:
    currentEvents.add(Event(eventType: events.EventType.Quit))
  of WM_KEYDOWN, WM_SYSKEYDOWN:
    let key = MapLeftRightKeys(INT(wParam), lParam)
    currentEvents.add(Event(eventType: KeyPressed, key: KeyTypeMap.getOrDefault(key, Key.UNKNOWN)))
  of WM_KEYUP, WM_SYSKEYUP:
    let key = MapLeftRightKeys(INT(wParam), lParam)
    currentEvents.add(Event(eventType: KeyReleased, key: KeyTypeMap.getOrDefault(key, Key.UNKNOWN)))
  of WM_LBUTTONDOWN:
    currentEvents.add(Event(eventType: MousePressed, button: MouseButton.Mouse1))
  of WM_LBUTTONUP:
    currentEvents.add(Event(eventType: MouseReleased, button: MouseButton.Mouse1))
  of WM_MBUTTONDOWN:
    currentEvents.add(Event(eventType: MousePressed, button: MouseButton.Mouse2))
  of WM_MBUTTONUP:
    currentEvents.add(Event(eventType: MouseReleased, button: MouseButton.Mouse2))
  of WM_RBUTTONDOWN:
    currentEvents.add(Event(eventType: MousePressed, button: MouseButton.Mouse3))
  of WM_RBUTTONUP:
    currentEvents.add(Event(eventType: MouseReleased, button: MouseButton.Mouse3))
  of WM_MOUSEMOVE:
    currentEvents.add(Event(eventType: events.MouseMoved, x: GET_X_LPARAM(lParam), y: GET_Y_LPARAM(lParam)))
  else:
    return DefWindowProc(hwnd, uMsg, wParam, lParam)


proc createWindow*(title: string): NativeWindow =
  result.hInstance = HINSTANCE(GetModuleHandle(nil))
  var
    windowClassName = T"EngineWindowClass"
    windowName = T(title)
    windowClass = WNDCLASSEX(
      cbSize: UINT(WNDCLASSEX.sizeof),
      lpfnWndProc: WindowHandler,
      hInstance: result.hInstance,
      lpszClassName: windowClassName,
    )
  
  if(RegisterClassEx(addr(windowClass)) == 0):
    raise newException(Exception, "Unable to register window class")

  result.hwnd = CreateWindowEx(
      DWORD(0),
      windowClassName,
      windowName,
      DWORD(WS_OVERLAPPEDWINDOW),
      CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
      HMENU(0),
      HINSTANCE(0),
      result.hInstance,
      nil
    )

  discard ShowWindow(result.hwnd, SW_SHOW)
  discard ShowCursor(false)

proc destroy*(window: NativeWindow) =
  discard

proc size*(window: NativeWindow): (int, int) =
  var rect: RECT
  checkWin32Result GetWindowRect(window.hwnd, addr(rect))
  (int(rect.right - rect.left), int(rect.bottom - rect.top))

proc pendingEvents*(window: NativeWindow): seq[Event] =
  # empty queue
  currentEvents = newSeq[Event]()
  var msg: MSG
  # fill queue
  while PeekMessage(addr(msg), window.hwnd, 0, 0, PM_REMOVE):
    TranslateMessage(addr(msg))
    DispatchMessage(addr(msg))
  return currentEvents

proc getMousePosition*(window: NativeWindow): Option[Vec2f] =
  var p: POINT
  let res = GetCursorPos(addr(p))
  if res:
    return some(Vec2f([float32(p.x), float32(p.y)]))
  return none(Vec2f)
