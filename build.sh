#!/bin/sh
# Compiles the library bodies (not hello.adb) to WebAssembly with
# AdaWebPack 24 / GNAT-LLVM and wasm-ld, the same route as
# murmuration-spark and symmetry-visualizations.
#
# Runtime checks stay on (-gnata, and no -gnatp). Item 1 has no proof
# that would justify stripping them. The version body is written so this
# module does not call the exception runtime; the link does not pass
# --allow-undefined, so a future check that needs that runtime fails here.
set -e
cd "$(dirname "$0")"
T=$PWD/toolchain/usr
[ -x "$T/bin/llvm-gcc" ] || { echo "Run tools/get-toolchain.sh first"; exit 1; }
export LD_LIBRARY_PATH="$PWD/toolchain/lib"
LD=$(command -v wasm-ld || ls /usr/bin/wasm-ld-* | tail -1)
rm -rf obj/wasm && mkdir -p obj/wasm
cd obj/wasm
for F in ../../src/*.adb; do
  case $(basename "$F") in
    hello.adb) continue ;;
  esac
  "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnata -gnatwa -gnatwe \
    --RTS="$T/lib/rts-native" -I../../src "$F"
done
ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
"$LD" --no-entry --strip-all \
  --export=aa_version_length --export=aa_version_byte \
  -z stack-size=2097152 --initial-memory=16777216 \
  -o ai_amplifier.wasm *.o
cd ../..
node tools/wasm-smoke.mjs
echo "Built obj/wasm/ai_amplifier.wasm ($(wc -c < obj/wasm/ai_amplifier.wasm) bytes)"
