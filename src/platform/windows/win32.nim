import winim

import ../../events

type
  NativeWindow* = object
    hinstance*: HINSTANCE
    hwnd*: HWND

template checkWin32Result*(call: untyped) =
  let value = call
  if value != 0:
    raise newException(Exception, "Win32 error: " & astToStr(call) & " returned " & $value)

proc WindowHandler(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  case uMsg
  of WM_DESTROY:
    discard
  else:
    return DefWindowProc(hwnd, uMsg, wParam, lParam)


proc createWindow*(title: string): NativeWindow =
  result.hInstance = HINSTANCE(GetModuleHandle(nil))
  var
    windowClassName = T"EngineWindowClass"
    windowName = T(title)
    windowClass = WNDCLASS(
      lpfnWndProc: WindowHandler,
      hInstance: result.hInstance,
      lpszClassName: windowClassName,
    )
  RegisterClass(addr(windowClass))

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

  discard ShowWindow(result.hwnd, 0)

proc trash*(window: NativeWindow) =
  PostQuitMessage(0)

proc size*(window: NativeWindow): (int, int) =
  var rect: RECT
  checkWin32Result GetWindowRect(window.hwnd, addr(rect))
  (int(rect.right - rect.left), int(rect.bottom - rect.top))

proc pendingEvents*(window: NativeWindow): seq[Event] =
  result
