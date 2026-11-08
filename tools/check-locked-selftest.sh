#!/bin/sh
# The gate has to fail when a spec is edited, when an Assume
# pragma is added, and when a test is marked skipped. This runs
# on a throwaway copy. It also checks that an updated specs/LOCK
# is refused unless the pull request text names that file.
set -e
cd "$(dirname "$0")/.."
root=$(pwd)
# The CI job exports the pull-request body and base. Those belong to
# the real checkout. A throwaway copy is not that checkout.
unset CHECK_LOCKED_EVENT CHECK_LOCKED_BASE CHECK_LOCKED_BODY
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

seed() {
  rm -rf "$tmp/tree"
  mkdir -p "$tmp/tree"
  cp -a specs src "$tmp/tree/"
  # The copy is not a git checkout unless a later step makes one.
}

seed
python3 tools/check-locked.py --root "$tmp/tree"

seed
printf '\n' >> "$tmp/tree/specs/item_01.adb"
if python3 tools/check-locked.py --root "$tmp/tree"; then
  echo "edited spec was accepted" >&2
  exit 1
fi

seed
printf '\n   pragma Assume (True);\n' >> "$tmp/tree/src/ai_amplifier-locked.adb"
if python3 tools/check-locked.py --root "$tmp/tree"; then
  echo "Assume pragma was accepted" >&2
  exit 1
fi

seed
printf '\n-- skipped test\n' >> "$tmp/tree/src/ai_amplifier-locked.adb"
if python3 tools/check-locked.py --root "$tmp/tree"; then
  echo "skipped test was accepted" >&2
  exit 1
fi

seed
git -C "$tmp/tree" init -q
git -C "$tmp/tree" config user.email dev@local
git -C "$tmp/tree" config user.name Lock
git -C "$tmp/tree" config commit.gpgsign false
git -C "$tmp/tree" add specs src
git -C "$tmp/tree" commit -q -m "base"
printf '\n# touch\n' >> "$tmp/tree/specs/LOCK"
git -C "$tmp/tree" add specs/LOCK
git -C "$tmp/tree" commit -q -m "lock"
base=$(git -C "$tmp/tree" rev-parse HEAD~1)
if CHECK_LOCKED_EVENT=pull_request \
   CHECK_LOCKED_BASE="$base" \
   CHECK_LOCKED_BODY="" \
   python3 "$root/tools/check-locked.py" --root "$tmp/tree"
then
  echo "unnamed LOCK update was accepted" >&2
  exit 1
fi
CHECK_LOCKED_EVENT=pull_request \
  CHECK_LOCKED_BASE="$base" \
  CHECK_LOCKED_BODY="This change updates specs/LOCK." \
  python3 "$root/tools/check-locked.py" --root "$tmp/tree"

echo "locked self-test ok"
