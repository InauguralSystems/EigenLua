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

# The product grade (hq#58 EL-REQ-1): bin/eigenlua against the whole corpus,
# held to LEDGER.md row by row. Before, only a separate non-required job graded
# bin/eigenlua, so this required job stayed green on a front-end regression the
# fuzz programs never touch. The grader runs one program at a time, so it runs
# in the background on a core the serial selftest and canary leave idle, and is
# joined (its output printed, its exit status checked) before RUN ok.
mkdir -p "$ROOT/.tmp"
GRADE_OUT="$ROOT/.tmp/grade-eigenlua.out"
echo "RUN grade bin/eigenlua --ledger (background; joined before RUN ok)"
timeout $((900 * S)) tools/grade.sh --candidate "$ROOT/bin/eigenlua" --tier all --ledger >"$GRADE_OUT" 2>&1 &
GRADE_PID=$!
trap 'kill "$GRADE_PID" 2>/dev/null || true' EXIT

echo "RUN selftest"
timeout $((420 * S)) tools/grade.sh --selftest

echo "RUN canary"
timeout $((240 * S)) tools/grade.sh --candidate "$ROOT/.ref/bin/lua-count" --tier all

# The fuzz harness's own plants (EL-FUZZ-1): a candidate that exits 0 early,
# loses its stdout or drops a program must turn the fuzz steps below red.
echo "RUN fuzz harness plants"
timeout $((120 * S)) tests/test_fuzz_verdicts.sh

# Plants for the two gates hq#58 added here: this script runs and joins the
# background grade (EL-REQ-1), and --ledger holds each row exactly (EL-LEDGER-1).
echo "RUN grade-required plants"
timeout $((60 * S)) tests/test_grade_required_hq58.sh
echo "RUN ledger-exact plants"
timeout $((60 * S)) tests/test_ledger_exact_hq58.sh

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

echo "RUN grade bin/eigenlua --ledger (join)"
grade_rc=0
wait "$GRADE_PID" || grade_rc=$?
trap - EXIT
cat "$GRADE_OUT"
if [[ $grade_rc -ne 0 ]]; then
  echo "RUN grade bin/eigenlua --ledger FAILED rc=$grade_rc"
  exit 1
fi

echo "RUN ok"
