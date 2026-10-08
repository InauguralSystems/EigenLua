#!/usr/bin/env bash
# Self-checking pairs/next mutation fuzz (EigenLua #34). Each template is a
# pure-Lua program with its own LCG, so every binary sees the same sequence.
# It checks itself (every live key visited once, none dead, the nested count
# equals the live count, a RUNAWAY cap) rather than diffing against the
# reference, because #t with holes can legitimately diverge. A binary
# passes a seed when it prints no DEFECT line and no RUNAWAY.
# Usage: tools/fuzz/pairs_fuzz.sh <lua-binary> [steps] [seed...]
set -u
BIN=${1:?usage: pairs_fuzz.sh <lua-binary> [steps] [seed...]}; shift
STEPS=${1:-5000}; shift || true
SEEDS=${*:-1 7 42 99 123 555 1001 2024 4242 9999 12345 31337 65521 77777 100003 271828 314159 999331 1234567 2718281 3430008 7777777}
HERE=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if [[ ${ARRAY_SCALE:-0} == 1 ]]; then LIMIT=2000; BURST=500; else LIMIT=25; BURST=1; fi
bad=0; n=0
for tmpl in pairs_selfcheck pairs_readonly; do
  for s in $SEEDS; do
    n=$((n+1))
    sed -e "s/@SEED@/$s/g" -e "s/@STEPS@/$STEPS/g" -e "s/@INS@/false/g" \
      -e "s/@LIMIT@/$LIMIT/g" -e "s/@BURST@/$BURST/g" "$HERE/$tmpl.tmpl" > "$TMP/f.lua"
    out=$(timeout 300 "$BIN" "$TMP/f.lua" 2>&1); rc=$?
    if [ $rc -ne 0 ] || printf '%s\n' "$out" | grep -qE 'DEFECT|RUNAWAY'; then
      bad=$((bad+1)); echo "FAIL $tmpl seed=$s rc=$rc: $(printf '%s\n' "$out" | grep -m1 -E 'DEFECT|RUNAWAY|rror')"
    fi
  done
done
echo "PAIRS_FUZZ examined=$n failed=$bad"
[ $bad -eq 0 ]
