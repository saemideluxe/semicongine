import std/tables
export tables

import x11/keysym
# import x11/x

import ../../events

const KeyTypeMap* = {
  XK_A: A, XK_B: B, XK_C: C, XK_D: D, XK_E: E, XK_F: F, XK_G: G, XK_H: H, XK_I: I, XK_J: J, XK_K: K, XK_L: L, XK_M: M, XK_N: N, XK_O: O, XK_P: P, XK_Q: Q, XK_R: R, XK_S: S, XK_T: T, XK_U: U, XK_V: V, XK_W: W, XK_X: X, XK_Y: Y, XK_Z: Z,
  XK_a: a, XK_b: b, XK_c: c, XK_d: d, XK_e: e, XK_f: f, XK_g: g, XK_h: h, XK_i: i, XK_j: j, XK_k: k, XK_l: l, XK_m: m, XK_n: n, XK_o: o, XK_p: p, XK_q: q, XK_r: r, XK_s: s, XK_t: t, XK_u: u, XK_v: v, XK_w: w, XK_x: Key.x, XK_y: y, XK_z: z,
  XK_1: `1`, XK_2: `2`, XK_3: `3`, XK_4: `4`, XK_5: `5`, XK_6: `6`, XK_7: `7`, XK_8: `8`, XK_9: `9`, XK_0: `0`,
  XK_minus: Minus, XK_plus: Plus, XK_underscore: Underscore, XK_equal: Equals, XK_space: Space, XK_Return: Enter, XK_BackSpace: Backspace, XK_Tab: Tab,
  XK_comma: Comma, XK_period: Period, XK_semicolon: Semicolon, XK_colon: Colon,
  XK_Escape: Escape, XK_Control_L: CtrlL, XK_Shift_L: ShirtL, XK_Alt_L: AltL, XK_Control_R: CtrlR, XK_Shift_R: ShirtR, XK_Alt_R: AltR
}.toTable
