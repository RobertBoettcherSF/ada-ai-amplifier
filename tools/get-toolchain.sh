#!/bin/sh
# Downloads the Ada -> WebAssembly compiler (AdaWebPack 24 = GNAT-LLVM) into
# ./toolchain.  Needs once:  sudo apt install rpm2cpio cpio lld libedit2
# Same sources as murmuration-spark and symmetry-visualizations.
# Versions and checksums are ci/toolchain.lock. A cached copy is used
# only when its sha256 matches. Otherwise this retries the download,
# then the GitHub release asset API, and stops with
# "toolchain unavailable (HTTP <code>)".
set -e
cd "$(dirname "$0")/.."
fetch=$PWD/tools/toolchain-fetch.sh

need=0
for piece in adawebpack llvm16_libs clang16_libs gnat14; do
  "$fetch" "$piece"
  src=$("$fetch" --source "$piece")
  if [ "$src" != cache ]; then
    need=1
  fi
done

if [ "$need" -eq 0 ] && [ -x toolchain/usr/bin/llvm-gcc ]; then
  if ldconfig -p | grep -q libgnat-14.so || [ -e toolchain/lib/libgnat-14.so ]; then
    echo "Toolchain already present in $PWD/toolchain"
    exit 0
  fi
fi

rm -rf toolchain
mkdir -p toolchain
cd toolchain
for piece in adawebpack llvm16_libs clang16_libs; do
  rpm=$("$fetch" --path "$piece")
  rpm2cpio "$rpm" | cpio -idm --quiet
done
mkdir -p lib
cp usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
[ -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ] || ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
# The compiler itself is written in Ada and needs the GNAT 14 runtime library.
# The crate gnat_native=14.2.1 is the archive pinned as gnat14.
if ! ldconfig -p | grep -q libgnat-14.so; then
  if [ ! -e lib/libgnat-14.so ]; then
    archive=$("$fetch" --path gnat14)
    tmp=$(mktemp -d)
    tar -xzf "$archive" -C "$tmp"
    lib=$(find "$tmp" -name 'libgnat-14.so' | head -1)
    if [ -z "$lib" ]; then
      rm -rf "$tmp"
      echo "libgnat-14.so was not in the GNAT 14 archive" >&2
      exit 1
    fi
    cp "$lib" lib/
    rm -rf "$tmp"
  fi
fi
rm -rf usr/lib64
echo "Toolchain ready in $PWD"
