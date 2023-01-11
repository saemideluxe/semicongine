SOURCES := $(shell find src -name '*.nim')

# compilation requirements
examples/glslangValidator: thirdparty/bin/linux/glslangValidator
	cp $< examples
examples/glslangValidator.exe: thirdparty/bin/windows/glslangValidator.exe
	cp $< examples

# build hello_triangle
build/debug/linux/hello_triangle: ${SOURCES} examples/glslangValidator
	nim build_linux_debug -o:$@ examples/hello_triangle.nim
build/release/linux/hello_triangle: ${SOURCES} examples/glslangValidator
	nim build_linux_release -o:$@ examples/hello_triangle.nim
build/debug/windows/hello_triangle.exe: ${SOURCES} examples/glslangValidator.exe
	nim build_windows_debug -o:$@ examples/hello_triangle.nim
build/release/windows/hello_triangle.exe: ${SOURCES} examples/glslangValidator.exe
	nim build_windows_release -o:$@ examples/hello_triangle.nim

build_all_linux_hello_triangle: build/debug/linux/hello_triangle build/release/linux/hello_triangle
build_all_windows_hello_triangle: build/debug/windows/hello_triangle.exe build/release/windows/hello_triangle.exe
build_all_hello_triangle: build_all_linux_hello_triangle build_all_windows_hello_triangle

# build alotof_triangles
build/debug/linux/alotof_triangles: ${SOURCES} examples/glslangValidator
	nim build_linux_debug -o:$@ examples/alotof_triangles.nim
build/release/linux/alotof_triangles: ${SOURCES} examples/glslangValidator
	nim build_linux_release -o:$@ examples/alotof_triangles.nim
build/debug/windows/alotof_triangles.exe: ${SOURCES} examples/glslangValidator.exe
	nim build_windows_debug -o:$@ examples/alotof_triangles.nim
build/release/windows/alotof_triangles.exe: ${SOURCES} examples/glslangValidator.exe
	nim build_windows_release -o:$@ examples/alotof_triangles.nim

build_all_linux_alotof_triangles: build/debug/linux/alotof_triangles build/release/linux/alotof_triangles
build_all_windows_alotof_triangles: build/debug/windows/alotof_triangles.exe build/release/windows/alotof_triangles.exe
build_all_alotof_triangles: build_all_linux_alotof_triangles build_all_windows_alotof_triangles

# clean
clean:
	rm -rf build
	rm -rf thirdparty

# tests
.PHONY: tests
tests:
	testament p tests/

# publish
publish:
	rsync -rv build/ basx.dev:/var/www/public.basx.dev/zamikongine

# download thirdparty-libraries

thirdparty/bin/linux/glslangValidator:
	mkdir -p $$( dirname $@ )
	cd $$( dirname $@ ) && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-linux-Release.zip
	cd $$( dirname $@ ) && unzip *.zip
	cd $$( dirname $@ ) && mv bin/* .
	cd $$( dirname $@ ) && rm -rf *.zip bin lib include
thirdparty/bin/windows/glslangValidator.exe:
	mkdir -p $$( dirname $@ )
	cd $$( dirname $@ ) && wget https://github.com/KhronosGroup/glslang/releases/download/master-tot/glslang-master-windows-x64-Release.zip
	cd $$( dirname $@ ) && unzip *.zip
	cd $$( dirname $@ ) && mv bin/* .
	cd $$( dirname $@ ) && rm -rf *.zip bin lib include
