#!/usr/bin/env bash
# The counting reference, then exit 99: rc 99 is the candidate's own status
# (it used to be the grader's "cd failed" channel).
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
"$ROOT/.ref/bin/lua-count" "$1"
exit 99
