import std/sequtils
import std/tables
import std/random

import ../semicongine


when isMainModule:
  randomize()
  const
    COLUMNS = 10
    ROWS = 10
    WIDTH = 2'f32 / COLUMNS
    HEIGHT = 2'f32 / ROWS
  var
    vertices: array[COLUMNS * ROWS * 4, Vec3f]
    colors: array[COLUMNS * ROWS * 4, Vec4f]
    iValues: array[COLUMNS * ROWS * 4, uint32]
    indices: array[COLUMNS * ROWS * 2, array[3, uint16]]

  for row in 0 ..< ROWS:
    for col in 0 ..< COLUMNS:
      let
        y: float32 = (row * 2 / COLUMNS) - 1
        x: float32 = (col * 2 / ROWS) - 1
        color = NewVec4f((x + 1) / 2, (y + 1) / 2, 0, 1)
        squareIndex = row * COLUMNS + col
        vertIndex = squareIndex * 4
      vertices[vertIndex + 0] = NewVec3f(x, y)
      vertices[vertIndex + 1] = NewVec3f(x + WIDTH, y)
      vertices[vertIndex + 2] = NewVec3f(x + WIDTH, y + HEIGHT)
      vertices[vertIndex + 3] = NewVec3f(x, y + HEIGHT)
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
    shaderConfiguration = createShaderConfiguration(
      name = "default shader",
      inputs = [
        attr[Vec3f]("position"),
        attr[Vec4f]("color", memoryPerformanceHint = PreferFastWrite),
        attr[uint32]("index"),
      ],
      intermediates = [attr[Vec4f]("outcolor")],
      uniforms = [attr[float32]("time")],
      outputs = [attr[Vec4f]("color")],
      vertexCode = """
float pos_weight = index / 100.0; // add some gamma correction?
float t = sin(Uniforms.time * 0.5) * 0.5 + 0.5;
float v = min(1, max(0, pow(pos_weight - t, 2)));
v = pow(1 - v, 3000);
outcolor = vec4(color.r, color.g, v * 0.5, 1);
gl_Position = vec4(position, 1.0);
""",
      fragmentCode = "color = outcolor;",
    )
  let matDef = MaterialType(name: "default", vertexAttributes: {
    "position": Vec3F32,
    "color": Vec4F32,
    "index": UInt32,
  }.toTable)
  var squaremesh = newMesh(
    positions = vertices,
    indices = indices,
    colors = colors,
  )
  squaremesh[].initVertexAttribute("index", iValues.toSeq)
  squaremesh.material = matDef.initMaterialData(name = "default")

  var myengine = initEngine("Squares")
  myengine.initRenderer({matDef: shaderConfiguration})

  var scene = Scene(name: "scene", meshes: @[squaremesh])
  scene.addShaderGlobal("time", 0.0'f32)
  myengine.loadScene(scene)
  while myengine.UpdateInputs() and not KeyWasPressed(Escape):
    scene.setShaderGlobal("time", getShaderGlobal[float32](scene, "time") + 0.0005'f)
    myengine.renderScene(scene)

  myengine.destroy()
