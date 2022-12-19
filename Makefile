SOURCES := $(shell find src -name '*.nim')
COMPILE_OPTIONS := --path:src --mm:orc --experimental:strictEffects --threads:on
DEBUG_OPTIONS := --debugger:native --checks:on --assertions:on
RELEASE_OPTIONS := -d:release --checks:off --assertions:off

build/debug/linux:
	mkdir -p $@
build/debug/linux/test: build/debug/linux ${SOURCES}
	nim c ${COMPILE_OPTIONS} ${DEBUG_OPTIONS} -o:$@ examples/test.nim

build/release/linux:
	mkdir -p $@
build/release/linux/test: build/release/linux ${SOURCES}
	nim c ${COMPILE_OPTIONS} ${RELEASE_OPTIONS} -o:$@ examples/test.nim

# not working yet, need to implement windows window-API
# build/debug/windows:
	# mkdir -p $@
# build/debug/windows/test: build/debug/windows ${SOURCES}
	# nim c ${COMPILE_OPTIONS} ${DEBUG_OPTIONS} -d:mingw -o:$@ examples/test.nim
# build/release/windows:
	# mkdir -p $@
# build/release/windows/test: build/release/windows ${SOURCES}
	# nim c ${COMPILE_OPTIONS} ${DEBUG_OPTIONS} -d:mingw -o:$@ examples/test.nim
thirdparty:
	echo https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-release/continuous/1885/20221216-081805/install.zip
	echo https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-release/continuous/1885/20221216-081805/install.zip

SPIRV_TOOLS_LINUX_DEBUG:
	wget https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-release/continuous/1889/20221216-081754/install.tgz
SPIRV_TOOLS_LINUX_DEBUG:
	wget https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-debug/continuous/1899/20221216-081758/install.tgz
SPIRV_TOOLS_WINDOWS_DEBUG:
	wget https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-debug/continuous/1599/20221216-081803/install.zip
SPIRV_TOOLS_WINDOWS_RELEASE:
	wget https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-release/continuous/1885/20221216-081805/install.zip

GLSL_LINUX_DEBUG:
	wget
GLSL_LINUX_RELEASE:
	wget
GLSL_WINDOWS_DEBUG:
	wget
GLSL_WINDOWS_RELEASE:
	wget
