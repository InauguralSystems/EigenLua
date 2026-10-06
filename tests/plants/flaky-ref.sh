#!/usr/bin/env bash
# A reference whose assert count changes between runs: every second program
# run stops at the first line event past line 100. State: $FLAKY_STATE.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LUA="$ROOT/.ref/lua-5.4.9/src/lua"
[[ ${1:-} == -v ]] && exec "$LUA" -v
n=$(( $(cat "$FLAKY_STATE" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$FLAKY_STATE"
(( n % 2 == 1 )) && exec "$LUA" "$1"
exec "$ROOT/tests/plants/early-exit.sh" "$1"
