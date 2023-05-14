import std/times

import semicongine

proc main() =
  var scene = loadScene("test1.glb")
  # var scene = loadScene("tutorialk-donat.glb")

  var engine = initEngine("Test meshes")
  const
    vertexInput = @[attr[Vec3f]("POSITION", memoryPerformanceHint=PreferFastRead)]
    fragOutput = @[attr[Vec4f]("color")]
    uniforms = @[attr[Mat4]("transform")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      uniforms=uniforms,
      main="""gl_Position = vec4(POSITION * 0.2, 1.0) * Uniforms.transform;"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      outputs=fragOutput,
      uniforms=uniforms,
      main="""
color = vec4(61/255, 43/255, 31/255, 1);
"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput)
  let rotateAxis = newVec3f(1, 1, 1)
  scene.addShaderGlobal("transform", rotate3d(0'f32, rotateAxis))
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    scene.setShaderGlobal("transform", rotate3d(float32(cpuTime() - t), rotateAxis))
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
