import std/times
import std/unicode

import semicongine


proc main() =
  # setup engine
  var engine = initEngine("Test fonts")
  engine.initRenderer([])

  # build scene
  var scene = Scene(name: "main")
  var font = loadFont("DejaVuSans.ttf", lineHeightPixels = 210'f32)
  var origin = initPanel(transform = scale(0.01, 0.01))
  var main_text = font.initText("".toRunes, maxLen = 255, color = newVec4f(1, 0.15, 0.15, 1), maxWidth = 1.0, transform = scale(0.0005, 0.0005))
  var help_text = font.initText("""Controls

Horizontal alignment:
  F1: Left
  F2: Center
  F3: Right
Vertical alignment:
  F4: Top
  F5: Center
  F6: Bottom""".toRunes, horizontalAlignment = Left, verticalAlignment = Top, transform = translate(-0.9, -0.9) * scale(0.0002, 0.0002))
  scene.add origin
  scene.add main_text
  scene.add help_text
  engine.loadScene(scene)
  mixer[].loadSound("key", "key.ogg")
  mixer[].setLevel(0.5)

  while engine.updateInputs() and not keyIsDown(Escape):
    var t = cpuTime()
    main_text.color = newVec4f(sin(t) * 0.5 + 0.5, 0.15, 0.15, 1)
    if windowWasResized():
      var winSize = engine.getWindow().size

    # add character
    if main_text.text.len < main_text.maxLen - 1:
      for c in [Key.A, Key.B, Key.C, Key.D, Key.E, Key.F, Key.G, Key.H, Key.I,
          Key.J, Key.K, Key.L, Key.M, Key.N, Key.O, Key.P, Key.Q, Key.R, Key.S,
          Key.T, Key.U, Key.V, Key.W, Key.X, Key.Y, Key.Z]:
        if keyWasPressed(c):
          discard mixer[].play("key")
          if keyIsDown(ShiftL) or keyIsDown(ShiftR):
            main_text.text = main_text.text & ($c).toRunes
          else:
            main_text.text = main_text.text & ($c).toRunes[0].toLower()
      if keyWasPressed(Enter):
        discard mixer[].play("key")
        main_text.text = main_text.text & Rune('\n')
      if keyWasPressed(Space):
        discard mixer[].play("key")
        main_text.text = main_text.text & Rune(' ')

    # remove character
    if keyWasPressed(Backspace) and main_text.text.len > 0:
      discard mixer[].play("key")
      main_text.text = main_text.text[0 ..< ^1]

    # alignemtn with F-keys
    if keyWasPressed(F1): main_text.horizontalAlignment = Left
    elif keyWasPressed(F2): main_text.horizontalAlignment = Center
    elif keyWasPressed(F3): main_text.horizontalAlignment = Right
    elif keyWasPressed(F4): main_text.verticalAlignment = Top
    elif keyWasPressed(F5): main_text.verticalAlignment = Center
    elif keyWasPressed(F6): main_text.verticalAlignment = Bottom

    origin.refresh()
    main_text.text = main_text.text & Rune('_')
    main_text.refresh()
    main_text.text = main_text.text[0 ..< ^1]
    help_text.refresh()
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
