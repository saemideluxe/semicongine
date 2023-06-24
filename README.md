# Semicongine

Hi there

This is a little game engine, mainly trying to wrap around vulkan and the
operating system's windowing, input and audio system. I am using the last
programming language you will ever need, [Nim](https://nim-lang.org/)

## Building

Requires Nim to be installed and `glslangValidator` to be downloaded to the
directory of the main compilation file (e.g. into `examples/` in order to
compile the examples). It can be downloaded at
https://github.com/KhronosGroup/glslang/releases/.

Run `nim help` to see a list of available build commands.

## Roadmap

Here a bit to see what has been planed and what is done already. Is being
updated frequently (marking those checkboxes just feels to good to stop working).

Rendering:

- [x] Vertex attributes, vertex data
- [x] Shaders (allow for predefined and custom shaders)
- [x] Uniforms
- [x] Per-instance vertex attributes (required to be able to draw scene graph)
- [x] Fixed framerate
- [x] Instanced drawing (currently can use instance attributes, but we only support a single instance per draw call)
- [x] Textures
- [x] Materials (vertices with material indices)
- [ ] Allow different shaders (ie pipelines) for different meshes

Required for 3D rendering:

- [ ] Depth buffering
- [ ] Mipmaps

Asset handling:

- [x] Resource loading - [x] Mod/resource-pack concept - [x] Load from directory - [x] Load from zip - [x] Load from exe-embeded
- [x] Mesh/material files (glTF, but incomplete, not all features supported)
- [x] Image files (BMP RGBA)
- [x] Audio files (AU)
- [x] API to transform/recalculate mesh data

Other (required for alpha release):

- [x] Config files ala \*.ini files (use std/parsecfg)
- [x] Mouse/Keyboard input handling
  - [x] X11
  - [x] Win32
- [x] Enable/disable hardware cursor
- [x] Fullscreen mode + switch between modes - [x] Linux - [x] Window
- [x] Audio playing - [x] Linux - [x] Windows Waveform API
- [ ] Generic configuration concept (engine defaults, per-user, etc)
- [ ] Input-mapping configuration
- [ ] Telemetry
  - [x] Add simple event logging service
  - [ ] Add exception reporting

Other important features:

- [ ] Multisampling
- [x] Text rendering
- [x] Animation system
- [ ] Sprite system
- [ ] Particle system
- [ ] Sound fading
- [ ] Named entity components

Other less important features:

- [ ] Viewport scaling (e.g. framebuffer resolution != window resolution)
- [ ] Query and display rendering information from Vulkan?
- [ ] Game controller input handling
- [ ] Allow multipel Uniform blocks
- [ ] Documentation

Quality improvments:

- [x] Better scenegraph API
- [x] Better rendering pipeline API

Build-system:

- [x] move all of Makefile to config.nims

# Documentation

Okay, here is first quick-n-dirty documentation, the only purpose to organize my thoughts a bit.

## Engine parts

Currently we have at least the following:

- Rendering: rendering.nim vulkan/\*
- Scene graph: entity.nim
- Audio: audio.nim audiotypes.nim
- Input: events.nim
- Settings: settings.nim
- Meshes: mesh.nim
- Math: math/\*
- Telemetry: telemetry.nim (wip)
- Resources (loading, mods): resources.nim

Got you: Everything is wip, but (wip) here means work has not started yet.

## Handling of assets

A short description how I want to handle assets.

Support for file formats (super limited, no external dependencies, uses quite a bit of space, hoping for zip):

- Images: BMP
- Audio: AU
- Mesh: glTF (\*.gld)

In-memory layout of assets (everything needs to be converted to those while loading):

- Images: 4 channel with each uint8 = 32 bit RGBA, little endian (R is low bits, A is high bits)
- Audio: 2 Channel 16 bit signed little endian, 44100Hz
- Meshes: non-interleaved, lists of values for each vertex, one list per attribute

## Configuration

Or: How to organize s\*\*t that is not code

Not sure why, but this feels super important to get done right. The engine is
being designed with a library-mindset, not a framework mindset. And with that,
ensuring the configuration of the build, runtime and settings in general
becomes a bit less straight-forward.

So here is the idea: There are three to four different kinds of configurations
that the engine should be able to handle:

1. Build configuration: Engine version, project name, log level, etc.
2. Runtime engine/project settings: Video/audio settings, telemetry, log-output, etc.
3. Mods: Different sets of assets and configuration to allow easy testing of different scenarios
4. Save data: Saving world state of the game

Okay, let's look at each of those and how I plan to implement them:

**1. Build configuration**

**2. Runtime settings**

This is mostly implemented already. I am using the Nim module std/parsecfg.
There is also the option to watch the filesystem and update values at runtime,
mostly usefull for development.

The engine scans all files in the settings-root directory and builds a
settings tree that can be access via a setting-hierarchy like this:

    setting("a.b.c.d.e")

`a.b` refers to the settings directory `./a/b/` (from the settings-root)
`c` refers to the file `c.ini` inside `./a/b/`
`d` refers to the ini-section inside the file `./a/b/c.ini`
`e` refers to the key inside section `d` inside the file `./a/b/c.ini`

`a.b` are optional, they just allow larger configuration trees.
`d` is optional, if it is not give, `e` refers to the top-level section
of the ini-file.

**3. Mods**

A mod is just a collection of resources for a game. Can maybe switched from
inside a game. Current mod can be defined via "2. Runtime settings"

I want to support mods from:

a) a directory on the filesystem
b) a zip-file on the filesystem
c) a zip-file that is embeded in the executable

The reasoning is simple: a) is helpfull for development, testing of
new/replaced assets, b) is the default deployment with mod-support and c) is
deployment without mod-support, demo-versions and similar.

Should not be that difficult but give us everything we ever need in terms of
resource packaging.

**4. Save data**

Not too much thought here yet. Maybe we can use Nim's std/marshal module. It
produces JSON from nim objects. Pretty dope, but maybe pretty slow. However, we
are indie-JSON here, not 10M of GTA Online JSON:
https://nee.lv/2021/02/28/How-I-cut-GTA-Online-loading-times-by-70/
