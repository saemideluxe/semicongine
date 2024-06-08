import std/times
import std/tables

import ../semicongine

let
  barcolor = ToRGBA("5A3F00").ToSRGB().ColorToHex()
  barSize = 0.1'f
  barWidth = 0.01'f
  ballcolor = ToRGBA("B17F08").ToSRGB().ColorToHex()
  ballSize = 0.01'f
  ballSpeed = 60'f
  matDef = MaterialType(name: "default", vertexAttributes: {
    "position": Vec3F32,
    "color": Vec4F32,
  }.toTable)

var
  level: Scene
  ballVelocity = NewVec2f(1, 1).Normalized * ballSpeed

when isMainModule:
  var myengine = InitEngine("Pong")

  var player = Rect(color = barcolor, width = barWidth, height = barSize)
  player.material = matDef.InitMaterialData(name = "player material")
  var ball = Circle(color = ballcolor)
  ball.material = matDef.InitMaterialData(name = "player material")
  level = Scene(name: "scene", meshes: @[ball, player])

  const
    shaderConfiguration = CreateShaderConfiguration(
      name = "default shader",
      inputs = [
        Attr[Vec3f]("position"),
        Attr[Vec4f]("color", memoryPerformanceHint = PreferFastWrite),
        Attr[Mat4]("transform", memoryPerformanceHint = PreferFastWrite, perInstance = true),
      ],
      intermediates = [Attr[Vec4f]("outcolor")],
      uniforms = [Attr[Mat4]("projection")],
      outputs = [Attr[Vec4f]("color")],
      vertexCode = """outcolor = color; gl_Position = vec4(position, 1) * (transform * Uniforms.projection);""",
      fragmentCode = "color = outcolor;",
    )

  # set up rendering
  myengine.InitRenderer({matDef: shaderConfiguration})
  level.AddShaderGlobal("projection", Unit4f32)
  myengine.LoadScene(level)

  var
    winsize = myengine.GetWindow().Size
    height = float32(winsize[1]) / float32(winsize[0])
    width = 1'f
    currentTime = cpuTime()
    showSystemCursor = true
    fullscreen = false
  while myengine.UpdateInputs() and not KeyIsDown(Escape):
    if KeyWasPressed(C):
      if showSystemCursor:
        myengine.HideSystemCursor()
      else:
        myengine.ShowSystemCursor()
      showSystemCursor = not showSystemCursor
    if KeyWasPressed(F):
      fullscreen = not fullscreen
      myengine.Fullscreen = fullscreen

    let dt: float32 = cpuTime() - currentTime
    currentTime = cpuTime()
    if WindowWasResized():
      winsize = myengine.GetWindow().Size
      height = float32(winsize[1]) / float32(winsize[0])
      width = 1'f
      SetShaderGlobal(level, "projection", Ortho(0, width, 0, height, 0, 1))
    if KeyIsDown(Down) and (player.transform.Col(3).y + barSize/2) < height:
      player.transform = player.transform * Translate(0'f, 1'f * dt, 0'f)
    if KeyIsDown(Up) and (player.transform.Col(3).y - barSize/2) > 0:
      player.transform = player.transform * Translate(0'f, -1'f * dt, 0'f)

    # bounce level
    if ball.transform.Col(3).x + ballSize/2 > width: ballVelocity[0] = -ballVelocity[0]
    if ball.transform.Col(3).y - ballSize/2 <= 0: ballVelocity[1] = -ballVelocity[1]
    if ball.transform.Col(3).y + ballSize/2 > height: ballVelocity[1] = -ballVelocity[1]

    ball.transform = ball.transform * Translate(ballVelocity[0] * dt, ballVelocity[1] * dt, 0'f32)

    # loose
    if ball.transform.Col(3).x - ballSize/2 <= 0:
      ball.transform = Scale(ballSize, ballSize, 1'f) * Translate(30'f, 30'f, 0'f)
      ballVelocity = NewVec2f(1, 1).Normalized * ballSpeed

    # bar
    if ball.transform.Col(3).x - ballSize/2 <= barWidth:
      let
        barTop = player.transform.Col(3).y - barSize/2
        barBottom = player.transform.Col(3).y + barSize/2
        ballTop = ball.transform.Col(3).y - ballSize/2
        ballBottom = ball.transform.Col(3).y + ballSize/2
      if ballTop >= barTop and ballBottom <= barBottom:
        ballVelocity[0] = abs(ballVelocity[0])

    myengine.RenderScene(level)
  myengine.Destroy()
