type
  ShaderInputA = object
    positions {.VertexAttribute.}: seq[Vec3f]
    colors {.VertexAttribute.}: seq[Vec3f]
    transforms {.InstanceAttribute.}: seq[Vec3f]
    other: bool
  Enemy = object
    shaderData: ShaderInputA

proc initEnemy()
