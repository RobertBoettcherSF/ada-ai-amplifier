#!/bin/sh
# Rebuild the checking-status logs and fail if STATUS drifted.
# The Ada program derives the labels. This script only runs the
# programs and compares the text.
set -e
cd "$(dirname "$0")/.."
logs_only=0
if [ "${1:-}" = "--logs-only" ]; then
  logs_only=1
fi
mkdir -p obj/gen
if [ "$logs_only" -eq 0 ]; then
  set +e
  (
    set -e
    ./tools/check-version.sh
    echo "check-version ok"
    ./bin/tensors_test
    ./bin/mlp_test
    ./bin/attention_test
    ./bin/recurse_test
    ./bin/traces_test
    ./bin/audit_test
    ./bin/reward_test
    ./bin/harness_test
    ./bin/steps_test
    ./bin/recheck_test obj/gen/recheck-report.txt
    python3 tools/check-locked.py
  ) > obj/gen/tests.out
  code=$?
  set -e
  if [ "$code" -ne 0 ]; then
    echo "status inputs failed" >&2
    cat obj/gen/tests.out >&2
    exit "$code"
  fi
  set +e
  (
    set -e
    for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17; do
      ./bin/item_"$n"
    done
  ) > obj/gen/specs.out
  code=$?
  set -e
  if [ "$code" -ne 0 ]; then
    echo "spec inputs failed" >&2
    cat obj/gen/specs.out >&2
    exit "$code"
  fi
fi
for need in obj/gen/tests.out obj/gen/specs.out obj/gen/recheck-report.txt \
  proof/item_01.out proof/item_03.out proof/item_07.out \
  proof/item_09.out proof/item_11.out proof/item_12.out
do
  if [ ! -f "$need" ]; then
    echo "missing $need" >&2
    exit 1
  fi
done
./bin/status_cli > obj/gen/STATUS.out
diff -u STATUS obj/gen/STATUS.out
python3 tools/check-proof-runs.py
./tools/check-status-selftest.sh
echo "status ok"
