#!/bin/sh
# Prove one SPARK unit per item that has a proof. Each run writes
# proof/item_NN.out. A proved label may name only that file.
# The project file passes --level=2, --timeout=120, --report=all,
# and --checks-as-errors=on. Units with SPARK_Mode => Off are not
# targets. The timeout is long enough for the CI runner.
set -e
cd "$(dirname "$0")"

# gnatprove 16.1.0 is pinned in ci/toolchain.lock. The fetch tries
# the cache, then the release URL, then the release asset API.
install_gnatprove_archive() {
  root="$HOME/.local/gnatprove-16.1.0"
  bindir="$root/gnatprove-x86_64-linux-16.1.0-1/bin"
  if [ -x "$bindir/gnatprove" ]; then
    export PATH="$bindir:$PATH"
    return 0
  fi
  archive=$("$PWD/tools/toolchain-fetch.sh" --path gnatprove)
  mkdir -p "$root"
  tar -xzf "$archive" -C "$root"
  if [ ! -x "$bindir/gnatprove" ]; then
    echo "gnatprove was not in the pinned archive" >&2
    exit 1
  fi
  export PATH="$bindir:$PATH"
}

if [ ! -f config/ada_ai_amplifier_config.gpr ]; then
  alr -n build
fi
if [ -x "$HOME/.alire/bin/gnatprove" ]; then
  export PATH="$HOME/.alire/bin:$PATH"
fi
if ! command -v gnatprove >/dev/null 2>&1; then
  "$PWD/tools/toolchain-fetch.sh" gnatprove
  prove_ver=$(awk '$1=="gnatprove" { print $2; exit }' ci/toolchain.lock)
  if alr -n install "gnatprove=$prove_ver"; then
    export PATH="$HOME/.alire/bin:$PATH"
  else
    echo "alr could not install gnatprove; unpacking the pinned archive" >&2
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
prove_one proof/item_13.out ai_amplifier-reward_rule.adb
prove_one proof/item_15.out ai_amplifier-step_rule.adb
prove_one proof/item_16.out ai_amplifier-lock_rule.adb
prove_one proof/item_17.out ai_amplifier-agree_rule.adb
prove_one proof/item_18.out ai_amplifier-label_rule.adb
prove_one proof/ask_rule.out ai_amplifier-ask_rule.adb
gnatprove --version | head -1 > proof/version.txt

# Item 19's flag rules. Separate project, separate log.
# The same bytes are also item_19.out so STATUS names that run.
rm -rf obj/summary_rules
gnatprove -P summary_rules.gpr -j0
rules=$(find obj/summary_rules -path '*/gnatprove/gnatprove.out' -print | head -1)
if [ -z "$rules" ] || [ ! -f "$rules" ]; then
  echo "no gnatprove.out for summary rules" >&2
  exit 1
fi
cp "$rules" proof/summary_rules.out
cp "$rules" proof/item_19.out
gnatprove --version | head -1 > proof/version.txt
echo "Wrote per-item proof logs"
