#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp "${TMPDIR:-/tmp}/eigenlua-arith.XXXXXX") || exit 2
trap 'rm -f "$tmp"' EXIT HUP INT TERM
python3 "$ROOT/tools/arith.py" >"$tmp" || exit 1
cmp "$tmp" "$ROOT/corpus/D/number_arith.lua" || { echo 'number arithmetic corpus is stale' >&2; exit 1; }
echo 'PASS number arithmetic corpus is reproducible'
