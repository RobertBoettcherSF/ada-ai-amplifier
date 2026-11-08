#!/bin/sh
# Prove the SPARK units: the empty root, AI_Amplifier.Version, and
# AI_Amplifier.Tensors. Every other unit is SPARK_Mode => Off and is
# not a proof target. The project file passes --level=2,
# --timeout=120, and --report=all. Level 2 selects the provers.
# The timeout is long enough for the CI runner.
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
#  The legacy set is the root, the version unit, and the
#  tensors. Summary_Rules is excluded there so this log stays
#  the 419 checks. The flag rules are proved just below.
gnatprove -P ada_ai_amplifier.gpr -XPROOF_SET=legacy -j0
mkdir -p proof
out=$(find obj -path '*/gnatprove/gnatprove.out' -print | head -1)
cp "$out" proof/gnatprove.out
gnatprove -P summary_rules.gpr -j0
rules=$(find obj/summary_rules -path '*/gnatprove/gnatprove.out' -print | head -1)
cp "$rules" proof/summary_rules.out
gnatprove --version | head -1 > proof/version.txt
echo "Wrote proof/gnatprove.out and proof/summary_rules.out"
