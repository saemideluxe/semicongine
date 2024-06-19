import std/os

import semicongine/platform/window
import semicongine/core/vulkanapi
import semicongine/vulkan/instance
import semicongine/vulkan/device
import semicongine/vulkan/physicaldevice
# import ./vulkan/shader

import semicongine/core/vector
import semicongine/core/matrix

type
  MeshA = object
    positions: seq[Vec3f]
    colors: seq[Vec3f]
    transparency: float32
  InstanceDataA = object
    transforms: seq[Vec3f]

  Enemy = object
    mesh: MeshA
    enemies: InstanceDataA

let e = Enemy()
echo e

let w = CreateWindow("test2")
putEnv("VK_LAYER_ENABLES", "VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_AMD,VALIDATION_CHECK_ENABLE_VENDOR_SPECIFIC_NVIDIA,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXTVK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT")
let i = w.CreateInstance(
  vulkanVersion = VK_MAKE_API_VERSION(0, 1, 3, 0),
  instanceExtensions = @[],
  layers = @["VK_LAYER_KHRONOS_validation"],
)

let selectedPhysicalDevice = i.GetPhysicalDevices().FilterBestGraphics()
let d = i.CreateDevice(
  selectedPhysicalDevice,
  enabledExtensions = @[],
  selectedPhysicalDevice.FilterForGraphicsPresentationQueues()
)
