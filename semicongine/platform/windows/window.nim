import std/options

import ../../thirdparty/winim/winim

import ../../core/vector
import ../../core/buildconfig
import ./virtualkey_map
import ../../events

type
  NativeWindow* = object
    hinstance*: HINSTANCE
    hwnd*: HWND
    g_wpPrev: WINDOWPLACEMENT


# sorry, have to use module-global variable to capture windows events
var currentEvents: seq[Event]

template CheckWin32Result*(call: untyped) =
  let value = call
  if value == 0:
    raise newException(Exception, "Win32 error: " & astToStr(call) & " returned " & $value)

let andCursorMask = [0xff]
let xorCursorMask = [0x00]
let invisibleCursor = CreateCursor(HINSTANCE(0), 0, 0, 1, 1, pointer(addr andCursorMask), pointer(addr xorCursorMask))

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
  of WM_MOUSEWHEEL:
    currentEvents.add(Event(eventType: events.MouseWheel, amount: float32(GET_WHEEL_DELTA_WPARAM(wParam)) / WHEEL_DELTA))
  of WM_SETCURSOR:
    if LOWORD(lParam) == HTCLIENT:
      SetCursor(invisibleCursor)
      return 0
  else:
    return DefWindowProc(hwnd, uMsg, wParam, lParam)


proc CreateWindow*(title: string): NativeWindow =
  when DEBUG:
    AllocConsole()
    discard stdin.reopen("conIN$", fmRead)
    discard stdout.reopen("conOUT$", fmWrite)
    discard stderr.reopen("conOUT$", fmWrite)

  result.hInstance = HINSTANCE(GetModuleHandle(nil))
  var
    windowClassName = T"EngineWindowClass"
    windowName = T(title)
    windowClass = WNDCLASSEX(
      cbSize: UINT(WNDCLASSEX.sizeof),
      lpfnWndProc: WindowHandler,
      hInstance: result.hInstance,
      lpszClassName: windowClassName,
      # hcursor: LoadCursor(HINSTANCE(0), IDC_ARROW),
      hcursor: invisibleCursor,
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

  result.g_wpPrev.length = UINT(sizeof(WINDOWPLACEMENT))
  discard result.hwnd.ShowWindow(SW_SHOW)

proc SetTitle*(window: NativeWindow, title: string) =
  window.hwnd.SetWindowText(T(title))

# inspired by the one and only, Raymond Chen
# https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14353
proc Fullscreen*(window: var NativeWindow, enable: bool) =
  let dwStyle: DWORD = GetWindowLong(window.hwnd, GWL_STYLE)
  if enable:
    var mi = MONITORINFO(cbSize: DWORD(sizeof(MONITORINFO)))
    if GetWindowPlacement(window.hwnd, addr window.g_wpPrev) and GetMonitorInfo(MonitorFromWindow(window.hwnd, MONITOR_DEFAULTTOPRIMARY), addr mi):
      SetWindowLong(window.hwnd, GWL_STYLE, dwStyle and (not WS_OVERLAPPEDWINDOW))
      SetWindowPos(window.hwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top, SWP_NOOWNERZORDER or SWP_FRAMECHANGED)
  else:
    SetWindowLong(window.hwnd, GWL_STYLE, dwStyle or WS_OVERLAPPEDWINDOW)
    SetWindowPlacement(window.hwnd, addr window.g_wpPrev)
    SetWindowPos(window.hwnd, HWND(0), 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOOWNERZORDER or SWP_FRAMECHANGED)

proc HideSystemCursor*(window: NativeWindow) =
  discard
  # discard ShowCursor(false)

proc ShowSystemCursor*(window: NativeWindow) =
  discard
  # discard ShowCursor(true)

proc Destroy*(window: NativeWindow) =
  discard

proc Size*(window: NativeWindow): (int, int) =
  var rect: RECT
  CheckWin32Result GetWindowRect(window.hwnd, addr(rect))
  (int(rect.right - rect.left), int(rect.bottom - rect.top))

proc PendingEvents*(window: NativeWindow): seq[Event] =
  # empty queue
  currentEvents = newSeq[Event]()
  var msg: MSG
  # fill queue
  while PeekMessage(addr(msg), window.hwnd, 0, 0, PM_REMOVE):
    TranslateMessage(addr(msg))
    DispatchMessage(addr(msg))
  return currentEvents

proc GetMousePosition*(window: NativeWindow): Option[Vec2f] =
  var p: POINT
  let res = GetCursorPos(addr(p))
  if res:
    return some(Vec2f([float32(p.x), float32(p.y)]))
  return none(Vec2f)
