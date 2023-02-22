type
  VkPhysicalDevicePortabilitySubsetFeaturesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    constantAlphaColorBlendFactors*: VkBool32
    events*: VkBool32
    imageViewFormatReinterpretation*: VkBool32
    imageViewFormatSwizzle*: VkBool32
    imageView2DOn3DImage*: VkBool32
    multisampleArrayImage*: VkBool32
    mutableComparisonSamplers*: VkBool32
    pointPolygons*: VkBool32
    samplerMipLodBias*: VkBool32
    separateStencilMaskRef*: VkBool32
    shaderSampleRateInterpolationFunctions*: VkBool32
    tessellationIsolines*: VkBool32
    tessellationPointMode*: VkBool32
    triangleFans*: VkBool32
    vertexAttributeAccessBeyondStride*: VkBool32
  VkPhysicalDevicePortabilitySubsetPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    minVertexInputBindingStrideAlignment*: uint32
  VkQueueFamilyVideoPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    videoCodecOperations*: VkVideoCodecOperationFlagsKHR
  VkQueueFamilyQueryResultStatusPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    queryResultStatusSupport*: VkBool32
  VkVideoProfileListInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    profileCount*: uint32
    pProfiles*: ptr VkVideoProfileInfoKHR
  VkPhysicalDeviceVideoFormatInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    imageUsage*: VkImageUsageFlags
  VkVideoFormatPropertiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    format*: VkFormat
    componentMapping*: VkComponentMapping
    imageCreateFlags*: VkImageCreateFlags
    imageType*: VkImageType
    imageTiling*: VkImageTiling
    imageUsageFlags*: VkImageUsageFlags
  VkVideoProfileInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    videoCodecOperation*: VkVideoCodecOperationFlagBitsKHR
    chromaSubsampling*: VkVideoChromaSubsamplingFlagsKHR
    lumaBitDepth*: VkVideoComponentBitDepthFlagsKHR
    chromaBitDepth*: VkVideoComponentBitDepthFlagsKHR
  VkVideoCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoCapabilityFlagsKHR
    minBitstreamBufferOffsetAlignment*: VkDeviceSize
    minBitstreamBufferSizeAlignment*: VkDeviceSize
    pictureAccessGranularity*: VkExtent2D
    minCodedExtent*: VkExtent2D
    maxCodedExtent*: VkExtent2D
    maxDpbSlots*: uint32
    maxActiveReferencePictures*: uint32
    stdHeaderVersion*: VkExtensionProperties
  VkVideoSessionMemoryRequirementsKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryBindIndex*: uint32
    memoryRequirements*: VkMemoryRequirements
  VkBindVideoSessionMemoryInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    memoryBindIndex*: uint32
    memory*: VkDeviceMemory
    memoryOffset*: VkDeviceSize
    memorySize*: VkDeviceSize
  VkVideoPictureResourceInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    codedOffset*: VkOffset2D
    codedExtent*: VkExtent2D
    baseArrayLayer*: uint32
    imageViewBinding*: VkImageView
  VkVideoReferenceSlotInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    slotIndex*: int32
    pPictureResource*: ptr VkVideoPictureResourceInfoKHR
  VkVideoDecodeCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoDecodeCapabilityFlagsKHR
  VkVideoDecodeUsageInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    videoUsageHints*: VkVideoDecodeUsageFlagsKHR
  VkVideoDecodeInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoDecodeFlagsKHR
    srcBuffer*: VkBuffer
    srcBufferOffset*: VkDeviceSize
    srcBufferRange*: VkDeviceSize
    dstPictureResource*: VkVideoPictureResourceInfoKHR
    pSetupReferenceSlot*: ptr VkVideoReferenceSlotInfoKHR
    referenceSlotCount*: uint32
    pReferenceSlots*: ptr VkVideoReferenceSlotInfoKHR
  VkVideoDecodeH264ProfileInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    stdProfileIdc*: StdVideoH264ProfileIdc
    pictureLayout*: VkVideoDecodeH264PictureLayoutFlagBitsKHR
  VkVideoDecodeH264CapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxLevelIdc*: StdVideoH264LevelIdc
    fieldOffsetGranularity*: VkOffset2D
  VkVideoDecodeH264SessionParametersAddInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    stdSPSCount*: uint32
    pStdSPSs*: ptr StdVideoH264SequenceParameterSet
    stdPPSCount*: uint32
    pStdPPSs*: ptr StdVideoH264PictureParameterSet
  VkVideoDecodeH264SessionParametersCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxStdSPSCount*: uint32
    maxStdPPSCount*: uint32
    pParametersAddInfo*: ptr VkVideoDecodeH264SessionParametersAddInfoKHR
  VkVideoDecodeH264PictureInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pStdPictureInfo*: ptr StdVideoDecodeH264PictureInfo
    sliceCount*: uint32
    pSliceOffsets*: ptr uint32
  VkVideoDecodeH264DpbSlotInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pStdReferenceInfo*: ptr StdVideoDecodeH264ReferenceInfo
  VkVideoDecodeH265ProfileInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    stdProfileIdc*: StdVideoH265ProfileIdc
  VkVideoDecodeH265CapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxLevelIdc*: StdVideoH265LevelIdc
  VkVideoDecodeH265SessionParametersAddInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    stdVPSCount*: uint32
    pStdVPSs*: ptr StdVideoH265VideoParameterSet
    stdSPSCount*: uint32
    pStdSPSs*: ptr StdVideoH265SequenceParameterSet
    stdPPSCount*: uint32
    pStdPPSs*: ptr StdVideoH265PictureParameterSet
  VkVideoDecodeH265SessionParametersCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    maxStdVPSCount*: uint32
    maxStdSPSCount*: uint32
    maxStdPPSCount*: uint32
    pParametersAddInfo*: ptr VkVideoDecodeH265SessionParametersAddInfoKHR
  VkVideoDecodeH265PictureInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pStdPictureInfo*: ptr StdVideoDecodeH265PictureInfo
    sliceSegmentCount*: uint32
    pSliceSegmentOffsets*: ptr uint32
  VkVideoDecodeH265DpbSlotInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    pStdReferenceInfo*: ptr StdVideoDecodeH265ReferenceInfo
  VkVideoSessionCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    queueFamilyIndex*: uint32
    flags*: VkVideoSessionCreateFlagsKHR
    pVideoProfile*: ptr VkVideoProfileInfoKHR
    pictureFormat*: VkFormat
    maxCodedExtent*: VkExtent2D
    referencePictureFormat*: VkFormat
    maxDpbSlots*: uint32
    maxActiveReferencePictures*: uint32
    pStdHeaderVersion*: ptr VkExtensionProperties
  VkVideoSessionParametersCreateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoSessionParametersCreateFlagsKHR
    videoSessionParametersTemplate*: VkVideoSessionParametersKHR
    videoSession*: VkVideoSessionKHR
  VkVideoSessionParametersUpdateInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    updateSequenceCount*: uint32
  VkVideoBeginCodingInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoBeginCodingFlagsKHR
    videoSession*: VkVideoSessionKHR
    videoSessionParameters*: VkVideoSessionParametersKHR
    referenceSlotCount*: uint32
    pReferenceSlots*: ptr VkVideoReferenceSlotInfoKHR
  VkVideoEndCodingInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEndCodingFlagsKHR
  VkVideoCodingControlInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoCodingControlFlagsKHR
  VkVideoEncodeUsageInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    videoUsageHints*: VkVideoEncodeUsageFlagsKHR
    videoContentHints*: VkVideoEncodeContentFlagsKHR
    tuningMode*: VkVideoEncodeTuningModeKHR
  VkVideoEncodeInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEncodeFlagsKHR
    qualityLevel*: uint32
    dstBitstreamBuffer*: VkBuffer
    dstBitstreamBufferOffset*: VkDeviceSize
    dstBitstreamBufferMaxRange*: VkDeviceSize
    srcPictureResource*: VkVideoPictureResourceInfoKHR
    pSetupReferenceSlot*: ptr VkVideoReferenceSlotInfoKHR
    referenceSlotCount*: uint32
    pReferenceSlots*: ptr VkVideoReferenceSlotInfoKHR
    precedingExternallyEncodedBytes*: uint32
  VkVideoEncodeRateControlInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEncodeRateControlFlagsKHR
    rateControlMode*: VkVideoEncodeRateControlModeFlagBitsKHR
    layerCount*: uint8
    pLayerConfigs*: ptr VkVideoEncodeRateControlLayerInfoKHR
  VkVideoEncodeRateControlLayerInfoKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    averageBitrate*: uint32
    maxBitrate*: uint32
    frameRateNumerator*: uint32
    frameRateDenominator*: uint32
    virtualBufferSizeInMs*: uint32
    initialVirtualBufferSizeInMs*: uint32
  VkVideoEncodeCapabilitiesKHR* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEncodeCapabilityFlagsKHR
    rateControlModes*: VkVideoEncodeRateControlModeFlagsKHR
    rateControlLayerCount*: uint8
    qualityLevelCount*: uint8
    inputImageDataFillAlignment*: VkExtent2D
  VkVideoEncodeH264CapabilitiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEncodeH264CapabilityFlagsEXT
    inputModeFlags*: VkVideoEncodeH264InputModeFlagsEXT
    outputModeFlags*: VkVideoEncodeH264OutputModeFlagsEXT
    maxPPictureL0ReferenceCount*: uint8
    maxBPictureL0ReferenceCount*: uint8
    maxL1ReferenceCount*: uint8
    motionVectorsOverPicBoundariesFlag*: VkBool32
    maxBytesPerPicDenom*: uint32
    maxBitsPerMbDenom*: uint32
    log2MaxMvLengthHorizontal*: uint32
    log2MaxMvLengthVertical*: uint32
  VkVideoEncodeH264SessionParametersAddInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    stdSPSCount*: uint32
    pStdSPSs*: ptr StdVideoH264SequenceParameterSet
    stdPPSCount*: uint32
    pStdPPSs*: ptr StdVideoH264PictureParameterSet
  VkVideoEncodeH264SessionParametersCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxStdSPSCount*: uint32
    maxStdPPSCount*: uint32
    pParametersAddInfo*: ptr VkVideoEncodeH264SessionParametersAddInfoEXT
  VkVideoEncodeH264DpbSlotInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    slotIndex*: int8
    pStdReferenceInfo*: ptr StdVideoEncodeH264ReferenceInfo
  VkVideoEncodeH264VclFrameInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pReferenceFinalLists*: ptr VkVideoEncodeH264ReferenceListsInfoEXT
    naluSliceEntryCount*: uint32
    pNaluSliceEntries*: ptr VkVideoEncodeH264NaluSliceInfoEXT
    pCurrentPictureInfo*: ptr StdVideoEncodeH264PictureInfo
  VkVideoEncodeH264ReferenceListsInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    referenceList0EntryCount*: uint8
    pReferenceList0Entries*: ptr VkVideoEncodeH264DpbSlotInfoEXT
    referenceList1EntryCount*: uint8
    pReferenceList1Entries*: ptr VkVideoEncodeH264DpbSlotInfoEXT
    pMemMgmtCtrlOperations*: ptr StdVideoEncodeH264RefMemMgmtCtrlOperations
  VkVideoEncodeH264EmitPictureParametersInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    spsId*: uint8
    emitSpsEnable*: VkBool32
    ppsIdEntryCount*: uint32
    ppsIdEntries*: ptr uint8
  VkVideoEncodeH264ProfileInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    stdProfileIdc*: StdVideoH264ProfileIdc
  VkVideoEncodeH264NaluSliceInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    mbCount*: uint32
    pReferenceFinalLists*: ptr VkVideoEncodeH264ReferenceListsInfoEXT
    pSliceHeaderStd*: ptr StdVideoEncodeH264SliceHeader
  VkVideoEncodeH264RateControlInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    gopFrameCount*: uint32
    idrPeriod*: uint32
    consecutiveBFrameCount*: uint32
    rateControlStructure*: VkVideoEncodeH264RateControlStructureEXT
    temporalLayerCount*: uint8
  VkVideoEncodeH264QpEXT* = object
    qpI*: int32
    qpP*: int32
    qpB*: int32
  VkVideoEncodeH264FrameSizeEXT* = object
    frameISize*: uint32
    framePSize*: uint32
    frameBSize*: uint32
  VkVideoEncodeH264RateControlLayerInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    temporalLayerId*: uint8
    useInitialRcQp*: VkBool32
    initialRcQp*: VkVideoEncodeH264QpEXT
    useMinQp*: VkBool32
    minQp*: VkVideoEncodeH264QpEXT
    useMaxQp*: VkBool32
    maxQp*: VkVideoEncodeH264QpEXT
    useMaxFrameSize*: VkBool32
    maxFrameSize*: VkVideoEncodeH264FrameSizeEXT
  VkVideoEncodeH265CapabilitiesEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    flags*: VkVideoEncodeH265CapabilityFlagsEXT
    inputModeFlags*: VkVideoEncodeH265InputModeFlagsEXT
    outputModeFlags*: VkVideoEncodeH265OutputModeFlagsEXT
    ctbSizes*: VkVideoEncodeH265CtbSizeFlagsEXT
    transformBlockSizes*: VkVideoEncodeH265TransformBlockSizeFlagsEXT
    maxPPictureL0ReferenceCount*: uint8
    maxBPictureL0ReferenceCount*: uint8
    maxL1ReferenceCount*: uint8
    maxSubLayersCount*: uint8
    minLog2MinLumaCodingBlockSizeMinus3*: uint8
    maxLog2MinLumaCodingBlockSizeMinus3*: uint8
    minLog2MinLumaTransformBlockSizeMinus2*: uint8
    maxLog2MinLumaTransformBlockSizeMinus2*: uint8
    minMaxTransformHierarchyDepthInter*: uint8
    maxMaxTransformHierarchyDepthInter*: uint8
    minMaxTransformHierarchyDepthIntra*: uint8
    maxMaxTransformHierarchyDepthIntra*: uint8
    maxDiffCuQpDeltaDepth*: uint8
    minMaxNumMergeCand*: uint8
    maxMaxNumMergeCand*: uint8
  VkVideoEncodeH265SessionParametersAddInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    stdVPSCount*: uint32
    pStdVPSs*: ptr StdVideoH265VideoParameterSet
    stdSPSCount*: uint32
    pStdSPSs*: ptr StdVideoH265SequenceParameterSet
    stdPPSCount*: uint32
    pStdPPSs*: ptr StdVideoH265PictureParameterSet
  VkVideoEncodeH265SessionParametersCreateInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    maxStdVPSCount*: uint32
    maxStdSPSCount*: uint32
    maxStdPPSCount*: uint32
    pParametersAddInfo*: ptr VkVideoEncodeH265SessionParametersAddInfoEXT
  VkVideoEncodeH265VclFrameInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    pReferenceFinalLists*: ptr VkVideoEncodeH265ReferenceListsInfoEXT
    naluSliceSegmentEntryCount*: uint32
    pNaluSliceSegmentEntries*: ptr VkVideoEncodeH265NaluSliceSegmentInfoEXT
    pCurrentPictureInfo*: ptr StdVideoEncodeH265PictureInfo
  VkVideoEncodeH265EmitPictureParametersInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    vpsId*: uint8
    spsId*: uint8
    emitVpsEnable*: VkBool32
    emitSpsEnable*: VkBool32
    ppsIdEntryCount*: uint32
    ppsIdEntries*: ptr uint8
  VkVideoEncodeH265NaluSliceSegmentInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    ctbCount*: uint32
    pReferenceFinalLists*: ptr VkVideoEncodeH265ReferenceListsInfoEXT
    pSliceSegmentHeaderStd*: ptr StdVideoEncodeH265SliceSegmentHeader
  VkVideoEncodeH265RateControlInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    gopFrameCount*: uint32
    idrPeriod*: uint32
    consecutiveBFrameCount*: uint32
    rateControlStructure*: VkVideoEncodeH265RateControlStructureEXT
    subLayerCount*: uint8
  VkVideoEncodeH265QpEXT* = object
    qpI*: int32
    qpP*: int32
    qpB*: int32
  VkVideoEncodeH265FrameSizeEXT* = object
    frameISize*: uint32
    framePSize*: uint32
    frameBSize*: uint32
  VkVideoEncodeH265RateControlLayerInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    temporalId*: uint8
    useInitialRcQp*: VkBool32
    initialRcQp*: VkVideoEncodeH265QpEXT
    useMinQp*: VkBool32
    minQp*: VkVideoEncodeH265QpEXT
    useMaxQp*: VkBool32
    maxQp*: VkVideoEncodeH265QpEXT
    useMaxFrameSize*: VkBool32
    maxFrameSize*: VkVideoEncodeH265FrameSizeEXT
  VkVideoEncodeH265ProfileInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    stdProfileIdc*: StdVideoH265ProfileIdc
  VkVideoEncodeH265DpbSlotInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    slotIndex*: int8
    pStdReferenceInfo*: ptr StdVideoEncodeH265ReferenceInfo
  VkVideoEncodeH265ReferenceListsInfoEXT* = object
    sType*: VkStructureType
    pNext*: pointer
    referenceList0EntryCount*: uint8
    pReferenceList0Entries*: ptr VkVideoEncodeH265DpbSlotInfoEXT
    referenceList1EntryCount*: uint8
    pReferenceList1Entries*: ptr VkVideoEncodeH265DpbSlotInfoEXT
    pReferenceModifications*: ptr StdVideoEncodeH265ReferenceModifications
  StdVideoH264ProfileIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264LevelIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264ChromaFormatIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264PocType *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264SpsFlags *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264ScalingLists *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264SequenceParameterSetVui *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264AspectRatioIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264HrdParameters *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264SpsVuiFlags *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264WeightedBipredIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264PpsFlags *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264SliceType *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264CabacInitIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264DisableDeblockingFilterIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264PictureType *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264ModificationOfPicNumsIdc *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264MemMgmtControlOp *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoDecodeH264PictureInfo *{.header: "vk_video/vulkan_video_codec_h264std_decode.h".} = object
  StdVideoDecodeH264ReferenceInfo *{.header: "vk_video/vulkan_video_codec_h264std_decode.h".} = object
  StdVideoDecodeH264PictureInfoFlags *{.header: "vk_video/vulkan_video_codec_h264std_decode.h".} = object
  StdVideoDecodeH264ReferenceInfoFlags *{.header: "vk_video/vulkan_video_codec_h264std_decode.h".} = object
  StdVideoH264SequenceParameterSet *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH264PictureParameterSet *{.header: "vk_video/vulkan_video_codec_h264std.h".} = object
  StdVideoH265ProfileIdc *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265VideoParameterSet *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SequenceParameterSet *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265PictureParameterSet *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265DecPicBufMgr *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265HrdParameters *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265VpsFlags *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265LevelIdc *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SpsFlags *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265ScalingLists *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SequenceParameterSetVui *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265PredictorPaletteEntries *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265PpsFlags *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SubLayerHrdParameters *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265HrdFlags *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SpsVuiFlags *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265SliceType *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoH265PictureType *{.header: "vk_video/vulkan_video_codec_h265std.h".} = object
  StdVideoDecodeH265PictureInfo *{.header: "vk_video/vulkan_video_codec_h265std_decode.h".} = object
  StdVideoDecodeH265ReferenceInfo *{.header: "vk_video/vulkan_video_codec_h265std_decode.h".} = object
  StdVideoDecodeH265PictureInfoFlags *{.header: "vk_video/vulkan_video_codec_h265std_decode.h".} = object
  StdVideoDecodeH265ReferenceInfoFlags *{.header: "vk_video/vulkan_video_codec_h265std_decode.h".} = object
  StdVideoEncodeH264SliceHeader *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264PictureInfo *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264ReferenceInfo *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264SliceHeaderFlags *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264RefMemMgmtCtrlOperations *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264PictureInfoFlags *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264ReferenceInfoFlags *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264RefMgmtFlags *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264RefListModEntry *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH264RefPicMarkingEntry *{.header: "vk_video/vulkan_video_codec_h264std_encode.h".} = object
  StdVideoEncodeH265PictureInfoFlags *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265PictureInfo *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265SliceSegmentHeader *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265ReferenceInfo *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265ReferenceModifications *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265SliceSegmentHeaderFlags *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265ReferenceInfoFlags *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
  StdVideoEncodeH265ReferenceModificationFlags *{.header: "vk_video/vulkan_video_codec_h265std_encode.h".} = object
