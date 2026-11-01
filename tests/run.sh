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

# The fuzz harness's own plants (EL-FUZZ-1): a candidate that exits 0 early,
# loses its stdout or drops a program must turn the fuzz steps below red.
echo "RUN fuzz harness plants"
timeout $((120 * S)) tests/test_fuzz_verdicts.sh

# Each fuzz step runs its programs in parallel (FUZZ_JOBS, default nproc) and
# FUZZ_EXPECT pins how many programs it must examine (templates x seeds).
echo "RUN pairs fuzz"
FUZZ_EXPECT=44 timeout $((6600 * S)) tools/fuzz/pairs_fuzz.sh bin/eigenlua 2000

echo "RUN scaled pairs fuzz"
FUZZ_EXPECT=2 ARRAY_SCALE=1 timeout $((900 * S)) tools/fuzz/pairs_fuzz.sh bin/eigenlua 500 4242

echo "RUN warmup pairs fuzz"
FUZZ_EXPECT=16 WARMUP=1 timeout $((2400 * S)) tools/fuzz/pairs_fuzz.sh bin/eigenlua 5000 1 7 42 99 123 555 1001 2024

echo "RUN ghost-range pairs fuzz"
FUZZ_EXPECT=64 timeout $((1500 * S)) tools/fuzz/pairs_ghost.sh bin/eigenlua 300 $(seq 1 32)
echo "RUN table memory bound"
timeout $((600 * S)) tools/fuzz/mem_bound.sh bin/eigenlua
echo "RUN hexfloat_fuzz"
timeout $((900 * S)) tools/fuzz/hexfloat_fuzz.sh bin/eigenlua

echo "RUN ok"
