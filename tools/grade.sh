#!/usr/bin/env bash
# Grade a candidate against PUC-Rio Lua 5.4.9.
# tools/grade.sh --candidate <cmd> [--tier S|D|all] [--ref <path>] [--only a,b]
# tools/grade.sh --shim <src.lua> <dir>   (writes the tier S program, see below)
# Candidate argv is exactly: <cmd> <file>. A tier S program is the test file
# with tools/s_shim.lua joined onto the front of line 1, under the test's own
# name, in a fresh directory whose other entries link to the suite. An S row
# passes on rc 0 and an assert count equal to the reference (2 runs must agree,
# else UNSTABLE), or for a manifest `band` row, inside [min,max] of 5 runs.
# Residuals: tier D ignores stderr. A nonzero reference exit is not a harness
# error. UNSTABLE is a row verdict and is not a SUMMARY field. --selftest
# execs tools/selftest.sh. Membership is the files on disk, both ways.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ulimit -c 0
if [[ ${1:-} == --selftest ]]; then
  exec "$ROOT/tools/selftest.sh"
fi
die() { printf 'HARNESS %s\n' "$*" >&2; exit 2; }
PRELUDE=$(grep -v '^[[:space:]]*--' "$ROOT/tools/s_shim.lua" | tr '\n' ' ') || die "cannot read tools/s_shim.lua"
case $PRELUDE in
  *--*|*'[['*|*'[='*|'') die "s_shim.lua code must have no inline comment or long bracket" ;;
esac
shim_into() {
  local src=$1 dir=$2 base e
  base=$(basename "$src")
  [[ $(head -c 1 "$src") != '#' ]] || die "$base starts with '#'; the prelude would hide line 1"
  mkdir -p "$dir" || die "cannot create $dir"
  for e in "$(dirname "$src")"/*; do ln -s "$e" "$dir/" || die "cannot link $e"; done
  rm -f "$dir/$base"
  { printf '%s' "$PRELUDE"; cat "$src"; } >"$dir/$base" || die "cannot write $dir/$base"
}
if [[ ${1:-} == --shim ]]; then
  [[ $# -eq 3 && -f $2 ]] || die "usage: --shim <src.lua> <dir>"
  shim_into "$2" "$3"
  exit 0
fi
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
  local line
  line=$(grep -E 'EIGENLUA-ASSERTS:[0-9]+' "$1" 2>/dev/null | tail -n 1 || true)
  if [[ $line =~ EIGENLUA-ASSERTS:([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf 'none\n'
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
REF="$ROOT/.ref/lua-5.4.9/src/lua"
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
if [[ ! -x $REF ]]; then
  die "reference missing or not executable: $REF"
fi
ver=$("$REF" -v 2>&1 || true)
vre='^Lua 5\.4\.9( |$)'
if [[ ! $ver =~ $vre ]]; then
  die "reference -v is not 5.4.9: ${ver}"
fi
# <<< guard:version
SUITE="$ROOT/corpus/lua-tests"
DDIR="$ROOT/corpus/D"
SMAN="$ROOT/corpus/S.manifest"
DMAN="$ROOT/corpus/D.manifest"
[[ -f $SMAN && -f $DMAN && -f $ROOT/tools/s_shim.lua ]] || die "missing manifest or assert shim"
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
  [[ -z ${extra:-} ]] || die "bad D manifest row: $name"
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
    twice "$DDIR" 30 "$REF" "$DDIR/$name" "$pre"
    if ref_signaled "$RC1" || ref_signaled "$RC2"; then
      die "reference failed on D/$name rc=$RC1/$RC2"
    fi
    # >>> guard:nondet
    if [[ $RC1 -ne $RC2 ]] || ! cmp -s "$pre.1o" "$pre.2o"; then
      die "corpus defect: D/$name is nondeterministic"
    fi
    # <<< guard:nondet
    cp -f "$pre.1o" "$pre.exp"
    d_exp_rc[$name]=$RC1
    d_ms[$name]=$MS
  done
fi
run_s() {
  local name=$1 k=$2 cmd=$3 sec=$4 dir="$WORK/s-$name-$2"
  shim_into "$SUITE/$name" "$dir"
  run_at "$dir" "$sec" "$cmd" "$name" "$dir.o" "$dir.e"
  [[ $RUN_RC -eq 99 ]] && die "could not enter $dir"
  S_RC=$RUN_RC
  S_C=$(assert_count "$dir.e")
}
if (( ${#s_sel[@]} > 0 )); then
  for name in "${s_sel[@]}"; do
    nref=2
    [[ -n ${s_band[$name]:-} ]] && nref=5
    lo='' hi='' rcs='' MS=0
    for ((k = 1; k <= nref; k++)); do
      t0=$(date +%s%N)
      run_s "$name" "ref$k" "$REF" 180
      t1=$(( ($(date +%s%N) - t0) / 1000000 ))
      (( t1 > MS )) && MS=$t1
      ref_signaled "$S_RC" && die "reference failed on S/$name rc=$S_RC"
      [[ $S_C =~ ^[0-9]+$ ]] || die "reference printed no assert count on S/$name"
      rcs+=" $S_RC"
      [[ -z $lo ]] || (( S_C < lo )) && lo=$S_C
      [[ -z $hi ]] || (( S_C > hi )) && hi=$S_C
    done
    s_ms[$name]=$MS
    # >>> guard:stable
    if [[ $rcs == *[1-9]* ]] || [[ -z ${s_band[$name]:-} && $lo -ne $hi ]]; then
      s_why[$name]="reference over $nref runs: rc$rcs, asserts in [$lo,$hi]"
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
  # >>> guard:s-pass
  if [[ $rc -eq 0 && $c != none ]] && (( c >= lo && c <= hi )); then
    emit S "$name" PASS "asserts=$c$band"
    return
  fi
  # <<< guard:s-pass
  # >>> guard:s-fail
  [[ -n $band ]] || band=" ref=$lo"
  emit S "$name" FAIL "asserts cand=$c rc=$rc$band"
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
