WASM_MODULE=dist/opus-stream-decoder.js
WASM_MODULE_ESM=dist/opus-stream-decoder.mjs
WASM_LIB=tmp/lib.bc
OGG_CONFIG_TYPES=src/ogg/include/ogg/config_types.h
OPUS_DECODE_TEST_FILE_URL=https://fetch-stream-audio.anthum.com/audio/save/opus-stream-decoder-test.opus
OPUS_DECODE_TEST_FILE=tmp/decode-test-64kbps.opus
NATIVE_DECODER_TEST=tmp/opus_chunkdecoder_test
CONFIGURE_LIBOPUS=src/opus/configure
CONFIGURE_LIBOGG=src/ogg/configure
CONFIGURE_LIBOPUSFILE=src/opusfile/configure

TEST_FILE_JS=dist/test-opus-stream-decoder.js
TEST_FILE_HTML=dist/test-opus-stream-decoder.html
TEST_FILE_HTML_ESM=dist/test-opus-stream-decoder-esm.html

default: dist

# Runs nodejs test with some audio files
test-wasm: dist $(OPUS_DECODE_TEST_FILE)
	@ mkdir -p tmp
	@ echo "Testing 64 kbps Opus file..."
	@ node $(TEST_FILE_JS) $(OPUS_DECODE_TEST_FILE) tmp

.PHONY: native-decode-test

clean: dist-clean wasmlib-clean configures-clean

dist: wasm wasm-esm
	@ cp src/test-opus-stream-decoder* dist
