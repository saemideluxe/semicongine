import std/unicode

import semicongine


proc main() =
  # setup engine
  var engine = initEngine("Test fonts")
  engine.initRenderer([])

  # build scene
  var scene = Scene(name: "main")
  # var font = loadFont("DejaVuSans.ttf", lineHeightPixels=90'f32, charset="abcdefghijklmnopqrstuvwxyz ".toRunes)
  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 210'f32)
  var main_text = font.initText("", 32, color = newVec4f(1, 0.15, 0.15, 1), scale = 0.001)
  var help_text = font.initText("""Controls

Horizontal alignment:
  F1: Left
  F2: Center
  F3: Right
Vertical alignment:
  F4: Top
  F5: Center
  F6: Bottom""", scale = 0.0001, position = newVec2f(0, 0), horizontalAlignment = Left, verticalAlignment = Top)
  scene.add main_text
  scene.add help_text
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      main_text.aspect_ratio = winSize[0] / winSize[1]
      help_text.aspect_ratio = winSize[0] / winSize[1]
      help_text.position = newVec2f(-0.99, -0.99)

    # add character
    if main_text.text.len < main_text.maxLen - 1:
      for c in [Key.A, Key.B, Key.C, Key.D, Key.E, Key.F, Key.G, Key.H, Key.I,
          Key.J, Key.K, Key.L, Key.M, Key.N, Key.O, Key.P, Key.Q, Key.R, Key.S,
          Key.T, Key.U, Key.V, Key.W, Key.X, Key.Y, Key.Z]:
        if engine.keyWasPressed(c):
          if engine.keyIsDown(ShiftL) or engine.keyIsDown(ShiftR):
            main_text.text = main_text.text & ($c).toRunes
          else:
            main_text.text = main_text.text & ($c).toRunes[0].toLower()
      if engine.keyWasPressed(Enter):
        main_text.text = main_text.text & Rune('\n')
      if engine.keyWasPressed(Space):
        main_text.text = main_text.text & Rune(' ')

    # remove character
    if engine.keyWasPressed(Backspace) and main_text.text.len > 0:
      main_text.text = main_text.text[0 ..< ^1]

    # alignemtn with F-keys
    if engine.keyWasPressed(F1): main_text.horizontalAlignment = Left
    elif engine.keyWasPressed(F2): main_text.horizontalAlignment = Center
    elif engine.keyWasPressed(F3): main_text.horizontalAlignment = Right
    elif engine.keyWasPressed(F4): main_text.verticalAlignment = Top
    elif engine.keyWasPressed(F5): main_text.verticalAlignment = Center
    elif engine.keyWasPressed(F6): main_text.verticalAlignment = Bottom

    main_text.text = main_text.text & Rune('_')
    main_text.refresh()
    main_text.text = main_text.text[0 ..< ^1]
    help_text.refresh()
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
