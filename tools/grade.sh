#!/usr/bin/env bash
# Grade a candidate against PUC-Rio Lua 5.4.9.
# tools/grade.sh --candidate <cmd> [--tier S|D|all] [--ref <path>] [--only a,b]
#                [--repeat K]   (each S candidate run K times; all must pass)
# Candidate argv is exactly: <cmd> <file>, LUA_INIT and LUA_INIT_5_4 unset.
# --ref names the pristine reference; tools/build_ref.sh puts lua-count,
# lua-seedA and lua-seedB next to it.
# Tier S is gated by the assert-trust probe: corpus/D/assert_semantics.lua run
# on the candidate must match the reference's stdout and rc byte for byte, or
# every S row is `FAIL assert-untrusted` (SUMMARY assert=untrusted). Per row, the
# file with `assert(false);` before line 1 (no newline) must exit non-zero with
# "assertion failed!" on stderr, or the row is FAIL assert-untrusted(control).
# An S program is the UNMODIFIED suite file, run as `<cmd> <name>` in a fresh
# directory linking to the suite. At exit the candidate ends exactly one stderr
# line with `EIGENLUA-ASSERTS:<n>`, n = calls of its assert builtin (lua-count:
# tools/ref-count.patch). A row passes iff rc 0, one numeric count, the stdout
# lines with no digit equal the reference's (progress cross-check), and:
#  include: count == reference count (2 reference runs must agree, else
#    UNSTABLE);
#  count-unspecified: count >= floor = F x min of 20 reference runs, no upper
#    bound; F is the row's required `floor=0.N` field in S.manifest (missing:
#    exit 2). math.lua F=0.60: counts come in quanta of 10602 and the lowest
#    mode (36.2k, 0.6% of 1220 runs) is 53-77% of a min-of-20. nextvar F=0.90:
#    1220 runs span 9838..9942. Counts follow unspecified behaviour, so a count
#    a little off (off-by-one plant) is NOT caught; a large shortfall is.
# Tier D: stdout and rc byte-identical to the reference. Each program must
# print the same under lua-seedA twice, lua-seedB and the pristine build, or
# it is a corpus defect (exit 2). Residuals: tier D ignores stderr; a nonzero
# reference exit is not a harness error; UNSTABLE is a row verdict only.
# --selftest execs tools/selftest.sh. Membership is the files on disk, both ways.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ulimit -c 0
unset LUA_INIT LUA_INIT_5_4
if [[ ${1:-} == --selftest ]]; then
  exec "$ROOT/tools/selftest.sh"
