#!/usr/bin/env bash
# Entry point for CI and the devcontainer. Fails on the first red step.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
# These timeouts catch hangs at CI speed. A slower box (a Codex Cloud task)
# scales them with EIGENLUA_TIMEOUT_SCALE (a positive integer, default 1).
S=${EIGENLUA_TIMEOUT_SCALE:-1}
[[ $S =~ ^[1-9][0-9]*$ ]] || { echo "EIGENLUA_TIMEOUT_SCALE must be a positive integer" >&2; exit 2; }

echo "RUN build_ref"
timeout $((600 * S)) tools/build_ref.sh

echo "RUN selftest"
timeout $((420 * S)) tools/grade.sh --selftest

echo "RUN canary"
timeout $((240 * S)) tools/grade.sh --candidate "$ROOT/.ref/bin/lua-count" --tier all

echo "RUN pairs fuzz"
timeout $((6600 * S)) tools/fuzz/pairs_fuzz.sh bin/eigenlua 2000

echo "RUN scaled pairs fuzz"
ARRAY_SCALE=1 timeout $((900 * S)) tools/fuzz/pairs_fuzz.sh bin/eigenlua 500 4242

echo "RUN ghost-range pairs fuzz"
timeout $((1500 * S)) tools/fuzz/pairs_ghost.sh bin/eigenlua 300 $(seq 1 32)
echo "RUN hexfloat_fuzz"
timeout $((900 * S)) tools/fuzz/hexfloat_fuzz.sh bin/eigenlua

echo "RUN ok"
