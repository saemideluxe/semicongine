type
  VkWin32SurfaceCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkWin32SurfaceCreateFlagsKHR
    hinstance*: HINSTANCE
    hwnd*: HWND
  VkImportMemoryWin32HandleInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagsNV
    handle*: HANDLE
  VkExportMemoryWin32HandleInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: ptr SECURITY_ATTRIBUTES
    dwAccess*: DWORD
  VkWin32KeyedMutexAcquireReleaseInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    acquireCount*: uint32
    pAcquireSyncs*: ptr VkDeviceMemory
    pAcquireKeys*: ptr uint64
    pAcquireTimeoutMilliseconds*: ptr uint32
    releaseCount*: uint32
    pReleaseSyncs*: ptr VkDeviceMemory
    pReleaseKeys*: ptr uint64
  VkImportMemoryWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
    handle*: HANDLE
    name*: LPCWSTR
  VkExportMemoryWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: ptr SECURITY_ATTRIBUTES
    dwAccess*: DWORD
    name*: LPCWSTR
  VkMemoryWin32HandlePropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
  VkMemoryGetWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkWin32KeyedMutexAcquireReleaseInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    acquireCount*: uint32
    pAcquireSyncs*: ptr VkDeviceMemory
    pAcquireKeys*: ptr uint64
    pAcquireTimeouts*: ptr uint32
    releaseCount*: uint32
    pReleaseSyncs*: ptr VkDeviceMemory
    pReleaseKeys*: ptr uint64
  VkImportSemaphoreWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    flags*: VkSemaphoreImportFlags
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
    handle*: HANDLE
    name*: LPCWSTR
  VkExportSemaphoreWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: ptr SECURITY_ATTRIBUTES
    dwAccess*: DWORD
    name*: LPCWSTR
  VkD3D12FenceSubmitInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    waitSemaphoreValuesCount*: uint32
    pWaitSemaphoreValues*: ptr uint64
    signalSemaphoreValuesCount*: uint32
    pSignalSemaphoreValues*: ptr uint64
  VkSemaphoreGetWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
  VkImportFenceWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    flags*: VkFenceImportFlags
    handleType*: VkExternalFenceHandleTypeFlagBits
    handle*: HANDLE
    name*: LPCWSTR
  VkExportFenceWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: ptr SECURITY_ATTRIBUTES
    dwAccess*: DWORD
    name*: LPCWSTR
  VkFenceGetWin32HandleInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    handleType*: VkExternalFenceHandleTypeFlagBits
  VkSurfaceFullScreenExclusiveInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fullScreenExclusive*: VkFullScreenExclusiveEXT
  VkSurfaceFullScreenExclusiveWin32InfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    hmonitor*: HMONITOR
  VkSurfaceCapabilitiesFullScreenExclusiveEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    fullScreenExclusiveSupported*: VkBool32
  HINSTANCE *{.header: "windows.h".} = object
  HWND *{.header: "windows.h".} = object
  HMONITOR *{.header: "windows.h".} = object
  HANDLE *{.header: "windows.h".} = object
  SECURITY_ATTRIBUTES *{.header: "windows.h".} = object
  DWORD *{.header: "windows.h".} = object
  LPCWSTR *{.header: "windows.h".} = object
# extension VK_KHR_external_semaphore_win32
var
  vkImportSemaphoreWin32HandleKHR*: proc(device: VkDevice, pImportSemaphoreWin32HandleInfo: ptr VkImportSemaphoreWin32HandleInfoKHR): VkResult {.stdcall.}
  vkGetSemaphoreWin32HandleKHR*: proc(device: VkDevice, pGetWin32HandleInfo: ptr VkSemaphoreGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}
