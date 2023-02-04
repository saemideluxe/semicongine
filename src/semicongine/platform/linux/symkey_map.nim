import std/tables
export tables

import x11/x


import ../../events

# got values (keycodes) from xev
const KeyTypeMap* = {
  9: Escape, 67: F1, 68: F2, 69: F3, 70: F4, 71: F5, 72: F6, 73: F7, 74: F8,
  75: F9, 76: F10, 95: F11, 96: F12,
  49: NumberRowExtra1, 10: `1`, 11: `2`, 12: `3`, 13: `4`, 14: `5`, 15: `6`,
  16: `7`, 17: `8`, 18: `9`, 19: `0`, 20: NumberRowExtra2, 21: NumberRowExtra3,
  24: Q, 25: W, 26: E, 27: R, 28: T, 29: Y, 30: U, 31: I, 32: O, 33: P, 38: A,
  39: S, 40: D, 41: Key.F, 42: G, 43: H, 44: J, 45: K, 46: L, 52: Z, 53: X,
  54: C, 55: V, 56: B, 57: N, 58: M,

  23: Tab, 66: CapsLock, 50: ShiftL, 62: ShiftR, 37: CtrlL, 105: CtrlR,
  133: SuperL, 134: SuperR,
  64: AltL, 108: AltR,
  65: Space, 36: Enter, 22: Backspace,
  34: LetterRow1Extra1, 35: LetterRow1Extra2,
  47: LetterRow2Extra1, 48: LetterRow2Extra2, 51: LetterRow2Extra3,
  59: LetterRow3Extra1, 60: LetterRow3Extra2, 61: LetterRow3Extra3,
  111: Up, 116: Down, 113: Left, 114: Right,
  112: PageUp, 117: PageDown, 110: Home, 115: End, 118: Insert, 119: Delete,
  107: PrintScreen, 78: ScrollLock, 127: Pause,
}.toTable

const MouseButtonTypeMap* = {
  Button1: MouseButton.Mouse1,
  Button2: MouseButton.Mouse2,
  Button3: MouseButton.Mouse3,
}.toTable
