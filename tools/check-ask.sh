#!/bin/sh
# Point the three --ask commands at the local stand-in and
# record what each one sent and printed. bin/ask_test reads
# those files. This script does not call a real model.
set -e
cd "$(dirname "$0")/.."
port="${ASK_STANDIN_PORT:-8765}"
dir="obj/gen/ask"
rm -rf "$dir"
mkdir -p "$dir"
python3 tools/standin_model.py "$port" "$dir" >"$dir/server.out" 2>"$dir/server.err" &
server=$!
cleanup() {
  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
}
trap cleanup EXIT
ready=0
i=0
while [ "$i" -lt 50 ]; do
  if curl -sf "http://127.0.0.1:$port/health" >/dev/null; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 0.1
done
if [ "$ready" -ne 1 ]; then
  echo "stand-in did not start" >&2
  cat "$dir/server.err" >&2 || true
  exit 1
fi

run_one() {
  mode=$1
  which=$2
  bin=$3
  arg=$4
  url_name=$5
  key_name=$6
  model_name=$7
  # Drop a curl override so this run uses curl itself.
  set +e
  env -u RECURSE_LLM_CURL -u TRACES_LLM_CURL -u HARNESS_LLM_CURL \
    "$url_name=http://127.0.0.1:$port/$mode/$which" \
    "$key_name=standin-key" \
    "$model_name=standin" \
    "$bin" --ask "$arg" >"$dir/$mode-$which.cli" 2>"$dir/$mode-$which.err"
  echo $? >"$dir/$mode-$which.exit"
  set -e
}

run_one good recurse ./bin/recurse_cli 1 \
  RECURSE_LLM_URL RECURSE_LLM_KEY RECURSE_LLM_MODEL
run_one wrong recurse ./bin/recurse_cli 1 \
  RECURSE_LLM_URL RECURSE_LLM_KEY RECURSE_LLM_MODEL
run_one broken recurse ./bin/recurse_cli 1 \
  RECURSE_LLM_URL RECURSE_LLM_KEY RECURSE_LLM_MODEL
run_one good traces ./bin/traces_cli 1 \
  TRACES_LLM_URL TRACES_LLM_KEY TRACES_LLM_MODEL
run_one wrong traces ./bin/traces_cli 1 \
  TRACES_LLM_URL TRACES_LLM_KEY TRACES_LLM_MODEL
run_one broken traces ./bin/traces_cli 1 \
  TRACES_LLM_URL TRACES_LLM_KEY TRACES_LLM_MODEL
run_one good harness ./bin/harness_cli rate-diverges \
  HARNESS_LLM_URL HARNESS_LLM_KEY HARNESS_LLM_MODEL
run_one wrong harness ./bin/harness_cli rate-diverges \
  HARNESS_LLM_URL HARNESS_LLM_KEY HARNESS_LLM_MODEL
run_one broken harness ./bin/harness_cli rate-diverges \
  HARNESS_LLM_URL HARNESS_LLM_KEY HARNESS_LLM_MODEL

# The three timeouts wait on curl's 30 second limit. They
# share the stand-in, which answers other paths at once.
run_one timeout recurse ./bin/recurse_cli 1 \
  RECURSE_LLM_URL RECURSE_LLM_KEY RECURSE_LLM_MODEL &
p1=$!
run_one timeout traces ./bin/traces_cli 1 \
  TRACES_LLM_URL TRACES_LLM_KEY TRACES_LLM_MODEL &
p2=$!
run_one timeout harness ./bin/harness_cli rate-diverges \
  HARNESS_LLM_URL HARNESS_LLM_KEY HARNESS_LLM_MODEL &
p3=$!
wait "$p1" || true
wait "$p2" || true
wait "$p3" || true

./bin/ask_test "$dir"
