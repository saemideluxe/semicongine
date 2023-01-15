# compilation requirements
examples/glslangValidator: thirdparty/bin/linux/glslangValidator
	cp $< examples
examples/glslangValidator.exe: thirdparty/bin/windows/glslangValidator.exe
	cp $< examples

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
