#!/usr/bin/env bash
# Ghost-range pairs/next fuzz (EigenLua #34, from the round-6 blind critic):
# grow, traverse, shrink partway while a next() walk is paused, sparse-write
# into the trimmed range, grow back over it, resume. Self-checking (every key
# live at the start visited unless deleted, no duplicates, no dead visits).
# Defined mode only, so any DEFECT or RUNAWAY line fails.
# Usage: tools/fuzz/pairs_ghost.sh <lua-binary> [rounds] [seed...]
set -u
BIN=${1:?usage: pairs_ghost.sh <lua-binary> [rounds] [seed...]}; shift
ROUNDS=${1:-300}; shift || true
SEEDS=${*:-$(seq 1 32)}
HERE=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
bad=0; n=0
for s in $SEEDS; do
  n=$((n+1))
  sed -e "s/@SEED@/$s/g" -e "s/@ROUNDS@/$ROUNDS/g" -e "s/@UNDEF@/false/g" "$HERE/pairs_ghost.tmpl" > "$TMP/g.lua"
  out=$(timeout 300 "$BIN" "$TMP/g.lua" 2>&1); rc=$?
  if [ $rc -ne 0 ] || printf '%s\n' "$out" | grep -qE 'DEFECT|RUNAWAY'; then
    bad=$((bad+1)); echo "FAIL seed=$s rc=$rc: $(printf '%s\n' "$out" | grep -m1 -E 'DEFECT|RUNAWAY|rror')"
  fi
done
echo "PAIRS_GHOST examined=$n failed=$bad"
[ $bad -eq 0 ]
