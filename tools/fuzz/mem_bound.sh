#!/usr/bin/env bash
# mem_bound.sh <eigenlua>: peak-RSS gate for table memory (#31). Tier D compares
# stdout only, so it cannot see memory; this runs each probe under
# /usr/bin/time and fails when its peak RSS exceeds the probe's ceiling.
# Ceilings sit between main/fixed (~42 MB churn, ~19 MB geometric, measured
# 2026-10-09) and the round-1 defect (~4x churn, 149 MB geometric).
set -euo pipefail
EL=${1:?usage: mem_bound.sh <eigenlua>}
DIR=$(cd "$(dirname "$0")/mem" && pwd)
[[ -x /usr/bin/time ]] || { echo "MEM_BOUND: /usr/bin/time missing (apt-get install time)" >&2; exit 2; }
fail=0; n=0
check() {  # probe ceiling_kb expected_stdout
  local out kb; n=$((n+1))
  out=$(/usr/bin/time -f 'MAXRSS %M' "$EL" "$DIR/$1" 2>&1) || { echo "MEM_BOUND FAIL $1: exit $?"; fail=$((fail+1)); return; }
  kb=$(sed -n 's/^MAXRSS //p' <<<"$out")
  if ! grep -qxF "$3" <<<"$out"; then echo "MEM_BOUND FAIL $1: stdout ≠ '$3'"; fail=$((fail+1))
  elif (( kb > $2 )); then echo "MEM_BOUND FAIL $1: maxrss ${kb} KB > ${2} KB"; fail=$((fail+1))
  else echo "MEM_BOUND ok $1: maxrss ${kb} KB <= ${2} KB"; fi
}
check set_churn.lua 65536 $'1\ttrue'
check sparse_geometric.lua 49152 $'514\t14'
echo "MEM_BOUND examined=$n failed=$fail"
(( fail == 0 ))
