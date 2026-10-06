#!/usr/bin/env bash
# The counting reference behind tests/plants/callsite_driver.lua: direct
# assert(...) calls count but never raise.
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
exec "$ROOT/.ref/bin/lua-count" "$ROOT/tests/plants/callsite_driver.lua" "$1"
