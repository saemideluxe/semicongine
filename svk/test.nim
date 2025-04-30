import ./vkapi

var
  appinfo = VkApplicationInfo(
    pApplicationName: appName,
    pEngineName: "semicongine",
    apiVersion: VK_MAKE_API_VERSION(0, 1, 3, 0),
  )
  createinfo = VkInstanceCreateInfo(
    pApplicationInfo: addr appinfo,
    enabledLayerCount: layers.len.uint32,
    ppEnabledLayerNames: layersC,
    enabledExtensionCount: requiredExtensions.len.uint32,
    ppEnabledExtensionNames: instanceExtensionsC,
  )
checkVkResult vkCreateInstance(addr(createinfo), nil, addr(result.instance))
loadVulkan(result.instance)
