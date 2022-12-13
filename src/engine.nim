import std/enumerate

import ./vulkan
import ./vulkan_helpers
import ./xlib_helpers

import ./glslang/glslang
import ./glslang/glslang_c_shader_types


import
  x11/xlib,
  x11/x

const VULKAN_VERSION = VK_MAKE_API_VERSION(0'u32, 1'u32, 2'u32, 0'u32)

type
  QueueFamily = object
    properties*: VkQueueFamilyProperties
    hasSurfaceSupport*: bool
  PhyscialDevice = object
    device*: VkPhysicalDevice
    extensions*: seq[string]
    properties*: VkPhysicalDeviceProperties
    features*: VkPhysicalDeviceFeatures
    queueFamilies*: seq[QueueFamily]
    surfaceCapabilities*: VkSurfaceCapabilitiesKHR
    surfaceFormats: seq[VkSurfaceFormatKHR]
    presentModes: seq[VkPresentModeKHR]
  Vulkan* = object
    instance*: VkInstance
    deviceList*: seq[PhyscialDevice]
    activePhysicalDevice*: PhyscialDevice
    activeQueueFamily*: uint32
    device*: VkDevice
    presentationQueue*: VkQueue
    surface*: VkSurfaceKHR
    selectedSurfaceFormat: VkSurfaceFormatKHR
    selectedPresentationMode: VkPresentModeKHR
    selectedExtent: VkExtent2D
    swapChain: VkSwapchainKHR
    swapImages: seq[VkImage]
    swapImageViews: seq[VkImageView]
  Engine* = object
    display*: PDisplay
    window*: x.Window
    vulkan*: Vulkan


proc getAllPhysicalDevices(instance: VkInstance, surface: VkSurfaceKHR): seq[PhyscialDevice] =
  for vulkanPhysicalDevice in getVulkanPhysicalDevices(instance):
    var device = PhyscialDevice(device: vulkanPhysicalDevice, extensions: getDeviceExtensions(vulkanPhysicalDevice))
    vkGetPhysicalDeviceProperties(vulkanPhysicalDevice, addr(device.properties))
    vkGetPhysicalDeviceFeatures(vulkanPhysicalDevice, addr(device.features))
    checkVkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vulkanPhysicalDevice, surface, addr(device.surfaceCapabilities))
    device.surfaceFormats = getDeviceSurfaceFormats(vulkanPhysicalDevice, surface)
    device.presentModes = getDeviceSurfacePresentModes(vulkanPhysicalDevice, surface)

    for i, queueFamilyProperty in enumerate(getQueueFamilies(vulkanPhysicalDevice)):
      var hasSurfaceSupport: VkBool32 = VkBool32(false)
      checkVkResult vkGetPhysicalDeviceSurfaceSupportKHR(vulkanPhysicalDevice, uint32(i), surface, addr(hasSurfaceSupport))
      device.queueFamilies.add(QueueFamily(properties: queueFamilyProperty, hasSurfaceSupport: bool(hasSurfaceSupport)))

    result.add(device)

proc filterForDevice(devices: seq[PhyscialDevice]): seq[(PhyscialDevice, uint32)] =
  for device in devices:
    if "VK_KHR_swapchain" in device.extensions:
      for i, queueFamily in enumerate(device.queueFamilies):
        let hasGraphics = bool(uint32(queueFamily.properties.queueFlags) and ord(VK_QUEUE_GRAPHICS_BIT))
        if (
          queueFamily.hasSurfaceSupport and
          hasGraphics and
          device.surfaceFormats.len > 0 and
          device.presentModes.len > 0
        ):
          result.add((device, uint32(i)))

proc filterForSurfaceFormat(formats: seq[VkSurfaceFormatKHR]): seq[VkSurfaceFormatKHR] =
  for format in formats:
    if format.format == VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR:
      result.add(format)

proc getSwapExtent(display: PDisplay, window: Window, capabilities: VkSurfaceCapabilitiesKHR): VkExtent2D =
  if capabilities.currentExtent.width != high(uint32):
    return capabilities.currentExtent
  else:
    let (width, height) = xlibFramebufferSize(display, window)
    return VkExtent2D(
      width: min(max(uint32(width), capabilities.minImageExtent.width), capabilities.maxImageExtent.width),
      height: min(max(uint32(height), capabilities.minImageExtent.height), capabilities.maxImageExtent.height),
    )

