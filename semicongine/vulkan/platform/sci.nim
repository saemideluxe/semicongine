type
  VkExportMemorySciBufInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: NvSciBufAttrList
  VkImportMemorySciBufInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    handleType*: VkExternalMemoryHandleTypeFlagBits
    handle*: NvSciBufObj
  VkMemoryGetSciBufInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    memory*: VkDeviceMemory
    handleType*: VkExternalMemoryHandleTypeFlagBits
  VkMemorySciBufPropertiesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryTypeBits*: uint32
  VkPhysicalDeviceExternalMemorySciBufFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    sciBufImport*: VkBool32
    sciBufExport*: VkBool32
  VkPhysicalDeviceExternalSciBufFeaturesNV* = object
  VkExportFenceSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: NvSciSyncAttrList
  VkImportFenceSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    handleType*: VkExternalFenceHandleTypeFlagBits
    handle*: pointer
  VkFenceGetSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    fence*: VkFence
    handleType*: VkExternalFenceHandleTypeFlagBits
  VkExportSemaphoreSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    pAttributes*: NvSciSyncAttrList
  VkImportSemaphoreSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
    handle*: pointer
  VkSemaphoreGetSciSyncInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphore*: VkSemaphore
    handleType*: VkExternalSemaphoreHandleTypeFlagBits
  VkSciSyncAttributesInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    clientType*: VkSciSyncClientTypeNV
    primitiveType*: VkSciSyncPrimitiveTypeNV
  VkPhysicalDeviceExternalSciSyncFeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    sciSyncFence*: VkBool32
    sciSyncSemaphore*: VkBool32
    sciSyncImport*: VkBool32
    sciSyncExport*: VkBool32
  VkPhysicalDeviceExternalSciSync2FeaturesNV* = object
    sType*: VkStructureType
    pNext*: pointer
    sciSyncFence*: VkBool32
    sciSyncSemaphore2*: VkBool32
    sciSyncImport*: VkBool32
    sciSyncExport*: VkBool32
  VkSemaphoreSciSyncPoolCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    handle*: NvSciSyncObj
  VkSemaphoreSciSyncCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphorePool*: VkSemaphoreSciSyncPoolNV
    pFence*: ptr NvSciSyncFence
  VkDeviceSemaphoreSciSyncPoolReservationCreateInfoNV* = object
    sType*: VkStructureType
    pNext*: pointer
    semaphoreSciSyncPoolRequestCount*: uint32
  NvSciSyncAttrList *{.header: "nvscisync.h".} = object
  NvSciSyncObj *{.header: "nvscisync.h".} = object
  NvSciSyncFence *{.header: "nvscisync.h".} = object
  NvSciBufAttrList *{.header: "nvscibuf.h".} = object
  NvSciBufObj *{.header: "nvscibuf.h".} = object