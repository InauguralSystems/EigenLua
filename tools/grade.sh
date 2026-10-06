#!/usr/bin/env bash
# Grade a candidate against PUC-Rio Lua 5.4.9.
# tools/grade.sh --candidate <cmd> [--tier S|D|all] [--ref <path>] [--only a,b]
# Candidate argv is exactly: <cmd> <file>. Tier S passes the assert-count shim.
# Residuals: tier D ignores stderr. A nonzero reference exit is not a harness
# error. UNSTABLE is a row verdict and is not a SUMMARY field. --selftest
# execs tools/selftest.sh. Membership is the files on disk, both ways.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export LUA_HASHSEED=0
ulimit -c 0
if [[ ${1:-} == --selftest ]]; then
  exec "$ROOT/tools/selftest.sh"
fi
die() { printf 'HARNESS %s\n' "$*" >&2; exit 2; }
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
    printf '0\n'
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
write_shim() {
  local src=$1 dest=$2
  case $src in
    *\"*|*'\'*|*'|'*) die "shim path has a quote, bar, or backslash: $src" ;;
  esac
  awk -v p="$src" '{ gsub("__PATH__", p); print }' "$ROOT/tools/s_shim.lua" >"$dest"
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
declare -A s_status=() d_have=()
declare -a s_include=() d_names=()
while read -r status name reason; do
  [[ -z ${status:-} || ${status:0:1} == '#' ]] && continue
  [[ $status == include || $status == exclude ]] || die "bad S manifest status: $status"
  [[ -n ${s_status[$name]:-} ]] && die "duplicate S row: $name"
  s_status[$name]=$status
  [[ -f $SUITE/$name ]] || die "manifest row has no file: $name"
  if [[ $status == exclude ]]; then
    [[ -n ${reason:-} ]] || die "exclude without reason: $name"
  else
    s_include+=("$name")
  fi
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
declare -A d_exp_rc=() d_ms=() s_stable=() s_count=() s_ms=() s_shim=()
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
if (( ${#s_sel[@]} > 0 )); then
  for name in "${s_sel[@]}"; do
    shim="$WORK/shim-$name.lua"
    write_shim "$SUITE/$name" "$shim"
    s_shim[$name]=$shim
    pre="$WORK/s-$name"
    twice "$SUITE" 180 "$REF" "$shim" "$pre"
    if ref_signaled "$RC1" || ref_signaled "$RC2"; then
      die "reference failed on S/$name rc=$RC1/$RC2"
    fi
    c1=$(assert_count "$pre.1e")
    c2=$(assert_count "$pre.2e")
    if [[ $c1 != "$c2" || $RC1 -ne $RC2 ]]; then
      s_stable[$name]=0
    else
      s_stable[$name]=1
      s_count[$name]=$c1
    fi
    s_ms[$name]=$MS
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
  local name=$1 shim out err rc sec special c
  if [[ ${s_stable[$name]} -eq 0 ]]; then
    emit S "$name" UNSTABLE "reference assert count or rc disagreed across two runs"
    return
  fi
  shim=${s_shim[$name]}
  out="$WORK/s-$name.cand.out"
  err="$WORK/s-$name.cand.err"
  sec=$(row_timeout "${s_ms[$name]}")
  run_at "$SUITE" "$sec" "$CAND" "$shim" "$out" "$err"
  rc=$RUN_RC
  [[ $rc -eq 99 ]] && die "could not enter $SUITE"
  special=$(classify "$rc" "$err")
  if [[ -n $special ]]; then emit S "$name" "$special" "rc=$rc"; return; fi
  c=$(assert_count "$err")
  # >>> guard:s-pass
  if [[ $rc -eq 0 && $c -eq ${s_count[$name]} ]]; then
    emit S "$name" PASS "asserts=$c"
    return
  fi
  # <<< guard:s-pass
  # >>> guard:s-fail
  emit S "$name" FAIL "asserts ref=${s_count[$name]} cand=$c rc=$rc"
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
