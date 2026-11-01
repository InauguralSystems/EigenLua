#!/usr/bin/env bash
# Self-checking pairs/next mutation fuzz (EigenLua #34). Each template is a
# pure-Lua program with its own LCG, so every binary sees the same sequence.
# It checks itself (every live key visited once, none dead, the nested count
# equals the live count, a RUNAWAY cap) rather than diffing against the
# reference, because #t with holes can legitimately diverge. A binary
# passes a seed when it exits 0, prints no DEFECT line and no RUNAWAY, and
# prints exactly one DONE line (the template's last statement), so a run that
# stops early or loses its output fails instead of passing on absence.
# The programs run in parallel (FUZZ_JOBS, default nproc; see fuzz_run.sh) and
# FUZZ_EXPECT pins how many must be examined.
# Usage: FUZZ_EXPECT=<n> tools/fuzz/pairs_fuzz.sh <lua-binary> [steps] [seed...]
set -u
BIN=${1:?usage: FUZZ_EXPECT=<n> pairs_fuzz.sh <lua-binary> [steps] [seed...]}; shift
STEPS=${1:-5000}; shift || true
SEEDS=${*:-1 7 42 99 123 555 1001 2024 4242 9999 12345 31337 65521 77777 100003 271828 314159 999331 1234567 2718281 3430008 7777777}
HERE=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# shellcheck source=tools/fuzz/fuzz_run.sh
. "$HERE/fuzz_run.sh"
fuzz_init PAIRS_FUZZ
if [[ ${ARRAY_SCALE:-0} == 1 || ${WARMUP:-0} == 1 ]]; then LIMIT=2000; BURST=500; else LIMIT=25; BURST=1; fi
WARM=${WARMUP:-0}
for tmpl in pairs_selfcheck pairs_readonly; do
  for s in $SEEDS; do
    sed -e "s/@SEED@/$s/g" -e "s/@STEPS@/$STEPS/g" -e "s/@INS@/false/g" \
      -e "s/@LIMIT@/$LIMIT/g" -e "s/@BURST@/$BURST/g" -e "s/@WARMUP@/$WARM/g" \
      "$HERE/$tmpl.tmpl" > "$TMP/$tmpl.$s.lua" || exit 2
    fuzz_add "$tmpl.$s" "$TMP/$tmpl.$s.lua"
  done
done
label() { echo "${1%%.*} seed=${1#*.}"; }
failure_re() { echo 'DEFECT|RUNAWAY'; }
fuzz_run "$BIN" "$TMP"
fuzz_grade "$TMP" label failure_re
