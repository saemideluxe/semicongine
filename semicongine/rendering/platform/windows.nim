import std/tables
import std/options

import ../../thirdparty/winim/winim/inc/[windef, winuser, wincon, winbase]
import ../../thirdparty/winim/winim/[winstr, utils]

const REQUIRED_PLATFORM_EXTENSIONS = @["VK_KHR_win32_surface"]

const KeyTypeMap* = {
  VK_ESCAPE: Key.Escape,
  VK_F1: F1,
  VK_F2: F2,
  VK_F3: F3,
  VK_F4: F4,
  VK_F5: F5,
  VK_F6: F6,
  VK_F7: F7,
  VK_F8: F8,
  VK_F9: F9,
  VK_F10: F10,
  VK_F11: F11,
  VK_F12: F12,
  VK_OEM_3: NumberRowExtra1,
  int('0'): `0`,
  int('1'): `1`,
  int('2'): `2`,
  int('3'): `3`,
  int('4'): `4`,
  int('5'): `5`,
  int('6'): `6`,
  int('7'): `7`,
  int('8'): `8`,
  int('9'): `9`,
  VK_OEM_MINUS: NumberRowExtra2,
  VK_OEM_PLUS: NumberRowExtra3,
  int('A'): A,
  int('B'): Key.B,
  int('C'): C,
  int('D'): D,
  int('E'): E,
  int('F'): F,
  int('G'): Key.G,
  int('H'): H,
  int('I'): I,
  int('J'): J,
  int('K'): K,
  int('L'): Key.L,
  int('M'): M,
  int('N'): N,
  int('O'): Key.O,
  int('P'): P,
  int('Q'): Q,
  int('R'): Key.R,
  int('S'): S,
  int('T'): Key.T,
  int('U'): U,
  int('V'): V,
  int('W'): W,
  int('X'): Key.X,
  int('Y'): Key.Y,
  int('Z'): Key.Z,
  VK_TAB: Tab,
  VK_CAPITAL: CapsLock,
  VK_LSHIFT: ShiftL,
  VK_SHIFT: ShiftL,
  VK_RSHIFT: ShiftR,
  VK_LCONTROL: CtrlL,
  VK_CONTROL: CtrlL,
  VK_RCONTROL: CtrlR,
  VK_LWIN: SuperL,
  VK_RWIN: SuperR,
  VK_LMENU: AltL,
  VK_RMENU: AltR,
  VK_SPACE: Space,
  VK_RETURN: Enter,
  VK_BACK: Backspace,
  VK_OEM_4: LetterRow1Extra1,
  VK_OEM_6: LetterRow1Extra2,
  VK_OEM_5: LetterRow2Extra3,
  VK_OEM_1: LetterRow2Extra1,
  VK_OEM_7: LetterRow2Extra2,
  VK_OEM_COMMA: LetterRow3Extra1,
  VK_OEM_PERIOD: LetterRow3Extra2,
  VK_OEM_2: LetterRow3Extra3,
  VK_UP: Up,
  VK_DOWN: Down,
  VK_LEFT: Key.Left,
  VK_RIGHT: Key.Right,
  VK_PRIOR: PageUp,
  VK_NEXT: PageDown,
  VK_HOME: Home,
  VK_END: End,
  VK_INSERT: Insert,
  VK_DELETE: Key.Delete,
}.toTable

# sorry, have to use module-global variable to capture windows events
var currentEvents: seq[Event]

template checkWin32Result*(call: untyped) =
  let value = call
  if value == 0:
    raise
      newException(Exception, "Win32 error: " & astToStr(call) & " returned " & $value)

let
  andCursorMask = [0xff]
  xorCursorMask = [0x00]
  invisibleCursor = CreateCursor(
    0, 0, 0, 1, 1, pointer(addr andCursorMask), pointer(addr xorCursorMask)
  )
  defaultCursor = LoadCursor(0, IDC_ARROW)
var currentCursor = defaultCursor

proc mapLeftRightKeys(key: INT, lparam: LPARAM): INT =
  case key
  of VK_SHIFT:
    MapVirtualKey(UINT((lParam and 0x00ff0000) shr 16), MAPVK_VSC_TO_VK_EX)
  of VK_CONTROL:
    if (lParam and 0x01000000) == 0: VK_LCONTROL else: VK_RCONTROL
  of VK_MENU:
    if (lParam and 0x01000000) == 0: VK_LMENU else: VK_RMENU
  else:
    key

