#!/usr/bin/env bash
# Entry point for CI and the devcontainer. Fails on the first red step.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "RUN build_ref"
timeout 120 tools/build_ref.sh

echo "RUN selftest"
timeout 420 tools/grade.sh --selftest

echo "RUN canary"
timeout 240 tools/grade.sh --candidate "$ROOT/.ref/lua-5.4.9/src/lua" --tier all

echo "RUN ok"
