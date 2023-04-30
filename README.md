Semicongine
===========

Hi there

This is a very simplistic little game engine, mainly trying to wrap around vulkan and the operating system's windowing, input and audio system.
I am using the last programming language you will ever need, [Nim](https://nim-lang.org/)

Building
--------

Requires Nim to be installed and ```glslangValidator``` to be downloaded to the
directory of the main compilation file (e.g. into ```examples/``` in order to
compile the examples). It can be downloaded at
https://github.com/KhronosGroup/glslang/releases/.

Run ```nim help``` to see a list of available build commands.

Roadmap
-------

Still tons to do. Making render pipeline and scenegraph somewhat compatible
seems like it will require quite a bit more of work. Also, audio might require
quite a bit of work, no experience there.

Rendering:

- [x] Vertex attributes, vertex data
- [x] Shaders (allow for predefined and custom shaders)
- [x] Uniforms
- [x] Per-instance vertex attributes (required to be able to draw scene graph)
- [x] Fixed framerate
- [x] Instanced drawing (currently can use instance attributes, but we only support a single instance per draw call)
- [ ] Textures
- [ ] Depth buffering
- [ ] Mipmaps 
- [ ] Multisampling 

Asset handling:
- [ ] Resource concept: load from directory, zip or in-memory-zip, select "mod" as root
- [ ] Mesh files (Wavefront OBJ, MTL) (use something from sketchfab for testing, https://sketchfab.com/)
- [ ] Image files (BMP RGB + BMP Graysscale for transparency)
- [ ] Audio files (AU)

Other (required for alpha release):
- [x] Config files ala \*.ini files (use std/parsecfg)
- [x] Mouse/Keyboard input handling
  - [x] X11
  - [x] Win32
- [x] Enable/disable hardware cursor
- [ ] Fullscreen mode + switch between modes
      - [x] Linux (works well enough, I hope)
      - [ ] Window
- [ ] Input-mapping configuration
- [ ] Audio playing
      - [ ] Linux (Alsa)
      - [ ] Windows Waveform API?
- [ ] Telemetry
- [ ]  Documentation?

Advanced features (very low priority):
- [ ] Allow multipel Uniform blocks?
- [ ] Text rendering
- [ ] Animation system
- [ ] Sprite system
- [ ] Particle system
- [ ] Query and display rendering information from Vulkan
- [ ] Game controller input handling

Quality improvments:

- [x] Better scenegraph API
- [x] Better rendering pipeline API

Build-system:
- [x] move all of Makefile to config.nims
