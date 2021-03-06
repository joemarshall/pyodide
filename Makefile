PYODIDE_ROOT=$(abspath .)
include Makefile.envs
.PHONY=check

FILEPACKAGER=$(PYODIDE_ROOT)/emsdk/emsdk/upstream/emscripten/tools/file_packager.py

CPYTHONROOT=cpython
CPYTHONLIB=$(CPYTHONROOT)/installs/python-$(PYVERSION)/lib/python$(PYMINOR)

LIBXML=packages/libxml/libxml2-2.9.10/.libs/libxml2.a
LIBXSLT=packages/libxslt/libxslt-1.1.33/libxslt/.libs/libxslt.a
LIBICONV=packages/libiconv/libiconv-1.16/lib/.libs/libiconv.a
ZLIB=packages/zlib/zlib-1.2.11/lib/libz.a
LZ4LIB=packages/lz4/lz4-1.8.3/lib/liblz4.a
CLAPACK=packages/CLAPACK/CLAPACK-WA/lapack_WA.a

PYODIDE_EMCC=$(PYODIDE_ROOT)/ccache/emcc
PYODIDE_CXX=$(PYODIDE_ROOT)/ccache/em++

SHELL := /bin/bash
CC=emcc
CXX=em++
OPTFLAGS=-O2
CFLAGS=$(OPTFLAGS) -g4 -I$(PYTHONINCLUDE) -Wno-warn-absolute-paths -fPIC -s LZ4=1 -s EMULATE_FUNCTION_POINTER_CASTS=1
CXXFLAGS=$(CFLAGS) -std=c++14 -fPIC -s LZ4=1 -s EMULATE_FUNCTION_POINTER_CASTS=1


LDFLAGS=\
	-O2 \
	-s MODULARIZE=1 \
	$(CPYTHONROOT)/installs/python-$(PYVERSION)/lib/libpython$(PYMINOR).a \
	$(LZ4LIB) \
	-s "BINARYEN_METHOD='native-wasm'" \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s MAIN_MODULE=1 \
	-s LINKABLE=1 \
        -s LZ4=1\
	-s EXPORT_ALL=1 \
	-s EXPORTED_FUNCTIONS='["___cxa_guard_acquire", "__ZNSt3__28ios_base4initEPv","_main"]' \
	-s WASM=1 \
	-s USE_FREETYPE=1 \
	-s USE_LIBPNG=1 \
	-std=c++14 \
        --source-map-base / \
	-L$(wildcard $(CPYTHONROOT)/build/sqlite*/.libs) -lsqlite3 \
	$(wildcard $(CPYTHONROOT)/build/bzip2*/libbz2.a) \
	-lstdc++ \
	--memory-init-file 0 \
	-s EXTRA_EXPORTED_RUNTIME_METHODS=['LZ4']\
	-s FORCE_FILESYSTEM=1\
	-s TEXTDECODER=0\
	-s EMULATE_FUNCTION_POINTER_CASTS=1

SIX_ROOT=packages/six/six-1.11.0/build/lib
SIX_LIBS=$(SIX_ROOT)/six.py

JEDI_ROOT=packages/jedi/jedi-0.17.2/jedi
JEDI_LIBS=$(JEDI_ROOT)/__init__.py

PARSO_ROOT=packages/parso/parso-0.7.1/parso
PARSO_LIBS=$(PARSO_ROOT)/__init__.py

SITEPACKAGES=root/lib/python$(PYMINOR)/site-packages
all: 	build/pyodide.asm.js \
	build/pyodide.asm.data \
	build/pyodide.js \
	build/pyodide_dev.js \
	build/console.html \
	build/renderedhtml.css \
	build/test.data \
	build/packages.json \
	build/test.html \
	build/webworker.js \
	build/webworker_dev.js
	echo -e "\nSUCCESS!"


build/pyodide.asm.js: src/main.o src/type_conversion/jsimport.o \
	        src/type_conversion/jsproxy.o src/type_conversion/js2python.o \
		src/type_conversion/pyimport.o src/type_conversion/pyproxy.o \
		src/type_conversion/python2js.o \
		src/type_conversion/python2js_buffer.o \
		src/type_conversion/runpython.o src/type_conversion/hiwire.o root/.built
	date +"[%F %T] Building pyodide.asm.js..."
	[ -d build ] || mkdir build
	$(CXX) -s EXPORT_NAME="'pyodide'" -o build/pyodide.asm.js $(filter %.o,$^) -g4 \
		$(LDFLAGS) -s FORCE_FILESYSTEM=1 -s EXTRA_EXPORTED_RUNTIME_METHODS=['LZ4'] --preload-file root/lib@lib
