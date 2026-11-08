#!/bin/sh
# A missing test line has to change the label. The copy is not
# the committed STATUS file.
set -e
cd "$(dirname "$0")/.."
if [ ! -f obj/gen/tests.out ] || [ ! -x bin/status_cli ]; then
  echo "status self-test needs the logs and status_cli" >&2
  exit 1
fi
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
sed '/^mlp ok$/d' obj/gen/tests.out > "$tmp/tests.out"
./bin/status_cli \
  proof/gnatprove.out \
  "$tmp/tests.out" \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/out"
grep -q '^item 04 unchecked ' "$tmp/out"
grep -q '^item 08 unchecked ' "$tmp/out"
grep -q '^item 10 unchecked ' "$tmp/out"
grep -q '^item 03 proved ' "$tmp/out"
grep -q '^item 07 proved ' "$tmp/out"
grep -q 'would take mlp_test' "$tmp/out"
if diff -q STATUS "$tmp/out" >/dev/null; then
  echo "tampered log matched STATUS" >&2
  exit 1
fi
echo "status self-test ok"
