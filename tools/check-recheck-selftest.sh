#!/bin/sh
# The comparison has to fail when either checker is wrong.
# This runs on a throwaway copy. The copy is not a git checkout:
# .git is not copied, and a later step does not run git init.
set -e
cd "$(dirname "$0")/.."
root=$(pwd)
# A throwaway copy is not the CI checkout. Do not inherit a
# pull-request body or a base commit from that checkout.
unset CHECK_LOCKED_EVENT CHECK_LOCKED_BASE CHECK_LOCKED_BODY
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/tree" "$tmp/pristine"
cp alire.toml ada_ai_amplifier.gpr "$tmp/tree/"
cp -a src specs "$tmp/pristine/"
cp -a src specs "$tmp/tree/"
if git -C "$tmp/tree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "throwaway copy is a git checkout" >&2
  exit 1
fi

build_copy() {
  find "$tmp/tree/src" "$tmp/tree/specs" -type f -exec touch {} +
  (cd "$tmp/tree" && alr -n build)
}

restore() {
  rm -rf "$tmp/tree/src" "$tmp/tree/specs"
  cp -a "$tmp/pristine/src" "$tmp/pristine/specs" "$tmp/tree/"
}

expect_fail() {
  label=$1
  shift
  set +e
  out=$("$tmp/tree/bin/recheck_test" 2>&1)
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    echo "$label was accepted" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  printf '%s\n' "$out" | grep -q "disagree $label" || {
    echo "missing case $label" >&2
    printf '%s\n' "$out" >&2
    exit 1
  }
  for needle in "$@"; do
    printf '%s\n' "$out" | grep -F -q "$needle" || {
      echo "missing answer for $label: $needle" >&2
      printf '%s\n' "$out" >&2
      exit 1
    }
  done
}

build_copy
"$tmp/tree/bin/recheck_test" >/dev/null

restore
sed -i 's/Reason := XOR_Returned;/Reason := Loss_Rose;/' \
  "$tmp/tree/src/ai_amplifier-traces.adb"
build_copy
expect_fail "11/rate-diverges/1" \
  "traces verdict fixes-it reason loss-rose bad 0" \
  "recheck verdict fixes-it reason xor-returned bad 0"

restore
sed -i 's/Add_Flag (Bank.Slot (I), Wrong_Expected);/null;/' \
  "$tmp/tree/src/ai_amplifier-audit.adb"
build_copy
expect_fail "12/fib-5-wrong" \
  "audit verdict pass reason none bad 0" \
  "recheck verdict flag reason wrong-expected bad 0"

restore
sed -i 's/Blame (Where, Bad_Value);/null;/' \
  "$tmp/tree/src/ai_amplifier-steps.adb"
build_copy
expect_fail "15/xor-10-cancel" \
  "steps verdict pass reason none bad 0 answer pass" \
  "recheck verdict fail reason bad-value bad 2 answer pass"

restore
sed -i 's/Fix_Reason : constant String := "xor-returned";/Fix_Reason : constant String := "loss-rose";/' \
  "$tmp/tree/src/ai_amplifier-recheck.adb"
build_copy
expect_fail "11/rate-diverges/1" \
  "traces verdict fixes-it reason xor-returned bad 0" \
  "recheck verdict fixes-it reason loss-rose bad 0"

echo "recheck self-test ok"
