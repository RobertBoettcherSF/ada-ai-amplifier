#!/bin/sh
# Prove one SPARK unit per item that has a proof. Each run writes
# proof/item_NN.out. A proved label may name only that file.
# The project file passes --level=2, --timeout=120, --report=all,
# and --checks-as-errors=on. Units with SPARK_Mode => Off are not
# targets. The timeout is long enough for the CI runner.
set -e
cd "$(dirname "$0")"

# The release page on github.com has been returning 504. The
# asset API still serves the same archive. Try Alire once, then
# that API.
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

install_gnatprove_archive() {
  root="$HOME/.local/gnatprove-16.1.0"
  bindir="$root/gnatprove-x86_64-linux-16.1.0-1/bin"
  if [ -x "$bindir/gnatprove" ]; then
    export PATH="$bindir:$PATH"
    return 0
  fi
  meta=$(mktemp)
  archive=$(mktemp)
  retry curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
    -o "$meta" \
    https://api.github.com/repos/alire-project/GNAT-FSF-builds/releases/tags/gnatprove-16.1.0-1
  asset=$(python3 -c '
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
name = "gnatprove-x86_64-linux-16.1.0-1.tar.gz"
for item in data["assets"]:
    if item["name"] == name:
        print(item["url"])
        raise SystemExit(0)
raise SystemExit("missing " + name)
' "$meta")
  retry curl -fL --retry 5 --retry-all-errors --retry-delay 5 \
    -H "Accept: application/octet-stream" \
    -o "$archive" "$asset"
  mkdir -p "$root"
  tar -xzf "$archive" -C "$root"
  rm -f "$meta" "$archive"
  export PATH="$bindir:$PATH"
}

if [ ! -f config/ada_ai_amplifier_config.gpr ]; then
  alr -n build
fi
if ! command -v gnatprove >/dev/null 2>&1; then
  if alr -n install gnatprove=16.1.0; then
    export PATH="$HOME/.alire/bin:$PATH"
  else
    echo "alr could not fetch gnatprove; downloading the release asset" >&2
    install_gnatprove_archive
  fi
fi

mkdir -p proof
rm -f proof/gnatprove.out

prove_one() {
  dest=$1
  unit=$2
  echo "Proving $unit -> $dest"
  # A leftover session would mix another item's units into this
  # summary. Each item starts from an empty proof directory.
  rm -rf obj/development/gnatprove
  gnatprove -P ada_ai_amplifier.gpr -j0 "$unit"
  out=$(find obj -path '*/gnatprove/gnatprove.out' -print | head -1)
  if [ -z "$out" ] || [ ! -f "$out" ]; then
    echo "no gnatprove.out for $unit" >&2
    exit 1
  fi
  cp "$out" "$dest"
}

prove_one proof/item_01.out ai_amplifier-version.adb
prove_one proof/item_03.out ai_amplifier-tensors.adb
prove_one proof/item_07.out ai_amplifier-tensors.adb
prove_one proof/item_09.out ai_amplifier-chain_rule.adb
prove_one proof/item_11.out ai_amplifier-trace_rule.adb
prove_one proof/item_12.out ai_amplifier-audit_rule.adb
gnatprove --version | head -1 > proof/version.txt
echo "Wrote per-item proof logs"
