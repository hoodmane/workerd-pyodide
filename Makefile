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



all: dist/pyodide.asm.js

emsdk/emsdk/.complete:
	@date +"[%F %T] Building emsdk..."
	make -C emsdk
	@date +"[%F %T] done building emsdk."

LIB_DOWNLOAD=$(PYTHON_INSTALL)/.installed-pyodide

$(LIB_DOWNLOAD):
	mkdir -p download
	cd download && wget https://github.com/pyodide/pyodide/releases/download/0.26.0a2/static-libraries-0.26.0a2.tar.bz2
	cd download && tar -xf static-libraries-0.26.0a2.tar.bz2


src/main.o : src/main.c emsdk/emsdk/.complete
	emcc -c src/main.c -o src/main.o $(CFLAGS)

dist/pyodide.asm.js : src/main.o $(LIB_DOWNLOAD)
	mkdir -p dist
	emcc src/main.o -o dist/pyodide.asm.js $(LDFLAGS) $(LIBS)
	sed -f sed.txt -i dist/pyodide.asm.js

clean:
	rm src/main.o
	rm -rf dist
	rm -rf download
