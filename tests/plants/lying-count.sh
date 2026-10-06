#!/usr/bin/env bash
# A lying candidate: it learns the true count from a full counting run, then
# runs the program only partway (exit 0) and reports the full count.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
full=$("$ROOT/.ref/bin/lua-count" "$1" 2>&1 >/dev/null | grep -o 'EIGENLUA-ASSERTS:[0-9]*$')
"$ROOT/tests/plants/early-exit.sh" "$1" 2>/dev/null
printf '%s\n' "$full" >&2
exit 0
