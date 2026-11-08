#!/bin/sh
# Build the locked specs, run them, and write the wasm body.
set -e
cd "$(dirname "$0")/.."
alr -n build
python3 tools/bake-locked.py