proc igniteEngine*(): Engine =
  vkLoad1_0()
  vkLoad1_1()
  vkLoad1_2()

  # init X11 window
  (result.display, result.window) = xlibInit()

  # create vulkan instance
  result.vulkan.instance = createVulkanInstance(VULKAN_VERSION)

  # create vulkan-X11 surface
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: result.display,
    window: result.window,
  )
  checkVkResult vkCreateXlibSurfaceKHR(result.vulkan.instance, addr(surfaceCreateInfo), nil, addr(result.vulkan.surface))

  # determine device and queue to use and instantiate
  result.vulkan.deviceList = result.vulkan.instance.getAllPhysicalDevices(result.vulkan.surface)
  let usableDevices = result.vulkan.deviceList.filterForDevice()
  if len(usableDevices) == 0:
    raise newException(Exception, "No suitable graphics device found")
  (result.vulkan.activePhysicalDevice, result.vulkan.activeQueueFamily) = usableDevices[0]
  
  (result.vulkan.device, result.vulkan.presentationQueue) = getVulcanDevice(
    result.vulkan.activePhysicalDevice.device,
    result.vulkan.activePhysicalDevice.features,
    result.vulkan.activeQueueFamily
  )
  
  # determine surface format for swapchain
  let usableSurfaceFormats = filterForSurfaceFormat(result.vulkan.activePhysicalDevice.surfaceFormats)
  if len(usableSurfaceFormats) == 0:
    raise newException(Exception, "No suitable surface formats found")
  result.vulkan.selectedSurfaceFormat = usableSurfaceFormats[0]
  result.vulkan.selectedPresentationMode = getPresentMode(result.vulkan.activePhysicalDevice.presentModes)
  result.vulkan.selectedExtent = getSwapExtent(result.display, result.window, result.vulkan.activePhysicalDevice.surfaceCapabilities)

  # setup swapchain
  var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: result.vulkan.surface,
    minImageCount: max(result.vulkan.activePhysicalDevice.surfaceCapabilities.minImageCount + 1, result.vulkan.activePhysicalDevice.surfaceCapabilities.maxImageCount),
    imageFormat: result.vulkan.selectedSurfaceFormat.format,
    imageColorSpace: result.vulkan.selectedSurfaceFormat.colorSpace,
    imageExtent: result.vulkan.selectedExtent,
    imageArrayLayers: 1,
    imageUsage: VkImageUsageFlags(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
    # VK_SHARING_MODE_CONCURRENT no supported (i.e cannot use different queue families for  drawing to swap surface?)
    imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
    preTransform: result.vulkan.activePhysicalDevice.surfaceCapabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    presentMode: result.vulkan.selectedPresentationMode,
    clipped: VkBool32(true),
    oldSwapchain: VkSwapchainKHR(0),
  )
  checkVkResult vkCreateSwapchainKHR(result.vulkan.device, addr(swapchainCreateInfo), nil, addr(result.vulkan.swapChain))
  result.vulkan.swapImages = getSwapChainImages(result.vulkan.device, result.vulkan.swapChain)

  # setup swapchian image views
  result.vulkan.swapImageViews = newSeq[VkImageView](result.vulkan.swapImages.len)
  for i, image in enumerate(result.vulkan.swapImages):
    var imageViewCreateInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      image: image,
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: result.vulkan.selectedSurfaceFormat.format,
      components: VkComponentMapping(
        r: VK_COMPONENT_SWIZZLE_IDENTITY,
        g: VK_COMPONENT_SWIZZLE_IDENTITY,
        b: VK_COMPONENT_SWIZZLE_IDENTITY,
        a: VK_COMPONENT_SWIZZLE_IDENTITY,
      ),
      subresourceRange: VkImageSubresourceRange(
        aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1,
      ),
    )
    checkVkResult vkCreateImageView(result.vulkan.device, addr(imageViewCreateInfo), nil, addr(result.vulkan.swapImageViews[i]))
    echo compileShaderToSPIRV_Vulkan(GLSLANG_STAGE_VERTEX, """#version 450
vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);
void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
}""", "<memory-shader>")


proc fullThrottle*(engine: Engine) =
  var event: XEvent
  while true:
    discard XNextEvent(engine.display, addr(event))
    case event.theType
    of Expose:
      discard
    of ClientMessage:
      if cast[Atom](event.xclient.data.l[0]) == deleteMessage:
        break
    of KeyPress:
      let key = XLookupKeysym(cast[PXKeyEvent](addr(event)), 0)
      if key != 0:
        echo "Key ", key, " pressed"
    of ButtonPressMask:
      echo "Mouse button ", event.xbutton.button, " pressed at ",
          event.xbutton.x, ",", event.xbutton.y
    else:
      discard

proc trash*(engine: Engine) =
  vkDestroySwapchainKHR(engine.vulkan.device, engine.vulkan.swapChain, nil);
  vkDestroySurfaceKHR(engine.vulkan.instance, engine.vulkan.surface, nil);
  vkDestroyDevice(engine.vulkan.device, nil)
  vkDestroyInstance(engine.vulkan.instance, nil)
  checkXlibResult engine.display.XDestroyWindow(engine.window)
  discard engine.display.XCloseDisplay() # always returns 0
