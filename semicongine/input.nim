# Linux joystick: https://www.kernel.org/doc/Documentation/input/joystick-api.txt
# Windows joystick: https://learn.microsoft.com/en-us/windows/win32/xinput/getting-started-with-xinput
#
# API to define actions that are connected to user inputs
#
# Example:
#
# type
#   Action = enum
#     Jump
#     Left
#     Right
#
# AddAction(Jump, SpaceDown, Pressed) # trigger action
# AddAction(Left, Arrow, Down) # boolean action
# AddAction(Left, Joystick_Left, Axis) # axis action
#
#
#
#
# if Action(Jump).Triggered:
#   accel_y = 1
# if Action(Left).Active:
#   accel_y = 1
# if Action(Left).Value:
#   accel_y = 1


import ./core/vector
import ./events

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

var input*: Input

proc updateInputs*(events: seq[Event]): bool =
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

proc keyIsDown*(key: Key): bool = key in input.keyIsDown
proc keyWasPressed*(key: Key): bool = key in input.keyWasPressed
proc keyWasPressed*(): bool = input.keyWasPressed.len > 0
proc keyWasReleased*(key: Key): bool = key in input.keyWasReleased
proc mouseIsDown*(button: MouseButton): bool = button in input.mouseIsDown
proc mouseWasPressed*(): bool = input.mouseWasPressed.len > 0
proc mouseWasPressed*(button: MouseButton): bool = button in input.mouseWasPressed
proc mousePressedButtons*(): set[MouseButton] = input.mouseWasPressed
proc mouseWasReleased*(): bool = input.mouseWasReleased.len > 0
proc mouseWasReleased*(button: MouseButton): bool = button in input.mouseWasReleased
proc mouseReleasedButtons*(): set[MouseButton] = input.mouseWasReleased
proc mousePosition*(): Vec2f = input.mousePosition
proc mousePositionNormalized*(size: (int, int)): Vec2f =
  result.x = (input.mousePosition.x / float32(size[0])) * 2.0 - 1.0
  result.y = (input.mousePosition.y / float32(size[1])) * 2.0 - 1.0
proc mouseMove*(): auto = input.mouseMove
proc mouseWheel*(): auto = input.mouseWheel
proc windowWasResized*(): auto = input.windowWasResized
