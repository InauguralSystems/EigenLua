# shellcheck shell=bash
# Sourced by pairs_fuzz.sh and pairs_ghost.sh: run a directory of generated
# self-checking programs in parallel and grade each one in a fixed order.
#
# A program PASSES only on positive evidence that it ran to the end: exit
# status 0, exactly one line that is exactly "DONE" (every template prints it
# as its last statement, after the loop), and no line matching the failure
# pattern. Absence of a DEFECT line is not a pass: a candidate that exits 0
# early or loses its stdout prints no DEFECT either.
#
# The examined count is pinned from outside: FUZZ_EXPECT must equal the number
# of programs that produced a verdict, so a dropped seed, a lost worker or a
# shrunken seed list fails the step instead of quietly testing less.
#
# FUZZ_JOBS (default: nproc) sets the parallelism. Each program keeps its own
# 300 s timeout, exactly as when they ran one at a time.

fuzz_init() {  # fuzz_init <tag>: validate FUZZ_EXPECT / FUZZ_JOBS
  TAG=$1
  EXPECT=${FUZZ_EXPECT:-}
  [[ $EXPECT =~ ^[1-9][0-9]*$ ]] || { echo "$TAG HARNESS: set FUZZ_EXPECT to the number of programs this run must examine" >&2; exit 2; }
  JOBS=${FUZZ_JOBS:-$(nproc 2>/dev/null || echo 1)}
  [[ $JOBS =~ ^[1-9][0-9]*$ ]] || { echo "$TAG HARNESS: FUZZ_JOBS must be a positive integer" >&2; exit 2; }
  ids=()
}

fuzz_add() {  # fuzz_add <id> <file>: register a generated program
  # Defense in depth: a template that lost its DONE line or a placeholder would
  # otherwise only show up as every program failing (done=0 or a syntax error).
  local x
  for x in "${ids[@]}"; do
    [[ $x != "$1" ]] || { echo "$TAG HARNESS: $1 registered twice (duplicate seed?)" >&2; exit 2; }
  done
  if grep -q '@[A-Z]*@' "$2" || ! grep -qx 'print("DONE")' "$2"; then
    echo "$TAG HARNESS: $1: template not fully substituted or has no DONE line" >&2; exit 2
  fi
  ids+=("$1")
}

fuzz_run() {  # fuzz_run <bin> <dir>: <dir>/<id>.lua -> <dir>/<id>.out + <dir>/<id>.rc
  # shellcheck disable=SC2016  # expanded by the worker shell, not here
  local one='timeout 300 "$1" "$2/$3.lua" >"$2/$3.out" 2>&1; echo $? >"$2/$3.rc.tmp" && mv "$2/$3.rc.tmp" "$2/$3.rc"'
  printf '%s\n' "${ids[@]}" | xargs -r -P "$JOBS" -n 1 bash -c "$one" _ "$1" "$2"
  XARGS_RC=$?
}

# fuzz_grade <dir> <label-fn> <failure-re-fn>: both functions take a program
# id and print its label / the pattern of lines that fail it. Prints one FAIL
# line per bad program (in registration order) and the summary; returns 0 iff
# every program passed and examined == FUZZ_EXPECT.
fuzz_grade() {
  local dir=$1 label=$2 refn=$3 id rc out ndone why re bad=0 n=0
  for id in "${ids[@]}"; do
    if [[ ! -f $dir/$id.rc ]]; then
      bad=$((bad+1)); echo "FAIL $($label "$id") rc=none: no verdict (the program never finished running)"
      continue
    fi
    n=$((n+1))
    rc=$(<"$dir/$id.rc"); out=$dir/$id.out; re=$($refn "$id")
    ndone=$(grep -cx 'DONE' "$out")
    why=$(grep -m1 -E "$re" "$out")
    if [[ $rc != 0 || -n $why || $ndone != 1 ]]; then
      [[ -n $why ]] || why=$(grep -m1 -E 'DEFECT|RUNAWAY|rror' "$out")
      [[ -n $why || $ndone == 1 ]] || why="want exactly one DONE line, got $ndone"
      bad=$((bad+1)); echo "FAIL $($label "$id") rc=$rc done=$ndone: $why"
    fi
  done
  echo "$TAG examined=$n expected=$EXPECT failed=$bad"
  if [[ $XARGS_RC -ne 0 ]]; then echo "$TAG HARNESS: the parallel runner exited $XARGS_RC"; return 1; fi
  if [[ $n -ne $EXPECT || ${#ids[@]} -ne $EXPECT ]]; then
    echo "$TAG COUNT MISMATCH: generated=${#ids[@]} examined=$n expected=$EXPECT"; return 1
  fi
  [[ $bad -eq 0 ]]
}
