PYODIDE_ROOT=$(abspath ..)
include ../Makefile.envs

all: emsdk/.complete

emsdk/.complete:
	if [ -d emsdk ]; then rm -rf emsdk; fi
	git clone https://github.com/emscripten-core/emsdk.git
	( \
		cd emsdk && \
		./emsdk install --build=Release $(EMSCRIPTEN_VERSION) && \
#		git clone --branch "version_98" --depth 1 https://github.com/WebAssembly/binaryen.git  && \
		cd .. && \
#		 (cat patches/*.patch | patch -p1) && \
		cd emsdk && \
		./emsdk activate --embedded --build=Release $(EMSCRIPTEN_VERSION) && \
		cd .. && \
#	        cd binaryen && \
#		cmake . && make -j5 && \
#		cd ../.. && \
		touch emsdk/.complete\
	)

clean:
	rm -rf emsdk
