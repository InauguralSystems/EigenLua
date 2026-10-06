#!/usr/bin/env bash
# The counting reference run in full (same stdout, rc 0), but it reports one
# assert more than it executed: only the count comparison can catch it.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
"$ROOT/.ref/bin/lua-count" "$1" 2>"$1.err.$$"
rc=$?
n=$(sed -n 's/.*EIGENLUA-ASSERTS:\([0-9][0-9]*\)$/\1/p' "$1.err.$$")
rm -f "$1.err.$$"
printf 'EIGENLUA-ASSERTS:%s\n' "$((n + 1))" >&2
exit "$rc"
