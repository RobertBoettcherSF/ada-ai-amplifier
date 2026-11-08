#!/bin/sh
# Build the locked specs, run them, and write the wasm body.
set -e
cd "$(dirname "$0")/.."
alr -n build
if [ -f obj/gen/tests.out ] && [ -f obj/gen/specs.out ] && [ -f obj/gen/recheck-report.txt ]; then
  ./tools/check-status.sh --logs-only
else
  ./tools/check-status.sh
fi
python3 tools/bake-locked.py