proc loadVK_KHR_external_semaphore_win32*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkImportSemaphoreWin32HandleKHR = cast[proc(device: VkDevice, pImportSemaphoreWin32HandleInfo: ptr VkImportSemaphoreWin32HandleInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkImportSemaphoreWin32HandleKHR"))
  vkGetSemaphoreWin32HandleKHR = cast[proc(device: VkDevice, pGetWin32HandleInfo: ptr VkSemaphoreGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetSemaphoreWin32HandleKHR"))

# extension VK_KHR_external_memory_win32
var
  vkGetMemoryWin32HandleKHR*: proc(device: VkDevice, pGetWin32HandleInfo: ptr VkMemoryGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}
  vkGetMemoryWin32HandlePropertiesKHR*: proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, handle: HANDLE, pMemoryWin32HandleProperties: ptr VkMemoryWin32HandlePropertiesKHR): VkResult {.stdcall.}
proc loadVK_KHR_external_memory_win32*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkGetMemoryWin32HandleKHR = cast[proc(device: VkDevice, pGetWin32HandleInfo: ptr VkMemoryGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryWin32HandleKHR"))
  vkGetMemoryWin32HandlePropertiesKHR = cast[proc(device: VkDevice, handleType: VkExternalMemoryHandleTypeFlagBits, handle: HANDLE, pMemoryWin32HandleProperties: ptr VkMemoryWin32HandlePropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryWin32HandlePropertiesKHR"))

# extension VK_KHR_external_fence_win32
var
  vkImportFenceWin32HandleKHR*: proc(device: VkDevice, pImportFenceWin32HandleInfo: ptr VkImportFenceWin32HandleInfoKHR): VkResult {.stdcall.}
  vkGetFenceWin32HandleKHR*: proc(device: VkDevice, pGetWin32HandleInfo: ptr VkFenceGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}
proc loadVK_KHR_external_fence_win32*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  vkImportFenceWin32HandleKHR = cast[proc(device: VkDevice, pImportFenceWin32HandleInfo: ptr VkImportFenceWin32HandleInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkImportFenceWin32HandleKHR"))
  vkGetFenceWin32HandleKHR = cast[proc(device: VkDevice, pGetWin32HandleInfo: ptr VkFenceGetWin32HandleInfoKHR, pHandle: ptr HANDLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetFenceWin32HandleKHR"))

proc loadVK_KHR_win32_keyed_mutex*(instance: VkInstance) =
  loadVK_KHR_external_memory_win32(instance)

# extension VK_NV_external_memory_win32
var
  vkGetMemoryWin32HandleNV*: proc(device: VkDevice, memory: VkDeviceMemory, handleType: VkExternalMemoryHandleTypeFlagsNV, pHandle: ptr HANDLE): VkResult {.stdcall.}
proc loadVK_NV_external_memory_win32*(instance: VkInstance) =
  loadVK_NV_external_memory(instance)
  vkGetMemoryWin32HandleNV = cast[proc(device: VkDevice, memory: VkDeviceMemory, handleType: VkExternalMemoryHandleTypeFlagsNV, pHandle: ptr HANDLE): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetMemoryWin32HandleNV"))

# extension VK_EXT_full_screen_exclusive
var
  vkGetPhysicalDeviceSurfacePresentModes2EXT*: proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pPresentModeCount: ptr uint32, pPresentModes: ptr VkPresentModeKHR): VkResult {.stdcall.}
  vkAcquireFullScreenExclusiveModeEXT*: proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}
  vkReleaseFullScreenExclusiveModeEXT*: proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}
  vkGetDeviceGroupSurfacePresentModes2EXT*: proc(device: VkDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pModes: ptr VkDeviceGroupPresentModeFlagsKHR): VkResult {.stdcall.}
proc loadVK_EXT_full_screen_exclusive*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_KHR_surface(instance)
  loadVK_KHR_get_surface_capabilities2(instance)
  loadVK_KHR_swapchain(instance)
  vkGetPhysicalDeviceSurfacePresentModes2EXT = cast[proc(physicalDevice: VkPhysicalDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pPresentModeCount: ptr uint32, pPresentModes: ptr VkPresentModeKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModes2EXT"))
  vkAcquireFullScreenExclusiveModeEXT = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireFullScreenExclusiveModeEXT"))
  vkReleaseFullScreenExclusiveModeEXT = cast[proc(device: VkDevice, swapchain: VkSwapchainKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkReleaseFullScreenExclusiveModeEXT"))
  vkGetDeviceGroupSurfacePresentModes2EXT = cast[proc(device: VkDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pModes: ptr VkDeviceGroupPresentModeFlagsKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceGroupSurfacePresentModes2EXT"))
  vkGetDeviceGroupSurfacePresentModes2EXT = cast[proc(device: VkDevice, pSurfaceInfo: ptr VkPhysicalDeviceSurfaceInfo2KHR, pModes: ptr VkDeviceGroupPresentModeFlagsKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetDeviceGroupSurfacePresentModes2EXT"))

# extension VK_KHR_win32_surface
var
  vkCreateWin32SurfaceKHR*: proc(instance: VkInstance, pCreateInfo: ptr VkWin32SurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceWin32PresentationSupportKHR*: proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32): VkBool32 {.stdcall.}
proc loadVK_KHR_win32_surface*(instance: VkInstance) =
  loadVK_KHR_surface(instance)
  vkCreateWin32SurfaceKHR = cast[proc(instance: VkInstance, pCreateInfo: ptr VkWin32SurfaceCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pSurface: ptr VkSurfaceKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR"))
  vkGetPhysicalDeviceWin32PresentationSupportKHR = cast[proc(physicalDevice: VkPhysicalDevice, queueFamilyIndex: uint32): VkBool32 {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceWin32PresentationSupportKHR"))

# extension VK_NV_acquire_winrt_display
var
  vkAcquireWinrtDisplayNV*: proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR): VkResult {.stdcall.}
  vkGetWinrtDisplayNV*: proc(physicalDevice: VkPhysicalDevice, deviceRelativeId: uint32, pDisplay: ptr VkDisplayKHR): VkResult {.stdcall.}
proc loadVK_NV_acquire_winrt_display*(instance: VkInstance) =
  loadVK_EXT_direct_mode_display(instance)
  vkAcquireWinrtDisplayNV = cast[proc(physicalDevice: VkPhysicalDevice, display: VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkAcquireWinrtDisplayNV"))
  vkGetWinrtDisplayNV = cast[proc(physicalDevice: VkPhysicalDevice, deviceRelativeId: uint32, pDisplay: ptr VkDisplayKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetWinrtDisplayNV"))
