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

