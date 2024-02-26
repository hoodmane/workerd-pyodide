include Makefile.envs

PYTHON_INSTALL=download/static-libraries/python-$(PYVERSION)
PYTHON_INCLUDE=$(PYTHON_INSTALL)/include/python$(PYMAJOR).$(PYMINOR)/
LIB_DIR=$(PYTHON_INSTALL)/lib

OPTFLAGS=-O2
CFLAGS=\
	$(OPTFLAGS) \
	$(DBGFLAGS) \
	-fPIC \
	-Wall \
	-Wno-warn-absolute-paths \
	-Werror=unused-variable \
	-Werror=sometimes-uninitialized \
	-Werror=int-conversion \
	-Werror=incompatible-pointer-types \
	-Werror=unused-result \
	-mreference-types \
	-I$(PYTHON_INCLUDE) \
	-I$(PYTHON_INCLUDE)/.. \
	-s EXCEPTION_CATCHING_ALLOWED=['we only want to allow exception handling in side modules'] \
	$(EXTRA_CFLAGS)

LDFLAGS_BASE=\
	$(OPTFLAGS) \
	$(DBGFLAGS) \
	-s WASM_BIGINT \
	$(EXTRA_LDFLAGS)

LDFLAGS_MODULE=\
	-s MAIN_MODULE=1 \
	-s USE_ES6_IMPORT_META \
	-s EXPORT_ES6 \
	-s EXPORT_ALL=1 \
	-s EXPORTED_RUNTIME_METHODS='wasmTable,ERRNO_CODES' \
	-s ENVIRONMENT=web \


LDFLAGS_MEM_SIZE= \
	-s TOTAL_MEMORY=8mb \
	-s STACK_SIZE=3mb \
	-s ALLOW_MEMORY_GROWTH=1 \

LDFLAGS_EH=	\
	-s EXPORT_EXCEPTION_HANDLING_HELPERS \
	-s EXCEPTION_CATCHING_ALLOWED=['we only want to allow exception handling in side modules'] \
	-s DEMANGLE_SUPPORT=1 \

LDFLAGS_EMSCRIPTEN_LIBS= \
	-s AUTO_JS_LIBRARIES=0 \
	-s AUTO_NATIVE_LIBRARIES=0 \
	-s LZ4=1 \
	-s USE_ZLIB \
	-s USE_BZIP2 \
	-s FORCE_FILESYSTEM=1 \


LDFLAGS= $(LDFLAGS_BASE) \
	$(LDFLAGS_MODULE) \
	$(LDFLAGS_MEM_SIZE) \
	$(LDFLAGS_EH) \
	$(LDFLAGS_EMSCRIPTEN_LIBS) \
	--extern-pre-js prelude.js


LIBS= \
	-L$(LIB_DIR) \
	-lpython$(PYMAJOR).$(PYMINOR)$(CPYTHON_ABI_FLAGS) \
	-lffi \
	-lhiwire \
	-lpyodide \



LIB_URL=https://github.com/pyodide/pyodide/releases/download/0.26.0a2/static-libraries-0.26.0a2.tar.bz2
LIB_SHA256=a92da527f6d4bc4510ff51d4288c615740ab9b0cabca8f3536b15bbfdac1cfd2
LIB_TARBALL=download/static-libraries-0.26.0a2.tar.bz2
LIB_INSTALL_MARK=$(PYTHON_INSTALL)/.installed-pyodide

PYODIDE_CORE_URL=https://github.com/pyodide/pyodide/releases/download/0.26.0a2/pyodide-core-0.26.0a2.tar.bz2
PYODIDE_CORE_SHA256=fbda450a64093a8d246c872bb901ee172a57fe594c9f35bba61f36807c73300d
PYODIDE_TARBALL=download/pyodide-core-0.26.0a2.tar.bz2
PYODIDE_INSTALL=download/pyodide
PYODIDE_INSTALL_MARK=$(PYODIDE_INSTALL)/.installed-pyodide


all: dist/pyodide.asm.js dist/python_stdlib.zip

emsdk/emsdk/.complete:
	@date +"[%F %T] Building emsdk..."
	make -C emsdk
	@date +"[%F %T] done building emsdk."

$(LIB_TARBALL):
	mkdir -p download
	wget -O $@ $(LIB_URL)
	@GOT_SHASUM=`shasum --algorithm 256 $@ | cut -f1 -d' '` \
		&& (echo $$GOT_SHASUM | grep -q $(LIB_SHA256)) \
		|| (\
			   rm $@ \
			&& echo "Got unexpected shasum $$GOT_SHASUM" \
			&& echo "If you are updating, set LIB_TARBALL_SHA256 to this." \
			&& exit 1 \
		)

$(LIB_INSTALL_MARK): $(LIB_TARBALL)
	tar -xf $(LIB_TARBALL) -C download
	touch $@

$(PYODIDE_TARBALL):
	mkdir -p download
	wget -O $@ $(PYODIDE_CORE_URL)
	@GOT_SHASUM=`shasum --algorithm 256 $@ | cut -f1 -d' '` \
		&& (echo $$GOT_SHASUM | grep -q $(PYODIDE_CORE_SHA256)) \
		|| (\
			   rm $@ \
			&& echo "Got unexpected shasum $$GOT_SHASUM" \
			&& echo "If you are updating, set PYODIDE_CORE_SHA256 to this." \
			&& exit 1 \
		)

$(PYODIDE_INSTALL_MARK): $(PYODIDE_TARBALL)
	tar -xf $(PYODIDE_TARBALL) -C download
	touch $@

$(PYODIDE_INSTALL)/python_stdlib.zip: $(PYODIDE_INSTALL_MARK)

dist/python_stdlib.zip: $(PYODIDE_INSTALL)/python_stdlib.zip
	cp $< $@

src/main.o : src/main.c emsdk/emsdk/.complete $(LIB_INSTALL_MARK)
	emcc -c src/main.c -o src/main.o $(CFLAGS)

dist/pyodide.asm.js : src/main.o $(LIB_INSTALL_MARK)
	mkdir -p dist
	emcc src/main.o -o dist/pyodide.asm.js $(LDFLAGS) $(LIBS)
	sed -f sed.txt -i dist/pyodide.asm.js

clean:
	rm src/main.o
	rm -rf dist
	rm -rf download
