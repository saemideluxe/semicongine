Semicongine
===========

Hi there

This is a very simplistic little game engine, mainly trying to wrap around vulkan and the operating system's windowing, input and audio system.
This is using the last programming language you will ever need, [Nim](https://nim-lang.org/)

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
- [~] Instanced drawing (using it currently but number of instances is hardcoded to 1

Build-system:
- [x] move all of Makefile to config.nims

Asset handling:
- [ ] Mesh files (Wavefront OBJ, MTL) (use something from sketchfab for testing, https://sketchfab.com/)
- [ ] Image files (BMP RGB + BMP Graysscale for transparency)
- [ ] Audio files (WAV)

Quality improvments:

- [ ] Better scenegraph API
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
