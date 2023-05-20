type
  EventType* = enum
    Quit
    ResizedWindow
    KeyPressed, KeyReleased
    MousePressed, MouseReleased, MouseMoved,
    MouseWheel
  Key* {.size: sizeof(cint), pure.} = enum
    UNKNOWN
    Escape, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12
    NumberRowExtra1, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `0`,
        NumberRowExtra2, NumberRowExtra3                 # tilde, minus, plus
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z
    Tab, CapsLock, ShiftL, ShiftR, CtrlL, CtrlR, SuperL, SuperR, AltL, AltR,
        Space, Enter, Backspace
    LetterRow1Extra1, LetterRow1Extra2 # open bracket, close brackt, backslash
    LetterRow2Extra1, LetterRow2Extra2, LetterRow2Extra3 # semicolon, quote
    LetterRow3Extra1, LetterRow3Extra2, LetterRow3Extra3 # comma, period, slash
    Up, Down, Left, Right
    PageUp, PageDown, Home, End, Insert, Delete
    PrintScreen, ScrollLock, Pause
  MouseButton* {.size: sizeof(cint), pure.} = enum
    UNKNOWN, Mouse1, Mouse2, Mouse3
  Event* = object
    case eventType*: EventType
    of KeyPressed, KeyReleased:
      key*: Key
    of MousePressed, MouseReleased:
      button*: MouseButton
    of MouseMoved:
      x*, y*: int
    of MouseWheel:
      amount*: float32
    else:
      discard
