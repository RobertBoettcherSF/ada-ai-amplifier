#!/bin/sh
# Downloads the Ada -> WebAssembly compiler (AdaWebPack 24 = GNAT-LLVM) into
# ./toolchain.  Needs once:  sudo apt install rpm2cpio cpio lld libedit2
# Same sources as murmuration-spark and symmetry-visualizations.
set -e
cd "$(dirname "$0")/.."

# GitHub has returned 504 for the AdaWebPack archive. Retry the
# transfer, and keep the bytes only when curl exits 0.
retry() {
  n=1
  while [ "$n" -le 6 ]; do
    if "$@"; then
      return 0
    fi
    echo "attempt $n failed: $*" >&2
    if [ "$n" -eq 6 ]; then
      return 1
    fi
    sleep $((n * 15))
    n=$((n + 1))
  done
}

fetch_rpm() {
  url=$1
  dest=$(mktemp)
  echo "Downloading $url"
  if ! retry curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -o "$dest" "$url"; then
    rm -f "$dest"
    return 1
  fi
  rpm2cpio "$dest" | cpio -idm --quiet
  rm -f "$dest"
}

if [ -x toolchain/usr/bin/llvm-gcc ]; then
  echo "Toolchain already present in $PWD/toolchain"
  exit 0
fi
mkdir -p toolchain && cd toolchain
F=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Everything/x86_64/os/Packages
for U in https://github.com/godunko/adawebpack/releases/download/24.0.0/adawebpack-24.0.0-git.fc40.x86_64.rpm \
         $F/l/llvm16-libs-16.0.6-7.fc40.x86_64.rpm \
         $F/c/clang16-libs-16.0.6-5.fc40.x86_64.rpm; do
  fetch_rpm "$U"
done
mkdir -p lib
cp usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
[ -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ] || ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
# The compiler itself is written in Ada and needs the GNAT 14 runtime library.
if ! ldconfig -p | grep -q libgnat-14.so; then
  retry alr -n install --prefix="$PWD/gnat14" gnat_native=14.2.1
  cp "$(find gnat14 -name libgnat-14.so | head -1)" lib/
fi
rm -rf usr/lib64 gnat14
echo "Toolchain ready in $PWD"
