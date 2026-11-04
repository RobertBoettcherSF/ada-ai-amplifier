#!/bin/sh
# Prove the SPARK units: the empty root, AI_Amplifier.Version, and
# AI_Amplifier.Tensors. Every other unit is SPARK_Mode => Off and is
# not a proof target. The project file passes --level=2,
# --timeout=120, and --report=all. Level 2 selects the provers.
# The timeout is long enough for the CI runner.
set -e
cd "$(dirname "$0")"
if [ ! -f config/ada_ai_amplifier_config.gpr ]; then
  alr -n build
fi
if ! command -v gnatprove >/dev/null 2>&1; then
  alr -n install gnatprove=16.1.0
  export PATH="$HOME/.alire/bin:$PATH"
fi
gnatprove -P ada_ai_amplifier.gpr -j0
mkdir -p proof
out=$(find obj -path '*/gnatprove/gnatprove.out' -print | head -1)
cp "$out" proof/gnatprove.out
gnatprove --version | head -1 > proof/version.txt
echo "Wrote proof/gnatprove.out"
