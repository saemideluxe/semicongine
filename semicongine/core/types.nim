import std/json

import ../thirdparty/parsetoml
import ../thirdparty/db_connector/db_sqlite

const
  INFLIGHTFRAMES* = 2'u32
  MAX_DESCRIPTORSETS* = 4
  BUFFER_ALIGNMENT* = 64'u64 # align offsets inside buffers along this alignment
  # ca. 100mb per block, seems reasonable
  MEMORY_BLOCK_ALLOCATION_SIZE* = 100_000_000'u64
  # ca. 9mb per block, seems reasonable, can put 10 buffers into one memory block
  BUFFER_ALLOCATION_SIZE* = 9_000_000'u64
  SURFACE_FORMAT* = VK_FORMAT_B8G8R8A8_SRGB
  DEPTH_FORMAT* = VK_FORMAT_D32_SFLOAT
  PUSH_CONSTANT_SIZE* = 128

# some declaration needed for platform-types
type
  AudioLevel* = 0'f .. 1'f
  Sample* = array[2, int16]
  SoundData* = seq[Sample]
  DescriptorSetIndex* = range[0 .. MAX_DESCRIPTORSETS - 1]

# custom pragmas to classify shader attributes
template VertexAttribute*() {.pragma.}
template InstanceAttribute*() {.pragma.}
template PushConstant*() {.pragma.}
template Pass*() {.pragma.}
template PassFlat*() {.pragma.}
template ShaderOutput*() {.pragma.}
template DescriptorSet*(index: DescriptorSetIndex) {.pragma.}

when defined(windows):
  include ../platform/windows/types
when defined(linux):
  include ../platform/linux/types

