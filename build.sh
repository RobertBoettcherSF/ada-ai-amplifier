#!/bin/sh
# Compiles the library bodies (not hello.adb) to WebAssembly with
# AdaWebPack 24 / GNAT-LLVM and wasm-ld, the same route as
# murmuration-spark and symmetry-visualizations, then embeds the module
# into site/index.html.
#
# Runtime checks stay on (-gnata, and no -gnatp). Nothing here is proved,
# so checks are not stripped. The bodies are written so this module does
# not call the exception runtime; the link does not pass
# --allow-undefined, so a check that needs that runtime fails here.
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
  # -gnatw.X: this runtime forbids exception propagation, and the
  # compiler warns that a check would call Last_Chance_Handler. The
  # same switch is in the native Alire profile. Checks stay compiled
  # in; -gnatp is not used.
  "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnata -gnatwa -gnatw.X -gnatwe \
    --RTS="$T/lib/rts-native" -I../../src "$F"
done
ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
"$LD" --no-entry --strip-all \
  --export=aa_version_length --export=aa_version_byte \
  --export=aa_splash_reset --export=aa_splash_tick \
  --export=aa_step --export=aa_count --export=aa_get \
  -z stack-size=2097152 --initial-memory=16777216 \
  -o ai_amplifier.wasm *.o
cd ../..
node tools/wasm-smoke.mjs
python3 - <<'PY'
import base64
import pathlib
wasm = pathlib.Path("obj/wasm/ai_amplifier.wasm").read_bytes()
token = "__WASM_BASE64__"
html = pathlib.Path("web/template.html").read_text()
if html.count(token) != 1:
    raise SystemExit("web/template.html must contain __WASM_BASE64__ once")
out = html.replace(token, base64.b64encode(wasm).decode("ascii"), 1)
site = pathlib.Path("site")
site.mkdir(exist_ok=True)
(site / "index.html").write_text(out)
(site / "version.txt").write_text(pathlib.Path("version.txt").read_text())
if token in out:
    raise SystemExit("placeholder survived into site/index.html")
print(f"Wrote site/index.html ({len(out)} bytes)")
PY
echo "Built obj/wasm/ai_amplifier.wasm ($(wc -c < obj/wasm/ai_amplifier.wasm) bytes)"
