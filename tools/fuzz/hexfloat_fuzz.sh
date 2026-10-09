#!/usr/bin/env bash
# High-volume hexfloat subnormal differential (EigenLua #43, #25). The Tier D
# row num_hexfloat_subnormal.lua keeps a curated 312-numeral subset (every
# known #25 witness, every exponent bin, every significand length) so it fits
# the per-row timeout. This keeps the ORIGINAL 3000-numeral fixed-seed program
# as a volume check: it must print identically under the reference and the
# candidate (stdout, as the grader compares). Usage: tools/fuzz/hexfloat_fuzz.sh <candidate> [reference]
set -u
CAND=${1:?usage: hexfloat_fuzz.sh <candidate> [reference]}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REF=${2:-$ROOT/.ref/bin/lua}
PROG="$ROOT/tools/fuzz/hexfloat_subnormal_full.lua"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
timeout 120 "$REF" "$PROG" > "$TMP/ref" 2>"$TMP/ref.err"; rr=$?
timeout 600 "$CAND" "$PROG" > "$TMP/cand" 2>"$TMP/cand.err"; rc=$?
if [ $rr -ne 0 ] || [ $rc -ne 0 ] || ! cmp -s "$TMP/ref" "$TMP/cand"; then
  echo "HEXFLOAT_FUZZ FAIL ref_rc=$rr cand_rc=$rc first diff:"; diff "$TMP/ref" "$TMP/cand" | head -5
  exit 1
fi
echo "HEXFLOAT_FUZZ ok lines=$(wc -l < "$TMP/ref")"
