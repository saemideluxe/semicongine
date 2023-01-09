SOURCES := $(shell find src -name '*.nim')

# HACK to get cross-compilation working --------------------------------

# anywhere with a windows filesystem that has the visual basic compiler tools installed
WINDOWS_BASE := /mnt

# path variables, need to have correct versions
WINDOWS_PROGAMS := ${WINDOWS_BASE}/Program Files (x86)
MSVC_BUILDTOOLS_PATH := ${WINDOWS_PROGAMS}/Microsoft Visual Studio/2022/BuildTools/VC
WINDOWS_KIT_INCLUDE_BASE := ${WINDOWS_PROGAMS}/Windows Kits/10/Include/10.0.22000.0
WINDOWS_KIT_LIBS_BASE := ${WINDOWS_PROGAMS}/Windows Kits/10/Lib/10.0.22000.0
MSVC_PATH := ${MSVC_BUILDTOOLS_PATH}/Tools/MSVC/14.34.31933

MSVC_ADDITIONAL_PATH := ${MSVC_BUILDTOOLS_PATH}/Auxiliary/Build/
CL_DIR := ${MSVC_PATH}/bin/Hostx64/x64/
CL_INCL_DIR := ${MSVC_PATH}/include
WINE_NIM_VERSION := 1.6.10

# nim command:
WINE_NIM := WINEPATH="${CL_DIR}" wine ./build/nim_windows/nim-${WINE_NIM_VERSION}/bin/nim.exe --path:"${MSVC_ADDITIONAL_PATH}" --path:"${CL_INCL_DIR}" --passC:'/I "${CL_INCL_DIR}"' --passC:'/I "${WINDOWS_KIT_INCLUDE_BASE}/ucrt"' --passC:'/I "${WINDOWS_KIT_INCLUDE_BASE}/um"' --passC:'/I "${WINDOWS_KIT_INCLUDE_BASE}/shared"' --passL:'/LIBPATH:"${WINDOWS_KIT_LIBS_BASE}/ucrt/x64"' --passL:'/LIBPATH:"${WINDOWS_KIT_LIBS_BASE}/um/x64"' --passL:'/LIBPATH:"${MSVC_PATH}/lib/x64"'

# end of HACK-----------------------------------------------------------


# build hello_triangle
build/debug/linux/hello_triangle: ${SOURCES}
	nim build_linux_debug -o:$@ examples/hello_triangle.nim
build/release/linux/hello_triangle: ${SOURCES}
	nim build_linux_release -o:$@ examples/hello_triangle.nim
build/debug/windows/hello_triangle.exe: ${SOURCES} build/nim_windows
	${WINE_NIM} build_windows_debug -o:$@ examples/hello_triangle.nim
build/release/windows/hello_triangle.exe: ${SOURCES} build/nim_windows
	${WINE_NIM} build_windows_release -o:$@ examples/hello_triangle.nim

build/debug/linux/alotof_triangles: ${SOURCES}
	nim build_linux_debug -o:$@ examples/alotof_triangles.nim
build/release/linux/alotof_triangles: ${SOURCES}
	nim build_linux_release -o:$@ examples/alotof_triangles.nim
build/debug/windows/alotof_triangles.exe: ${SOURCES} build/nim_windows
	${WINE_NIM} build_windows_debug -o:$@ examples/alotof_triangles.nim
build/release/windows/alotof_triangles.exe: ${SOURCES} build/nim_windows
	${WINE_NIM} build_windows_release -o:$@ examples/alotof_triangles.nim

build_all_linux: build/debug/linux/hello_triangle build/release/linux/hello_triangle
build_all_windows: build/debug/windows/hello_triangle.exe build/release/windows/hello_triangle.exe
build_all: build_all_linux build_all_windows

# clean
clean:
	rm -rf build
	# clean thirdparty too?

.PHONY: tests

# tests
tests:
	testament p tests/

# publish
publish_linux_debug: build/debug/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/debug/
publish_linux_release: build/release/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/release/
publish_windows_debug: build/debug/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/debug/
publish_windows_release: build/release/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/release/

publish_all_linux: publish_linux_debug publish_linux_release
publish_all_windows: publish_windows_debug publish_windows_release
publish_all: publish_all_linux publish_all_windows


# download thirdparty-libraries

thirdparty/lib/glslang/linux_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Debug.zip
	unzip glslang-master-linux-Debug.zip -d $@
thirdparty/lib/glslang/linux_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Release.zip
	unzip glslang-master-linux-Release.zip -d $@
thirdparty/lib/glslang/windows_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Debug.zip
	unzip glslang-master-windows-x64-Debug.zip -d $@
thirdparty/lib/glslang/windows_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Release.zip
	unzip glslang-master-windows-x64-Release.zip -d $@

thirdparty/lib/spirv-tools/linux_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-debug/continuous/1899/20221216-081758/install.tgz
	tar --directory $@ -xf $@/install.tgz
thirdparty/lib/spirv-tools/linux_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/linux-gcc-release/continuous/1889/20221216-081754/install.tgz
	tar --directory $@ -xf $@/install.tgz
thirdparty/lib/spirv-tools/windows_debug:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-debug/continuous/1599/20221216-081803/install.zip
	unzip $@/install.zip -d $@
thirdparty/lib/spirv-tools/windows_release:
	mkdir -p $@
	wget --directory-prefix=$@ https://storage.googleapis.com/spirv-tools/artifacts/prod/graphics_shader_compiler/spirv-tools/windows-msvc-2017-release/continuous/1885/20221216-081805/install.zip
	unzip $@/install.zip -d $@

# set up cross compilation to compile for windows on linux
build/nim_windows/:
	mkdir -p build/nim_windows
	wget --directory-prefix=$@ https://nim-lang.org/download/nim-${WINE_NIM_VERSION}_x64.zip
	unzip $@/nim-${WINE_NIM_VERSION}_x64.zip -d $@
