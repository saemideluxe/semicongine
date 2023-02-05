Semicongine
===========

Hi there

This is a very simplistic little game engine, mainly trying to wrap around vulkan and the operating system's windowing, input and audio system.
This is using the last programming language you will ever need, [Nim](https://nim-lang.org/)

Building
--------

Run ```nim help``` to see a list of available build commands.

It is required to download the glslangValidator binary into the ```examples/``` directory in order to be able to build.
There is a nim command for this that works on linux.

Compilation on Windows
----------------------

Requires a Windows SDK to be installed (e.g. via Visual Studio Build Tools).
Also, using Nim on Windows with mingw seems to be way faster than with vcc/lc.
For compilation with vcc/ls, install additionaly (with Visual Studio Build Tools):
- Windows Universal C Runtime (some important files)
- Windows CRT SDK (some important header files)
- Some version of MSVC (the compiler)

glslangValidator cannot yet be downloaded automatically on windows, check config.nim for instructions.

Roadmap
-------

Still tons to do, but it feels like the worst things (except audio maybe?) are over the hill.

Rendering:

- [x] Vertex attributes, vertex data
- [x] Shaders (allow for predefined and custom shaders)
- [x] Uniforms
- [x] Per-instance vertex attributes (required to be able to draw scene graph)
- [ ] Textures
- [ ] Depth buffering
- [ ] Mipmaps 
- [ ] Multisampling 
- [~] Instanced drawing (currently can use instance attributes, but we only support a single instance per mesh)
- [ ] Fullscreen mode + switch between modes
- [x] Fixed framerate
- [ ] Allow multipel Uniform blocks

Build-system:
- [x] move all of Makefile to config.nims

Asset handling:
- [ ] Mesh files (Wavefront OBJ, MTL) (use something from sketchfab for testing, https://sketchfab.com/)
- [ ] Image files (BMP RGB + BMP Graysscale for transparency)
- [ ] Audio files (WAV)

Quality improvments:

- [x] Better scenegraph API
- [ ] Better rendering pipeline API

Other:
- [x] Mouse/Keyboard input handling
  - [x] X11
  - [x] Win32
- [ ] Config files ala \*.ini files (use std/parsecfg)
- [ ] Input-mapping configuration
- [ ] Audio (Alsa, Windows Waveform API?)
- [ ] Game controller input handling

Advanced features:
- [ ] Text rendering
- [ ] Animation system
- [ ] Sprite system
- [ ] Particle system
- [ ] Query and display rendering information from Vulkan
