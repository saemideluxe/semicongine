import winim

import ../../events

type
  NativeWindow* = object
    hinstance*: HINSTANCE
    hwnd*: HWND

var currentEvents: seq[Event]

template checkWin32Result*(call: untyped) =
  let value = call
  if value != 0:
    raise newException(Exception, "Win32 error: " & astToStr(call) & " returned " & $value)

proc WindowHandler(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  case uMsg
  of WM_DESTROY:
    currentEvents.add(Event(eventType: events.EventType.Quit))
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

  discard ShowWindow(result.hwnd, 1)

proc trash*(window: NativeWindow) =
  discard

proc size*(window: NativeWindow): (int, int) =
  var rect: RECT
  checkWin32Result GetWindowRect(window.hwnd, addr(rect))
  (int(rect.right - rect.left), int(rect.bottom - rect.top))

proc pendingEvents*(window: NativeWindow): seq[Event] =
  currentEvents = newSeq[Event]()
  var msg: MSG
  while PeekMessage(addr(msg), window.hwnd, 0, 0, PM_REMOVE):
    DispatchMessage(addr(msg))
  return currentEvents