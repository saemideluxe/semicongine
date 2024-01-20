import std/unicode

import semicongine

proc main() =
  # setup engine
  var engine = initEngine("Test fonts")
  engine.initRenderer([])

  # build scene
  var scene = Scene(name: "main")
  # var font = loadFont("DejaVuSans.ttf", lineHeightPixels=90'f32, charset="abcdefghijklmnopqrstuvwxyz ".toRunes)
  var font = loadFont("DejaVuSans.ttf", lineHeightPixels=180'f32)
  var textbox = initText(32, font, "", color=newVec4f(1, 0, 0, 1))
  let fontscale = 0.001
  scene.add textbox
  textbox.mesh.transform = scale(fontscale, fontscale)
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      textbox.mesh.transform = scale(fontscale * (winSize[1] / winSize[0]), fontscale)
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
