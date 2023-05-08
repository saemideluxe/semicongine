import std/times

import semicongine

proc main() =
  var scene = newScene("main", root=newEntity("rect", rect()))
  var engine = initEngine("Test materials")
  const
    vertexInput = @[
      attr[Vec3f]("position", memoryPerformanceHint=PreferFastRead),
    ]
    fragOutput = @[attr[Vec4f]("color")]
    vertexCode = compileGlslShader(
      stage=VK_SHADER_STAGE_VERTEX_BIT,
      inputs=vertexInput,
      main="""gl_Position = vec4(position, 1.0);"""
    )
    fragmentCode = compileGlslShader(
      stage=VK_SHADER_STAGE_FRAGMENT_BIT,
      outputs=fragOutput,
      main="""color = vec4(1, 0, 0, 1);"""
    )
  engine.setRenderer(engine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode))
  engine.addScene(scene, vertexInput)
  var t = cpuTime()
  while engine.updateInputs() == Running and not engine.keyIsDown(Escape):
    engine.renderScene(scene)
  engine.destroy()


when isMainModule:
  main()
