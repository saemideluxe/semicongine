import std/strutils
import std/enumerate

import semicongine


const
  vertexInput = @[
    attr[Vec3f]("position", memoryLocation=VRAM),
    attr[Vec3f]("color", memoryLocation=VRAM),
  ]
  vertexOutput = @[attr[Vec3f]("outcolor")]
  fragOutput = @[attr[Vec4f]("color")]
  vertexCode = compileGlslShader(
    stage=VK_SHADER_STAGE_VERTEX_BIT,
    inputs=vertexInput,
    outputs=vertexOutput,
    main="""gl_Position = vec4(position, 1.0); outcolor = color;"""
  )
  fragmentCode = compileGlslShader(
    stage=VK_SHADER_STAGE_FRAGMENT_BIT,
    inputs=vertexOutput,
    outputs=fragOutput,
    main="color = vec4(outcolor, 1);"
  )

var
  triangle = newEntity(
    "triangle",
    newMesh(
      [newVec3f(-0.5, 0.5), newVec3f(0, -0.5), newVec3f(0.5, 0.5)],
      [X, Y, Z],
    )
  )
  myengine = initEngine("Hello triangle")
  renderPass = myengine.gpuDevice.simpleForwardRenderPass(vertexCode, fragmentCode)

myengine.setRenderer(renderPass)
myengine.addScene(triangle, vertexInput)

while myengine.running and not myengine.keyWasPressed(Escape):
  myengine.updateInputs()
  myengine.renderScene(triangle)

myengine.destroy()
