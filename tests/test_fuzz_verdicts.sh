#!/usr/bin/env bash
# Candidate bodies below are single-quoted: they expand when the candidate runs.
# shellcheck disable=SC2016
# Plants for tools/fuzz/pairs_fuzz.sh and tools/fuzz/pairs_ghost.sh (hq#58,
# finding EL-FUZZ-1). Each plant runs the REAL fuzz script against a candidate
# built from reference Lua and checks the exit status plus the summary line.
# Before the fix both scripts passed a candidate that exited 0 without running
# anything, or that lost its stdout, because a program passed on the absence
# of a DEFECT line. A program now passes only with exit 0, exactly one DONE
# line and no failure line, and FUZZ_EXPECT pins the examined count.
# Needs .ref/bin/lua (tools/build_ref.sh). Exit 0 iff every plant is OK and the
# number of plants run equals the number declared below.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=$ROOT/.ref/bin/lua
[[ -x $REF ]] || { echo "FUZZ_PLANTS HARNESS: $REF missing (run tools/build_ref.sh)"; exit 2; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
NPLANTS=17
cand() {  # cand <name> <body>: a candidate script that gets the program path as $1
  printf '#!/usr/bin/env bash\nREF=%q\n%s\n' "$REF" "$2" >"$WORK/$1.sh"; chmod +x "$WORK/$1.sh"
}
cand honest       'exec "$REF" "$1"'
cand exit0        'exit 0'
cand lost-stdout  'exec "$REF" "$1" >/dev/null'
cand early-return 'sed "/^print(\"DONE\")$/d" "$1" >"$1.cut.lua" && exec "$REF" "$1.cut.lua"'
cand done-twice   '"$REF" "$1" || exit; echo DONE'
# Programs are recognised by content, not file name: seed, and the template
# (pairs_readonly pins "mode = 0"; pairs_ghost declares UNDEF).
cand one-defect   'grep -qx "local seed = 2" "$1" && grep -q "mode = 0$" "$1" && echo "DEFECT planted seed=2"; exec "$REF" "$1"'
# lost-worker SIGKILLs the xargs worker shell running seed 2. Its timeout and
# Lua children are orphaned and finish on their own; they write only into the
# run's own mktemp dir, which the fuzz script's trap removes.
cand lost-worker  'if grep -qx "local seed = 2" "$1" && ! grep -q "mode = 0$" "$1"; then read -r _ _ _ w _ </proc/$PPID/stat; kill -KILL "$w"; fi; exec "$REF" "$1"'
cand runaway      'grep -qx "local seed = 1" "$1" && grep -q "^local UNDEF = true" "$1" && echo "DEFECT RUNAWAY planted"; exec "$REF" "$1"'
# undef-defect makes the TEMPLATE itself report a PRE-traversal DUP at round 3
# in undefined-mode programs only (the real report() path: it sets fail, and
# the program returns before DONE). Before hq#58 undefined mode failed only on
# RUNAWAY, so this passed.
cand undef-defect 'f=$1; if grep -q "^local UNDEF = true" "$f"; then sed "s/^  full_check(t, r, \"PRE\")\$/&; if r == 3 then report(\"PRE DUP 7\", r) end/" "$f" >"$f.x.lua"; grep -q "PRE DUP 7" "$f.x.lua" || exit 3; f=$f.x.lua; fi; exec "$REF" "$f"'
# invalid-key makes the paused walk raise "invalid key to 'next'" once, in both
# modes. The template excuses that error only in undefined mode, so defined
# mode must fail and undefined mode must still pass: the gate is not stricter
# than Lua's own rule for insert-while-traversing.
cand invalid-key  '{ echo "local _next, _c = next, 0; local next = function(t, k) _c = _c + 1; if _c == 50 then error(\"invalid key to \" .. string.char(39) .. \"next\" .. string.char(39)) end; return _next(t, k) end"; cat "$1"; } >"$1.x.lua"; exec "$REF" "$1.x.lua"'
# A copy of the real fuzz scripts whose pairs_selfcheck template lost its DONE
# line: fuzz_add must refuse it before anything runs.
cp -r "$ROOT/tools/fuzz" "$WORK/fuzz-nodone"
sed -i '/^print("DONE")$/d' "$WORK/fuzz-nodone/pairs_selfcheck.tmpl"
bad=0 n=0
plant() {  # plant <name> <expected> <script> <expect-count|-> <cand> <size> <seed...>
  local name=$1 exp=$2 script=$3 ec=$4 c=$5; shift 5
  local out rc got path=tools/fuzz/$script
  [[ $script == /* ]] && path=$script
  if [[ $ec == - ]]; then
    out=$(cd "$ROOT" && env -u FUZZ_EXPECT "$path" "$WORK/$c.sh" "$@" 2>&1); rc=$?
  else
    out=$(cd "$ROOT" && FUZZ_EXPECT=$ec "$path" "$WORK/$c.sh" "$@" 2>&1); rc=$?
  fi
  got="rc=$rc $(grep -E '^PAIRS_(FUZZ|GHOST) (examined|COUNT|HARNESS)' <<<"$out" | tr '\n' ' ')"
  got="${got% } $(grep -oE '^FAIL [a-z_=]+ seed=[0-9]+ rc=[a-z0-9]+' <<<"$out" | tr '\n' ' ')"
  got=${got% }
  n=$((n+1))
  if [[ $got == "$exp" ]]; then echo "PLANT $name OK"; else bad=$((bad+1)); echo "PLANT $name WRONG"; echo "  expected: $exp"; echo "  got:      $got"; fi
}
F=pairs_fuzz.sh G=pairs_ghost.sh
plant fuzz-honest       'rc=0 PAIRS_FUZZ examined=4 expected=4 failed=0' $F 4 honest 200 1 2
plant fuzz-exit0        'rc=1 PAIRS_FUZZ examined=4 expected=4 failed=4 FAIL pairs_selfcheck seed=1 rc=0 FAIL pairs_selfcheck seed=2 rc=0 FAIL pairs_readonly seed=1 rc=0 FAIL pairs_readonly seed=2 rc=0' $F 4 exit0 200 1 2
plant fuzz-lost-stdout  'rc=1 PAIRS_FUZZ examined=4 expected=4 failed=4 FAIL pairs_selfcheck seed=1 rc=0 FAIL pairs_selfcheck seed=2 rc=0 FAIL pairs_readonly seed=1 rc=0 FAIL pairs_readonly seed=2 rc=0' $F 4 lost-stdout 200 1 2
plant fuzz-early-return 'rc=1 PAIRS_FUZZ examined=4 expected=4 failed=4 FAIL pairs_selfcheck seed=1 rc=0 FAIL pairs_selfcheck seed=2 rc=0 FAIL pairs_readonly seed=1 rc=0 FAIL pairs_readonly seed=2 rc=0' $F 4 early-return 200 1 2
plant fuzz-done-twice   'rc=1 PAIRS_FUZZ examined=4 expected=4 failed=4 FAIL pairs_selfcheck seed=1 rc=0 FAIL pairs_selfcheck seed=2 rc=0 FAIL pairs_readonly seed=1 rc=0 FAIL pairs_readonly seed=2 rc=0' $F 4 done-twice 200 1 2
plant fuzz-one-defect   'rc=1 PAIRS_FUZZ examined=4 expected=4 failed=1 FAIL pairs_readonly seed=2 rc=0' $F 4 one-defect 200 1 2
plant fuzz-dropped-seed 'rc=1 PAIRS_FUZZ examined=2 expected=4 failed=0 PAIRS_FUZZ COUNT MISMATCH: generated=2 examined=2 expected=4' $F 4 honest 200 1
# One job, so the programs after the lost one are deterministically never run.
FUZZ_JOBS=1 plant fuzz-lost-worker 'rc=1 PAIRS_FUZZ examined=1 expected=4 failed=3 PAIRS_FUZZ HARNESS: the parallel runner exited 125 FAIL pairs_selfcheck seed=2 rc=none FAIL pairs_readonly seed=1 rc=none FAIL pairs_readonly seed=2 rc=none' $F 4 lost-worker 200 1 2
plant fuzz-dup-seed     'rc=2 PAIRS_FUZZ HARNESS: pairs_selfcheck.1 registered twice (duplicate seed?)' $F 4 honest 200 1 1
plant fuzz-tmpl-no-done 'rc=2 PAIRS_FUZZ HARNESS: pairs_selfcheck.1: template not fully substituted or has no DONE line' "$WORK/fuzz-nodone/$F" 4 honest 200 1 2
plant fuzz-no-expect    'rc=2 PAIRS_FUZZ HARNESS: set FUZZ_EXPECT to the number of programs this run must examine' $F - honest 200 1 2
plant ghost-honest      'rc=0 PAIRS_GHOST examined=4 expected=4 failed=0' $G 4 honest 30 1 2
plant ghost-exit0       'rc=1 PAIRS_GHOST examined=4 expected=4 failed=4 FAIL mode=defined seed=1 rc=0 FAIL mode=defined seed=2 rc=0 FAIL mode=undefined seed=1 rc=0 FAIL mode=undefined seed=2 rc=0' $G 4 exit0 30 1 2
plant ghost-runaway     'rc=1 PAIRS_GHOST examined=4 expected=4 failed=1 FAIL mode=undefined seed=1 rc=0' $G 4 runaway 30 1 2
plant ghost-undef-defect 'rc=1 PAIRS_GHOST examined=4 expected=4 failed=2 FAIL mode=undefined seed=1 rc=0 FAIL mode=undefined seed=2 rc=0' $G 4 undef-defect 30 1 2
plant ghost-invalid-key 'rc=1 PAIRS_GHOST examined=4 expected=4 failed=2 FAIL mode=defined seed=1 rc=0 FAIL mode=defined seed=2 rc=0' $G 4 invalid-key 30 1 2
plant ghost-dropped     'rc=1 PAIRS_GHOST examined=2 expected=4 failed=0 PAIRS_GHOST COUNT MISMATCH: generated=2 examined=2 expected=4' $G 4 honest 30 1
echo "FUZZ_PLANTS examined=$n expected=$NPLANTS wrong=$bad"
[[ $n -eq $NPLANTS && $bad -eq 0 ]]
