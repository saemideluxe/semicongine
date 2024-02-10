import std/unicode

import semicongine


proc main() =
  # setup engine
  var engine = initEngine("Test panels")
  engine.initRenderer([])

  # build scene
  var
    font = loadFont("DejaVuSans.ttf", lineHeightPixels = 210'f32)
    scene = Scene(name: "main")
    origin = initPanel(size = newVec2f(0.01, 0.01), color = newVec4f(0, 0, 0, 1))
    panel = initPanel(size = newVec2f(0.2, 0.2), color = newVec4f(1, 0, 0, 1))
    help_text = font.initText("""Controls

Horizontal alignment:
  F1: Left
  F2: Center
  F3: Right
Vertical alignment:
  F4: Top
  F5: Center
  F6: Bottom""", scale = 0.0002, position = newVec2f(-0.9, -0.9), horizontalAlignment = Left, verticalAlignment = Top)

  scene.add panel
  scene.add help_text
  scene.add origin
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      panel.aspect_ratio = winSize[0] / winSize[1]
      origin.aspect_ratio = winSize[0] / winSize[1]
      help_text.aspect_ratio = winSize[0] / winSize[1]

    if engine.keyWasPressed(F1): panel.horizontalAlignment = Left
    elif engine.keyWasPressed(F2): panel.horizontalAlignment = Center
    elif engine.keyWasPressed(F3): panel.horizontalAlignment = Right
    elif engine.keyWasPressed(F4): panel.verticalAlignment = Top
    elif engine.keyWasPressed(F5): panel.verticalAlignment = Center
    elif engine.keyWasPressed(F6): panel.verticalAlignment = Bottom

    panel.refresh()
    origin.refresh()
    help_text.refresh()

    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
