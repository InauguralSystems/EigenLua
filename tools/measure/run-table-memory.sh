#!/usr/bin/env bash
# Reproduce REPORT-31.md's peak-RSS samples. Output is TSV on stdout.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
EIGS=${EIGENSCRIPT:-$(command -v eigenscript)}
REF=${LUA_REF:-$ROOT/.ref/bin/lua}
OUT=${1:-$ROOT/.tmp/measure-31}
mkdir -p "$OUT"
[[ -x /usr/bin/time ]] || { echo "run-table-memory: GNU /usr/bin/time is required" >&2; exit 2; }
[[ -x $REF ]] || "$ROOT/tools/build_ref.sh" >/dev/null

# Compile once: compiler RSS must not contaminate runtime RSS.
"$EIGS" "$ROOT/src/compile.eigs" "$ROOT/tools/measure/table-memory.lua" \
  "$OUT/table-memory.eigs" "$ROOT/src/runtime.eigs"

printf 'implementation\tmode\tn\tmax_rss_kb\n'
measure() {
  local impl=$1 mode=$2 n=$3; shift 3
  local f="$OUT/time.$impl.$mode.$n"
  /usr/bin/time -v -o "$f" "$@" "$mode" "$n" >/dev/null 2>/dev/null
  awk -v i="$impl" -v m="$mode" -v n="$n" \
    '/Maximum resident set size/ {print i "\t" m "\t" n "\t" $NF}' "$f"
}

for n in 0 10000 100000 1000000; do
  measure lua empty "$n" "$REF" "$ROOT/tools/measure/table-memory.lua"
  measure eigenlua empty "$n" env EIGENLUA_ARGV0=eigenlua MEASURE_MODE=empty MEASURE_N="$n" "$EIGS" "$OUT/table-memory.eigs"
done
for mode in array strings sparse sparse_offset sparse_descending; do
  measure lua "$mode" 1000000 "$REF" "$ROOT/tools/measure/table-memory.lua"
  measure eigenlua "$mode" 1000000 env EIGENLUA_ARGV0=eigenlua MEASURE_MODE="$mode" MEASURE_N=1000000 "$EIGS" "$OUT/table-memory.eigs"
done
measure lua small4 100000 "$REF" "$ROOT/tools/measure/table-memory.lua"
measure eigenlua small4 100000 env EIGENLUA_ARGV0=eigenlua MEASURE_MODE=small4 MEASURE_N=100000 "$EIGS" "$OUT/table-memory.eigs"

for mode in baseline empty array strings small4; do
  n=0; [[ $mode != baseline ]] && n=1000000
  [[ $mode == small4 ]] && n=100000
  measure native-"$mode" "$mode" "$n" "$EIGS" "$ROOT/tools/measure/native-table-memory.eigs"
done
for mode in dict list core3 base5 full10; do
  measure component "$mode" 100000 "$EIGS" "$ROOT/tools/measure/native-components.eigs"
done
