import ./core

type
  # based on the default material
  # from glTF
  PBRMetalicRoughness* = object
    name: string

    baseColor: Vec4f
    baseColorTexture: Image

    metalic: float32
    roughness: float32
    metalicRoughnessTexture: Image

    normalScale: float32
    normalTexture: Image

    occlusionStrength: float32
    occlusionTexture: Image

    emissiveFactor: float32
    emissiveTexture: Image
