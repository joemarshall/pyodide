

PYODIDE_ROOT=$(abspath ..)

include $(PYODIDE_ROOT)/Makefile.envs

ROOT=$(abspath .)

HOSTINSTALL=$(ROOT)/build/$(PYVERSION)/host
HOSTBUILD=$(HOSTINSTALL)/Python-$(PYVERSION)
HOSTPYTHON=$(HOSTINSTALL)/bin/python3$(EXE)
HOSTPYTHON_CPPFLAGS="-I/usr/local/opt/openssl/include"
HOSTPYTHON_LDFLAGS="-L/usr/local/opt/openssl/lib"

BUILD=$(ROOT)/build/$(PYVERSION)/Python-$(PYVERSION)
INSTALL=$(ROOT)/installs/python-$(PYVERSION)
TARBALL=$(ROOT)/downloads/Python-$(PYVERSION).tgz
URL=https://www.python.org/ftp/python/$(PYVERSION)/Python-$(PYVERSION).tgz
LIB=libpython$(PYMINOR).a
BIN=python

ZLIBVERSION = 1.2.11
ZLIBTARBALL=$(ROOT)/downloads/zlib-$(ZLIBVERSION).tar.gz
ZLIBBUILD=$(ROOT)/build/zlib-$(ZLIBVERSION)
ZLIBURL=https://zlib.net/zlib-1.2.11.tar.gz

SQLITETARBALL=$(ROOT)/downloads/sqlite-autoconf-3270200.tar.gz
SQLITEBUILD=$(ROOT)/build/sqlite-autoconf-3270200
SQLITEURL=https://www.sqlite.org/2019/sqlite-autoconf-3270200.tar.gz

BZIP2TARBALL=$(ROOT)/downloads/bzip2-1.0.2.tar.gz
BZIP2BUILD=$(ROOT)/build/bzip2-1.0.2
BZIP2URL=ftp://sources.redhat.com/pub/bzip2/v102/bzip2-1.0.2.tar.gz



all: $(INSTALL)/lib/$(LIB) $(INSTALL)/bin/python

$(INSTALL)/bin/python: $(BUILD)/$(LIB)
	( \
		cd $(BUILD); \
		cp $(BIN).wasm $(INSTALL)/bin/$(bin) \
	)
$(INSTALL)/lib/$(LIB): $(BUILD)/$(LIB)
	( \
		mkdir -p $(INSTALL)/bin;\
		mkdir -p $(INSTALL)/lib;\
		cd $(BUILD); \
		sed -i -e 's/libinstall:.*/libinstall:/' Makefile; \
		sed -i -e 's/BUILDEXE=/BUILDEXE=.wasm/' Makefile; \
		touch $(BUILD)/$(LIB) ; \
		touch $(BUILD)/$(BIN).wasm ; \
		emmake make HOSTPYTHON=$(HOSTPYTHON) PYTHON_FOR_BUILD=$(HOSTPYTHON) CROSS_COMPILE=yes inclinstall libinstall $(LIB) -j $${PYODIDE_JOBS:-3} && \
		cp $(LIB) $(INSTALL)/lib/ && \
		cp $(BIN).wasm $(INSTALL)/bin/ && \
		cp $(HOSTINSTALL)/lib/python$(PYMINOR)/`$(HOSTPYTHON) -c "import sysconfig; print(sysconfig._get_sysconfigdata_name())"`.py $(INSTALL)/lib/python$(PYMINOR)/_sysconfigdata__emscripten_.py; \
		sed -i -e 's#'"$(PYODIDE_ROOT)"'##g' $(INSTALL)/lib/python$(PYMINOR)/_sysconfigdata__emscripten_.py; \
	)


clean:
	-rm -fr $(HOSTINSTALL)
	-rm -fr $(BUILD)
	-rm -fr $(INSTALL)


$(TARBALL):
	[ -d $(ROOT)/downloads ] || mkdir $(ROOT)/downloads
	wget -q -O $@ $(URL)
	md5sum --quiet --check checksums || (rm $@; false)


$(ZLIBTARBALL):
	[ -d $(ROOT)/downloads ] || mkdir $(ROOT)/downloads
	wget -q -O $@ $(ZLIBURL)


$(SQLITETARBALL):
	[ -d $(ROOT)/downloads ] || mkdir $(ROOT)/downloads
	wget -q -O $@ $(SQLITEURL)


$(BZIP2TARBALL):
	[ -d $(ROOT)/downloads ] || mkdir $(ROOT)/downloads
	wget -q -O $@ $(BZIP2URL)


