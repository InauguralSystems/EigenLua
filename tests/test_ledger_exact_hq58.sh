#!/usr/bin/env bash
# shellcheck disable=SC2016  # the single-quoted $n are awk fields, not shell
# Plants for the exact ledger gate (hq#58 EL-LEDGER-1): tools/ledger_check.sh,
# which tools/grade.sh --ledger runs on its own ROW lines.
#
# Before hq#58 the gate compared only the SET of non-PASS rows, so any of the
# 34 ledgered rows could crash, hang or lose most of its asserts and the run
# still passed. Each plant here perturbs one honest grade run, built from the
# real LEDGER.md and corpus manifests, and runs it through the real checker.
# The checker must turn it red, or green for the two controls.
#
# Prints one PLANT line per plant and a summary line. Exits 0 iff every plant
# gets its expected outcome and the plant count equals the pin.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHECK="$ROOT/tools/ledger_check.sh"
LEDGER="$ROOT/LEDGER.md"
EXPECT_PLANTS=16
[[ -x $CHECK && -f $LEDGER ]] || { echo "LEDGER_PLANTS HARNESS: missing $CHECK or $LEDGER" >&2; exit 2; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ledger-plants.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

# The honest run: every ledger row with its ledgered verdict, count and first
# difference, in the grader's own ROW formats. Every other graded row passes.
# The extraction is written separately from the checker's parser on purpose.
awk -F'|' -v cu="$(awk '$1 == "count-unspecified" {printf " %s ", $2}' "$ROOT/corpus/S.manifest")" '
  function t(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^## Tier S / { sec = "S"; next }
  /^## Tier D: DIVERGE/ { sec = "D"; next }
  /^## / { sec = "" }
  sec == "S" && t($2) ~ /\.lua$/ {
    v = t($3); gsub(/\*/, "", v); split(t($4), c, " ")
    if (index(cu, " " t($2) " "))
      printf "ROW S %s %s rc=1 class=count-unspecified fraction=0.60 floor=28101 count=%s progress=differs(line 2 ref= cand=)\n", t($2), v, c[1]
    else if (v == "PASS") printf "ROW S %s PASS count=%s progress=1\n", t($2), c[1]
    else if (v == "HANG") printf "ROW S %s HANG rc=124 count=%s\n", t($2), c[1]
    else if (v == "UNSUPPORTED") printf "ROW S %s UNSUPPORTED rc=3 count=%s\n", t($2), c[1]
    else printf "ROW S %s %s rc=1 count=%s ref=999999 progress=differs(line 2 ref=+ cand=)\n", t($2), v, c[1]
  }
  sec == "D" && t($2) ~ /\.lua$/ {
    split(t($3), w, /[ :]/)
    printf "ROW D %s DIVERGE line %s ref=a cand=b\n", t($2), w[2]
  }
' "$LEDGER" >"$WORK/ledgered.rows"
awk '{print $3}' "$WORK/ledgered.rows" | sort >"$WORK/ledgered.names"
awk '$1 == "include" || $1 == "count-unspecified" {print $2}' "$ROOT/corpus/S.manifest" | sort \
  | comm -23 - "$WORK/ledgered.names" | sed 's/^/ROW S /; s/$/ PASS count=1 progress=1/' >"$WORK/pass.rows"
awk 'NF && $1 !~ /^#/ && $1 != "operators:" {print $1}' "$ROOT/corpus/D.manifest" | sort \
  | comm -23 - "$WORK/ledgered.names" | sed 's/^/ROW D /; s/$/ MATCH rc=0/' >"$WORK/match.rows"
cat "$WORK/ledgered.rows" "$WORK/pass.rows" "$WORK/match.rows" >"$WORK/honest.rows"
n_ledgered=$(grep -c . "$WORK/ledgered.rows")
[[ $n_ledgered -ge 30 ]] || { echo "LEDGER_PLANTS HARNESS: only $n_ledgered ledger rows extracted" >&2; exit 2; }

examined=0 wrong=0
# plant <name> <expected rc> <expected text in the checker's output, or ''>
#       <sed program applied to the honest rows> [<ledger file>]
plant() {
  local name=$1 want_rc=$2 want_txt=$3 prog=$4 ledger=${5:-$LEDGER} rc st=OK
  sed -E "$prog" "$WORK/honest.rows" >"$WORK/p-$name.rows"
  "$CHECK" "$WORK/p-$name.rows" "$ledger" >"$WORK/p-$name.out" 2>&1
  rc=$?
  examined=$((examined + 1))
  if [[ $rc -ne $want_rc ]] || { [[ -n $want_txt ]] && ! grep -qF -- "$want_txt" "$WORK/p-$name.out"; }; then
    st=WRONG; wrong=$((wrong + 1))
  fi
  printf 'PLANT %s want rc=%s%s got rc=%s %s | %s\n' "$name" "$want_rc" "${want_txt:+ \"$want_txt\"}" "$rc" "$st" \
    "$(grep -E '^(LEDGER|HARNESS) ' "$WORK/p-$name.out" | tr '\n' ' ' | cut -c1-200)"
}

# The rows the plants perturb are picked from the ledger, not named here, so
# the plants keep working as rows are fixed and the ledger changes.
pick() { awk "$1" "$WORK/ledgered.rows" | head -n 1; }
cnt() { sed -n 's/.* count=\([0-9][0-9]*\).*/\1/p' <<<"$1"; }
esc() { printf '%s\n' "${1//./\\.}"; }
FS=$(pick '$2 == "S" && $4 == "FAIL" && !/count-unspecified/ && / count=[1-9][0-9]* / {print}')
CU=$(pick '$2 == "S" && $4 == "FAIL" && / class=count-unspecified / && / count=[1-9][0-9]* / {print}')
UN=$(pick '$2 == "S" && $4 == "UNSUPPORTED" && / count=[1-9][0-9]*$/ {print}')
DL=$(pick '$2 == "D" {print}')
MT=$(awk '$4 == "MATCH" {print; exit}' "$WORK/match.rows")
PS=$(pick '$2 == "S" && $4 == "PASS" {print}')
for v in FS CU UN DL MT PS; do
  [[ -n ${!v} ]] || { echo "LEDGER_PLANTS HARNESS: no ledger row of the kind $v perturbs" >&2; exit 2; }
done
fs=$(awk '{print $3}' <<<"$FS") fsc=$(cnt "$FS"); cu=$(awk '{print $3}' <<<"$CU") cuc=$(cnt "$CU")
un=$(awk '{print $3}' <<<"$UN") unc=$(cnt "$UN"); dl=$(awk '{print $3}' <<<"$DL") dll=$(awk '{print $6}' <<<"$DL")
mt=$(awk '{print $3}' <<<"$MT"); ps=$(awk '{print $3}' <<<"$PS")

# Controls: the honest run, and a higher S count (ratchets only by a ledger edit).
plant honest 0 "mismatched=0 improved=0" ''
plant count-rise 0 "LEDGER improved S/$fs count=$((fsc + 1))" "s/^(ROW S $(esc "$fs") FAIL rc=1 count=)$fsc /\1$((fsc + 1)) /"
# The defect class: a ledgered row changes and the old set-equality gate passes.
plant crash-ledgered 1 "mismatched=$n_ledgered" \
  "$(printf 's/^ROW (S|D) (%s) [A-Z]+ .*/ROW \\1 \\2 CRASH rc=139/' "$(awk '{print $3}' "$WORK/ledgered.rows" | sed 's/\./\\./g' | paste -sd'|')")"
plant s-fail-to-hang 1 "LEDGER mismatch S/$fs (verdict,count)" "s/^ROW S $(esc "$fs") FAIL .*/ROW S $fs HANG rc=124 count=none/"
plant s-count-drop 1 "LEDGER mismatch S/$fs (count)" "s/^(ROW S $(esc "$fs") FAIL rc=1 count=)$fsc /\1$((fsc - 1)) /"
plant s-count-unspec-drop 1 "LEDGER mismatch S/$cu (count)" "s/^(ROW S $(esc "$cu") FAIL .* count=)$cuc /\1$((cuc - 1)) /"
plant s-unsupported-to-fail 1 "LEDGER mismatch S/$un (verdict,count)" \
  "s/^ROW S $(esc "$un") UNSUPPORTED rc=3 count=$unc\$/ROW S $un FAIL rc=1 count=$((unc - 1)) ref=999999 progress=differs(line 4 ref= cand=)/"
plant s-untrusted 1 "LEDGER mismatch S/$fs (count)" \
  's/^ROW S ([a-z0-9_]+\.lua) (FAIL|HANG|UNSUPPORTED|PASS) .*/ROW S \1 FAIL assert-untrusted probe rc=1 line 1 ref=x cand=y/'
plant d-line-move 1 "LEDGER mismatch D/$dl ledger=DIVERGE line $dll" \
  "s/^ROW D $(esc "$dl") DIVERGE line $dll /ROW D $dl DIVERGE line $((dll + 1)) /"
plant d-exit-only 1 "LEDGER mismatch D/$dl" "s/^ROW D $(esc "$dl") DIVERGE .*/ROW D $dl DIVERGE exit ref=0 cand=1/"
plant unexpected 1 "LEDGER unexpected D/$mt verdict=DIVERGE" "s/^ROW D $(esc "$mt") MATCH .*/ROW D $mt DIVERGE line 1 ref=a cand=b/"
plant stale 1 "LEDGER stale S/$fs unexpectedly=PASS" "s/^ROW S $(esc "$fs") FAIL .*/ROW S $fs PASS count=$fsc progress=1/"
plant pass-row-fails 1 "LEDGER mismatch S/$ps (verdict)" "s/^ROW S $(esc "$ps") PASS .*/ROW S $ps FAIL rc=1 count=999999 ref=999999 progress=differs(x)/"
plant ungraded-row 2 "ledger names no graded row: S/$fs" "/^ROW S $(esc "$fs") /d"
# The ledger itself must be machine-readable: prose in a verdict or a first
# difference that does not start "line <n>" is a harness error, not a pass.
sed -E "s/^\| $(esc "$fs") \| FAIL \|/| $fs | FAIL (round 6; HANG in round 5) |/" "$LEDGER" >"$WORK/prose-verdict.md"
plant ledger-prose-verdict 2 "verdict column must be exactly one verdict" '' "$WORK/prose-verdict.md"
sed -E "s/^\| $(esc "$dl") \| line $dll /| $dl | the line after line $((dll - 1)) /" "$LEDGER" >"$WORK/prose-diff.md"
plant ledger-prose-diff 2 "first difference must start 'line <n>'" '' "$WORK/prose-diff.md"

echo "LEDGER_PLANTS examined=$examined expected=$EXPECT_PLANTS wrong=$wrong"
[[ $examined -eq $EXPECT_PLANTS && $wrong -eq 0 ]]
