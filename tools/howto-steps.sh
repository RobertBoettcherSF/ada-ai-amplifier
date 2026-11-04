#!/bin/sh
# Newcomer path. docs/HOWTO.md quotes this file.
# CI job "how-to steps" runs it on a clean Ubuntu runner after
# tools/howto-packages.sh, with Node 22 and Alire 2.1.1 on PATH.
set -e
cd "$(dirname "$0")/.."
alr -n toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
./tools/get-toolchain.sh
alr -n build
./bin/hello
./tools/check-version.sh
./bin/tensors_test
./bin/mlp_test
./bin/attention_test
npm ci
./build.sh
node tools/page-smoke.mjs
printf 'Open site/index.html in a browser. The badge should read %s.\n' "$(tr -d '\n' < version.txt)"
