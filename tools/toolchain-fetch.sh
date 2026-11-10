#!/bin/sh
# Fetch one archive named in ci/toolchain.lock.
#
# Order: a cached copy whose sha256 matches the lock, then the
# release URL with the same retries this repo already used, then
# the GitHub release asset API. If all three fail, exit 1 with
# "toolchain unavailable (HTTP <code>)".
#
# A cached copy is kept only after the checksum matches. The log
# says which source was used, for example
# "toolchain from cache: gnat_native 16.1.0".
#
# Alire calls this as "toolchain-fetch.sh ${URL} ${DEST}". That
# copies a locked archive into the destination and does not print
# a second "toolchain from cache" line.
#
#   toolchain-fetch.sh NAME
#   toolchain-fetch.sh --path NAME
#   toolchain-fetch.sh --source NAME
#   toolchain-fetch.sh URL DEST
#
# TOOLCHAIN_ATTEMPTS and TOOLCHAIN_SLEEP_STEP override the retry
# only for a local check. CI leaves them unset (6 attempts, sleep
# 15, 30, 45, 60, 75 seconds).
set -e
cd "$(dirname "$0")/.."

LOCK=$PWD/ci/toolchain.lock
CACHE=${TOOLCHAIN_CACHE:-$HOME/.cache/ada-ai-amplifier/toolchain}
ATTEMPTS=${TOOLCHAIN_ATTEMPTS:-6}
SLEEP_STEP=${TOOLCHAIN_SLEEP_STEP:-15}

if [ ! -f "$LOCK" ]; then
  echo "missing $LOCK" >&2
  exit 1
fi

HTTP_CODE=000
NAME=
VERSION=
SHA=
URL=
QUIET=0

find_lock() {
  key=$1
  NAME=
  VERSION=
  SHA=
  URL=
  while read -r f1 f2 f3 f4 rest; do
    case $f1 in
      ""|\#*) continue ;;
    esac
    if [ "$f1" = "$key" ] || [ "$f4" = "$key" ]; then
      NAME=$f1
      VERSION=$f2
      SHA=$f3
      URL=$f4
      return 0
    fi
  done < "$LOCK"
  return 1
}

archive_path() {
  printf '%s\n' "$CACHE/archives/$NAME/$(basename "$URL")"
}

matches() {
  file=$1
  if [ ! -f "$file" ]; then
    return 1
  fi
  got=$(sha256sum "$file" | awk 'NR==1 { print $1 }')
  [ "$got" = "$SHA" ]
}

note_source() {
  dir=$CACHE/archives/$NAME
  mkdir -p "$dir"
  printf '%s\n' "$1" > "$dir/source"
  if [ "$QUIET" = 1 ] && [ "$1" = cache ]; then
    return 0
  fi
  case $1 in
    cache) echo "toolchain from cache: $NAME $VERSION" ;;
    download) echo "toolchain from download: $NAME $VERSION" ;;
    release-asset) echo "toolchain from release asset: $NAME $VERSION" ;;
  esac
}

http_get() {
  url=$1
  dest=$2
  hdr=$3
  if [ -n "$hdr" ]; then
    HTTP_CODE=$(curl -sS -L --connect-timeout 30 \
      -H "$hdr" -o "$dest" -w "%{http_code}" "$url" || true)
  else
    HTTP_CODE=$(curl -sS -L --connect-timeout 30 \
      -o "$dest" -w "%{http_code}" "$url" || true)
  fi
  HTTP_CODE=$(printf '%s' "$HTTP_CODE" | tr -cd '0-9')
  if [ -z "$HTTP_CODE" ]; then
    HTTP_CODE=000
  fi
  case $HTTP_CODE in
    2*) return 0 ;;
  esac
  rm -f "$dest"
  return 1
}

download_retries() {
  url=$1
  dest=$2
  hdr=$3
  n=1
  while [ "$n" -le "$ATTEMPTS" ]; do
    if http_get "$url" "$dest" "$hdr"; then
      return 0
    fi
    echo "attempt $n failed: $url (HTTP $HTTP_CODE)" >&2
    if [ "$n" -eq "$ATTEMPTS" ]; then
      return 1
    fi
    sleep $((n * SLEEP_STEP))
    n=$((n + 1))
  done
  return 1
}