#	rm build/pyodide.asm.html
	date +"[%F %T] done building pyodide.asm.js."


env:
	env


#build/pyodide.asm.data: root/.built
#	( \
#		cd build; /
#          emcc -o pyodide.asm.data --lz4 --preload ../root/lib@lib
#/ #python $(FILEPACKAGER) pyodide.asm.data --lz4 --preload ../root/lib@lib --js-output=pyodide.asm.data.js --use-preload-plugins \
#	)
#	uglifyjs build/pyodide.asm.data.js -o build/pyodide.asm.data.js


build/pyodide_dev.js: src/pyodide.js
	cp $< $@
	sed -i -e "s#{{DEPLOY}}#./#g" $@
	sed -i -e "s#{{ABI}}#$(PYODIDE_PACKAGE_ABI)#g" $@


build/pyodide.js: src/pyodide.js
	cp $< $@
	sed -i -e 's#{{DEPLOY}}#https://cdn.jsdelivr.net/pyodide/v0.15.0/full/#g' $@

	sed -i -e "s#{{ABI}}#$(PYODIDE_PACKAGE_ABI)#g" $@


build/test.html: src/templates/test.html
	cp $< $@


build/console.html: src/templates/console.html
	cp $< $@


build/renderedhtml.css: src/css/renderedhtml.less
	lessc $< $@

build/webworker.js: src/webworker.js
	cp $< $@
	sed -i -e 's#{{DEPLOY}}#https://cdn.jsdelivr.net/pyodide/v0.15.0/full/#g' $@

build/webworker_dev.js: src/webworker.js
	cp $< $@
	sed -i -e "s#{{DEPLOY}}#./#g" $@
	sed -i -e "s#pyodide.js#pyodide_dev.js#g" $@

test: all
	pytest src packages/*/test* pyodide_build -v


lint:
	# check for unused imports, the rest is done by black
	flake8 --select=F401 src tools pyodide_build benchmark
	clang-format -output-replacements-xml src/*.c src/*.h src/*.js src/*/*.c src/*/*.h src/*/*.js | (! grep '<replacement ')


benchmark: all
	python benchmark/benchmark.py $(HOSTPYTHON) build/benchmarks.json
	python benchmark/plot_benchmark.py build/benchmarks.json build/benchmarks.png


