PYODIDE_ROOT=$(abspath ..)
include ../Makefile.envs

all: emsdk/.complete

emsdk/.complete: ../Makefile.envs $(wildcard patches/*.patch)
	if [ -d emsdk ]; then rm -rf emsdk; fi
	git clone https://github.com/emscripten-core/emsdk.git
	cd emsdk && ./emsdk install --build=Release $(EMSCRIPTEN_VERSION)
	git clone --depth 1 https://github.com/WebAssembly/binaryen.git emsdk/binaryen
	cd emsdk/binaryen && git checkout $(BINARYEN_VERSION)
	cat patches/*.patch | patch -p1
	cd emsdk && ./emsdk activate --embedded --build=Release $(EMSCRIPTEN_VERSION)
	cmake -S emsdk/binaryen -B emsdk/binaryen
	make -C emsdk/binaryen -j5
	sed -i "s/BINARYEN_ROOT.*/BINARYEN_ROOT = emsdk_path \+ '\/binaryen'/g" emsdk/.emscripten
	touch emsdk/.complete

clean:
	rm -rf emsdk
