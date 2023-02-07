import semicongine

type
  Vertex = object
    position: PositionAttribute[Vec2]
    color: ColorAttribute[Vec3]
    transform: ModelTransformAttribute
  Uniforms = object
    view: ViewProjectionTransform

const
  barcolor = RGBfromHex("5A3F00").gamma(2.2)
  barSize = 0.1'f
  barWidth = 0.01'f
  ballcolor = RGBfromHex("B17F08").gamma(2.2)
  levelRatio = 1
  ballSize = 0.01'f
  backgroundColor = RGBAfromHex("FAC034").gamma(2.2)
  ballSpeed = 60'f

var
  uniforms = Uniforms()
  pipeline: RenderPipeline[Vertex, Uniforms]
  level: Thing
  ballVelocity = Vec2([1'f, 1'f]).normalized * ballSpeed

proc globalUpdate(engine: var Engine; t, dt: float32) =
  var height = float32(engine.vulkan.frameSize.y) / float32(
      engine.vulkan.frameSize.x)
  var width = 1'f
  uniforms.view.value = ortho[float32](
    0'f, width,
    0'f, height,
    0'f, 1'f,
  )
  engine.vulkan.device.updateUniformData(pipeline, uniforms)
  var player = level.firstWithName("player")
  if Down in engine.input.keysDown and (player.transform.col(3).y + barSize/2) < height:
    player.transform = player.transform * translate3d(0'f, 1'f * dt, 0'f)
  if Up in engine.input.keysDown and (player.transform.col(3).y - barSize/2) > 0:
    player.transform = player.transform * translate3d(0'f, -1'f * dt, 0'f)

  var ball = level.firstWithName("ball")
  ball.transform = ball.transform * translate3d(ballVelocity[0] * dt,
      ballVelocity[1] * dt, 0'f)

  # loose
  if ball.transform.col(3).x - ballSize/2 <= 0:
    ballVelocity = Vec2([1'f, 1'f]).normalized * ballSpeed
    ball.transform[0, 3] = width / 2
    ball.transform[1, 3] = height / 2

  # bounce level
  if ball.transform.col(3).x + ballSize/2 > width: ballVelocity[
      0] = -ballVelocity[0]
  if ball.transform.col(3).y - ballSize/2 <= 0: ballVelocity[1] = -ballVelocity[1]
  if ball.transform.col(3).y + ballSize/2 > height: ballVelocity[
      1] = -ballVelocity[1]

  # bar
  if ball.transform.col(3).x - ballSize/2 <= barWidth:
    let
      barTop = player.transform.col(3).y - barSize/2
      barBottom = player.transform.col(3).y + barSize/2
      ballTop = ball.transform.col(3).y - ballSize/2
      ballBottom = ball.transform.col(3).y + ballSize/2
    if ballTop >= barTop and ballBottom <= barBottom:
      ballVelocity[0] = abs(ballVelocity[0])


when isMainModule:
  var myengine = igniteEngine("Pong")
  myengine.maxFPS = 61
  level = newThing("Level")
  var playerbarmesh = quad[Vertex, Vec2, float32]()
  playerbarmesh.vertexData.color.data = @[barcolor, barcolor, barcolor, barcolor]
  playerbarmesh.vertexData.transform.data = @[Unit44]
  var playerbar = newThing("playerbar", playerbarmesh)
  playerbar.transform = scale3d(barWidth, barSize, 1'f) * translate3d(0.5'f,
      0'f, 0'f)
  var player = newThing("player", playerbar)
  player.transform = translate3d(0'f, 0.3'f, 0'f)
  level.add player

  var ballmesh = circle[Vertex, Vec2, float32]()
  ballmesh.vertexData.color.data = newSeq[Vec3](
      ballmesh.vertexData.position.data.len)
  for i in 0 ..< ballmesh.vertexData.color.data.len:
    ballmesh.vertexData.color.data[i] = ballcolor
  ballmesh.vertexData.transform.data = @[Unit44]
  var ball = newThing("ball", ballmesh)
  ball.transform = scale3d(ballSize, ballSize, 1'f) * translate3d(10'f, 10'f, 0'f)
  level.add ball

  # upload data, prepare shaders, etc
  const vertexShader = generateVertexShaderCode[Vertex, Uniforms]()
  const fragmentShader = generateFragmentShaderCode[Vertex]()
  pipeline = setupPipeline[Vertex, Uniforms, uint16](
    myengine,
    level,
    vertexShader,
    fragmentShader
  )
  pipeline.clearColor = backgroundColor
  # show something
  myengine.run(pipeline, globalUpdate)
  pipeline.trash()
  myengine.trash()
