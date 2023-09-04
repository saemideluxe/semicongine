import std/times
import std/tables

import ../src/semicongine

let
  barcolor = hexToColorAlpha("5A3F00").gamma(2.2).colorToHex()
  barSize = 0.1'f
  barWidth = 0.01'f
  ballcolor = hexToColorAlpha("B17F08").gamma(2.2).colorToHex()
  ballSize = 0.01'f
  ballSpeed = 60'f
  material = Material(name: "default")

var
  level: Scene
  ballVelocity = newVec2f(1, 1).normalized * ballSpeed

when isMainModule:
  var myengine = initEngine("Pong")

  var player = rect(color=barcolor, width=barWidth, height=barSize)
  player.material = material
  var ball = circle(color=ballcolor)
  ball.material = material
  level = Scene(name: "scene", meshes: @[ball, player])

  const
    shaderConfiguration = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position"),
        attr[Vec4f]("color", memoryPerformanceHint=PreferFastWrite),
        attr[Mat4]("transform", memoryPerformanceHint=PreferFastWrite, perInstance=true),
      ],
      intermediates=[attr[Vec4f]("outcolor")],
      uniforms=[attr[Mat4]("projection")],
      outputs=[attr[Vec4f]("color")],
      vertexCode="""outcolor = color; gl_Position = vec4(position, 1) * (transform * Uniforms.projection);""",
      fragmentCode="color = outcolor;",
    )

  # set up rendering
  myengine.initRenderer({"default": shaderConfiguration}.toTable)
  level.addShaderGlobal("projection", Unit4f32)
  myengine.addScene(level)

  var
    winsize = myengine.getWindow().size
    height = float32(winsize[1]) / float32(winsize[0])
    width = 1'f
    currentTime = cpuTime()
    showSystemCursor = true
    fullscreen = false
  while myengine.updateInputs() == Running and not myengine.keyIsDown(Escape):
    if myengine.keyWasPressed(C):
      if showSystemCursor:
        myengine.hideSystemCursor()
      else:
        myengine.showSystemCursor()
      showSystemCursor = not showSystemCursor
    if myengine.keyWasPressed(F):
      fullscreen = not fullscreen
      myengine.fullscreen(fullscreen)

    let dt: float32 = cpuTime() - currentTime
    currentTime = cpuTime()
    if myengine.windowWasResized():
      winsize = myengine.getWindow().size
      height = float32(winsize[1]) / float32(winsize[0])
      width = 1'f
      setShaderGlobal(level, "projection", ortho(0, width, 0, height, 0, 1))
    if myengine.keyIsDown(Down) and (player.transform.col(3).y + barSize/2) < height:
      player.transform = player.transform * translate(0'f, 1'f * dt, 0'f)
    if myengine.keyIsDown(Up) and (player.transform.col(3).y - barSize/2) > 0:
      player.transform = player.transform * translate(0'f, -1'f * dt, 0'f)

    # bounce level
    if ball.transform.col(3).x + ballSize/2 > width: ballVelocity[0] = -ballVelocity[0]
    if ball.transform.col(3).y - ballSize/2 <= 0: ballVelocity[1] = -ballVelocity[1]
    if ball.transform.col(3).y + ballSize/2 > height: ballVelocity[1] = -ballVelocity[1]

    ball.transform = ball.transform * translate(ballVelocity[0] * dt, ballVelocity[1] * dt, 0'f32)

    # loose
    if ball.transform.col(3).x - ballSize/2 <= 0:
      ball.transform = scale(ballSize, ballSize, 1'f) * translate(30'f, 30'f, 0'f)
      ballVelocity = newVec2f(1, 1).normalized * ballSpeed

    # bar
    if ball.transform.col(3).x - ballSize/2 <= barWidth:
      let
        barTop = player.transform.col(3).y - barSize/2
        barBottom = player.transform.col(3).y + barSize/2
        ballTop = ball.transform.col(3).y - ballSize/2
        ballBottom = ball.transform.col(3).y + ballSize/2
      if ballTop >= barTop and ballBottom <= barBottom:
        ballVelocity[0] = abs(ballVelocity[0])

    myengine.renderScene(level)
