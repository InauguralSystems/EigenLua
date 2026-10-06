#!/usr/bin/env bash
# A counting reference whose assert count changes between runs: every second
# program run stops at the first line event past line 100. State: $FLAKY_STATE.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
[[ ${1:-} == -v ]] && exec "$ROOT/.ref/bin/lua-count" -v
n=$(( $(cat "$FLAKY_STATE" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$FLAKY_STATE"
(( n % 2 == 1 )) && exec "$ROOT/.ref/bin/lua-count" "$1"
exec "$ROOT/tests/plants/early-exit.sh" "$1"
