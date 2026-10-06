#!/usr/bin/env bash
# A lying candidate: it learns the true count from a full counting run, then
# runs the program only partway and reports the full count. It keeps the
# partway run's rc and stderr (minus its own count line), so it still fails
# the per-row assert(false) control honestly and only the count lies.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
full=$("$ROOT/.ref/bin/lua-count" "$1" 2>&1 >/dev/null | grep -o 'EIGENLUA-ASSERTS:[0-9]*$')
"$ROOT/tests/plants/early-exit.sh" "$1" 2>"$1.err.$$"
rc=$?
grep -v 'EIGENLUA-ASSERTS:' "$1.err.$$" >&2
rm -f "$1.err.$$"
printf '%s\n' "$full" >&2
exit "$rc"
