import std/unicode

import semicongine

var counter = 0
var counterText: Text

proc click(panel: var Panel, buttons: set[MouseButton]) =
  if buttons.contains(Mouse1):
    counter.inc
  if buttons.contains(Mouse3):
    counter.dec
  counterText.text = $counter
proc enter(panel: var Panel) =
  panel.mesh.transform = panel.mesh.transform * scale(1.05, 1.05)
  panel.color = newVec4f(1, 0, 0, 0.3)
proc leave(panel: var Panel) =
  panel.mesh.transform = panel.mesh.transform * scale(1 / 1.05, 1 / 1.05)
  panel.color = newVec4f(1, 0, 0, 0.5)

proc main() =
  # setup engine
  var engine = initEngine("Test panels")
  engine.initRenderer([])

  const B = [0'u8, 0'u8, 0'u8, 255'u8]
  const T = [0'u8, 0'u8, 0'u8, 0'u8]
  # build scene
  #
  var
    font = loadFont("DejaVuSans.ttf", lineHeightPixels = 210'f32)
    scene = Scene(name: "main")
    origin = initPanel(
      transform = scale(0.005, 0.005),
      color = newVec4f(1, 1, 1, 1),
      texture = Texture(isGrayscale: false, colorImage: newImage[RGBAPixel](3, 3, [T, B, T, B, B, B, T, B, T]), sampler: NEAREST_SAMPLER),
    )
    button = initPanel(
      transform = translate(0.2, 0.1) * scale(0.3, 0.1),
      color = newVec4f(1, 0, 0, 0.5),
      onMouseDown = click,
      onMouseEnter = enter,
      onMouseLeave = leave
    )
    help_text = font.initText("""Controls

Horizontal alignment:
  F1: Left
  F2: Center
  F3: Right
Vertical alignment:
  F4: Top
  F5: Center
  F6: Bottom
Mouse:
  Left click: Increase counter
  Right click: Decrease counter""".toRunes, horizontalAlignment = Left, verticalAlignment = Top, transform = translate(-0.9, -0.9) * scale(0.0002, 0.0002))

  counterText = font.initText(($counter).toRunes, maxLen = 99, transform = translate(0.2, 0.1) * scale(0.0004, 0.0004))

  scene.add counterText
  scene.add button
  scene.add help_text
  scene.add origin
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.keyWasPressed(F1):
      button.horizontalAlignment = Left
      counterText.horizontalAlignment = Left
    elif engine.keyWasPressed(F2):
      button.horizontalAlignment = Center
      counterText.horizontalAlignment = Center
    elif engine.keyWasPressed(F3):
      button.horizontalAlignment = Right
      counterText.horizontalAlignment = Right
    elif engine.keyWasPressed(F4):
      button.verticalAlignment = Top
      counterText.verticalAlignment = Top
    elif engine.keyWasPressed(F5):
      button.verticalAlignment = Center
      counterText.verticalAlignment = Center
    elif engine.keyWasPressed(F6):
      button.verticalAlignment = Bottom
      counterText.verticalAlignment = Bottom

    engine.processEvents(button)

    button.refresh()
    counterText.refresh()
    origin.refresh()
    help_text.refresh()

    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
