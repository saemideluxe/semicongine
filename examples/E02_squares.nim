import std/sequtils
import std/random

import semicongine


when isMainModule:
  randomize()
  const
    COLUMNS = 10
    ROWS = 10
    WIDTH = 2'f32 / COLUMNS
    HEIGHT = 2'f32 / ROWS
  var
    vertices: array[COLUMNS * ROWS * 4, Vec3f]
    colors: array[COLUMNS * ROWS * 4, Vec3f]
    iValues: array[COLUMNS * ROWS * 4, uint32]
    indices: array[COLUMNS * ROWS * 2, array[3, uint16]]

  for row in 0 ..< ROWS:
    for col in 0 ..< COLUMNS:
      let
        y: float32 = (row * 2 / COLUMNS) - 1
        x: float32 = (col * 2 / ROWS) - 1
        color = Vec3f([(x + 1) / 2, (y + 1) / 2, 0'f32])
        squareIndex = row * COLUMNS + col
        vertIndex = squareIndex * 4
      vertices[vertIndex + 0] = newVec3f(x, y)
      vertices[vertIndex + 1] = newVec3f(x + WIDTH, y)
      vertices[vertIndex + 2] = newVec3f(x + WIDTH, y + HEIGHT)
      vertices[vertIndex + 3] = newVec3f(x, y + HEIGHT)
      colors[vertIndex + 0] = color
      colors[vertIndex + 1] = color
      colors[vertIndex + 2] = color
      colors[vertIndex + 3] = color
      iValues[vertIndex + 0] = uint32(squareIndex)
      iValues[vertIndex + 1] = uint32(squareIndex)
      iValues[vertIndex + 2] = uint32(squareIndex)
      iValues[vertIndex + 3] = uint32(squareIndex)
      indices[squareIndex * 2 + 0] = [uint16(vertIndex + 0), uint16(vertIndex + 1), uint16(vertIndex + 2)]
      indices[squareIndex * 2 + 1] = [uint16(vertIndex + 2), uint16(vertIndex + 3), uint16(vertIndex + 0)]


  const
    vertexInput = @[
      attr[Vec3f]("position"),
      attr[Vec3f]("color", memoryPerformanceHint=PreferFastWrite),
      attr[uint32]("index"),
    ]
    vertexOutput = @[attr[Vec3f]("outcolor")]
    uniforms = @[attr[float32]("time")]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      outputs=vertexOutput,
      main="""
float pos_weight = index / 100.0; // add some gamma correction?
float t = sin(Uniforms.time * 0.5) * 0.5 + 0.5;
float v = min(1, max(0, pow(pos_weight - t, 2)));
v = pow(1 - v, 3000);
outcolor = vec3(color.r, color.g, v * 0.5);
gl_Position = vec4(position, 1.0);
"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      inputs=vertexOutput,
      uniforms=uniforms,
      outputs=fragOutput,
      main="color = vec4(outcolor, 1);"
    )
  var squaremesh = newMesh(
    positions=vertices,
    indices=indices,
    colors=colors,
  )
  setMeshData[uint32](squaremesh, "index", iValues.toSeq)

  var myengine = initEngine("Squares")
  myengine.setRenderer(myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))

  var scene = newScene("scene", newEntity("scene", newEntity("squares", squaremesh)))
  myengine.addScene(scene, vertexInput)
  scene.addShaderGlobal("time", 0.0'f32)
  while myengine.updateInputs() == Running and not myengine.keyWasPressed(Escape):
    setShaderGlobal(scene, "time", getShaderGlobal[float32](scene, "time") + 0.0005'f)
    myengine.renderScene(scene)

  myengine.destroy()
