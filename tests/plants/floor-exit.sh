#!/usr/bin/env bash
# Executes far fewer asserts than the reference but shows the same stdout and
# rc: stdout and rc come from a full run of the pristine reference, the count
# from a run stopped at the first line event past line 100. Only the
# count-unspecified floor can catch it.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
"$ROOT/.ref/bin/lua" "$1"
rc=$?
"$ROOT/tests/plants/early-exit.sh" "$1" 2>&1 >/dev/null | grep 'EIGENLUA-ASSERTS:' >&2
exit "$rc"
