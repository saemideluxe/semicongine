# Linux joystick: https://www.kernel.org/doc/Documentation/input/joystick-api.txt
# Windows joystick: https://learn.microsoft.com/en-us/windows/win32/xinput/getting-started-with-xinput


import std/tables
import std/strutils

import ./core/vector
import ./events
import ./storage

type
  Input = object
    keyIsDown: set[Key]
    keyWasPressed: set[Key]
    keyWasReleased: set[Key]
    mouseIsDown: set[MouseButton]
    mouseWasPressed: set[MouseButton]
    mouseWasReleased: set[MouseButton]
    mousePosition: Vec2f
    mouseMove: Vec2f
    mouseWheel: float32
    windowWasResized: bool = true

# warning, shit is not thread safe
var input: Input

proc UpdateInputs*(events: seq[Event]): bool =
  # reset input states
  input.keyWasPressed = {}
  input.keyWasReleased = {}
  input.mouseWasPressed = {}
  input.mouseWasReleased = {}
  input.mouseWheel = 0
  input.mouseMove = newVec2f()
  input.windowWasResized = false

  var killed = false
  for event in events:
    case event.eventType:
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
      of MouseMoved:
        let newPos = newVec2(float32(event.x), float32(event.y))
        input.mouseMove = newPos - input.mousePosition
        input.mousePosition = newPos
      of MouseWheel:
        input.mouseWheel = event.amount
  return not killed

proc KeyIsDown*(key: Key): bool = key in input.keyIsDown
proc KeyWasPressed*(key: Key): bool = key in input.keyWasPressed
proc KeyWasPressed*(): bool = input.keyWasPressed.len > 0
proc KeyWasReleased*(key: Key): bool = key in input.keyWasReleased
proc MouseIsDown*(button: MouseButton): bool = button in input.mouseIsDown
proc MouseWasPressed*(): bool = input.mouseWasPressed.len > 0
proc MouseWasPressed*(button: MouseButton): bool = button in input.mouseWasPressed
proc MousePressedButtons*(): set[MouseButton] = input.mouseWasPressed
proc MouseWasReleased*(): bool = input.mouseWasReleased.len > 0
proc MouseWasReleased*(button: MouseButton): bool = button in input.mouseWasReleased
proc MouseReleasedButtons*(): set[MouseButton] = input.mouseWasReleased
proc MousePosition*(): Vec2f = input.mousePosition
proc MousePositionNormalized*(size: (int, int)): Vec2f =
  result.x = (input.mousePosition.x / float32(size[0])) * 2.0 - 1.0
  result.y = (input.mousePosition.y / float32(size[1])) * 2.0 - 1.0
proc MouseMove*(): auto = input.mouseMove
proc MouseWheel*(): auto = input.mouseWheel
proc WindowWasResized*(): auto = input.windowWasResized

# actions as a slight abstraction over raw input

type
  ActionMap = object
    keyActions: Table[string, set[Key]]
    mouseActions: Table[string, set[MouseButton]]

# warning, shit is not thread safe
var actionMap: ActionMap

proc MapAction*[T: enum](action: T, key: Key) =
  if not actionMap.keyActions.contains($action):
    actionMap.keyActions[$action] = {}
  actionMap.keyActions[$action].incl key

proc MapAction*[T: enum](action: T, button: MouseButton) =
  if not actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action] = {}
  actionMap.mouseActions[$action].incl button

proc MapAction*[T: enum](action: T, keys: openArray[Key|MouseButton]) =
  for key in keys:
    MapAction(action, key)

proc UnmapAction*[T: enum](action: T, key: Key) =
  if actionMap.keyActions.contains($action):
    actionMap.keyActions[$action].excl(key)

proc UnmapAction*[T: enum](action: T, button: MouseButton) =
  if actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action].excl(button)

proc UnmapAction*[T: enum](action: T) =
  if actionMap.keyActions.contains($action):
    actionMap.keyActions[$action] = {}
  if actionMap.mouseActions.contains($action):
    actionMap.mouseActions[$action] = {}

proc SaveCurrentActionMapping*() =
  for name, keys in actionMap.keyActions.pairs:
    SystemStorage.store(name, keys, table = "input_mapping_key")
  for name, buttons in actionMap.mouseActions.pairs:
    SystemStorage.store(name, buttons, table = "input_mapping_mouse")

proc LoadActionMapping*[T]() =
  reset(actionMap)
  for name in SystemStorage.list(table = "input_mapping_key"):
    let action = parseEnum[T](name)
    let keys = SystemStorage.load(name, set[Key](), table = "input_mapping_key")
    for key in keys:
      MapAction(action, key)

proc ActionDown*[T](action: T): bool =
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

proc ActionPressed*[T](action: T): bool =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyWasPressed:
        return true
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseWasPressed:
        return true

proc ActionReleased*[T](action: T): bool =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyWasReleased:
        return true
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseWasReleased:
        return true

proc ActionValue*[T](action: T): float32 =
  if actionMap.keyActions.contains($action):
    for key in actionMap.keyActions[$action]:
      if key in input.keyIsDown:
        return 1
  elif actionMap.mouseActions.contains($action):
    for button in actionMap.mouseActions[$action]:
      if button in input.mouseIsDown:
        return 1
