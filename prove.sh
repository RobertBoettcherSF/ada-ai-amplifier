#!/bin/sh
# Flow analysis only (--mode=flow). Does not attempt proof of
# run-time checks or functional contracts. The project file requests
# the same mode.
set -e
cd "$(dirname "$0")"
if [ ! -f config/ada_ai_amplifier_config.gpr ]; then
  alr -n build
fi
gnatprove -P ada_ai_amplifier.gpr --mode=flow -j0 --report=all
mkdir -p proof
out=$(find obj -path '*/gnatprove/gnatprove.out' -print | head -1)
cp "$out" proof/gnatprove.out
gnatprove --version | head -1 > proof/version.txt
echo "Wrote proof/gnatprove.out"
