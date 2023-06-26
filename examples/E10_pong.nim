import std/times

import ../src/semicongine

let
  barcolor = hexToColorAlpha("5A3F00").gamma(2.2).colorToHex()
  barSize = 0.1'f
  barWidth = 0.01'f
  ballcolor = hexToColorAlpha("B17F08").gamma(2.2).colorToHex()
  ballSize = 0.01'f
  backgroundColor = hexToColorAlpha("FAC034FF").gamma(2.2)
  ballSpeed = 60'f

var
  level: Scene
  ballVelocity = newVec2f(1, 1).normalized * ballSpeed

when isMainModule:
  var myengine = initEngine("Pong")
  level = newScene("scene", newEntity("Level"))
  var playerbarmesh = rect(color=barcolor)
  var playerbar = newEntity("playerbar", {"mesh": Component(playerbarmesh)})
  playerbar.transform = scale3d(barWidth, barSize, 1'f) * translate3d(0.5'f, 0'f, 0'f)
  var player = newEntity("player", [], playerbar)
  player.transform = translate3d(0'f, 0.3'f, 0'f)
  level.root.add player

  var ballmesh = circle(color=ballcolor)
  var ball = newEntity("ball", {"mesh": Component(ballmesh)})
  ball.transform = scale3d(ballSize, ballSize, 1'f) * translate3d(10'f, 10'f, 0'f)
  level.root.add ball

  const
    vertexInput = @[
      attr[Vec3f]("position"),
      attr[Vec4f]("color", memoryPerformanceHint=PreferFastWrite),
      attr[Mat4]("transform", memoryPerformanceHint=PreferFastWrite, perInstance=true),
    ]
    vertexOutput = @[attr[Vec4f]("outcolor")]
    uniforms = @[attr[Mat4]("projection")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      outputs=vertexOutput,
      main="""outcolor = color; gl_Position = vec4(position, 1) * (transform * Uniforms.projection);"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      outputs=fragOutput,
      main="color = outcolor;"
    )

  # set up rendering
  myengine.setRenderer(myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode, clearColor=backgroundColor))
  myengine.addScene(level, vertexInput, @[], transformAttribute="transform")
  level.addShaderGlobal("projection", Unit4f32)

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
    var player = level.root.firstWithName("player")
    if myengine.keyIsDown(Down) and (player.transform.col(3).y + barSize/2) < height:
      player.transform = player.transform * translate3d(0'f, 1'f * dt, 0'f)
    if myengine.keyIsDown(Up) and (player.transform.col(3).y - barSize/2) > 0:
      player.transform = player.transform * translate3d(0'f, -1'f * dt, 0'f)

    # bounce level
    if ball.transform.col(3).x + ballSize/2 > width: ballVelocity[0] = -ballVelocity[0]
    if ball.transform.col(3).y - ballSize/2 <= 0: ballVelocity[1] = -ballVelocity[1]
    if ball.transform.col(3).y + ballSize/2 > height: ballVelocity[1] = -ballVelocity[1]

    ball.transform = ball.transform * translate3d(ballVelocity[0] * dt, ballVelocity[1] * dt, 0'f32)

    # loose
    if ball.transform.col(3).x - ballSize/2 <= 0:
      ball.transform = scale3d(ballSize, ballSize, 1'f) * translate3d(30'f, 30'f, 0'f)
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