$(HOSTPYTHON): $(TARBALL)
	mkdir -p $(HOSTINSTALL)
	[ -d $(HOSTBUILD) ] || tar -C $(HOSTINSTALL) -xf $(TARBALL)
	( \
		cd $(HOSTBUILD); \
		PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig" ./configure --prefix=$(HOSTINSTALL) || cat config.log && \
	  	make regen-grammar -j $${PYODIDE_JOBS:-3} && \
		make install -j $${PYODIDE_JOBS:-3} && \
		make distclean \
	)


$(BUILD)/.patched: $(TARBALL)
	[ -d $(BUILD) ] || (mkdir -p $(dir $(BUILD)); tar -C $(dir $(BUILD)) -xf $(TARBALL))
	cat patches/*.patch | (cd $(BUILD) ; patch -p1)
	touch $@


$(ZLIBBUILD)/.patched: $(ZLIBTARBALL)
	[ -d $(ROOT)/build ] || (mkdir $(ROOT)/build)
	tar -C $(ROOT)/build/ -xf $(ROOT)/downloads/zlib-1.2.11.tar.gz
	cat patches/zlib/*.patch | (cd $(ZLIBBUILD) ; patch -p1)
	touch $@


$(SQLITEBUILD)/libsqlite3.la: $(SQLITETARBALL)
	[ -d $(ROOT)/build ] || (mkdir $(ROOT)/build)
	tar -C $(ROOT)/build/ -xf $(SQLITETARBALL)
	( \
		cd $(SQLITEBUILD); \
		emconfigure ./configure CFLAGS="$(EMMAKEN_CFLAGS) -s ERROR_ON_UNDEFINED_SYMBOLS=0"; \
		emmake make  -j $${PYODIDE_JOBS:-3}; \
	)


$(BZIP2BUILD)/libbz2.a: $(BZIP2TARBALL)
	[ -d $(ROOT)/build ] || (mkdir $(ROOT)/build)
	tar -C $(ROOT)/build/ -xf $(BZIP2TARBALL)
	( \
		cd $(BZIP2BUILD); \
		emmake make -j  $${PYODIDE_JOBS:-3} CC=emcc CFLAGS="$(EMMAKEN_CFLAGS) -Wall -Winline -O2 -fomit-frame-pointer -D_FILE_OFFSET_BITS=64" AR=emar RANLIB=emranlib libbz2.a; \
	)


$(BUILD)/Makefile: $(BUILD)/.patched $(ZLIBBUILD)/.patched $(SQLITEBUILD)/libsqlite3.la $(BZIP2BUILD)/libbz2.a
	cp config.site $(BUILD)/
	( \
		cd $(BUILD); \
		CONFIG_SITE=./config.site READELF=true LD_RUN_PATH="$(SQLITEBUILD):$(BZIP2BUILD)" emconfigure \
		   ./configure CFLAGS="$(EMMAKEN_CFLAGS)"\
			  --without-pymalloc \
			  --disable-shared \
			  --disable-ipv6 \
			  --without-gcc \
			  --host=asmjs-unknown-emscripten \
			  --build=wasm32 \
			  --prefix=$(INSTALL) ; \
	)


$(BUILD)/$(LIB): $(BUILD)/Makefile $(HOSTPYTHON) Setup.local
	cp Setup.local $(BUILD)/Modules/
	cat pyconfig.undefs.h >> $(BUILD)/pyconfig.h
	( \
		cp build/$(PYVERSION)/host/lib/python$(PYMINOR)/`$(HOSTPYTHON) -c "import sysconfig; print(sysconfig._get_sysconfigdata_name())"`.py build/$(PYVERSION)/Python-$(PYVERSION)/Lib/_sysconfigdata__emscripten_.py; \
		cd $(BUILD); \
		emmake make HOSTPYTHON=$(HOSTPYTHON) CROSS_COMPILE=yes $(LIB) -j $${PYODIDE_JOBS:-3} SQLITEBUILD=${SQLITEBUILD} BZIP2BUILD=${BZIP2BUILD} ZLIBBUILD=${ZLIBBUILD}\
	)
	sed -i -e 's/\-undefined dynamic_lookup//' build/$(PYVERSION)/Python-$(PYVERSION)/Lib/_sysconfigdata__emscripten_.py;
	touch $(BUILD)/$(LIB)
	mkdir -p $(INSTALL)/lib
	cp $(BUILD)/$(LIB) $(INSTALL)/$(LIB)