type
  # === rendering ===
  SupportedGPUType* =
    float32 | float64 | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 |
    TVec2[int32] | TVec2[int64] | TVec3[int32] | TVec3[int64] | TVec4[int32] |
    TVec4[int64] | TVec2[uint32] | TVec2[uint64] | TVec3[uint32] | TVec3[uint64] |
    TVec4[uint32] | TVec4[uint64] | TVec2[float32] | TVec2[float64] | TVec3[float32] |
    TVec3[float64] | TVec4[float32] | TVec4[float64] | TMat2[float32] | TMat2[float64] |
    TMat23[float32] | TMat23[float64] | TMat32[float32] | TMat32[float64] |
    TMat3[float32] | TMat3[float64] | TMat34[float32] | TMat34[float64] | TMat43[
      float32
    ] | TMat43[float64] | TMat4[float32] | TMat4[float64]

  VulkanObject* = object # populated through InitVulkan proc
    instance*: VkInstance
    device*: VkDevice
    physicalDevice*: VkPhysicalDevice
    surface*: VkSurfaceKHR
    window*: NativeWindow
    graphicsQueueFamily*: uint32
    graphicsQueue*: VkQueue
    debugMessenger*: VkDebugUtilsMessengerEXT
    # populated through the initSwapchain proc
    swapchain*: Swapchain
    # unclear as of yet
    anisotropy*: float32 = 0 # needs to be enable during device creation
    fullscreen_internal*: bool

  RenderPass* = ref object
    vk*: VkRenderPass
    samples*: VkSampleCountFlagBits
    depthBuffer*: bool

  Swapchain* = ref object
    # parameters to initSwapchain, required for swapchain recreation
    renderPass*: RenderPass
    vSync*: bool
    tripleBuffering*: bool
    # populated through initSwapchain proc
    vk*: VkSwapchainKHR
    width*: uint32
    height*: uint32
    framebuffers*: seq[VkFramebuffer]
    framebufferViews*: seq[VkImageView]
    currentFramebufferIndex*: uint32
    commandBufferPool*: VkCommandPool
    # depth buffer stuff, if enabled
    depthImage*: VkImage
    depthImageView*: VkImageView
    depthMemory*: VkDeviceMemory
    # MSAA stuff, if enabled
    msaaImage*: VkImage
    msaaImageView*: VkImageView
    msaaMemory*: VkDeviceMemory
    # frame-in-flight handling
    currentFiF*: range[0 .. (INFLIGHTFRAMES - 1).int]
    queueFinishedFence*: array[INFLIGHTFRAMES.int, VkFence]
    imageAvailableSemaphore*: array[INFLIGHTFRAMES.int, VkSemaphore]
    renderFinishedSemaphore*: array[INFLIGHTFRAMES.int, VkSemaphore]
    commandBuffers*: array[INFLIGHTFRAMES.int, VkCommandBuffer]
    oldSwapchain*: Swapchain
    oldSwapchainCounter*: int # swaps until old swapchain will be destroyed

  # shader related types
  DescriptorSetData*[T: object] = object
    data*: T
    vk*: array[INFLIGHTFRAMES.int, VkDescriptorSet]

  Pipeline*[TShader] = object
    vk*: VkPipeline
    vertexShaderModule*: VkShaderModule
    fragmentShaderModule*: VkShaderModule
    layout*: VkPipelineLayout
    descriptorSetLayouts*: array[MAX_DESCRIPTORSETS, VkDescriptorSetLayout]

  # memory/buffer related types
  BufferType* = enum
    VertexBuffer
    VertexBufferMapped
    IndexBuffer
    IndexBufferMapped
    UniformBuffer
    UniformBufferMapped
    StorageBuffer
    StorageBufferMapped

  MemoryBlock* = object
    vk*: VkDeviceMemory
    size*: uint64
    rawPointer*: pointer # if not nil, this is mapped memory
    offsetNextFree*: uint64

  Buffer* = object
    vk*: VkBuffer
    size*: uint64
    rawPointer*: pointer # if not nil, buffer is using mapped memory
    offsetNextFree*: uint64
    memoryOffset*: uint64
    memory*: VkDeviceMemory

  GPUArray*[T: SupportedGPUType, TBuffer: static BufferType] = object
    # TODO: when using mapped buffer memory, directly write values to mapped location
    # instead of using data as buffer
    data*: seq[T]
    buffer*: Buffer
    offset*: uint64

  GPUValue*[T: object, TBuffer: static BufferType] = object
    data*: T
    buffer*: Buffer
    offset*: uint64

  GPUData* = GPUArray | GPUValue

  RenderDataObject = object
    descriptorPool*: VkDescriptorPool
    memory*: array[VK_MAX_MEMORY_TYPES.int, seq[MemoryBlock]]
    buffers*: array[BufferType, seq[Buffer]]
    images*: seq[VkImage]
    imageViews*: seq[VkImageView]
    samplers*: seq[VkSampler]

  RenderData* = ref RenderDataObject

  # === audio ===
  Playback* = object
    sound*: SoundData
    position*: int
    loop*: bool
    levelLeft*: AudioLevel
    levelRight*: AudioLevel
    paused*: bool

  Track* = object
    playing*: Table[uint64, Playback]
    level*: AudioLevel
    targetLevel*: AudioLevel
    fadeTime*: float
    fadeStep*: float

  Mixer* = object
    playbackCounter*: uint64
    tracks*: Table[string, Track]
    sounds*: Table[string, SoundData]
    level*: AudioLevel
    device*: NativeSoundDevice
    lock*: Lock
    buffers*: seq[SoundData]
    currentBuffer*: int
    lastUpdate*: MonoTime

  # === input + window handling ===
  EventType* = enum
    Quit
    ResizedWindow
    MinimizedWindow
    RestoredWindow
    KeyPressed
    KeyReleased
    MousePressed
    MouseReleased
    MouseWheel
    GotFocus
    LostFocus

  Key* {.size: sizeof(cint), pure.} = enum
    UNKNOWN
    Escape
    F1
    F2
    F3
    F4
    F5
    F6
    F7
    F8
    F9
    F10
    F11
    F12
    NumberRowExtra1
    `1`
    `2`
    `3`
    `4`
    `5`
    `6`
    `7`
    `8`
    `9`
    `0`
    NumberRowExtra2
    NumberRowExtra3 # tilde, minus, plus
    A
    B
    C
    D
    E
    F
    G
    H
    I
    J
    K
    L
    M
    N
    O
    P
    Q
    R
    S
    T
    U
    V
    W
    X
    Y
    Z
    Tab
    CapsLock
    ShiftL
    ShiftR
    CtrlL
    CtrlR
    SuperL
    SuperR
    AltL
    AltR
    Space
    Enter
    Backspace
    LetterRow1Extra1
    LetterRow1Extra2 # open bracket, close brackt, backslash
    LetterRow2Extra1
    LetterRow2Extra2
    LetterRow2Extra3 # semicolon, quote
    LetterRow3Extra1
    LetterRow3Extra2
    LetterRow3Extra3 # comma, period, slash
    Up
    Down
    Left
    Right
    PageUp
    PageDown
    Home
    End
    Insert
    Delete
    PrintScreen
    ScrollLock
    Pause

  MouseButton* {.size: sizeof(cint), pure.} = enum
    UNKNOWN
    Mouse1
    Mouse2
    Mouse3 # Left, middle, right

  Event* = object
    case eventType*: EventType
    of KeyPressed, KeyReleased:
      key*: Key
      char*: Rune
    of MousePressed, MouseReleased:
      button*: MouseButton
    of MouseWheel:
      amount*: float32
    of GotFocus:
      discard
    of LostFocus:
      discard
    else:
      discard

  # === images ===
  Gray* = TVec1[uint8]
  BGRA* = TVec4[uint8]
  PixelType* = Gray | BGRA

  ImageObject*[T: PixelType, IsArray: static bool] = object
    width*: uint32
    height*: uint32
    minInterpolation*: VkFilter = VK_FILTER_LINEAR
    magInterpolation*: VkFilter = VK_FILTER_LINEAR
    wrapU*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    wrapV*: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_REPEAT
    data*: seq[T]
    vk*: VkImage
    imageview*: VkImageView
    sampler*: VkSampler
    isRenderTarget*: bool = false
    samples*: VkSampleCountFlagBits = VK_SAMPLE_COUNT_1_BIT
    when IsArray:
      nLayers*: uint32

  Image*[T: PixelType] = ImageObject[T, false]
  ImageArray*[T: PixelType] = ImageObject[T, true]

  # === fonts ===
  GlyphQuad*[MaxGlyphs: static int] = object
    # vertex offsets to glyph center: [left, bottom, right, top]
    pos*: array[MaxGlyphs, Vec4f]
    uv*: array[MaxGlyphs, Vec4f] # [left, bottom, right, top]

  TextRendering* = object
    aspectRatio*: float32

  GlyphDescriptorSet*[MaxGlyphs: static int] = object
    fontAtlas*: Image[Gray]
    glyphquads*: GPUValue[GlyphQuad[MaxGlyphs], StorageBuffer]

  GlyphShader*[MaxGlyphs: static int] = object
    position {.InstanceAttribute.}: Vec3f
    color {.InstanceAttribute.}: Vec4f
    scale {.InstanceAttribute.}: float32
    glyphIndex {.InstanceAttribute.}: uint16
    textRendering {.PushConstant.}: TextRendering

    fragmentUv {.Pass.}: Vec2f
    fragmentColor {.PassFlat.}: Vec4f
    outColor {.ShaderOutput.}: Vec4f
    glyphData {.DescriptorSet: 3.}: GlyphDescriptorSet[MaxGlyphs]
    vertexCode* =
      """
const int[6] indices = int[](0, 1, 2, 2, 3, 0);
const int[4] i_x = int[](0, 0, 2, 2);
const int[4] i_y = int[](1, 3, 3, 1);
const float epsilon = 0.0000001;

void main() {
  int vertexI = indices[gl_VertexIndex];
  vec3 vertexPos = vec3(
    glyphquads.pos[glyphIndex][i_x[vertexI]] * scale / textRendering.aspectRatio,
    glyphquads.pos[glyphIndex][i_y[vertexI]] * scale,
    0
  );
  // the epsilon-offset is necessary, as otherwise characters with the same Z might overlap, despite transparency
  gl_Position = vec4(vertexPos + position, 1.0);
  gl_Position.z -= gl_InstanceIndex * epsilon;
  gl_Position.z = fract(abs(gl_Position.z));
  vec2 uv = vec2(glyphquads.uv[glyphIndex][i_x[vertexI]], glyphquads.uv[glyphIndex][i_y[vertexI]]);
  fragmentUv = uv;
  fragmentColor = color;
}  """
    fragmentCode* =
      """void main() {
    float a = texture(fontAtlas, fragmentUv).r;
    outColor = vec4(fragmentColor.rgb, fragmentColor.a * a);
}"""

  FontObj*[MaxGlyphs: static int] = object
    advance*: Table[Rune, float32]
    kerning*: Table[(Rune, Rune), float32]
    leftBearing*: Table[Rune, float32]
    lineAdvance*: float32
    lineHeight*: float32 # like lineAdvance - lineGap
    ascent*: float32 # from baseline to highest glyph
    descent*: float32 # from baseline to lowest glyph
    xHeight*: float32 # from baseline to height of lowercase x
    descriptorSet*: DescriptorSetData[GlyphDescriptorSet[MaxGlyphs]]
    descriptorGlyphIndex*: Table[Rune, uint16]
    descriptorGlyphIndexRev*: Table[uint16, Rune] # only used for debugging atm
    fallbackCharacter*: Rune

  Font*[MaxGlyphs: static int] = ref FontObj[MaxGlyphs]

  TextHandle* = object
    index*: uint32
    generation*: uint32

  TextAlignment* = enum
    Left
    Center
    Right

  Text* = object
    bufferOffset*: int
    text*: seq[Rune]
    position*: Vec3f = vec3()
    alignment*: TextAlignment = TextAlignment.Left
    anchor*: Vec2f = vec2()
    scale*: float32 = 0
    color*: Vec4f = vec4(1, 1, 1, 1)
    capacity*: int

  TextBuffer*[MaxGlyphs: static int] = object
    cursor*: int
    generation*: uint32
    font*: Font[MaxGlyphs]
    baseScale*: float32
    position*: GPUArray[Vec3f, VertexBufferMapped]
    color*: GPUArray[Vec4f, VertexBufferMapped]
    scale*: GPUArray[float32, VertexBufferMapped]
    glyphIndex*: GPUArray[uint16, VertexBufferMapped]
    texts*: seq[Text]

  # === background loader thread ===
  LoaderThreadArgs*[T] = (
    ptr Channel[(string, string)],
    ptr Channel[LoaderResponse[T]],
    proc(f, p: string): T {.gcsafe.},
  )
  LoaderResponse*[T] = object
    path*: string
    package*: string
    data*: T
    error*: string

  BackgroundLoader*[T] = object
    loadRequestCn*: Channel[(string, string)] # used for sending load requests
    responseCn*: Channel[LoaderResponse[T]] # used for sending back loaded data
    worker*: Thread[LoaderThreadArgs[T]] # does the actual loading from the disk
    responseTable*: Table[string, LoaderResponse[T]] # stores results

  # === input ===
  Input* = object
    keyIsDown*: set[Key]
    keyWasPressed*: set[Key]
    keyWasReleased*: set[Key]
    mouseIsDown*: set[MouseButton]
    mouseWasPressed*: set[MouseButton]
    mouseWasReleased*: set[MouseButton]
    mousePosition*: Vec2i
    mouseMove*: Vec2i
    mouseWheel*: float32
    windowWasResized*: bool = true
    windowIsMinimized*: bool = false
    lockMouse*: bool = false
    hasFocus*: bool = false
    characterInput*: Rune

  ActionMap* = object
    keyActions*: Table[string, set[Key]]
    mouseActions*: Table[string, set[MouseButton]]

  # === storage ===
  StorageType* = enum
    SystemStorage
    UserStorage # ? level storage type ?

  # === steam ===
  SteamUserStatsRef* = ptr object

  # === global engine object ===
  EngineObj = object
    initialized*: bool
    vulkan*: VulkanObject
    mixer*: ptr Mixer
    audiothread*: Thread[ptr Mixer]
    input*: Input
    actionMap*: ActionMap
    db*: Table[StorageType, DbConn]
    rawLoader*: ptr BackgroundLoader[seq[byte]]
    jsonLoader*: ptr BackgroundLoader[JsonNode]
    configLoader*: ptr BackgroundLoader[TomlValueRef]
    grayImageLoader*: ptr BackgroundLoader[Image[Gray]]
    imageLoader*: ptr BackgroundLoader[Image[BGRA]]
    audioLoader*: ptr BackgroundLoader[SoundData]
    userStats*: SteamUserStatsRef
    steam_api*: LibHandle
    steam_is_loaded*: bool

  Engine* = ref EngineObj

