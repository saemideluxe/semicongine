import std/unicode

import semicongine


proc main() =
  # setup engine
  var engine = initEngine("Test panels")
  engine.initRenderer([])

  # build scene
  var scene = Scene(name: "main")
  var panel = initPanel(position: newVec2f(0, 0), size: newVec2f(0.1, 0.1))

  scene.add panel
  engine.loadScene(scene)

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.windowWasResized():
      var winSize = engine.getWindow().size
      panel.aspect_ratio = winSize[0] / winSize[1]

    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
