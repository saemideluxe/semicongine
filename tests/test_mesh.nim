import std/algorithm
import std/sequtils
import std/tables
import semicongine

proc main() =
  # var myScene = Scene(name: "hi", meshes: @[rect()])
  # myScene.meshes[0].transform = translate3d(0.2'f32, 0'f32, 0'f32)
  # myScene.root[0].transform = translate3d(0'f32, 0.2'f32, 0'f32)
  var scenes = [
    # loadScene("default_cube.glb", "1"),
    # loadScene("default_cube1.glb", "3"),
    # loadScene("default_cube2.glb", "4"),
    # loadScene("flat.glb", "5"),
    Scene(name: "Donut", meshes: loadMeshes("tutorialk-donat.glb")[0].toSeq),
    # myScene,
    # loadScene("personv3.glb", "2"),
  ]

  var engine = initEngine("Test meshes")
  const
    shaderConfiguration = createShaderConfiguration(
      inputs=[
        attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
        attr[uint16]("materialIndex", memoryPerformanceHint=PreferFastRead),
        attr[Vec2f]("texcoord_0", memoryPerformanceHint=PreferFastRead),
        attr[Mat4]("transform", memoryPerformanceHint=PreferFastWrite, perInstance=true),
      ],
      intermediates=[
        attr[Vec4f]("vertexColor"),
        attr[Vec2f]("colorTexCoord"),
        attr[uint16]("materialIndexOut", noInterpolation=true)
      ],
      outputs=[attr[Vec4f]("color")],
      uniforms=[
        attr[Mat4]("projection"),
        attr[Mat4]("view"),
        attr[Vec4f]("baseColorFactor", arrayCount=4),
      ],
      samplers=[attr[Texture]("baseColorTexture", arrayCount=4)],
      vertexCode="""
  gl_Position =  vec4(position, 1.0) * (transform * Uniforms.view * Uniforms.projection);
  vertexColor = Uniforms.baseColorFactor[materialIndex];
  colorTexCoord = texcoord_0;
  materialIndexOut = materialIndex;
  """,
      fragmentCode="color = texture(baseColorTexture[materialIndexOut], colorTexCoord) * vertexColor;"
    )
  engine.initRenderer({
    "Material": shaderConfiguration,
    "Material.001": shaderConfiguration,
    "Material.002": shaderConfiguration,
    "Material.004": shaderConfiguration,
  }.toTable)

  for scene in scenes.mitems:
    scene.addShaderGlobal("projection", Unit4F32)
    scene.addShaderGlobal("view", Unit4F32)
    var materials: Table[uint16, Material]
    for mesh in scene.meshes:
      if not materials.contains(mesh.material.index):
        materials[mesh.material.index] = mesh.material
    let baseColors = sortedByIt(values(materials).toSeq, it.index).mapIt(getValue[Vec4f](it.constants["baseColorFactor"], 0))
    let baseTextures = sortedByIt(values(materials).toSeq, it.index).mapIt(it.textures["baseColorTexture"])
    for t in baseTextures:
      echo "- ", t
    scene.addShaderGlobalArray("baseColorFactor", baseColors)
    scene.addShaderGlobalArray("baseColorTexture", baseTextures)
    engine.addScene(scene)

  var
    size = 1'f32
    elevation = 0'f32
    azimut = 0'f32
    currentScene = 0

  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    if engine.keyWasPressed(`1`):
      currentScene = 0
    elif engine.keyWasPressed(`2`):
      currentScene = 1
    elif engine.keyWasPressed(`3`):
      currentScene = 2
    elif engine.keyWasPressed(`4`):
      currentScene = 3
    elif engine.keyWasPressed(`5`):
      currentScene = 4
    elif engine.keyWasPressed(`6`):
      currentScene = 5

    if engine.keyWasPressed(NumberRowExtra3):
      size = 0.3'f32
      elevation = 0'f32
      azimut = 0'f32

    let ratio = engine.getWindow().size[0] / engine.getWindow().size[1]
    size *= 1'f32 + engine.mouseWheel() * 0.05
    azimut += engine.mouseMove().x / 180'f32
    elevation -= engine.mouseMove().y / 180'f32
    scenes[currentScene].setShaderGlobal("projection", ortho(-ratio, ratio, -1, 1, -1, 1))
    scenes[currentScene].setShaderGlobal(
      "view",
       scale(size, size, size) * rotate(elevation, newVec3f(1, 0, 0)) * rotate(azimut, Yf32)
    )
    engine.renderScene(scenes[currentScene])
  engine.destroy()

when isMainModule:
  main()
