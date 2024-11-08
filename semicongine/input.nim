import std/strutils
import std/tables

import ./core
import ./events
import ./rendering
import ./storage

type Input = object
  keyIsDown: set[Key]
  keyWasPressed: set[Key]
  keyWasReleased: set[Key]
  mouseIsDown: set[MouseButton]
  mouseWasPressed: set[MouseButton]
  mouseWasReleased: set[MouseButton]
  mousePosition: Vec2i
  mouseMove: Vec2i
  mouseWheel: float32
  windowWasResized: bool = true
  windowIsMinimized: bool = false
  lockMouse: bool = false
  hasFocus: bool = false

# warning, shit is not thread safe
var input = Input()

proc updateInputs*(): bool =
  # reset input states
  input.keyWasPressed = {}
  input.keyWasReleased = {}
  input.mouseWasPressed = {}
  input.mouseWasReleased = {}
  input.mouseWheel = 0
  input.mouseMove = vec2i(0, 0)
  input.windowWasResized = false

  let newMousePos = getMousePosition(vulkan.window)
  input.mouseMove = newMousePos - input.mousePosition
  if input.lockMouse and input.hasFocus:
    input.mousePosition = vulkan.window.size div 2
    setMousePosition(vulkan.window, input.mousePosition)
  else:
    input.mousePosition = newMousePos

  var killed = false
  for event in vulkan.window.pendingEvents():
    case event.eventType
    of Quit:
      killed = true
    of ResizedWindow:
      input.windowWasResized = true
    of KeyPressed:
      input.keyWasPressed.incl event.key
      input.keyIsDown.incl event.key
    of KeyReleased:
      input.keyWasReleased.incl event.key
      input.keyIsDown.excl event.key
    of MousePressed:
      input.mouseWasPressed.incl event.button
      input.mouseIsDown.incl event.button
    of MouseReleased:
      input.mouseWasReleased.incl event.button
      input.mouseIsDown.excl event.button
    of MouseWheel:
      input.mouseWheel = event.amount
    of MinimizedWindow:
      input.windowIsMinimized = true
    of RestoredWindow:
      input.windowIsMinimized = false
    of GotFocus:
      input.hasFocus = true
    of LostFocus:
      input.hasFocus = false

  return not killed

proc keyIsDown*(key: Key): bool =
  key in input.keyIsDown

proc keyWasPressed*(key: Key): bool =
  key in input.keyWasPressed

proc keyWasPressed*(): bool =
  input.keyWasPressed.len > 0

proc keyWasReleased*(key: Key): bool =
  key in input.keyWasReleased

proc mouseIsDown*(button: MouseButton): bool =
  button in input.mouseIsDown

proc mouseWasPressed*(): bool =
  input.mouseWasPressed.len > 0

proc mouseWasPressed*(button: MouseButton): bool =
  button in input.mouseWasPressed

proc mousePressedButtons*(): set[MouseButton] =
  input.mouseWasPressed

proc mouseWasReleased*(): bool =
  input.mouseWasReleased.len > 0

proc mouseWasReleased*(button: MouseButton): bool =
  button in input.mouseWasReleased

proc mouseReleasedButtons*(): set[MouseButton] =
  input.mouseWasReleased

proc mousePositionPixel*(): Vec2i =
  input.mousePosition

proc mousePosition*(): Vec2f =
  result = input.mousePosition.f32 / vulkan.window.size().f32 * 2.0'f32 - 1.0'f32
  result.y = result.y * -1

proc mouseMove*(): Vec2i =
  input.mouseMove

proc mouseWheel*(): float32 =
  input.mouseWheel

proc windowWasResized*(): auto =
  input.windowWasResized

proc windowIsMinimized*(): auto =
  input.windowIsMinimized

proc lockMouse*(value: bool) =
  input.lockMouse = value

proc hasFocus*(): bool =
  input.hasFocus

# actions as a slight abstraction over raw input

type ActionMap = object
  keyActions: Table[string, set[Key]]
  mouseActions: Table[string, set[MouseButton]]

# warning, shit is not thread safe
var actionMap: ActionMap

proc mapAction*[T: enum](action: T, key: Key) =
  if not actionMap.keyActions.contains($action):
    actionMap.keyActions[$action] = {}
  actionMap.keyActions[$action].incl key

proc mapAction*[T: enum](action: T, button: MouseButton) =
  if not actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action] = {}
  actionMap.mouseActions[$action].incl button

proc mapAction*[T: enum](action: T, keys: openArray[Key | MouseButton]) =
  for key in keys:
    mapAction(action, key)

proc unmapAction*[T: enum](action: T, key: Key) =
  if actionMap.keyActions.contains($action):
    actionMap.keyActions[$action].excl(key)

proc unmapAction*[T: enum](action: T, button: MouseButton) =
  if actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action].excl(button)

proc unmapAction*[T: enum](action: T) =
  if actionMap.keyActions.contains($action):
    actionMap.keyActions[$action] = {}
  if actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action] = {}

proc saveCurrentActionMapping*() =
  for name, keys in actionMap.keyActions.pairs:
    SystemStorage.store(name, keys, table = "input_mapping_key")
  for name, buttons in actionMap.mouseActions.pairs:
    SystemStorage.store(name, buttons, table = "input_mapping_mouse")

proc loadActionMapping*[T]() =
  reset(actionMap)
  for name in SystemStorage.List(table = "input_mapping_key"):
    let action = parseEnum[T](name)
    let keys = SystemStorage.Load(name, set[Key](), table = "input_mapping_key")
    for key in keys:
      mapAction(action, key)

proc actionDown*[T](action: T): bool =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyIsDown:
        return true
    return false
  if actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseIsDown:
        return true
    return false

proc actionPressed*[T](action: T): bool =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyWasPressed:
        return true
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseWasPressed:
        return true

proc actionReleased*[T](action: T): bool =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyWasReleased:
        return true
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseWasReleased:
        return true

proc actionValue*[T](action: T): float32 =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyIsDown:
        return 1
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseIsDown:
        return 1