# extension VK_KHR_video_queue
var
  vkGetPhysicalDeviceVideoCapabilitiesKHR*: proc(physicalDevice: VkPhysicalDevice, pVideoProfile: ptr VkVideoProfileInfoKHR, pCapabilities: ptr VkVideoCapabilitiesKHR): VkResult {.stdcall.}
  vkGetPhysicalDeviceVideoFormatPropertiesKHR*: proc(physicalDevice: VkPhysicalDevice, pVideoFormatInfo: ptr VkPhysicalDeviceVideoFormatInfoKHR, pVideoFormatPropertyCount: ptr uint32, pVideoFormatProperties: ptr VkVideoFormatPropertiesKHR): VkResult {.stdcall.}
  vkCreateVideoSessionKHR*: proc(device: VkDevice, pCreateInfo: ptr VkVideoSessionCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pVideoSession: ptr VkVideoSessionKHR): VkResult {.stdcall.}
  vkDestroyVideoSessionKHR*: proc(device: VkDevice, videoSession: VkVideoSessionKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkGetVideoSessionMemoryRequirementsKHR*: proc(device: VkDevice, videoSession: VkVideoSessionKHR, pMemoryRequirementsCount: ptr uint32, pMemoryRequirements: ptr VkVideoSessionMemoryRequirementsKHR): VkResult {.stdcall.}
  vkBindVideoSessionMemoryKHR*: proc(device: VkDevice, videoSession: VkVideoSessionKHR, bindSessionMemoryInfoCount: uint32, pBindSessionMemoryInfos: ptr VkBindVideoSessionMemoryInfoKHR): VkResult {.stdcall.}
  vkCreateVideoSessionParametersKHR*: proc(device: VkDevice, pCreateInfo: ptr VkVideoSessionParametersCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pVideoSessionParameters: ptr VkVideoSessionParametersKHR): VkResult {.stdcall.}
  vkUpdateVideoSessionParametersKHR*: proc(device: VkDevice, videoSessionParameters: VkVideoSessionParametersKHR, pUpdateInfo: ptr VkVideoSessionParametersUpdateInfoKHR): VkResult {.stdcall.}
  vkDestroyVideoSessionParametersKHR*: proc(device: VkDevice, videoSessionParameters: VkVideoSessionParametersKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}
  vkCmdBeginVideoCodingKHR*: proc(commandBuffer: VkCommandBuffer, pBeginInfo: ptr VkVideoBeginCodingInfoKHR): void {.stdcall.}
  vkCmdEndVideoCodingKHR*: proc(commandBuffer: VkCommandBuffer, pEndCodingInfo: ptr VkVideoEndCodingInfoKHR): void {.stdcall.}
  vkCmdControlVideoCodingKHR*: proc(commandBuffer: VkCommandBuffer, pCodingControlInfo: ptr VkVideoCodingControlInfoKHR): void {.stdcall.}
proc loadVK_KHR_video_queue*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)
  loadVK_VERSION_1_3(instance)
  vkGetPhysicalDeviceVideoCapabilitiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pVideoProfile: ptr VkVideoProfileInfoKHR, pCapabilities: ptr VkVideoCapabilitiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceVideoCapabilitiesKHR"))
  vkGetPhysicalDeviceVideoFormatPropertiesKHR = cast[proc(physicalDevice: VkPhysicalDevice, pVideoFormatInfo: ptr VkPhysicalDeviceVideoFormatInfoKHR, pVideoFormatPropertyCount: ptr uint32, pVideoFormatProperties: ptr VkVideoFormatPropertiesKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceVideoFormatPropertiesKHR"))
  vkCreateVideoSessionKHR = cast[proc(device: VkDevice, pCreateInfo: ptr VkVideoSessionCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pVideoSession: ptr VkVideoSessionKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateVideoSessionKHR"))
  vkDestroyVideoSessionKHR = cast[proc(device: VkDevice, videoSession: VkVideoSessionKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyVideoSessionKHR"))
  vkGetVideoSessionMemoryRequirementsKHR = cast[proc(device: VkDevice, videoSession: VkVideoSessionKHR, pMemoryRequirementsCount: ptr uint32, pMemoryRequirements: ptr VkVideoSessionMemoryRequirementsKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkGetVideoSessionMemoryRequirementsKHR"))
  vkBindVideoSessionMemoryKHR = cast[proc(device: VkDevice, videoSession: VkVideoSessionKHR, bindSessionMemoryInfoCount: uint32, pBindSessionMemoryInfos: ptr VkBindVideoSessionMemoryInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkBindVideoSessionMemoryKHR"))
  vkCreateVideoSessionParametersKHR = cast[proc(device: VkDevice, pCreateInfo: ptr VkVideoSessionParametersCreateInfoKHR, pAllocator: ptr VkAllocationCallbacks, pVideoSessionParameters: ptr VkVideoSessionParametersKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCreateVideoSessionParametersKHR"))
  vkUpdateVideoSessionParametersKHR = cast[proc(device: VkDevice, videoSessionParameters: VkVideoSessionParametersKHR, pUpdateInfo: ptr VkVideoSessionParametersUpdateInfoKHR): VkResult {.stdcall.}](vkGetInstanceProcAddr(instance, "vkUpdateVideoSessionParametersKHR"))
  vkDestroyVideoSessionParametersKHR = cast[proc(device: VkDevice, videoSessionParameters: VkVideoSessionParametersKHR, pAllocator: ptr VkAllocationCallbacks): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkDestroyVideoSessionParametersKHR"))
  vkCmdBeginVideoCodingKHR = cast[proc(commandBuffer: VkCommandBuffer, pBeginInfo: ptr VkVideoBeginCodingInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdBeginVideoCodingKHR"))
  vkCmdEndVideoCodingKHR = cast[proc(commandBuffer: VkCommandBuffer, pEndCodingInfo: ptr VkVideoEndCodingInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEndVideoCodingKHR"))
  vkCmdControlVideoCodingKHR = cast[proc(commandBuffer: VkCommandBuffer, pCodingControlInfo: ptr VkVideoCodingControlInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdControlVideoCodingKHR"))

# extension VK_KHR_video_encode_queue
var
  vkCmdEncodeVideoKHR*: proc(commandBuffer: VkCommandBuffer, pEncodeInfo: ptr VkVideoEncodeInfoKHR): void {.stdcall.}
proc loadVK_KHR_video_encode_queue*(instance: VkInstance) =
  loadVK_KHR_video_queue(instance)
  loadVK_VERSION_1_3(instance)
  vkCmdEncodeVideoKHR = cast[proc(commandBuffer: VkCommandBuffer, pEncodeInfo: ptr VkVideoEncodeInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdEncodeVideoKHR"))

# extension VK_KHR_video_decode_queue
var
  vkCmdDecodeVideoKHR*: proc(commandBuffer: VkCommandBuffer, pDecodeInfo: ptr VkVideoDecodeInfoKHR): void {.stdcall.}
proc loadVK_KHR_video_decode_queue*(instance: VkInstance) =
  loadVK_KHR_video_queue(instance)
  loadVK_VERSION_1_3(instance)
  vkCmdDecodeVideoKHR = cast[proc(commandBuffer: VkCommandBuffer, pDecodeInfo: ptr VkVideoDecodeInfoKHR): void {.stdcall.}](vkGetInstanceProcAddr(instance, "vkCmdDecodeVideoKHR"))

proc loadVK_KHR_portability_subset*(instance: VkInstance) =
  loadVK_VERSION_1_1(instance)

proc loadVK_EXT_video_encode_h264*(instance: VkInstance) =
  loadVK_KHR_video_encode_queue(instance)

proc loadVK_EXT_video_encode_h265*(instance: VkInstance) =
  loadVK_KHR_video_encode_queue(instance)

proc loadVK_KHR_video_decode_h265*(instance: VkInstance) =
  loadVK_KHR_video_decode_queue(instance)

proc loadVK_KHR_video_decode_h264*(instance: VkInstance) =
  loadVK_KHR_video_decode_queue(instance)
