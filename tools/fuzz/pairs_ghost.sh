#!/usr/bin/env bash
# Ghost-range pairs/next fuzz (EigenLua #34, from the round-6 blind critic):
# grow, traverse, shrink partway while a next() walk is paused, sparse-write
# into the trimmed range, grow back over it, resume. Self-checking (every key
# live at the start visited unless deleted, no duplicates, no dead visits).
# Runs both defined mode and undefined mode, which also inserts while the
# traversal is paused. The TEMPLATE decides what undefined mode checks: it
# skips the DUP/DEAD/MISSED checks on the paused walk and excuses an
# "invalid key to 'next'" error there, and keeps checking termination
# (RUNAWAY), the unmutated PRE/POST full traversals and any other error.
# Whatever the template reports is a DEFECT line, after which it returns
# without printing DONE, so the outer rule is the same in both modes: a
# program passes only with exit 0, exactly one DONE line and no DEFECT or
# RUNAWAY line. (Before hq#58 undefined mode failed only on RUNAWAY, so a
# PRE/POST DUP, DEAD or MISSED or a stray error there passed silently.)
# The programs run in parallel (FUZZ_JOBS, default nproc; see fuzz_run.sh) and
# FUZZ_EXPECT pins how many must be examined.
# Usage: FUZZ_EXPECT=<n> tools/fuzz/pairs_ghost.sh <lua-binary> [rounds] [seed...]
set -u
BIN=${1:?usage: FUZZ_EXPECT=<n> pairs_ghost.sh <lua-binary> [rounds] [seed...]}; shift
ROUNDS=${1:-300}; shift || true
SEEDS=${*:-$(seq 1 32)}
HERE=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# shellcheck source=tools/fuzz/fuzz_run.sh
. "$HERE/fuzz_run.sh"
fuzz_init PAIRS_GHOST
for mode in defined undefined; do
  if [ "$mode" = defined ]; then undef=false; else undef=true; fi
  for s in $SEEDS; do
    sed -e "s/@SEED@/$s/g" -e "s/@ROUNDS@/$ROUNDS/g" -e "s/@UNDEF@/$undef/g" \
      "$HERE/pairs_ghost.tmpl" > "$TMP/$mode.$s.lua" || exit 2
    fuzz_add "$mode.$s" "$TMP/$mode.$s.lua"
  done
done
label() { echo "mode=${1%%.*} seed=${1#*.}"; }
# Same rule in both modes; the mode split lives in the template (see above).
failure_re() { echo 'DEFECT|RUNAWAY'; }
fuzz_run "$BIN" "$TMP"
fuzz_grade "$TMP" label failure_re