dist-clean:
	rm -rf dist/*

wasm-esm: wasmlib $(WASM_MODULE_ESM)
wasm: wasmlib $(WASM_MODULE)

wasmlib: configures $(OGG_CONFIG_TYPES) $(WASM_LIB)
wasmlib-clean: dist-clean
	rm -rf $(WASM_LIB)

configures: $(CONFIGURE_LIBOGG) $(CONFIGURE_LIBOPUS) $(CONFIGURE_LIBOPUSFILE)
configures-clean: wasmlib-clean
	rm -rf $(CONFIGURE_LIBOPUSFILE)
	rm -rf $(CONFIGURE_LIBOPUS)
	rm -rf $(CONFIGURE_LIBOGG)

native-decode-test: $(OPUS_DECODE_TEST_FILE)

define WASM_EMCC_OPTS
-O3 \
-s NO_DYNAMIC_EXECUTION=1 \
-s NO_FILESYSTEM=1 \
-s EXTRA_EXPORTED_RUNTIME_METHODS="['cwrap']" \
-s EXPORTED_FUNCTIONS="[ \
    '_free', '_malloc' \
  , '_opus_get_version_string' \
  , '_opus_chunkdecoder_version' \
  , '_opus_chunkdecoder_create' \
  , '_opus_chunkdecoder_free' \
  , '_opus_chunkdecoder_enqueue' \
  , '_opus_chunkdecoder_decode_float_stereo_deinterleaved' \
]" \
--pre-js 'src/emscripten-pre.js' \
--post-js 'src/emscripten-post.js' \
-I src/opusfile/include \
-I "src/ogg/include" \
-I "src/opus/include" \
src/opus_chunkdecoder.c \ 
endef


$(WASM_MODULE_ESM): 
	@ mkdir -p dist
	@ echo "Building Emscripten WebAssembly ES Module $(WASM_MODULE_ESM)..."
	@ emcc \
		-o "$(WASM_MODULE_ESM)" \
		-s EXPORT_ES6=1 \
		-s MODULARIZE=1 \
	  $(WASM_EMCC_OPTS) \
	  $(WASM_LIB)
	@ echo "+-------------------------------------------------------------------------------"
	@ echo "|"
	@ echo "|  Successfully built ES Module: $(WASM_MODULE_ESM)"
	@ echo "|"
	@ echo "|  open \"$(TEST_FILE_HTML_ESM)\" in browser to test"
	@ echo "|"
	@ echo "+-------------------------------------------------------------------------------"


$(WASM_MODULE):
	@ mkdir -p dist
	@ echo "Building Emscripten WebAssembly module $(WASM_MODULE)..."
	@ emcc \
		-o "$(WASM_MODULE)" \
	  $(WASM_EMCC_OPTS) \
	  $(WASM_LIB)
	@ echo "+-------------------------------------------------------------------------------"
	@ echo "|"
	@ echo "|  Successfully built JS Module: $(WASM_MODULE)"
	@ echo "|"
	@ echo "|  run \"make test-wasm\" to test"
	@ echo "|"
	@ echo "|  or open \"$(TEST_FILE_HTML)\" in browser to test"
	@ echo "|"
	@ echo "+-------------------------------------------------------------------------------"


$(WASM_LIB):
	@ mkdir -p tmp
	@ echo "Building Ogg/Opus Emscripten Library $(WASM_LIB)..."
	@ emcc \
	  -o "$(WASM_LIB)" \
	  -O0 \
	  -D VAR_ARRAYS \
	  -D OPUS_BUILD \
	  --llvm-lto 1 \
	  -s NO_DYNAMIC_EXECUTION=1 \
	  -s NO_FILESYSTEM=1 \
	  -s EXPORTED_FUNCTIONS="[ \
	     '_op_read_float_stereo' \
	  ]" \
	  -I "src/opusfile/" \
	  -I "src/opusfile/include" \
	  -I "src/opusfile/src" \
	  -I "src/ogg/include" \
	  -I "src/opus/include" \
	  -I "src/opus/celt" \
	  -I "src/opus/celt/arm" \
	  -I "src/opus/celt/dump_modes" \
	  -I "src/opus/celt/mips" \
	  -I "src/opus/celt/x86" \
	  -I "src/opus/silk" \
	  -I "src/opus/silk/arm" \
	  -I "src/opus/silk/fixed" \
	  -I "src/opus/silk/float" \
	  -I "src/opus/silk/mips" \
	  -I "src/opus/silk/x86" \
	  src/opus/src/opus.c \
	  src/opus/src/opus_multistream.c \
	  src/opus/src/opus_multistream_decoder.c \
	  src/opus/src/opus_decoder.c \
	  src/opus/silk/*.c \
	  src/opus/celt/*.c \
	  src/ogg/src/*.c \
	  src/opusfile/src/*.c
	@ echo "+-------------------------------------------------------------------------------"
	@ echo "|"
	@ echo "|  Successfully built: $(WASM_LIB)"
	@ echo "|"
	@ echo "+-------------------------------------------------------------------------------"

$(CONFIGURE_LIBOPUSFILE):
	cd src/opusfile; ./autogen.sh
$(CONFIGURE_LIBOPUS):
	cd src/opus; ./autogen.sh
$(CONFIGURE_LIBOGG):
	cd src/ogg; ./autogen.sh

$(OGG_CONFIG_TYPES):
	cd src/ogg; emconfigure ./configure
	# Remove a.out* files created by emconfigure
	cd src/ogg; rm a.out*


$(OPUS_DECODE_TEST_FILE):
	@ mkdir -p tmp
	@ echo "Downloading decode test file $(OPUS_DECODE_TEST_FILE_URL)..."
	@ wget -q --show-progress $(OPUS_DECODE_TEST_FILE_URL) -O $(OPUS_DECODE_TEST_FILE)


native-decode-test: $(OPUS_DECODE_TEST_FILE)
# ** For development only **
#
# This target is used to test the opus decoding functionality independent
# of WebAssembly.  It's a fast workflow to test the decoding/deinterlacing of
# an .opus file and ensure that things work natively before we try integrating
# it into Wasm.  libopus and libopusfile must be installed natively on your
# system. If you're on a Mac, you can install with "brew install opusfile"
#
# The test program outputs 3 files:
#   - *.wav stereo wav file
#   - *left.pcm raw PCM file of left channel
#   - *right.pcm raw PCM file of right channel
#
# Raw left/right PCM files can be played from the command using SoX https://sox.sourceforge.io/
# "brew install sox" if you're on a Mac.  then play decoded *.pcm file:
#
#   $ play --type raw --rate 48000 --endian little --encoding floating-point --bits 32 --channels 1 [PCM_FILENAME]
#
ifndef OPUS_DIR
	$(error OPUS_DIR environment variable is required)
endif
ifndef OPUSFILE_DIR
	$(error OPUSFILE_DIR environment variable is required)
endif
	@ mkdir -p tmp
	@ clang \
		-o "$(NATIVE_DECODER_TEST)" \
		-I "$(OPUSFILE_DIR)/include/opus" \
		-I "$(OPUS_DIR)/include/opus" \
		"$(OPUSFILE_DIR)/lib/libopusfile.dylib" \
		src/*.c

	@ $(NATIVE_DECODER_TEST) tmp/decode-test-64kbps.opus
