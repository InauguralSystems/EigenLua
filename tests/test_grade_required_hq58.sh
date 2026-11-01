#!/usr/bin/env bash
# Plants for hq#58 EL-REQ-1: the required job (`suite (in devcontainer)`, which
# runs tests/run.sh) must grade bin/eigenlua against the whole corpus with
# --ledger, and must fail when that grade fails.
#
# Before hq#58 only a separate, non-required job graded bin/eigenlua. tests/run.sh
# graded the reference (the canary), so a front-end regression that the fuzz
# programs never touch left the required check green.
#
# Each plant runs the REAL tests/run.sh in a staged tree whose tools are stubs.
# The grade stub records its argv and behaves as the plant says (pass, fail,
# fail late after every other step has finished, or die by signal). Prints one
# PLANT line per plant and a summary line. Exits 0 iff every plant gets its
# expected outcome and the plant count equals the pin.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN="$ROOT/tests/run.sh"
WF="$ROOT/.github/workflows/tests.yml"
EXPECT_PLANTS=6
[[ -f $RUN && -f $WF ]] || { echo "GRADE_REQUIRED HARNESS: missing $RUN or $WF" >&2; exit 2; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/grade-required.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

examined=0 wrong=0
verdict() {  # verdict <plant> <ok 0/1> <detail>
  examined=$((examined + 1))
  local st=OK
  [[ $2 -eq 1 ]] || { st=WRONG; wrong=$((wrong + 1)); }
  printf 'PLANT %s %s | %s\n' "$1" "$st" "$3"
}

# The required job runs tests/run.sh. Which check is required is a ruleset
# setting (only `suite (in devcontainer)` is), so this pins the job behind that name.
job=$(awk '/^  [A-Za-z_-]+:$/ { j = $1 } /name: suite \(in devcontainer\)/ { print j }' "$WF")
run_cmd=$(awk -v j="$job" '/^  [A-Za-z_-]+:$/ { in_j = ($1 == j) } in_j && /runCmd:/ { sub(/^.*runCmd:[ ]*/, ""); print }' "$WF")
ok=0
[[ -n $job && $run_cmd == *"bash tests/run.sh"* ]] && ok=1
verdict required-job-runs-suite "$ok" "job=${job:-none} runCmd=${run_cmd:-none}"

stage() {  # stage <dir>: the real tests/run.sh and stub tools
  local d=$1 f
  mkdir -p "$d/tests" "$d/tools/fuzz" "$d/bin"
  cp "$RUN" "$d/tests/run.sh"
  for f in tools/build_ref.sh tests/test_fuzz_verdicts.sh tests/test_grade_required_hq58.sh \
           tests/test_ledger_exact_hq58.sh tools/fuzz/pairs_fuzz.sh tools/fuzz/pairs_ghost.sh \
           tools/fuzz/mem_bound.sh tools/fuzz/hexfloat_fuzz.sh bin/eigenlua; do
    printf '#!/usr/bin/env bash\nexit 0\n' >"$d/$f"
  done
  cat >"$d/tools/grade.sh" <<'STUB'
#!/usr/bin/env bash
# Stub grader: record argv; the bin/eigenlua grade behaves as $PLANT_GRADE says.
printf '%s\n' "$*" >>"$GRADE_ARGS"
case " $* " in
  *" --ledger "*) ;;
  *) exit 0 ;;
esac
echo "STUB-GRADE-OUTPUT LEDGER expected=1"
case $PLANT_GRADE in
  pass) exit 0 ;;
  fail) exit 1 ;;
  late) sleep 2; exit 1 ;;
  slow) sleep 30; exit 0 ;;
  signal) kill -KILL $$ ;;
esac
STUB
  chmod +x "$d"/tests/*.sh "$d"/tools/*.sh "$d"/tools/fuzz/*.sh "$d/bin/eigenlua"
}

# plant <name> <grade behaviour> <want: green|red>
plant() {
  local name=$1 beh=$2 want=$3 d="$WORK/$1" rc ok=1 calls
  stage "$d"
  GRADE_ARGS="$d/args" PLANT_GRADE=$beh timeout 60 bash "$d/tests/run.sh" >"$d/log" 2>&1
  rc=$?
  calls=$(grep -c -- '--ledger' "$d/args" 2>/dev/null)
  # The bin/eigenlua grade must be called exactly once, on the whole corpus, with the ledger.
  grep -qx -- "--candidate $d/bin/eigenlua --tier all --ledger" "$d/args" 2>/dev/null || ok=0
  [[ $calls == 1 ]] || ok=0
  # Its output is printed in the job log.
  grep -q 'STUB-GRADE-OUTPUT' "$d/log" || ok=0
  if [[ $want == green ]]; then
    [[ $rc -eq 0 ]] && grep -qx 'RUN ok' "$d/log" || ok=0
  else
    [[ $rc -ne 0 ]] && ! grep -qx 'RUN ok' "$d/log" || ok=0
  fi
  verdict "$name" "$ok" "want=$want rc=$rc grade-calls=${calls:-0} last=$(tail -n 1 "$d/log")"
}
plant grade-pass pass green
plant grade-fail fail red
plant grade-fail-after-fuzz late red
plant grade-killed signal red
# A failing foreground step must still fail the job, and the background
# grade must not outlive it (the EXIT trap kills it).
d="$WORK/fuzz-fail"
stage "$d"
printf '#!/usr/bin/env bash\nexit 1\n' >"$d/tools/fuzz/pairs_fuzz.sh"
GRADE_ARGS="$d/args" PLANT_GRADE=slow timeout 60 bash "$d/tests/run.sh" >"$d/log" 2>&1
rc=$?
sleep 1
ok=1
[[ $rc -ne 0 ]] && ! grep -qx 'RUN ok' "$d/log" || ok=0
pgrep -f -- "tools/grade.sh --candidate $d/bin/eigenlua" >/dev/null && ok=0
verdict fuzz-fail-kills-grade "$ok" "rc=$rc last=$(tail -n 1 "$d/log")"

echo "GRADE_REQUIRED examined=$examined expected=$EXPECT_PLANTS wrong=$wrong"
[[ $examined -eq $EXPECT_PLANTS && $wrong -eq 0 ]]
