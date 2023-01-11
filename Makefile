SOURCES := $(shell find src -name '*.nim')

# build hello_triangle
build/debug/linux/hello_triangle: ${SOURCES} thirdparty/bin/linux
	nim build_linux_debug -o:$@ examples/hello_triangle.nim
build/release/linux/hello_triangle: ${SOURCES} thirdparty/bin/linux
	nim build_linux_release -o:$@ examples/hello_triangle.nim
build/debug/windows/hello_triangle.exe: ${SOURCES} thirdparty/bin/windows
	nim build_windows_debug -o:$@ examples/hello_triangle.nim
build/release/windows/hello_triangle.exe: ${SOURCES} thirdparty/bin/windows
	nim build_windows_release -o:$@ examples/hello_triangle.nim

build_all_linux_hello_triangle: build/debug/linux/hello_triangle build/release/linux/hello_triangle
build_all_windows_hello_triangle: build/debug/windows/hello_triangle.exe build/release/windows/hello_triangle.exe
build_all_hello_triangle: build_all_linux_hello_triangle build_all_windows_hello_triangle

# build alotof_triangles
build/debug/linux/alotof_triangles: ${SOURCES} thirdparty/bin/linux
	nim build_linux_debug -o:$@ examples/alotof_triangles.nim
build/release/linux/alotof_triangles: ${SOURCES} thirdparty/bin/linux
	nim build_linux_release -o:$@ examples/alotof_triangles.nim
build/debug/windows/alotof_triangles.exe: ${SOURCES} thirdparty/bin/windows
	nim build_windows_debug -o:$@ examples/alotof_triangles.nim
build/release/windows/alotof_triangles.exe: ${SOURCES} thirdparty/bin/windows
	nim build_windows_release -o:$@ examples/alotof_triangles.nim

build_all_linux_alotof_triangles: build/debug/linux/alotof_triangles build/release/linux/alotof_triangles
build_all_windows_alotof_triangles: build/debug/windows/alotof_triangles.exe build/release/windows/alotof_triangles.exe
build_all_alotof_triangles: build_all_linux_alotof_triangles build_all_windows_alotof_triangles

# clean
clean:
	rm -rf build
	rm -rf thirdparty

.PHONY: tests
.PHONY: glslang-master-linux-Debug.zip
.PHONY: glslang-master-linux-Release.zip
.PHONY: glslang-master-windows-x64-Debug.zip
.PHONY: glslang-master-windows-x64-Release.zip

# tests
tests:
	testament p tests/

# publish
publish_linux_debug_hello_triangle: build/debug/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/debug/
publish_linux_release_hello_triangle: build/release/linux/hello_triangle
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/release/
publish_windows_debug_hello_triangle: build/debug/linux/hello_triangle.exe
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/debug/
publish_windows_release_hello_triangle: build/release/linux/hello_triangle.exe
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/release/
publish_all_linux_hello_triangle: publish_linux_debug_hello_triangle publish_linux_release_hello_triangle
publish_all_windows_hello_triangle: publish_windows_debug_hello_triangle publish_windows_release_hello_triangle
publish_all_alotof_hello_triangle: publish_all_linux_hello_triangle publish_all_windows_hello_triangle

publish_linux_debug_alotof_triangles: build/debug/linux/alotof_triangles
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/debug/
publish_linux_release_alotof_triangles: build/release/linux/alotof_triangles
	scp $< basx.dev:/var/www/public.basx.dev/joni/linux/release/
publish_windows_debug_alotof_triangles: build/debug/linux/alotof_triangles.exe
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/debug/
publish_windows_release_alotof_triangles: build/release/linux/alotof_triangles.exe
	scp $< basx.dev:/var/www/public.basx.dev/joni/windows/release/
publish_all_linux_alotof_triangles: publish_linux_debug_alotof_triangles publish_linux_release_alotof_triangles
publish_all_windows_alotof_triangles: publish_windows_debug_alotof_triangles publish_windows_release_alotof_triangles
publish_all_alotof_triangles: publish_all_linux_alotof_triangles publish_all_windows_alotof_triangles


# download thirdparty-libraries

thirdparty/bin/linux: glslang-master-linux-Release.zip
	mkdir -p $@
	cd $@ && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/$<
	cd $@ && unzip $<
	cd $@ && mv bin/* .
	cd $@ && rm -rf $< bin lib include
thirdparty/bin/windows: glslang-master-windows-x64-Release.zip
	mkdir -p $@
	cd $@ && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/$<
	cd $@ && unzip $<
	cd $@ && mv bin/* .
	cd $@ && rm -rf $< bin lib include
