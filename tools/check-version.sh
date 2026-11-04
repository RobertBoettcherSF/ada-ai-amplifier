#!/bin/sh
# The Ada constant is the source of the visible stamp. hello's output,
# version.txt, and the badge in web/index.html must carry that same text.
set -e
cd "$(dirname "$0")/.."
stamp=$(sed -n 's/.*Version_Text : constant String := "\([^"]*\)".*/\1/p' \
  src/ai_amplifier-version.ads)
if [ -z "$stamp" ]; then
  echo "Version_Text not found in src/ai_amplifier-version.ads" >&2
  exit 1
fi
printf '%s\n' "$stamp" | cmp - version.txt
got=$(./bin/hello)
if [ "$got" != "ada-ai-amplifier $stamp" ]; then
  echo "hello printed: $got" >&2
  exit 1
fi
grep -F "id=\"ver\">${stamp}<" web/template.html >/dev/null
echo "stamp $stamp matches hello, version.txt, and web/template.html"
