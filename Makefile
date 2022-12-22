SOURCES := $(shell find src -name '*.nim')
COMPILE_OPTIONS := --path:src --mm:orc --experimental:strictEffects --threads:on
DEBUG_OPTIONS := --debugger:native --checks:on --assertions:on
RELEASE_OPTIONS := -d:release --checks:off --assertions:off
WINDOWS_OPTIONS := -d:mingw

# build
build/debug/linux/test: ${SOURCES}
	mkdir -p $$( dirname $@ )
	nim c ${COMPILE_OPTIONS} ${DEBUG_OPTIONS} -o:$@ examples/test.nim
build/release/linux/test: ${SOURCES}
	mkdir -p $$( dirname $@ )
	nim c ${COMPILE_OPTIONS} ${RELEASE_OPTIONS} -o:$@ examples/test.nim
build/debug/windows/test:  ${SOURCES}
	mkdir -p $$( dirname $@ )
	nim c ${COMPILE_OPTIONS} ${DEBUG_OPTIONS} ${WINDOWS_OPTIONS} -o:$@ examples/test.nim
build/release/windows/test: ${SOURCES}
	mkdir -p $$( dirname $@ )
	nim c ${COMPILE_OPTIONS} ${RELEASE_OPTIONS} ${WINDOWS_OPTIONS} -o:$@ examples/test.nim

build_all_linux: build/debug/linux/test build/release/linux/test
build_all_windows: build/debug/windows/test build/release/windows/test

build_all: build_all_linux build_all_windows

# publish
publish_linux_debug: build/debug/linux/test
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/debug/
publish_linux_release: build/release/linux/test
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/release/
publish_windows_debug: build/debug/linux/test
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/debug/
publish_windows_release: build/release/linux/test
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/release/

publish_all: publish_linux_debug publish_linux_release publish_windows_debug publish_windows_release


# download thirdparty-libraries

thirdparty/lib/glslang/linux_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Debug.zip
	unzip glslang-master-linux-Debug.zip
thirdparty/lib/glslang/linux_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Release.zip
	unzip glslang-master-linux-Release.zip
thirdparty/lib/glslang/windows_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Debug.zip
	unzip glslang-master-windows-x64-Debug.zip
thirdparty/lib/glslang/windows_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Release.zip
	unzip glslang-master-windows-x64-Release.zip

thirdparty/lib/spirv-tools/linux_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-debug/continuous/1899/20221216-081758/install.tgz
	tar -xf $@/install.tgz
thirdparty/lib/spirv-tools/linux_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-release/continuous/1889/20221216-081754/install.tgz
	tar -xf $@/install.tgz
thirdparty/lib/spirv-tools/windows_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-debug/continuous/1599/20221216-081803/install.zip
	unzip $@/install.zip
thirdparty/lib/spirv-tools/windows_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-release/continuous/1885/20221216-081805/install.zip
	unzip $@/install.zip
