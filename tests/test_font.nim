import std/unicode

import semicongine

proc main() =
  # setup engine
  var engine = initEngine("Test fonts")
  engine.initRenderer([])

  # build scene
  var scene = Scene(name: "main")
  var font = loadFont("DejaVuSans.ttf", color=newVec4f(1, 0.5, 0.5, 1), resolution=20)
  var textbox = initTextbox(32, font, "")
  scene.add textbox
  textbox.mesh.transform = scale(0.01, 0.01)
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      textbox.mesh.transform = scale(0.01 * (winSize[1] / winSize[0]), 0.01)
    for c in [Key.A, Key.B, Key.C, Key.D, Key.E, Key.F, Key.G, Key.H, Key.I, Key.J, Key.K, Key.L, Key.M, Key.N, Key.O, Key.P, Key.Q, Key.R, Key.S, Key.T, Key.U, Key.V, Key.W, Key.X, Key.Y, Key.Z]:
      if engine.keyWasPressed(c):
        if engine.keyIsDown(ShiftL) or engine.keyIsDown(ShiftR):
          textbox.text = textbox.text & ($c).toRunes
        else:
          textbox.text = textbox.text & ($c).toRunes[0].toLower()
    if engine.keyWasPressed(Space):
        textbox.text = textbox.text & " ".toRunes[0]
    if engine.keyWasPressed(Backspace) and textbox.text.len > 0:
          textbox.text = textbox.text[0 ..< ^1]
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