proc windowHandler(
    hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
): LRESULT {.stdcall.} =
  case uMsg
  of WM_DESTROY:
    currentEvents.add(Event(eventType: events.EventType.Quit))
  of WM_KEYDOWN, WM_SYSKEYDOWN:
    let key = mapLeftRightKeys(INT(wParam), lParam)
    currentEvents.add(
      Event(eventType: KeyPressed, key: KeyTypeMap.getOrDefault(key, Key.UNKNOWN))
    )
  of WM_KEYUP, WM_SYSKEYUP:
    let key = mapLeftRightKeys(INT(wParam), lParam)
    currentEvents.add(
      Event(eventType: KeyReleased, key: KeyTypeMap.getOrDefault(key, Key.UNKNOWN))
    )
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
  of WM_MOUSEWHEEL:
    currentEvents.add(
      Event(
        eventType: MouseWheel,
        amount: float32(GET_WHEEL_DELTA_WPARAM(wParam)) / WHEEL_DELTA,
      )
    )
  of WM_SIZING:
    currentEvents.add(Event(eventType: ResizedWindow))
  of WM_SIZE:
    if wParam == SIZE_MINIMIZED:
      currentEvents.add(Event(eventType: MinimizedWindow))
    elif wParam == SIZE_RESTORED:
      currentEvents.add(Event(eventType: RestoredWindow))
  of WM_SETFOCUS:
    currentEvents.add(Event(eventType: GotFocus))
  of WM_KILLFOCUS:
    currentEvents.add(Event(eventType: LostFocus))
  of WM_SETCURSOR:
    if LOWORD(lParam) == HTCLIENT:
      SetCursor(currentCursor)
      return 1
    else:
      return DefWindowProc(hwnd, uMsg, wParam, lParam)
  else:
    return DefWindowProc(hwnd, uMsg, wParam, lParam)

proc createWindow*(title: string): NativeWindow =
  when not defined(release):
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

proc setTitle*(window: NativeWindow, title: string) =
  window.hwnd.SetWindowText(T(title))

# inspired by the one and only, Raymond Chen
# https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14353
proc setFullscreen*(window: var NativeWindow, enable: bool) =
  let dwStyle: DWORD = GetWindowLong(window.hwnd, GWL_STYLE)
  if enable:
    var mi = MONITORINFO(cbSize: DWORD(sizeof(MONITORINFO)))
    if GetWindowPlacement(window.hwnd, addr window.g_wpPrev) and
        GetMonitorInfo(
          MonitorFromWindow(window.hwnd, MONITOR_DEFAULTTOPRIMARY), addr mi
        ):
      SetWindowLong(window.hwnd, GWL_STYLE, dwStyle and (not WS_OVERLAPPEDWINDOW))
      SetWindowPos(
        window.hwnd,
        HWND_TOP,
        mi.rcMonitor.left,
        mi.rcMonitor.top,
        mi.rcMonitor.right - mi.rcMonitor.left,
        mi.rcMonitor.bottom - mi.rcMonitor.top,
        SWP_NOOWNERZORDER or SWP_FRAMECHANGED,
      )
  else:
    SetWindowLong(window.hwnd, GWL_STYLE, dwStyle or WS_OVERLAPPEDWINDOW)
    SetWindowPlacement(window.hwnd, addr window.g_wpPrev)
    SetWindowPos(
      window.hwnd,
      HWND(0),
      0,
      0,
      0,
      0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOOWNERZORDER or SWP_FRAMECHANGED,
    )

proc showSystemCursor*(window: NativeWindow, value: bool) =
  if value == true:
    currentCursor = defaultCursor
    SetCursor(currentCursor)
  else:
    currentCursor = invisibleCursor
    SetCursor(currentCursor)

proc destroy*(window: NativeWindow) =
  discard

proc size*(window: NativeWindow): Vec2i =
  var rect: RECT
  discard GetClientRect(window.hwnd, addr(rect))
  vec2i(rect.right - rect.left, rect.bottom - rect.top)

proc pendingEvents*(window: NativeWindow): seq[Event] =
  # empty queue
  var msg: MSG
  # fill queue
  while PeekMessage(addr(msg), window.hwnd, 0, 0, PM_REMOVE):
    TranslateMessage(addr(msg))
    DispatchMessage(addr(msg))
  result = currentEvents
  currentEvents.setLen(0)

proc getMousePosition*(window: NativeWindow): Vec2i =
  var p: POINT
  discard GetCursorPos(addr(p))
  discard window.hwnd.ScreenToClient(addr(p))
  vec2i(p.x, p.y)

proc setMousePosition*(window: NativeWindow, pos: Vec2i) =
  var p = POINT(x: pos.x, y: pos.y)
  discard window.hwnd.ClientToScreen(addr(p))
  discard SetCursorPos(p.x, p.y)

proc createNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  assert instance.Valid
  var surfaceCreateInfo = VkWin32SurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    hinstance: cast[HINSTANCE](window.hinstance),
    hwnd: cast[HWND](window.hwnd),
  )
  checkVkResult vkCreateWin32SurfaceKHR(
    instance, addr(surfaceCreateInfo), nil, addr(result)
  )
