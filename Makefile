SOURCES := $(shell find src -name '*.nim')

build/debug/linux:
	mkdir -p $@
build/debug/linux/test: build/debug/linux ${SOURCES}
	nim c -o:$@ --gc:orc --debugger:native --checks:on --assertions:on src/test.nim

build/release/linux:
	mkdir -p $@
build/release/linux/test: build/release/linux ${SOURCES}
	nim c -d:release --gc:orc -o:$@ --checks:off --assertions:off src/test.nim
