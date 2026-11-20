#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp "${TMPDIR:-/tmp}/eigenlua-arith.XXXXXX") || exit 2
trap 'rm -f "$tmp" "$tmp.with-header"' EXIT HUP INT TERM
python3 "$ROOT/tools/arith.py" >"$tmp" || exit 1
cmp "$tmp" "$ROOT/corpus/D/number_arith.lua" || { echo 'number arithmetic corpus is stale' >&2; exit 1; }
echo 'PASS number arithmetic corpus is reproducible'
python3 "$ROOT/tools/review2/gen.py" kinds >"$tmp" || exit 1
{ printf '%s\n' '-- surface: independently generated number-result kinds'; cat "$tmp"; } >"$tmp.with-header"
cmp "$tmp.with-header" "$ROOT/corpus/D/review2_kinds.lua" || { echo 'review kinds corpus is stale' >&2; exit 1; }
echo 'PASS review kinds corpus is reproducible'
