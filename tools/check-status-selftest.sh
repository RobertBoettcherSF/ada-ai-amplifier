#!/bin/sh
# A missing test line, a missing proof file, or an unproved mark
# has to change the label. The copy is not the committed STATUS file.
set -e
cd "$(dirname "$0")/.."
if [ ! -f obj/gen/tests.out ] || [ ! -x bin/status_cli ]; then
  echo "status self-test needs the logs and status_cli" >&2
  exit 1
fi
if [ ! -f proof/item_03.out ] || [ ! -f proof/item_07.out ]; then
  echo "status self-test needs the per-item proof logs" >&2
  exit 1
fi
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
sed '/^mlp ok$/d' obj/gen/tests.out > "$tmp/tests.out"
./bin/status_cli \
  proof \
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
grep -q 'live-ask unchecked' "$tmp/out"
if diff -q STATUS "$tmp/out" >/dev/null; then
  echo "tampered log matched STATUS" >&2
  exit 1
fi
mkdir -p "$tmp/proof"
cp proof/item_*.out "$tmp/proof/"
rm -f "$tmp/proof/item_03.out"
./bin/status_cli \
  "$tmp/proof" \
  obj/gen/tests.out \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/missing"
if grep -q '^item 03 proved ' "$tmp/missing"; then
  echo "missing proof file still proved item 03" >&2
  exit 1
fi
cp proof/item_07.out "$tmp/proof/item_07.out"
printf '\nunproved\n' >> "$tmp/proof/item_07.out"
./bin/status_cli \
  "$tmp/proof" \
  obj/gen/tests.out \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/bad"
if grep -q '^item 07 proved ' "$tmp/bad"; then
  echo "unproved mark still proved item 07" >&2
  exit 1
fi
./bin/status_cli \
  proof \
  obj/gen/tests.out \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/good"
grep -q '^item 18 tested ' "$tmp/good"
grep -q 'no gnatprove run' "$tmp/good"
grep -q '^summary proved 7 of 19, tested 12, unchecked 0$' "$tmp/good"
if grep -q '^item 18 proved ' "$tmp/good"; then
  echo "item 18 was proved without a gnatprove run" >&2
  exit 1
fi
mkdir -p "$tmp/proof18"
cp proof/item_*.out "$tmp/proof18/"
cat > "$tmp/proof18/item_18.out" << 'EOF'
Total                             4    1 (25%)    3 (75%)           .          .

in unit ai_amplifier-status, 1 subprograms and packages out of 1 analyzed
  AI_Amplifier.Status at ai_amplifier-status.ads:1 flow analyzed (0 errors, 0 checks, 0 warnings and 0 pragma Assume statements) and proved (3 checks)
EOF
./bin/status_cli \
  "$tmp/proof18" \
  obj/gen/tests.out \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/proved18"
grep -q '^item 18 proved ' "$tmp/proved18"
grep -q 'proof/item_18.out' "$tmp/proved18"
grep -q 'unproved 0' "$tmp/proved18"
grep -q 'ai_amplifier-status' "$tmp/proved18"
grep -q '^summary proved 8 of 19, tested 11, unchecked 0$' "$tmp/proved18"
printf '\nunproved\n' >> "$tmp/proof18/item_18.out"
./bin/status_cli \
  "$tmp/proof18" \
  obj/gen/tests.out \
  obj/gen/specs.out \
  obj/gen/recheck-report.txt \
  specs > "$tmp/bad18"
if grep -q '^item 18 proved ' "$tmp/bad18"; then
  echo "a marked proof still proved item 18" >&2
  exit 1
fi
grep -q '^item 18 tested ' "$tmp/bad18"
echo "status self-test ok"
