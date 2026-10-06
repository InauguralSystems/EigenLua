#!/usr/bin/env bash
# Grade a candidate against PUC-Rio Lua 5.4.9.
# tools/grade.sh --candidate <cmd> [--tier S|D|all] [--ref <path>] [--only a,b]
# Candidate argv is exactly: <cmd> <file>, run with LUA_INIT and LUA_INIT_5_4
# unset. --ref names the pristine reference; lua-count, lua-seedA and
# lua-seedB must sit next to it (tools/build_ref.sh builds all four).
# Tier S: the program is the UNMODIFIED suite file, run as `<cmd> <name>` in a
# fresh directory whose entries link to the suite. Count protocol: at exit the
# candidate ends exactly one stderr line with `EIGENLUA-ASSERTS:<n>`, n = calls of
# its assert builtin (lua-count does this in C, tools/ref-count.patch). A row
# passes iff rc 0, one count line, the count equals the reference's (2 runs
# must agree, else UNSTABLE) or for a manifest `band` row lies in [min,max] of
# 5 runs, AND the stdout lines containing no digit equal the reference's (the
# progress cross-check on a self-reported count; a row whose reference prints
# no such line has no cross-check, shown as progress=0).
# Tier D: stdout and rc byte-identical to the reference. Each program must
# print the same under the pristine build twice and under lua-seedA and
# lua-seedB (different string hash seeds), or it is a corpus defect (exit 2).
# Residuals: tier D ignores stderr. A nonzero reference exit is not a harness
# error. UNSTABLE is a row verdict and is not a SUMMARY field. --selftest
# execs tools/selftest.sh. Membership is the files on disk, both ways.
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
run_at() {
  local cwd=$1 sec=$2 cmd=$3 file=$4 out=$5 err=$6
  (
    cd "$cwd" || exit 99
    : | timeout -k 2s "${sec}s" "$cmd" "$file" >"$out" 2>"$err"
    exit $?
  )
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
  awk '
    function q(s) { gsub(/\\/, "\\\\", s); if (length(s) > 60) s = substr(s, 1, 60); return s }
    NR == FNR { r[NR] = $0; rn = NR; next }
    { c[FNR] = $0; cn = FNR
      if ($0 != r[FNR]) { printf "line %d ref=%s cand=%s", FNR, q(r[FNR]), q($0); found = 1; exit }
    }
    END {
      if (found) exit
      if ((rn + 0) != (cn + 0)) {
        n = (rn < cn ? rn : cn) + 1
        printf "line %d ref=%s cand=%s", n, q(n in r ? r[n] : ""), q(n in c ? c[n] : "")
      } else printf "bytes differ"
    }
  ' "$1" "$2"
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
  local cwd=$1 sec=$2 cmd=$3 file=$4 pre=$5 t0 t1 ms2
  t0=$(date +%s%N)
  run_at "$cwd" "$sec" "$cmd" "$file" "$pre.1o" "$pre.1e"
  RC1=$RUN_RC
  t1=$(date +%s%N)
  MS=$(( (t1 - t0) / 1000000 ))
  t0=$(date +%s%N)
  run_at "$cwd" "$sec" "$cmd" "$file" "$pre.2o" "$pre.2e"
  RC2=$RUN_RC
  t1=$(date +%s%N)
  ms2=$(( (t1 - t0) / 1000000 ))
  (( ms2 > MS )) && MS=$ms2
  [[ $RC1 -eq 99 || $RC2 -eq 99 ]] && die "could not enter $cwd"
}
CAND=""
TIER=all
REF="$ROOT/.ref/bin/lua"
ONLY=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --candidate|--tier|--ref|--only)
      [[ $# -ge 2 ]] || die "missing value for $1"
      case $1 in
        --candidate) CAND=$2 ;;
        --tier) TIER=$2 ;;
        --ref) REF=$2 ;;
        --only) ONLY=$2 ;;
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
declare -A s_status=() d_have=() s_band=()
declare -a s_include=() d_names=()
while read -r status name reason; do
  [[ -z ${status:-} || ${status:0:1} == '#' ]] && continue
  [[ $status =~ ^(include|exclude|band)$ ]] || die "bad S manifest status: $status"
  [[ -n ${s_status[$name]:-} ]] && die "duplicate S row: $name"
  s_status[$name]=$status
  [[ -f $SUITE/$name ]] || die "manifest row has no file: $name"
  if [[ $status == include ]]; then [[ -z ${reason:-} ]]; else [[ -n ${reason:-} ]]; fi || die "bad reason field for $status row: $name"
  [[ $status == band ]] && s_band[$name]=1
  [[ $status == exclude ]] || s_include+=("$name")