fi
die() { printf 'HARNESS %s\n' "$*" >&2; exit 2; }
link_dir() {
  local dir=$1 e
  mkdir -p "$dir" || die "cannot create $dir"
  for e in "$SUITE"/*; do ln -s "$e" "$dir/" || die "cannot link $e"; done
}
RUN_RC=0
run_at() {  # the cd check is outside the subshell: every candidate rc is the candidate's
  local cwd=$1 sec=$2 cmd=$3 file=$4 out=$5 err=$6
  [[ -d $cwd && -x $cwd ]] || die "could not enter $cwd"
  ( cd "$cwd" && : | timeout -k 2s "${sec}s" "$cmd" "$file" >"$out" 2>"$err" )
  RUN_RC=$?
}
assert_count() {
  local n
  n=$(grep -cE 'EIGENLUA-ASSERTS:[0-9]+$' "$1")
  if [[ $n -eq 1 ]]; then
    sed -n 's/^.*EIGENLUA-ASSERTS:\([0-9][0-9]*\)$/\1/p' "$1"
  elif [[ $n -eq 0 ]]; then printf 'none\n'
  else printf 'many\n'
  fi
}
row_timeout() {
  local sec=$(( ($1 + 999) / 1000 )) t
  (( sec < 1 )) && sec=1
  t=$(( sec * 20 ))
  (( t < 10 )) && t=10
  printf '%s\n' "$t"
}
first_diff() {
  awk -v REF="$1" '
    function q(s) { gsub(/\\/, "\\\\", s); if (length(s) > 60) s = substr(s, 1, 60); return s }
    BEGIN { while ((getline l < REF) > 0) r[++rn] = l }
    { c[FNR] = $0; cn = FNR
      if (($0 "") != (r[FNR] "")) { printf "line %d ref=%s cand=%s", FNR, q(r[FNR]), q($0); found = 1; exit }
    }
    END {
      if (found) exit
      if ((rn + 0) != (cn + 0)) {
        n = (rn < cn ? rn : cn) + 1
        printf "line %d ref=%s cand=%s", n, q(n in r ? r[n] : ""), q(n in c ? c[n] : "")
      } else printf "bytes differ"
    }
  ' "$2"
}
classify() {
  local rc=$1 err=$2
  # >>> guard:hang
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then printf 'HANG\n'; return; fi
  # <<< guard:hang
  # >>> guard:crash
  if [[ $rc -ge 128 ]]; then printf 'CRASH\n'; return; fi
  # <<< guard:crash
  # >>> guard:unsupported
  if [[ $rc -eq 3 ]] && grep -Eq '^EIGENLUA-UNSUPPORTED:' "$err"; then
    printf 'UNSUPPORTED\n'
    return
  fi
  # <<< guard:unsupported
  printf '\n'
}
examined=0 s_n=0 d_n=0 s_pass=0 d_match=0
fail=0 diverge=0 hang=0 crash=0 unsup=0 unstable=0
emit() {
  local tier=$1 name=$2 verdict=$3 detail=$4
  detail=${detail//$'\n'/ }
  detail=${detail//$'\t'/ }
  if (( ${#detail} > 180 )); then detail=${detail:0:180}; fi
  printf 'ROW %s %s %s %s\n' "$tier" "$name" "$verdict" "$detail"
  examined=$((examined + 1))
  [[ $tier == S ]] && s_n=$((s_n + 1))
  [[ $tier == D ]] && d_n=$((d_n + 1))
  case $verdict in
    PASS) s_pass=$((s_pass + 1)) ;;
    MATCH) d_match=$((d_match + 1)) ;;
    FAIL) fail=$((fail + 1)) ;;
    DIVERGE) diverge=$((diverge + 1)) ;;
    HANG) hang=$((hang + 1)) ;;
    CRASH) crash=$((crash + 1)) ;;
    UNSUPPORTED) unsup=$((unsup + 1)) ;;
    UNSTABLE) unstable=$((unstable + 1)) ;;
  esac
}
twice() {
  local cwd=$1 sec=$2 cmd=$3 file=$4 pre=$5 k t0 t
  MS=0
  for k in 1 2; do
    t0=$(date +%s%N)
    run_at "$cwd" "$sec" "$cmd" "$file" "$pre.${k}o" "$pre.${k}e"
    printf -v "RC$k" '%s' "$RUN_RC"
    t=$(( ($(date +%s%N) - t0) / 1000000 )); (( t > MS )) && MS=$t
  done
}
CAND=""
TIER=all
REF="$ROOT/.ref/bin/lua"
ONLY=""
REPEAT=1
while [[ $# -gt 0 ]]; do
  case $1 in
    --candidate|--tier|--ref|--only|--repeat)
      [[ $# -ge 2 ]] || die "missing value for $1"
      case $1 in
        --candidate) CAND=$2 ;;
        --tier) TIER=$2 ;;
        --ref) REF=$2 ;;
        --only) ONLY=$2 ;;
        --repeat) REPEAT=$2 ;;
      esac
      shift 2
      ;;
    *) die "unknown argument: $1" ;;
  esac
done
case $TIER in
  S|D|all) ;;
  *) die "bad tier: $TIER" ;;
esac
case $REPEAT in
  [1-9]|[1-9][0-9]) ;;
  *) die "bad --repeat: $REPEAT" ;;
esac
[[ -n $CAND ]] || die "missing --candidate"
if [[ $CAND != /* && -e $CAND ]]; then CAND=$PWD/$CAND; fi
if [[ $REF != /* && -e $REF ]]; then REF=$PWD/$REF; fi
# >>> guard:candidate
if [[ ! -f $CAND || ! -x $CAND ]]; then
  die "candidate is not executable: $CAND"
fi
# <<< guard:candidate
# >>> guard:version
vre='^Lua 5\.4\.9( |$)'
for r in "$REF" "${REF%/*}/lua-count" "${REF%/*}/lua-seedA" "${REF%/*}/lua-seedB"; do
  [[ -x $r ]] || die "reference missing or not executable: $r"
  ver=$("$r" -v 2>&1 || true)
  if [[ ! $ver =~ $vre ]]; then
    die "reference -v is not 5.4.9: ${ver}"
  fi
done
REF_COUNT="${REF%/*}/lua-count"
# <<< guard:version
SUITE="$ROOT/corpus/lua-tests"
DDIR="$ROOT/corpus/D"
SMAN="$ROOT/corpus/S.manifest"
DMAN="$ROOT/corpus/D.manifest"
[[ -f $SMAN && -f $DMAN ]] || die "missing manifest"
declare -A s_status=() d_have=() s_cu=()
declare -a s_include=() d_names=()
while read -r status name reason; do
  [[ -z ${status:-} || ${status:0:1} == '#' ]] && continue
  [[ $status =~ ^(include|exclude|count-unspecified)$ ]] || die "bad S manifest status: $status"
  [[ -n ${s_status[$name]:-} ]] && die "duplicate S row: $name"
  s_status[$name]=$status
  [[ -f $SUITE/$name ]] || die "manifest row has no file: $name"
  if [[ $status == include ]]; then [[ -z ${reason:-} ]]; else [[ -n ${reason:-} ]]; fi || die "bad reason field for $status row: $name"
  if [[ $status == count-unspecified ]]; then
    [[ $reason =~ ^floor=0\.([0-9][0-9]?)\ +[^\ ] ]] || die "count-unspecified row has no floor=0.N fraction: $name"
    s_cu[$name]=${BASH_REMATCH[1]}0 s_cu[$name]=${s_cu[$name]:0:2}
    (( 10#${s_cu[$name]} > 0 )) || die "count-unspecified floor must be in (0,1): $name"
  fi
  [[ $status == exclude ]] || s_include+=("$name")
done <"$SMAN"
[[ ${#s_include[@]} -eq 23 ]] || die "graded S count ${#s_include[@]} != 23"
for need in heavy.lua attrib.lua big.lua main.lua files.lua api.lua code.lua bwcoercion.lua tracegc.lua; do
  [[ ${s_status[$need]:-} == exclude ]] || die "$need must be excluded"
done
[[ -f $SUITE/all.lua ]] || die "all.lua missing"
[[ -z ${s_status[all.lua]:-} ]] || die "all.lua must not be a row"
while read -r name extra; do
  [[ -z ${name:-} || ${name:0:1} == '#' ]] && continue
  [[ $name == operators: ]] && { OPS=$extra; continue; }
  [[ ${extra:-} == "unspecified-audit: ok" ]] || die "D manifest row lacks unspecified-audit: ok: $name"
  [[ -n ${d_have[$name]:-} ]] && die "duplicate D row: $name"
  d_have[$name]=1
  [[ -f $DDIR/$name ]] || die "manifest row has no file: D/$name"
  hdr=$(head -n 1 "$DDIR/$name")
  [[ $hdr == "-- surface:"* ]] || die "D/$name missing surface header"
  d_names+=("$name")
done <"$DMAN"
[[ ${#d_names[@]} -ge 30 ]] || die "D corpus has ${#d_names[@]} rows, want at least 30"
# >>> guard:ops (every operator on D.manifest's operators: line is in ops_matrix.lua's table, both ways)
[[ -n ${d_have[ops_matrix.lua]:-} && -n ${OPS:-} ]] || die "D needs ops_matrix.lua and an operators: line"
have=$(sed -n 's/^  {"\([^"]*\)", function.*/\1/p' "$DDIR/ops_matrix.lua" | LC_ALL=C sort -u | tr '\n' ' ')
[[ $have == "$(tr ' ' '\n' <<<"$OPS" | grep . | LC_ALL=C sort -u | tr '\n' ' ')" ]] || die "ops_matrix.lua operator table [$have] != D.manifest operators: [$OPS]"
# <<< guard:ops
# >>> guard:membership
for f in "$SUITE"/*.lua; do
  base=$(basename "$f")
  [[ $base == all.lua ]] && continue
  [[ -n ${s_status[$base]:-} ]] || die "corpus file not in manifest: $base"
done
for f in "$DDIR"/*.lua; do
  base=$(basename "$f")
  [[ -n ${d_have[$base]:-} ]] || die "corpus file not in manifest: D/$base"
done
# <<< guard:membership
# >>> guard:checksum
sumfile="$ROOT/corpus/lua-tests.sha256"
[[ -f $sumfile ]] || die "missing checksum manifest"
declare -A expect=()
nsum=0
while read -r sum path; do
  [[ -z ${sum:-} || ${sum:0:1} == '#' ]] && continue
  [[ -z ${expect[$path]:-} ]] || die "duplicate checksum row: $path"
  expect[$path]=$sum
  nsum=$((nsum + 1))
done <"$sumfile"
ndisk=0
while IFS= read -r -d '' f; do
  rel=${f#"$SUITE/"}
  [[ $rel == SOURCE.md ]] && continue
  ndisk=$((ndisk + 1))
  [[ -n ${expect[$rel]:-} ]] || die "checksum manifest missing $rel"
  got=$(sha256sum "$f" | awk '{print $1}')
  [[ $got == "${expect[$rel]}" ]] || die "checksum mismatch: $rel"
done < <(find "$SUITE" -type f -print0)
[[ $ndisk -eq $nsum ]] || die "checksum manifest has $nsum rows but $ndisk files"
# <<< guard:checksum
declare -a s_all=() d_all=()
mapfile -t s_all < <(printf '%s\n' "${s_include[@]}" | LC_ALL=C sort)
mapfile -t d_all < <(printf '%s\n' "${d_names[@]}" | LC_ALL=C sort)
in_list() {
  local n=$1 x
  shift
  for x in "$@"; do [[ $x == "$n" ]] && return 0; done
  return 1
}
declare -a s_sel=() d_sel=() want=()
IFS=',' read -r -a want <<<"$ONLY"
for n in "${want[@]}"; do
  [[ -z $n ]] && continue
  ok=0
  [[ $TIER != D ]] && in_list "$n" "${s_all[@]}" && ok=1
  [[ $TIER != S ]] && in_list "$n" "${d_all[@]}" && ok=1
  (( ok )) || die "--only is not a tier $TIER row: $n"
done
sel() { local n; for n in "${@:2}"; do [[ -z $ONLY || ",$ONLY," == *",$n,"* ]] && eval "$1+=(\"\$n\")"; done; }
[[ $TIER != D ]] && sel s_sel "${s_all[@]}"
[[ $TIER != S ]] && sel d_sel "${d_all[@]}"
if (( ${#s_sel[@]} + ${#d_sel[@]} == 0 )); then die "zero rows examined"; fi
mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/grade-XXXXXX")
trap 'rm -rf "$WORK"' EXIT
declare -A d_exp_rc=() d_ms=() s_lo=() s_hi=() s_why=() s_ms=()
ref_signaled() { [[ $1 -eq 124 || $1 -ge 128 ]]; }
if (( ${#d_sel[@]} > 0 )); then
  for name in "${d_sel[@]}"; do
    pre="$WORK/d-$name"
    twice "$DDIR" 30 "${REF%/*}/lua-seedA" "$DDIR/$name" "$pre"
    run_at "$DDIR" 30 "${REF%/*}/lua-seedB" "$DDIR/$name" "$pre.B" "$pre.Be"
    RCB=$RUN_RC
    run_at "$DDIR" 30 "$REF" "$DDIR/$name" "$pre.exp" "$pre.expe"
    for r in "$RC1" "$RC2" "$RCB" "$RUN_RC"; do ref_signaled "$r" && die "reference failed on D/$name rc=$RC1/$RC2/$RCB/$RUN_RC"; done
    # >>> guard:nondet
    if [[ $RC1 -ne $RC2 ]] || ! cmp -s "$pre.1o" "$pre.2o"; then
      die "corpus defect: D/$name is nondeterministic"
    fi
    # <<< guard:nondet
    # >>> guard:unspecified
    if [[ $RC1 -ne $RCB ]] || ! cmp -s "$pre.1o" "$pre.B"; then
      die "corpus defect: D/$name is UNSPECIFIED (stdout or rc depends on the string hash seed)"
    fi
    # <<< guard:unspecified
    [[ $RC1 -eq $RUN_RC ]] && cmp -s "$pre.1o" "$pre.exp" || die "corpus defect: D/$name differs between lua and lua-seedA"
    d_exp_rc[$name]=$RC1
    d_ms[$name]=$MS
  done
fi
progress() { grep -v '[0-9]' "$1" >"$1.p"; return 0; }
run_s() {
  local name=$1 k=$2 cmd=$3 sec=$4 dir="$WORK/s-$name-$2"
  link_dir "$dir"
  run_at "$dir" "$sec" "$cmd" "$name" "$dir.o" "$dir.e"
  S_RC=$RUN_RC
  S_C=$(assert_count "$dir.e")
  progress "$dir.o"
}
run_ctl() {  # <name> <cmd> <tag>: the row with `assert(false);` before line 1 must fail
  local dir="$WORK/c-$1-$3"
  [[ $(head -c 1 "$SUITE/$1") != '#' ]] || die "S/$1 starts with '#'; the control prefix would break it"
  link_dir "$dir"
  rm -f "$dir/$1"
  { printf 'assert(false);'; cat "$SUITE/$1"; } >"$dir/$1"
  run_at "$dir" 30 "$2" "$1" "$dir.o" "$dir.e"
  [[ $RUN_RC -ne 0 ]] && grep -q 'assertion failed!' "$dir.e"
}
PROBE="$DDIR/assert_semantics.lua" TRUST=n/a TRUST_WHY=''
if (( ${#s_sel[@]} > 0 )); then
  [[ -n ${d_have[assert_semantics.lua]:-} ]] || die "assert probe missing from D: $PROBE"
  run_at "$DDIR" 30 "$REF" "$PROBE" "$WORK/probe.ref" "$WORK/probe.refe"
  prc=$RUN_RC
  [[ $prc -eq 0 && -s $WORK/probe.ref ]] || die "reference failed the assert probe rc=$prc"
  run_at "$DDIR" 30 "$CAND" "$PROBE" "$WORK/probe.cand" "$WORK/probe.cande"
  # >>> guard:assert-trust
  if [[ $RUN_RC -eq $prc ]] && cmp -s "$WORK/probe.ref" "$WORK/probe.cand"; then
    TRUST=trusted
  else
    TRUST=untrusted TRUST_WHY="probe rc=$RUN_RC $(first_diff "$WORK/probe.ref" "$WORK/probe.cand")"
  fi
  # <<< guard:assert-trust
fi
if (( ${#s_sel[@]} > 0 )) && [[ $TRUST == trusted ]]; then
  for name in "${s_sel[@]}"; do
    nref=2
    [[ -n ${s_cu[$name]:-} ]] && nref=20
    lo='' hi='' rcs='' MS=0 prog=same
    for ((k = 1; k <= nref; k++)); do
      t0=$(date +%s%N)
      run_s "$name" "ref$k" "$REF_COUNT" 180
      t1=$(( ($(date +%s%N) - t0) / 1000000 ))
      (( t1 > MS )) && MS=$t1
      ref_signaled "$S_RC" && die "reference failed on S/$name rc=$S_RC"
      [[ $S_C =~ ^[0-9]+$ ]] || die "reference printed no single assert count on S/$name"
      cmp -s "$WORK/s-$name-ref1.o.p" "$WORK/s-$name-ref$k.o.p" || prog=differs
      rcs+=" $S_RC"
      [[ -z $lo ]] || (( S_C < lo )) && lo=$S_C
      [[ -z $hi ]] || (( S_C > hi )) && hi=$S_C
    done
    s_ms[$name]=$MS
    run_ctl "$name" "$REF_COUNT" ref || die "reference does not fail the assert(false) control on S/$name"
    # >>> guard:stable
    if [[ $rcs == *[1-9]* || $prog != same ]] || [[ -z ${s_cu[$name]:-} && $lo -ne $hi ]]; then
      s_why[$name]="reference over $nref runs: rc$rcs, asserts in [$lo,$hi], progress $prog"
    fi
    # <<< guard:stable
    s_lo[$name]=$lo s_hi[$name]=$hi
    if [[ -n ${s_cu[$name]:-} ]]; then
      floor=$(( lo * 10#${s_cu[$name]} / 100 ))
      s_lo[$name]=$floor s_hi[$name]=-1
    fi
  done
fi
grade_d() {
  local name=$1 out err rc sec special detail exp pre
  pre="$WORK/d-$name"
  out="$pre.cand.out"
  err="$pre.cand.err"
  exp="$pre.exp"
  sec=$(row_timeout "${d_ms[$name]}")
  run_at "$DDIR" "$sec" "$CAND" "$DDIR/$name" "$out" "$err"
  rc=$RUN_RC
  special=$(classify "$rc" "$err")
  if [[ -n $special ]]; then emit D "$name" "$special" "rc=$rc"; return; fi
  # >>> guard:d-match
  if cmp -s "$exp" "$out" && [[ $rc -eq ${d_exp_rc[$name]} ]]; then
    emit D "$name" MATCH "rc=$rc"
    return
  fi
  # <<< guard:d-match
  # >>> guard:d-diverge
  if cmp -s "$exp" "$out"; then
    detail="exit ref=${d_exp_rc[$name]} cand=$rc"
  else
    detail=$(first_diff "$exp" "$out")
  fi
  emit D "$name" DIVERGE "$detail"
  # <<< guard:d-diverge
}
grade_s() {
  local name=$1 rc sec special c lo hi k np pr pre="$WORK/s-$name" tag
  if [[ $TRUST != trusted ]]; then emit S "$name" FAIL "assert-untrusted $TRUST_WHY"; return; fi
  if [[ -n ${s_why[$name]:-} ]]; then
    emit S "$name" UNSTABLE "${s_why[$name]}"
    return
  fi
  lo=${s_lo[$name]} hi=${s_hi[$name]}
  sec=$(row_timeout "${s_ms[$name]}")
  np=$(wc -l <"$pre-ref1.o.p")
  # >>> guard:control
  if ! run_ctl "$name" "$CAND" cand; then emit S "$name" FAIL "assert-untrusted(control) rc=$RUN_RC"; return; fi
  # <<< guard:control
  for ((k = 1; k <= REPEAT; k++)); do
    run_s "$name" "cand$k" "$CAND" "$sec"
    rc=$S_RC c=$S_C pr=same
    tag="count=$c"
    [[ -n ${s_cu[$name]:-} ]] && tag="class=count-unspecified fraction=0.${s_cu[$name]} floor=$lo count=$c"
    (( REPEAT > 1 )) && tag="$tag run=$k/$REPEAT"
    special=$(classify "$rc" "$pre-cand$k.e")
    if [[ -n $special ]]; then emit S "$name" "$special" "rc=$rc $tag"; return; fi
    # >>> guard:progress
    cmp -s "$pre-ref1.o.p" "$pre-cand$k.o.p" || pr="differs($(first_diff "$pre-ref1.o.p" "$pre-cand$k.o.p"))"
    # <<< guard:progress
    # >>> guard:s-pass
    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && (hi < 0 || c <= hi) )); then
      continue
    fi
    # <<< guard:s-pass
    [[ -n ${s_cu[$name]:-} ]] || tag="$tag ref=$lo"
    emit S "$name" FAIL "rc=$rc $tag progress=$pr"
    return
  done
  emit S "$name" PASS "$tag progress=$np"
}
for name in "${s_sel[@]}"; do grade_s "$name"; done
for name in "${d_sel[@]}"; do grade_d "$name"; done
if (( examined == 0 )); then die "zero rows examined"; fi
printf 'SUMMARY S=%s/%s D=%s/%s fail=%s diverge=%s hang=%s crash=%s unsupported=%s examined=%s assert=%s\n' \
  "$s_pass" "$s_n" "$d_match" "$d_n" "$fail" "$diverge" "$hang" "$crash" "$unsup" "$examined" "$TRUST"
if (( fail == 0 && diverge == 0 && hang == 0 && crash == 0 && unsup == 0 && unstable == 0 \
      && s_pass == s_n && d_match == d_n )); then
  exit 0
fi
exit 1