clean:
	rm -fr root
	rm -fr build/*
	rm -fr src/*.bc
	rm -fr src/*.o
	make -C packages clean
	make -C packages/six clean
	make -C packages/jedi clean
	make -C packages/parso clean
	make -C packages/lz4 clean
	make -C packages/libxslt clean
	make -C packages/libxml clean
	make -C packages/libiconv clean
	make -C packages/zlib clean
	echo "The Emsdk, CPython and CLAPACK are not cleaned. cd into those directories to do so."

clean-all: clean
	make -C emsdk clean
	make -C cpython clean
	rm -fr cpython/build

%.o: %.c $(CPYTHONLIB) $(LZ4LIB)
	$(CC) -o $@ -c $< $(CFLAGS) -Isrc/type_conversion/


build/test.data: $(CPYTHONLIB)
	( \
		cd $(CPYTHONLIB)/test; \
		find . -type d -name __pycache__ -prune -exec rm -rf {} \; \
	)
	( \
		cd build; \
		python $(FILEPACKAGER) test.data --lz4 --preload ../$(CPYTHONLIB)/test@/lib/python3.8/test --js-output=test.js --export-name=pyodide._module --exclude __pycache__ \
	)
	uglifyjs build/test.js -o build/test.js


root/.built: \
		$(CPYTHONLIB) \
		$(SIX_LIBS) \
		$(JEDI_LIBS) \
		$(PARSO_LIBS) \
		src/sitecustomize.py \
		src/webbrowser.py \
		src/pyodide.py \
		cpython/remove_modules.txt
	rm -rf root
	mkdir -p root/lib
	cp -r $(CPYTHONLIB) root/lib
	mkdir -p $(SITEPACKAGES)
	cp $(SIX_LIBS) $(SITEPACKAGES)
	cp -r $(JEDI_ROOT) $(SITEPACKAGES)
	cp -r $(PARSO_ROOT) $(SITEPACKAGES)
	cp src/sitecustomize.py $(SITEPACKAGES)
	cp src/webbrowser.py root/lib/python$(PYMINOR)
	cp src/_testcapi.py	root/lib/python$(PYMINOR)
	cp src/pystone.py root/lib/python$(PYMINOR)
	cp src/pyodide.py root/lib/python$(PYMINOR)/site-packages
	( \
		cd root/lib/python$(PYMINOR); \
		rm -fr `cat ../../../cpython/remove_modules.txt`; \
		rm -fr test; \
		find . -type d -name __pycache__ -prune -exec rm -rf {} \; \
	)
	touch root/.built


$(PYODIDE_EMCC):
	mkdir -p $(PYODIDE_ROOT)/ccache ; \
	if test ! -h $@; then \
		if hash ccache &>/dev/null; then \
			ln -s `which ccache` $@ ; \
		else \
			ln -s emsdk/emsdk/upstream/emscripten/emcc $@; \
		fi; \
	fi


$(PYODIDE_CXX):
	mkdir -p $(PYODIDE_ROOT)/ccache ; \
	if test ! -h $@; then \
		if hash ccache &>/dev/null; then \
			ln -s `which ccache` $@ ; \
		else \
			ln -s emsdk/emsdk/upstream/empscripten/em++ $@; \
		fi; \
	fi


$(CPYTHONLIB): emsdk/emsdk/.complete $(PYODIDE_EMCC) $(PYODIDE_CXX)
	date +"[%F %T] Building cpython..."
	make -C $(CPYTHONROOT)
	date +"[%F %T] done building cpython..."


$(LZ4LIB):
	date +"[%F %T] Building lz4..."
	make -C packages/lz4
	date +"[%F %T] done building lz4."


$(LIBXML): $(CPYTHONLIB) $(ZLIB)
	date +"[%F %T] Building libxml..."
	make -C packages/libxml
	date +"[%F %T] done building libxml..."


$(LIBXSLT): $(CPYTHONLIB) $(LIBXML)
	date +"[%F %T] Building libxslt..."
	make -C packages/libxslt
	date +"[%F %T] done building libxslt..."

$(LIBICONV):
	date +"[%F %T] Building libiconv..."
	make -C packages/libiconv
	date +"[%F %T] done building libiconv..."

$(ZLIB):
	date +"[%F %T] Building zlib..."
	make -C packages/zlib
	date +"[%F %T] done building zlib..."


$(SIX_LIBS): $(CPYTHONLIB)
	date +"[%F %T] Building six..."
	make -C packages/six
	date +"[%F %T] done building six."


$(JEDI_LIBS): $(CPYTHONLIB)
	date +"[%F %T] Building jedi..."
	make -C packages/jedi
	date +"[%F %T] done building jedi."


$(PARSO_LIBS): $(CPYTHONLIB)
	date +"[%F %T] Building parso..."
	make -C packages/parso
	date +"[%F %T] done building parso."


$(CLAPACK): $(CPYTHONLIB)
ifdef PYODIDE_PACKAGES
	echo "Skipping BLAS/LAPACK build due to PYODIDE_PACKAGES being defined."
	echo "Build it manually with make -C packages/CLAPACK if needed."
	mkdir -p packages/CLAPACK/CLAPACK-WA/
	touch $(CLAPACK)
else
	date +"[%F %T] Building CLAPACK..."
	make -C packages/CLAPACK
	date +"[%F %T] done building CLAPACK."
endif



build/packages.json: $(CLAPACK) $(LIBXML) $(LIBXSLT) FORCE
	date +"[%F %T] Building packages..."
	make -C packages
	date +"[%F %T] done building packages..."

emsdk/emsdk/.complete:
	date +"[%F %T] Building emsdk..."
	make -C emsdk
	date +"[%F %T] done building emsdk."

FORCE:

check:
	./tools/dependency-check.sh
