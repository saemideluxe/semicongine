import std/strutils
import std/unicode
import std/tables

import ./core
import ./rendering
import ./storage

proc updateInputs*(readChars: bool = false): bool =
  # in order to prevent key-events to generate while the program
  # is reading text-input from the keyboard, set `readChars` to true

  # reset input states
  engine().input.keyWasPressed = {}
  engine().input.keyWasReleased = {}
  engine().input.mouseWasPressed = {}
  engine().input.mouseWasReleased = {}
  engine().input.mouseWheel = 0
  engine().input.mouseMove = vec2i(0, 0)
  engine().input.windowWasResized = false
  engine().input.characterInput = default(Rune)

  let newMousePos = getMousePosition(engine().vulkan.window)
  engine().input.mouseMove = newMousePos - engine().input.mousePosition
  if engine().input.lockMouse and engine().input.hasFocus:
    engine().input.mousePosition = engine().vulkan.window.size div 2
    setMousePosition(engine().vulkan.window, engine().input.mousePosition)
  else:
    engine().input.mousePosition = newMousePos

  proc isControlChar(r: Rune): bool =
    (0x00'i32 <= int32(r) and int32(r) <= 0x1F'i32) or int(r) == 0x7f

  var killed = false
  for event in engine().vulkan.window.pendingEvents():
    case event.eventType
    of Quit:
      killed = true
    of ResizedWindow:
      engine().input.windowWasResized = true
    of KeyPressed:
      # exclude control characters for text input
      if readChars and not event.char.isControlChar():
        engine().input.characterInput = event.char
      else:
        engine().input.keyWasPressed.incl event.key
        engine().input.keyIsDown.incl event.key
    of KeyReleased:
      if not readChars or event.char.isControlChar():
        engine().input.keyWasReleased.incl event.key
        engine().input.keyIsDown.excl event.key
    of MousePressed:
      engine().input.mouseWasPressed.incl event.button
      engine().input.mouseIsDown.incl event.button
    of MouseReleased:
      engine().input.mouseWasReleased.incl event.button
      engine().input.mouseIsDown.excl event.button
    of MouseWheel:
      engine().input.mouseWheel = event.amount
    of MinimizedWindow:
      engine().input.windowIsMinimized = true
    of RestoredWindow:
      engine().input.windowIsMinimized = false
    of GotFocus:
      engine().input.hasFocus = true
    of LostFocus:
      engine().input.hasFocus = false

  return not killed

proc keyIsDown*(key: Key): bool =
  key in engine().input.keyIsDown

proc keyWasPressed*(key: Key): bool =
  key in engine().input.keyWasPressed

proc keyWasPressed*(): bool =
  engine().input.keyWasPressed.len > 0

proc keyWasReleased*(key: Key): bool =
  key in engine().input.keyWasReleased

proc characterInput*(): Rune =
  engine().input.characterInput

proc mouseIsDown*(button: MouseButton): bool =
  button in engine().input.mouseIsDown

proc mouseWasPressed*(): bool =
  engine().input.mouseWasPressed.len > 0

proc mouseWasPressed*(button: MouseButton): bool =
  button in engine().input.mouseWasPressed

proc mousePressedButtons*(): set[MouseButton] =
  engine().input.mouseWasPressed

proc mouseWasReleased*(): bool =
  engine().input.mouseWasReleased.len > 0

proc mouseWasReleased*(button: MouseButton): bool =
  button in engine().input.mouseWasReleased

proc mouseReleasedButtons*(): set[MouseButton] =
  engine().input.mouseWasReleased

proc mousePositionPixel*(): Vec2i =
  engine().input.mousePosition

proc mousePosition*(): Vec2f =
  result =
    engine().input.mousePosition.f32 / engine().vulkan.window.size().f32 * 2.0'f32 -
    1.0'f32
  result.y = result.y * -1

proc mouseMove*(): Vec2i =
  engine().input.mouseMove

proc mouseWheel*(): float32 =
  engine().input.mouseWheel

proc windowWasResized*(): auto =
  engine().input.windowWasResized

proc windowIsMinimized*(): auto =
  engine().input.windowIsMinimized

proc lockMouse*(value: bool) =
  engine().input.lockMouse = value

proc hasFocus*(): bool =
  engine().input.hasFocus

# actions as a slight abstraction over raw input

proc mapAction*[T: enum](action: T, key: Key) =
  if not engine().actionMap.keyActions.contains($action):
    engine().actionMap.keyActions[$action] = {}
  engine().actionMap.keyActions[$action].incl key

proc mapAction*[T: enum](action: T, button: MouseButton) =
  if not engine().actionMap.mouseActions.contains($action):
    engine().actionMap.mouseActions[$action] = {}
  engine().actionMap.mouseActions[$action].incl button

proc mapAction*[T: enum](action: T, keys: openArray[Key | MouseButton]) =
  for key in keys:
    mapAction(action, key)

proc unmapAction*[T: enum](action: T, key: Key) =
  if engine().actionMap.keyActions.contains($action):
    engine().actionMap.keyActions[$action].excl(key)

proc unmapAction*[T: enum](action: T, button: MouseButton) =
  if engine().actionMap.mouseActions.contains($action):
    engine().actionMap.mouseActions[$action].excl(button)

proc unmapAction*[T: enum](action: T) =
  if engine().actionMap.keyActions.contains($action):
    engine().actionMap.keyActions[$action] = {}
  if engine().actionMap.mouseActions.contains($action):
    engine().actionMap.mouseActions[$action] = {}

proc saveCurrentActionMapping*() =
  for name, keys in engine().actionMap.keyActions.pairs:
    SystemStorage.store(name, keys, table = "input_mapping_key")
  for name, buttons in engine().actionMap.mouseActions.pairs:
    SystemStorage.store(name, buttons, table = "input_mapping_mouse")

proc loadActionMapping*[T]() =
  reset(engine().actionMap)
  for name in SystemStorage.List(table = "input_mapping_key"):
    let action = parseEnum[T](name)
    let keys = SystemStorage.Load(name, set[Key](), table = "input_mapping_key")
    for key in keys:
      mapAction(action, key)

proc actionDown*[T](action: T): bool =
  if engine().actionMap.keyActions.contains($action):
    for key in engine().actionMap.keyActions[$action]:
      if key in engine().input.keyIsDown:
        return true
    return false
  if engine().actionMap.mouseActions.contains($action):
    for button in engine().actionMap.mouseActions[$action]:
      if button in engine().input.mouseIsDown:
        return true
    return false

proc actionPressed*[T](action: T): bool =
  if engine().actionMap.keyActions.contains($action):
    for key in engine().actionMap.keyActions[$action]:
      if key in engine().input.keyWasPressed:
        return true
  elif engine().actionMap.mouseActions.contains($action):
    for button in engine().actionMap.mouseActions[$action]:
      if button in engine().input.mouseWasPressed:
        return true

proc actionReleased*[T](action: T): bool =
  if engine().actionMap.keyActions.contains($action):
    for key in engine().actionMap.keyActions[$action]:
      if key in engine().input.keyWasReleased:
        return true
  elif engine().actionMap.mouseActions.contains($action):
    for button in engine().actionMap.mouseActions[$action]:
      if button in engine().input.mouseWasReleased:
        return true

proc actionValue*[T](action: T): float32 =
  if engine().actionMap.keyActions.contains($action):
    for key in engine().actionMap.keyActions[$action]:
      if key in engine().input.keyIsDown:
        return 1
  elif engine().actionMap.mouseActions.contains($action):
    for button in engine().actionMap.mouseActions[$action]:
      if button in engine().input.mouseIsDown:
        return 1