# The github.com release page has been returning 504. The asset
# API still serves the same file. This is the route added for that.
github_asset() {
  case $1 in
    https://github.com/*/releases/download/*/*) ;;
    *) return 1 ;;
  esac
  rest=${1#https://github.com/}
  owner=${rest%%/*}
  rest=${rest#*/}
  repo=${rest%%/*}
  rest=${rest#*/releases/download/}
  tag=${rest%%/*}
  name=${rest#*/}
  meta=$(mktemp)
  if ! http_get \
      "https://api.github.com/repos/$owner/$repo/releases/tags/$tag" \
      "$meta" ""; then
    rm -f "$meta"
    return 1
  fi
  found=$(python3 -c '
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
name = sys.argv[2]
for item in data.get("assets", []):
    if item["name"] == name:
        print(item["url"])
        raise SystemExit(0)
raise SystemExit(1)
' "$meta" "$name" || true)
  rm -f "$meta"
  if [ -z "$found" ]; then
    HTTP_CODE=404
    return 1
  fi
  printf '%s\n' "$found"
}

fail_http() {
  echo "toolchain unavailable (HTTP $HTTP_CODE): $NAME $VERSION" >&2
  exit 1
}

fail_sum() {
  echo "toolchain checksum mismatch: $NAME $VERSION" >&2
  exit 1
}

accept_file() {
  src=$1
  kind=$2
  dest_out=$3
  if ! matches "$src"; then
    rm -f "$src"
    return 1
  fi
  dir=$CACHE/archives/$NAME
  mkdir -p "$dir"
  final=$dir/$(basename "$URL")
  if [ "$src" != "$final" ]; then
    mv -f "$src" "$final"
  fi
  note_source "$kind"
  if [ -n "$dest_out" ] && [ "$dest_out" != "$final" ]; then
    cp -f "$final" "$dest_out"
  fi
  return 0
}

fetch_locked() {
  dest_out=$1
  final=$(archive_path)
  if matches "$final"; then
    note_source cache
    if [ -n "$dest_out" ] && [ "$dest_out" != "$final" ]; then
      cp -f "$final" "$dest_out"
    fi
    return 0
  fi
  rm -f "$final"

  tmp=$(mktemp)
  got_bytes=0
  if download_retries "$URL" "$tmp" ""; then
    got_bytes=1
    if accept_file "$tmp" download "$dest_out"; then
      return 0
    fi
    echo "checksum mismatch after download: $NAME $VERSION" >&2
  fi

  asset_file=$(mktemp)
  if github_asset "$URL" > "$asset_file"; then
    asset=$(cat "$asset_file")
  else
    asset=
  fi
  rm -f "$asset_file"
  if [ -n "$asset" ]; then
    tmp=$(mktemp)
    if download_retries "$asset" "$tmp" "Accept: application/octet-stream"; then
      got_bytes=1
      if accept_file "$tmp" release-asset "$dest_out"; then
        return 0
      fi
      echo "checksum mismatch after release asset: $NAME $VERSION" >&2
    fi
  fi

  if [ "$got_bytes" -eq 1 ]; then
    fail_sum
  fi
  fail_http
}

case ${1:-} in
  --path)
    find_lock "$2" || {
      echo "toolchain lock has no entry for $2" >&2
      exit 1
    }
    path=$(archive_path)
    if [ ! -f "$path" ]; then
      echo "missing cached archive for $NAME $VERSION" >&2
      exit 1
    fi
    printf '%s\n' "$path"
    ;;
  --source)
    find_lock "$2" || {
      echo "toolchain lock has no entry for $2" >&2
      exit 1
    }
    srcfile=$CACHE/archives/$NAME/source
    if [ ! -f "$srcfile" ]; then
      echo "missing source note for $NAME $VERSION" >&2
      exit 1
    fi
    cat "$srcfile"
    ;;
  http://*|https://*)
    QUIET=1
    find_lock "$1" || {
      echo "toolchain lock has no entry for $1" >&2
      exit 1
    }
    if [ -z "${2:-}" ]; then
      echo "missing destination for $1" >&2
      exit 1
    fi
    fetch_locked "$2"
    ;;
  "")
    echo "usage: toolchain-fetch.sh NAME" >&2
    exit 1
    ;;
  *)
    find_lock "$1" || {
      echo "toolchain lock has no entry for $1" >&2
      exit 1
    }
    fetch_locked ""
    ;;
esac