# fixed value for non-array images
template nLayers*(image: Image): untyped =
  1'u32

# prevent object copies

proc `=copy`(dest: var VulkanObject, source: VulkanObject) {.error.}
proc `=copy`(dest: var RenderDataObject, source: RenderDataObject) {.error.}
proc `=copy`[T, S](dest: var GPUValue[T, S], source: GPUValue[T, S]) {.error.}
proc `=copy`[T, S](dest: var GPUArray[T, S], source: GPUArray[T, S]) {.error.}
proc `=copy`(dest: var MemoryBlock, source: MemoryBlock) {.error.}
proc `=copy`[T](dest: var Pipeline[T], source: Pipeline[T]) {.error.}
proc `=copy`[T](dest: var DescriptorSetData[T], source: DescriptorSetData[T]) {.error.}
proc `=copy`(dest: var Playback, source: Playback) {.error.}
proc `=copy`(dest: var Track, source: Track) {.error.}
proc `=copy`(dest: var Mixer, source: Mixer) {.error.}
proc `=copy`[S, T](dest: var ImageObject[S, T], source: ImageObject[S, T]) {.error.}
proc `=copy`(dest: var Input, source: Input) {.error.}
proc `=copy`(dest: var EngineObj, source: EngineObj) {.error.}
proc `=copy`[MaxGlyphs: static int](
  dest: var FontObj[MaxGlyphs], source: FontObj[MaxGlyphs]
) {.error.}

proc `=copy`[MaxGlyphs: static int](
  dest: var TextBuffer[MaxGlyphs], source: TextBuffer[MaxGlyphs]
) {.error.}
