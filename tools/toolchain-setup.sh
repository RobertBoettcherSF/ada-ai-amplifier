#!/bin/sh
# Put the pinned Alire toolchain on this machine.
# Reads ci/toolchain.lock. Each archive is cached, or downloaded,
# or taken from the GitHub release asset API. The log names the
# source. alr then installs from the cached bytes, so a later
# select does not fetch the archive again.
#
#   ./tools/toolchain-setup.sh
#   ./tools/toolchain-setup.sh with-gnatprove
#
# with-gnatprove also installs GNATprove 16.1.0. The prove job
# passes that. The page job does not: it does not run GNATprove.
set -e
cd "$(dirname "$0")/.."

mode=${1:-}
fetch=$PWD/tools/toolchain-fetch.sh

"$fetch" gnat_native
"$fetch" gprbuild
if [ "$mode" = with-gnatprove ]; then
  "$fetch" gnatprove
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  printf '%s\n' "$PWD/tools" >> "$GITHUB_PATH"
fi
export PATH="$PWD/tools:$PATH"

# Alire splits this on spaces and replaces the two tokens.
alr -n settings --global --set origins.archive.download_cmd \
  'toolchain-fetch.sh ${URL} ${DEST}'

gnat_ver=$(awk '$1=="gnat_native" { print $2; exit }' ci/toolchain.lock)
gpr_ver=$(awk '$1=="gprbuild" { print $2; exit }' ci/toolchain.lock)
if [ -z "$gnat_ver" ] || [ -z "$gpr_ver" ]; then
  echo "toolchain lock is missing gnat_native or gprbuild" >&2
  exit 1
fi
if ! alr -n toolchain --select \
    "gnat_native=$gnat_ver" "gprbuild=$gpr_ver"; then
  echo "alr could not select the pinned toolchain" >&2
  exit 1
fi

if [ "$mode" != with-gnatprove ]; then
  exit 0
fi

if [ -x "$HOME/.alire/bin/gnatprove" ]; then
  export PATH="$HOME/.alire/bin:$PATH"
fi
if command -v gnatprove >/dev/null 2>&1; then
  if [ -n "${GITHUB_PATH:-}" ] && [ -x "$HOME/.alire/bin/gnatprove" ]; then
    printf '%s\n' "$HOME/.alire/bin" >> "$GITHUB_PATH"
  fi
  exit 0
fi

prove_ver=$(awk '$1=="gnatprove" { print $2; exit }' ci/toolchain.lock)
if alr -n install "gnatprove=$prove_ver"; then
  export PATH="$HOME/.alire/bin:$PATH"
else
  echo "alr could not install gnatprove; unpacking the pinned archive" >&2
  archive=$("$fetch" --path gnatprove)
  root=$HOME/.local/gnatprove-16.1.0
  mkdir -p "$root"
  tar -xzf "$archive" -C "$root"
  bindir=$root/gnatprove-x86_64-linux-16.1.0-1/bin
  if [ ! -x "$bindir/gnatprove" ]; then
    echo "gnatprove was not in the pinned archive" >&2
    exit 1
  fi
  export PATH="$bindir:$PATH"
  if [ -n "${GITHUB_PATH:-}" ]; then
    printf '%s\n' "$bindir" >> "$GITHUB_PATH"
  fi
  exit 0
fi

if [ ! -x "$HOME/.alire/bin/gnatprove" ]; then
  echo "gnatprove was not installed to $HOME/.alire/bin" >&2
  exit 1
fi
if [ -n "${GITHUB_PATH:-}" ]; then
  printf '%s\n' "$HOME/.alire/bin" >> "$GITHUB_PATH"
fi