done <"$SMAN"
[[ ${#s_include[@]} -eq 27 ]] || die "include count ${#s_include[@]} != 27"
for need in heavy.lua attrib.lua big.lua main.lua; do
  [[ ${s_status[$need]:-} == exclude ]] || die "$need must be excluded"
done
[[ -f $SUITE/all.lua ]] || die "all.lua missing"
[[ -z ${s_status[all.lua]:-} ]] || die "all.lua must not be a row"
while read -r name extra; do
  [[ -z ${name:-} || ${name:0:1} == '#' ]] && continue
  [[ ${extra:-} == "unspecified-audit: ok" ]] || die "D manifest row lacks unspecified-audit: ok: $name"
  [[ -n ${d_have[$name]:-} ]] && die "duplicate D row: $name"
  d_have[$name]=1
  [[ -f $DDIR/$name ]] || die "manifest row has no file: D/$name"
  hdr=$(head -n 1 "$DDIR/$name")
  [[ $hdr == "-- surface:"* ]] || die "D/$name missing surface header"
  d_names+=("$name")
done <"$DMAN"
[[ ${#d_names[@]} -ge 30 ]] || die "D corpus has ${#d_names[@]} rows, want at least 30"
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
declare -a ONLY_NAMES=() s_sel=() d_sel=()
if [[ -n $ONLY ]]; then
  IFS=',' read -r -a ONLY_NAMES <<<"$ONLY"
  declare -a cleaned=()
  for n in "${ONLY_NAMES[@]}"; do
    [[ -n $n ]] && cleaned+=("$n")
  done
  ONLY_NAMES=("${cleaned[@]}")
  (( ${#ONLY_NAMES[@]} > 0 )) || die "zero rows examined"
  for n in "${ONLY_NAMES[@]}"; do
    case $TIER in
      S) in_list "$n" "${s_all[@]}" || die "--only is not an S row: $n" ;;
      D) in_list "$n" "${d_all[@]}" || die "--only is not a D row: $n" ;;
      all)
        in_list "$n" "${s_all[@]}" || in_list "$n" "${d_all[@]}" || die "--only is not a row: $n"
        ;;
    esac
  done
fi
pick() {
  local -n _src=$1 _dst=$2
  _dst=()
  if [[ -z $ONLY ]]; then
    _dst=("${_src[@]}")
    return
  fi
  local n
  for n in "${_src[@]}"; do
    in_list "$n" "${ONLY_NAMES[@]}" && _dst+=("$n")
  done
}
[[ $TIER != D ]] && pick s_all s_sel
[[ $TIER != S ]] && pick d_all d_sel
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
    run_at "$DDIR" 30 "$REF" "$DDIR/$name" "$pre.exp" "$pre.expe"
    if ref_signaled "$RC1" || ref_signaled "$RC2" || ref_signaled "$RUN_RC"; then
      die "reference failed on D/$name rc=$RC1/$RC2/$RUN_RC"
    fi
    # >>> guard:nondet
    if [[ $RC1 -ne $RC2 || $RC1 -ne $RUN_RC ]] || ! cmp -s "$pre.1o" "$pre.2o"; then
      die "corpus defect: D/$name is nondeterministic"
    fi
    # <<< guard:nondet
    # >>> guard:unspecified
    if ! cmp -s "$pre.1o" "$pre.B"; then
      die "corpus defect: D/$name is UNSPECIFIED (stdout depends on the string hash seed)"
    fi
    # <<< guard:unspecified
    cmp -s "$pre.1o" "$pre.exp" || die "corpus defect: D/$name differs between lua and lua-seedA"
    d_exp_rc[$name]=$RC1
    d_ms[$name]=$MS
  done
fi
progress() { grep -v '[0-9]' "$1" >"$1.p"; return 0; }
run_s() {
  local name=$1 k=$2 cmd=$3 sec=$4 dir="$WORK/s-$name-$2"
  link_dir "$dir"
  run_at "$dir" "$sec" "$cmd" "$name" "$dir.o" "$dir.e"
  [[ $RUN_RC -eq 99 ]] && die "could not enter $dir"
  S_RC=$RUN_RC
  S_C=$(assert_count "$dir.e")
  progress "$dir.o"
}
if (( ${#s_sel[@]} > 0 )); then
  for name in "${s_sel[@]}"; do
    nref=2
    [[ -n ${s_band[$name]:-} ]] && nref=5
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
    # >>> guard:stable
    if [[ $rcs == *[1-9]* || $prog != same ]] || [[ -z ${s_band[$name]:-} && $lo -ne $hi ]]; then
      s_why[$name]="reference over $nref runs: rc$rcs, asserts in [$lo,$hi], progress $prog"
    elif [[ -n ${s_band[$name]:-} && $lo -eq $hi ]]; then
      die "S/$name is declared band but $nref reference runs all counted $lo"
    fi
    # <<< guard:stable
    s_lo[$name]=$lo s_hi[$name]=$hi
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
  [[ $rc -eq 99 ]] && die "could not enter $DDIR"
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
  local name=$1 rc sec special c lo hi band=''
  if [[ -n ${s_why[$name]:-} ]]; then
    emit S "$name" UNSTABLE "${s_why[$name]}"
    return
  fi
  lo=${s_lo[$name]} hi=${s_hi[$name]}
  [[ -n ${s_band[$name]:-} ]] && band=" band=[$lo,$hi]"
  sec=$(row_timeout "${s_ms[$name]}")
  run_s "$name" cand "$CAND" "$sec"
  rc=$S_RC c=$S_C
  special=$(classify "$rc" "$WORK/s-$name-cand.e")
  if [[ -n $special ]]; then emit S "$name" "$special" "rc=$rc"; return; fi
  local np pr=same pre="$WORK/s-$name"
  np=$(wc -l <"$pre-ref1.o.p")
  # >>> guard:progress
  cmp -s "$pre-ref1.o.p" "$pre-cand.o.p" || pr="differs($(first_diff "$pre-ref1.o.p" "$pre-cand.o.p"))"
  # <<< guard:progress
  # >>> guard:s-pass
  if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && c <= hi )); then
    emit S "$name" PASS "asserts=$c progress=$np$band"
    return
  fi
  # <<< guard:s-pass
  # >>> guard:s-fail
  [[ -n $band ]] || band=" ref=$lo"
  emit S "$name" FAIL "asserts cand=$c rc=$rc$band progress=$pr"
  # <<< guard:s-fail
}
for name in "${s_sel[@]}"; do grade_s "$name"; done
for name in "${d_sel[@]}"; do grade_d "$name"; done
if (( examined == 0 )); then die "zero rows examined"; fi
printf 'SUMMARY S=%s/%s D=%s/%s fail=%s diverge=%s hang=%s crash=%s unsupported=%s examined=%s\n' \
  "$s_pass" "$s_n" "$d_match" "$d_n" "$fail" "$diverge" "$hang" "$crash" "$unsup" "$examined"
if (( fail == 0 && diverge == 0 && hang == 0 && crash == 0 && unsup == 0 && unstable == 0 \
      && s_pass == s_n && d_match == d_n )); then
  exit 0
fi
exit 1
