import std/tables
export tables

import ../../thirdparty/winim/winim/core

import ../../events

const KeyTypeMap* = {
  VK_ESCAPE: Key.Escape, VK_F1: F1, VK_F2: F2, VK_F3: F3, VK_F4: F4, VK_F5: F5,
  VK_F6: F6, VK_F7: F7, VK_F8: F8, VK_F9: F9, VK_F10: F10, VK_F11: F11,
  VK_F12: F12,
  VK_OEM_3: NumberRowExtra1, int('0'): `0`, int('1'): `1`, int('2'): `2`, int(
      '3'): `3`, int('4'): `4`, int('5'): `5`, int('6'): `6`, int('7'): `7`,
      int('8'): `8`, int('9'): `9`, VK_OEM_MINUS: NumberRowExtra2,
      VK_OEM_PLUS: NumberRowExtra3,
  int('A'): A, int('B'): B, int('C'): C, int('D'): D, int('E'): E, int('F'): F,
      int('G'): G, int('H'): H, int('I'): I, int('J'): J, int('K'): K, int(
      'L'): L, int('M'): M, int('N'): N, int('O'): O, int('P'): P, int('Q'): Q,
      int('R'): R, int('S'): S, int('T'): T, int('U'): U, int('V'): V, int(
      'W'): W, int('X'): X, int('Y'): Y, int('Z'): Z,
  VK_TAB: Tab, VK_CAPITAL: CapsLock, VK_LSHIFT: ShiftL, VK_SHIFT: ShiftL,
      VK_RSHIFT: ShiftR, VK_LCONTROL: CtrlL, VK_CONTROL: CtrlL,
      VK_RCONTROL: CtrlR, VK_LWIN: SuperL, VK_RWIN: SuperR, VK_LMENU: AltL,
      VK_RMENU: AltR, VK_SPACE: Space, VK_RETURN: Enter, VK_BACK: Backspace,
  VK_OEM_4: LetterRow1Extra1, VK_OEM_6: LetterRow1Extra2,
      VK_OEM_5: LetterRow2Extra3,
  VK_OEM_1: LetterRow2Extra1, VK_OEM_7: LetterRow2Extra2,
  VK_OEM_COMMA: LetterRow3Extra1, VK_OEM_PERIOD: LetterRow3Extra2,
      VK_OEM_2: LetterRow3Extra3,
    VK_UP: Up, VK_DOWN: Down, VK_LEFT: Left, VK_RIGHT: Right,
    VK_PRIOR: PageUp, VK_NEXT: PageDown, VK_HOME: Home, VK_END: End,
        VK_INSERT: Insert, VK_DELETE: Key.Delete,
}.toTable
